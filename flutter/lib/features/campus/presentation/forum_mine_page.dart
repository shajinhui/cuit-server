import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_widgets.dart';
import 'forum_widgets.dart';

/// 我的帖子列表。帖子管理（删除、编辑）属于后续范围，这里只做查看与跳转。
class ForumMinePage extends StatefulWidget {
  const ForumMinePage({super.key, required this.repository});

  final CampusRepository? repository;

  @override
  State<ForumMinePage> createState() => _ForumMinePageState();
}

class _ForumMinePageState extends State<ForumMinePage> {
  List<ForumThread> _threads = [];
  String? _cursor;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _requestVersion++;
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final repository = widget.repository;
    final version = ++_requestVersion;
    setState(() {
      _loading = reset;
      _loadingMore = !reset;
      _error = null;
    });
    try {
      if (repository == null) {
        throw const CampusRepositoryException('论坛服务暂时不可用。');
      }
      final page = await repository.listForumThreads(
        mine: true,
        cursor: reset ? null : _cursor,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _threads = reset ? page.items : [..._threads, ...page.items];
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted && version == _requestVersion) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openThread(ForumThread thread) async {
    await context.pushNamed(
      'forum-thread',
      pathParameters: {'threadId': thread.id},
    );
    if (mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: '我的帖子',
    child: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _loading && _threads.isEmpty
          ? const CampusPageState(title: '正在加载我的帖子', loading: true)
          : _error != null && _threads.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                CampusPageState(
                  title: '暂时无法加载',
                  description: _error,
                  actionLabel: '重新加载',
                  onAction: () => _load(reset: true),
                ),
              ],
            )
          : _threads.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                CampusPageState(
                  title: '还没有发过帖子',
                  description: '在校园论坛发帖后，你的帖子会出现在这里。',
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                for (final thread in _threads)
                  ForumThreadCard(
                    thread: thread,
                    repository: widget.repository,
                    showCategory: true,
                    onTap: () => _openThread(thread),
                  ),
                if (_hasMore)
                  Center(
                    child: OutlinedButton(
                      onPressed: _loadingMore
                          ? null
                          : () => _load(reset: false),
                      child: Text(_loadingMore ? '正在加载…' : '加载更多'),
                    ),
                  ),
              ],
            ),
    ),
  );
}
