import 'package:material_ui/material_ui.dart';

import '../../core/utils/feedback.dart';
import '../../services/download_center.dart';
import '../../services/download_utils.dart';
import '../../services/native_download_bridge.dart';

/// Built-in file manager for LANDeck's own file area.
///
/// Files downloaded by LANDeck live here. No SAF/DocumentsUI is involved.
class InternalFilesPage extends StatefulWidget {
  const InternalFilesPage({super.key});

  @override
  State<InternalFilesPage> createState() => _InternalFilesPageState();
}

class _InternalFilesPageState extends State<InternalFilesPage> {
  static const NativeFileBridge _bridge = NativeFileBridge();
  static const NativeDownloadBridge _downloads = NativeDownloadBridge();

  String _path = '';
  List<InternalFile> _entries = <InternalFile>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final List<InternalFile> entries = await _bridge.listInternalFiles(
      path: _path,
    );
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  void _openDirectory(InternalFile entry) {
    setState(() {
      _path = entry.path;
      _entries = <InternalFile>[];
      _loading = true;
    });
    _load();
  }

  void _goUp() {
    if (_path.isEmpty) return;
    final List<String> parts = _path.split('/')..removeLast();
    setState(() {
      _path = parts.join('/');
      _entries = <InternalFile>[];
      _loading = true;
    });
    _load();
  }

  Future<void> _openFile(InternalFile entry) async {
    final bool opened = await _downloads.openFile(
      uri: entry.uri,
      mimeType: mimeForFileName(entry.name),
    );
    if (!opened && mounted) {
      showAppSnackBar(context, '没有可打开此文件的应用');
    }
  }

  Future<void> _shareFile(InternalFile entry) async {
    final bool shared = await _downloads.shareFile(
      uri: entry.uri,
      mimeType: mimeForFileName(entry.name),
      fileName: entry.name,
    );
    if (!shared && mounted) {
      showAppSnackBar(context, '无法分享此文件');
    }
  }

  Future<void> _createFolder() async {
    final String? name = await _askName(title: '新建文件夹', hint: '文件夹名称');
    if (name == null || !mounted) return;
    final String? created = await _bridge.createInternalFolder(
      path: _path,
      name: name,
    );
    if (!mounted) return;
    if (created == null) {
      showAppSnackBar(context, '创建失败，可能已存在同名文件夹');
      return;
    }
    await _load();
  }

  Future<void> _rename(InternalFile entry) async {
    final String? name = await _askName(
      title: '重命名',
      hint: '新名称',
      initial: entry.name,
    );
    if (name == null || !mounted) return;
    final String? renamed = await _bridge.renameInternalEntry(
      path: entry.path,
      newName: name,
    );
    if (!mounted) return;
    if (renamed == null) {
      showAppSnackBar(context, '重命名失败，可能已存在同名项目');
      return;
    }
    await _load();
  }

  Future<void> _delete(InternalFile entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除？'),
        content: Text(
          entry.isDirectory
              ? '将删除「${entry.name}」及其中的所有文件，此操作不可撤销。'
              : '将删除「${entry.name}」，此操作不可撤销。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final bool deleted = await _bridge.deleteInternalEntry(path: entry.path);
    if (!mounted) return;
    if (!deleted) {
      showAppSnackBar(context, '删除失败');
      return;
    }
    await _load();
  }

  Future<void> _importFromUrl() async {
    final TextEditingController urlController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('从链接导入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '文件链接',
                hintText: 'http://192.168.1.10/file.bin',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '文件名（可选）',
                hintText: '留空则从链接推断',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('下载'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      urlController.dispose();
      nameController.dispose();
      return;
    }
    final String rawUrl = urlController.text.trim();
    final Uri? uri = Uri.tryParse(rawUrl);
    final String inferred = uri == null
        ? '下载文件'
        : fileNameFromUrl(rawUrl, fallback: '下载文件');
    final String name = nameController.text.trim().isEmpty
        ? inferred
        : nameController.text.trim();
    urlController.dispose();
    nameController.dispose();
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (mounted) showAppSnackBar(context, '请输入有效的 http/https 链接');
      return;
    }
    final String? destination = await _bridge.createInternalFile(
      path: _path,
      name: name,
    );
    if (!mounted) return;
    if (destination == null) {
      showAppSnackBar(context, '无法创建文件');
      return;
    }
    await DownloadCenter.instance.enqueue(
      service: null,
      url: rawUrl,
      fileName: name,
      mimeType: mimeForFileName(name),
      totalBytes: null,
      destinationUri: destination,
      headers: const <String, String>{},
    );
    if (!mounted) return;
    showAppSnackBar(context, '已加入下载队列');
  }

  Future<String?> _askName({
    required String title,
    required String hint,
    String initial = '',
  }) async {
    final TextEditingController controller = TextEditingController(
      text: initial,
    );
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (String value) =>
              Navigator.of(context).pop(value.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('内部文件'),
        actions: <Widget>[
          IconButton(
            tooltip: '从链接导入',
            onPressed: _importFromUrl,
            icon: const Icon(Icons.add_link_rounded),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建文件夹',
        onPressed: _createFolder,
        child: const Icon(Icons.create_new_folder_outlined),
      ),
      body: Column(
        children: <Widget>[
          _PathBar(path: _path, onUp: _path.isEmpty ? null : _goUp),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.folder_open_rounded,
                            size: 56,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text('这里还没有文件', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            '通过 LANDeck 下载的文件会保存到这里。',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final InternalFile entry = _entries[index];
                      return ListTile(
                        leading: Icon(
                          entry.isDirectory
                              ? Icons.folder_rounded
                              : _iconFor(entry.name),
                          color: entry.isDirectory
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          entry.isDirectory
                              ? '文件夹'
                              : '${_sizeLabel(entry.size)} · ${_dateLabel(entry.modified)}',
                        ),
                        onTap: () => entry.isDirectory
                            ? _openDirectory(entry)
                            : _openFile(entry),
                        trailing: PopupMenuButton<String>(
                          onSelected: (String action) {
                            switch (action) {
                              case 'rename':
                                _rename(entry);
                              case 'delete':
                                _delete(entry);
                              case 'share':
                                _shareFile(entry);
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'rename',
                                  child: Text('重命名'),
                                ),
                                if (!entry.isDirectory)
                                  const PopupMenuItem<String>(
                                    value: 'share',
                                    child: Text('分享 / 导出'),
                                  ),
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String name) {
    final String ext = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    return switch (ext) {
      'png' || 'jpg' || 'jpeg' || 'webp' || 'gif' => Icons.image_outlined,
      'mp4' || 'mkv' || 'mov' || 'avi' => Icons.movie_outlined,
      'mp3' || 'flac' || 'wav' => Icons.audio_file_outlined,
      'zip' || '7z' || 'rar' || 'tar' || 'gz' => Icons.folder_zip_outlined,
      'apk' => Icons.android_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'txt' ||
      'log' ||
      'json' ||
      'xml' ||
      'yaml' ||
      'yml' => Icons.description_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  static String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  static String _dateLabel(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _PathBar extends StatelessWidget {
  const _PathBar({required this.path, required this.onUp});

  final String path;
  final VoidCallback? onUp;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: '上一级',
            onPressed: onUp,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
          const Icon(Icons.folder_outlined, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              path.isEmpty ? '内部文件 / Downloads' : '内部文件 / $path',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
