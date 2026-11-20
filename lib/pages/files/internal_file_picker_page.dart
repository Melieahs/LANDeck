import 'package:material_ui/material_ui.dart';

import '../../core/utils/feedback.dart';
import '../../services/native_download_bridge.dart';

enum InternalFilePickMode { files, folder }

/// In-app file/folder picker for WebView uploads.
///
/// The user browses LANDeck's own directory tree; no system document picker
/// is opened. Returned values are FileProvider content URIs.
class InternalFilePickerPage extends StatefulWidget {
  const InternalFilePickerPage({
    super.key,
    required this.multiple,
    this.mode = InternalFilePickMode.files,
    this.title = '选择文件',
  });

  final bool multiple;
  final InternalFilePickMode mode;
  final String title;

  @override
  State<InternalFilePickerPage> createState() => _InternalFilePickerPageState();
}

class _InternalFilePickerPageState extends State<InternalFilePickerPage> {
  static const NativeFileBridge _bridge = NativeFileBridge();

  String _path = '';
  List<InternalFile> _entries = <InternalFile>[];
  final Set<String> _selected = <String>{};
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
      _selected.clear();
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
      _selected.clear();
      _loading = true;
    });
    _load();
  }

  void _toggle(InternalFile entry) {
    if (!widget.multiple) {
      Navigator.of(context).pop(<String>[entry.uri]);
      return;
    }
    setState(() {
      if (!_selected.remove(entry.uri)) _selected.add(entry.uri);
    });
  }

  void _confirmFiles() {
    if (_selected.isEmpty) return;
    Navigator.of(context).pop(_selected.toList());
  }

  Future<void> _confirmFolder() async {
    final List<InternalFile> all = await _bridge.listInternalFilesRecursive(
      path: _path,
    );
    if (!mounted) return;
    if (all.isEmpty) {
      showAppSnackBar(context, '这个文件夹里没有文件');
      return;
    }
    Navigator.of(context)
        .pop(all.map((InternalFile file) => file.uri).toList());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool folderMode = widget.mode == InternalFilePickMode.folder;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: '上一级',
                  onPressed: _path.isEmpty ? null : _goUp,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                const Icon(Icons.folder_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _path.isEmpty ? '内部文件 / Downloads' : '内部文件 / $_path',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                ? _EmptyPicker(folderMode: folderMode)
                : ListView.separated(
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final InternalFile entry = _entries[index];
                      final bool selected = _selected.contains(entry.uri);
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
                        subtitle: entry.isDirectory
                            ? const Text('文件夹')
                            : Text(
                                '${_sizeLabel(entry.size)} · ${_dateLabel(entry.modified)}',
                              ),
                        trailing: entry.isDirectory
                            ? const Icon(Icons.chevron_right_rounded)
                            : widget.multiple
                            ? Checkbox(
                                value: selected,
                                onChanged: (_) => _toggle(entry),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: () => entry.isDirectory
                            ? _openDirectory(entry)
                            : _toggle(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: folderMode
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: _confirmFolder,
                icon: const Icon(Icons.drive_folder_upload_outlined),
                label: Text(
                  _path.isEmpty ? '使用 Downloads 文件夹' : '使用「$_path」文件夹',
                ),
              ),
            )
          : widget.multiple
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: _selected.isEmpty ? null : _confirmFiles,
                child: Text(
                  _selected.isEmpty ? '选择文件' : '上传 ${_selected.length} 个文件',
                ),
              ),
            )
          : null,
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

class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker({required this.folderMode});

  final bool folderMode;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
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
            Text('这个文件夹是空的', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '通过 LANDeck 下载的文件会保存在应用内；也可以先新建文件夹整理。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (!folderMode)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(<String>[]),
                child: const Text('取消'),
              ),
          ],
        ),
      ),
    );
  }
}
