import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tool_page_scaffold.dart';

class PastExamsPage extends StatefulWidget {
  const PastExamsPage({super.key});
  @override
  State<PastExamsPage> createState() => _PastExamsPageState();
}

class _PastExamsPageState extends State<PastExamsPage> {
  static const _fileHost = 'https://cuit-server.pages.dev';
  final _searchController = TextEditingController();
  List<_PastFile> _files = [];
  String _commit = '';
  String _updatedAt = '';
  String _sourceUrl = '';
  String _directory = '';
  String _query = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/data/past-exams-index.json',
                ),
              )
              as Map<String, dynamic>;
      final files = (raw['files'] as List)
          .map((item) => _PastFile.fromJson(item as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _files = files;
          _commit = raw['commit'] as String;
          _sourceUrl = raw['sourceURL'] as String;
          _updatedAt = '${raw['updatedAt'] ?? ''}'.split('T').first;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '资料目录读取失败，请稍后重试。';
          _loading = false;
        });
      }
    }
  }

  List<_PastItem> get _items {
    if (_query.trim().isNotEmpty) {
      final keywords = _query.trim().toLowerCase().split(RegExp(r'\s+'));
      return _files
          .where(
            (file) => keywords.every(
              (word) => file.path.toLowerCase().contains(word),
            ),
          )
          .map(_PastItem.file)
          .toList();
    }
    final prefix = _directory.isEmpty ? '' : '$_directory/';
    final directories = <String, int>{};
    final directFiles = <_PastItem>[];
    for (final file in _files) {
      if (!file.path.startsWith(prefix)) continue;
      final remainder = file.path.substring(prefix.length);
      final slash = remainder.indexOf('/');
      if (slash < 0) {
        directFiles.add(_PastItem.file(file));
      } else {
        final name = remainder.substring(0, slash);
        directories[name] = (directories[name] ?? 0) + 1;
      }
    }
    final result = directories.entries
        .map(
          (entry) => _PastItem.directory(
            name: entry.key,
            path: prefix.isEmpty ? entry.key : '$_directory/${entry.key}',
            fileCount: entry.value,
          ),
        )
        .toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    directFiles.sort((a, b) => a.name.compareTo(b.name));
    return [...result, ...directFiles];
  }

  List<(String, String)> get _breadcrumbs {
    var path = '';
    final result = <(String, String)>[];
    for (final segment
        in _directory.split('/').where((item) => item.isNotEmpty)) {
      path = path.isEmpty ? segment : '$path/$segment';
      result.add((segment, path));
    }
    return result;
  }

  Future<void> _openFile(_PastFile file, {required bool download}) async {
    final encodedPath = file.path.split('/').map(Uri.encodeComponent).join('/');
    final uri = Uri.parse(
      '$_fileHost/past-exams/files/$_commit/$encodedPath?${download ? 'download' : 'view'}=1',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开文件链接，请检查网络后重试')));
    }
  }

  void _back() {
    if (_query.isNotEmpty) {
      _searchController.clear();
      setState(() => _query = '');
    } else if (_directory.isNotEmpty) {
      final segments = _directory.split('/')..removeLast();
      setState(() => _directory = segments.join('/'));
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final rootDirectories = _files
        .map((file) => file.path.split('/').first)
        .toSet()
        .length;
    final totalBytes = _files.fold<int>(0, (total, file) => total + file.size);
    final title = _query.isNotEmpty
        ? '搜索结果'
        : _directory.isEmpty
        ? '全部课程'
        : _directory.split('/').last;
    return ToolPageScaffold(
      title: '历年试卷',
      subtitle: 'GitHub 课程资料',
      onBack: _back,
      actions: [
        IconButton(
          tooltip: '查看资料来源',
          onPressed: _sourceUrl.isEmpty
              ? null
              : () => launchUrl(
                  Uri.parse(_sourceUrl),
                  mode: LaunchMode.externalApplication,
                ),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
      child: _loading
          ? const ToolLoading(label: '正在整理资料目录…')
          : _error != null
          ? ToolMessage(message: _error!, onRetry: _load)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              itemCount: items.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToolCard(
                        padding: const EdgeInsets.all(18),
                        radius: 24,
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/icons/tools/tool-past-exams.png',
                              width: 58,
                              height: 58,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CUIT SHARING',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: .8,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Text(
                                    '课程共享库',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$rootDirectories 个课程目录 · ${_files.length} 份资料',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    _formatSize(totalBytes),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: '搜索课程、文件夹或文件名',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                ),
                        ),
                      ),
                      if (_query.isEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _breadcrumb('全部课程', ''),
                              for (final entry in _breadcrumbs) ...[
                                const Text('›'),
                                _breadcrumb(entry.$1, entry.$2),
                              ],
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: ToolSectionHeading(
                          title: title,
                          subtitle: _query.isNotEmpty ? '全库搜索' : '当前位置',
                          subtitleAbove: true,
                          trailing: '${items.length} 项',
                        ),
                      ),
                    ],
                  );
                }
                if (index == items.length + 1) {
                  return Column(
                    children: [
                      if (items.isEmpty)
                        const ToolCard(
                          child: ToolMessage(message: '没有找到相关资料。'),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        '目录更新于 $_updatedAt · GitHub 课程共享资料',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }
                final item = items[index - 1];
                final directory = item.file == null;
                final color = directory
                    ? toolAccent(context)
                    : switch (item.file!.extension) {
                        'pdf' => const Color(0xFFE65E58),
                        'doc' || 'docx' => const Color(0xFF397CDA),
                        'xls' || 'xlsx' => const Color(0xFF2D9D74),
                        _ => const Color(0xFF8B79BB),
                      };
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: index == items.length
                      ? const BorderRadius.vertical(bottom: Radius.circular(24))
                      : BorderRadius.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Divider(height: 1, thickness: .5),
                      ),
                      InkWell(
                        onTap: directory
                            ? () => setState(() => _directory = item.path)
                            : () => _openFile(item.file!, download: false),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: directory
                                    ? Icon(
                                        Icons.folder_outlined,
                                        color: color,
                                        size: 24,
                                      )
                                    : Text(
                                        item.file!.extension.toUpperCase(),
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _itemDescription(item),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (directory)
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                )
                              else
                                TextButton(
                                  onPressed: () =>
                                      _openFile(item.file!, download: true),
                                  child: const Text(
                                    '下载',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _itemDescription(_PastItem item) {
    final file = item.file;
    if (file == null) return '${item.fileCount} 份资料';
    if (_query.isEmpty) return _formatSize(file.size);
    final parts = file.path.split('/')..removeLast();
    final location = parts.isEmpty ? '根目录' : parts.join('/');
    return '$location · ${_formatSize(file.size)}';
  }

  Widget _breadcrumb(String label, String path) => TextButton(
    onPressed: () => setState(() => _directory = path),
    child: Text(label, style: const TextStyle(fontSize: 13)),
  );
}

class _PastFile {
  const _PastFile(this.path, this.name, this.extension, this.size);
  final String path;
  final String name;
  final String extension;
  final int size;
  factory _PastFile.fromJson(Map<String, dynamic> json) => _PastFile(
    json['path'] as String,
    json['name'] as String,
    json['extension'] as String,
    (json['size'] as num).toInt(),
  );
}

class _PastItem {
  const _PastItem._({
    required this.name,
    this.path = '',
    this.fileCount = 0,
    this.file,
  });
  factory _PastItem.file(_PastFile file) =>
      _PastItem._(name: file.name, file: file);
  factory _PastItem.directory({
    required String name,
    required String path,
    required int fileCount,
  }) => _PastItem._(name: name, path: path, fileCount: fileCount);
  final String name;
  final String path;
  final int fileCount;
  final _PastFile? file;
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
