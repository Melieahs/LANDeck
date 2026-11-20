import 'package:material_ui/material_ui.dart';

import '../../services/native_download_bridge.dart';

/// In-app replacement for the Android document picker.
///
/// Lists files downloaded or stored in LANDeck's own Downloads directory and
/// returns `content://` URIs that the WebView can upload.
class InternalFilePickerPage extends StatefulWidget {
  const InternalFilePickerPage({
    super.key,
    required this.multiple,
    this.title = '选择文件',
  });

  final bool multiple;
  final String title;

  @override
  State<InternalFilePickerPage> createState() => _InternalFilePickerPageState();
}

class _InternalFilePickerPageState extends State<InternalFilePickerPage> {
  static const NativeFileBridge _bridge = NativeFileBridge();
  List<InternalFile> _files = <InternalFile>[];
  final Set<String> _selected = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<InternalFile> files = await _bridge.listInternalFiles();
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  void _toggle(InternalFile file) {
    if (!widget.multiple) {
      Navigator.of(context).pop(<String>[file.uri]);
      return;
    }
    setState(() {
      if (!_selected.remove(file.uri)) {
        _selected.add(file.uri);
      }
    });
  }

  void _confirm() {
    if (_selected.isEmpty) return;
    Navigator.of(context).pop(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          if (widget.multiple && _files.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selected.length == _files.length) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(_files.map((InternalFile file) => file.uri));
                  }
                });
              },
              child: Text(_selected.length == _files.length ? '取消全选' : '全选'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
          ? _EmptyInternalFiles(onRefresh: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _files.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final InternalFile file = _files[index];
                  final bool selected = _selected.contains(file.uri);
                  return ListTile(
                    leading: Icon(
                      _iconFor(file.name),
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_sizeLabel(file.size)} · ${_dateLabel(file.modified)}',
                    ),
                    trailing: widget.multiple
                        ? Checkbox(
                            value: selected,
                            onChanged: (_) => _toggle(file),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => _toggle(file),
                  );
                },
              ),
            ),
      bottomNavigationBar: widget.multiple
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: _selected.isEmpty ? null : _confirm,
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

class _EmptyInternalFiles extends StatelessWidget {
  const _EmptyInternalFiles({required this.onRefresh});

  final Future<void> Function() onRefresh;

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
            const SizedBox(height: 16),
            Text('内部目录暂无文件', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '通过 LANDeck 下载的文件会保存在应用内，之后可在这里选择上传。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }
}
