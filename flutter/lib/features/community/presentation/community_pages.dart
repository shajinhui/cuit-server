import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../ui/components/page_dialog.dart';
import '../../../ui/components/page_layout.dart';
import '../../campus/data/campus_repository.dart';
import '../../campus/models/campus_models.dart';
import '../../campus/presentation/campus_image_picker.dart';
import '../../campus/presentation/campus_widgets.dart';
import '../../campus/presentation/forum_widgets.dart';
import '../../profile/data/profile_avatar.dart';
import '../models/community_models.dart';
import 'community_scope.dart';
import 'community_view_model.dart';

class CommunityProfileEditorPage extends StatefulWidget {
  const CommunityProfileEditorPage({super.key, this.localAvatar});
  final ProfileAvatar? localAvatar;
  @override
  State<CommunityProfileEditorPage> createState() =>
      _CommunityProfileEditorPageState();
}

class _CommunityProfileEditorPageState
    extends State<CommunityProfileEditorPage> {
  final _name = TextEditingController();
  CommunityViewModel? _model;
  int _preset = 1;
  String? _assetId, _error;
  Uint8List? _image;
  String _mime = 'image/png';
  bool _initialized = false, _loading = true, _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model = CommunityScope.maybeOf(context);
    if (!_initialized) {
      _initialized = true;
      scheduleMicrotask(_load);
    }
  }

  Future<void> _load() async {
    final model = _model;
    if (model == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await model.loadProfile(refresh: true);
    if (!mounted) return;
    final profile = model.profile;
    setState(() {
      _loading = false;
      _error = model.error;
      if (profile != null) {
        _name.text = profile.displayName;
        _preset = profile.avatarPreset.clamp(1, 15);
        _assetId = profile.avatarAssetId;
      }
    });
  }

  Future<void> _pick() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final image = await readCampusUploadImage(file);
      if (image.bytes.length > 2 * 1024 * 1024) {
        throw const CampusImageException('头像不能超过 2 MB，请换一张图片。');
      }
      if (mounted) {
        setState(() {
          _image = image.bytes;
          _mime = image.mimeType;
          _assetId = null;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _useLocal() {
    final local = widget.localAvatar;
    if (local == null) return;
    setState(() {
      _image = local.customImage;
      _mime = 'image/png';
      _preset = local.presetId;
      _assetId = null;
      _error = null;
    });
  }

  Future<void> _save() async {
    final model = _model;
    final name = _name.text.trim();
    if (model == null || model.profile == null || _saving) return;
    if (name.characters.length < 2 ||
        name.characters.length > 24 ||
        RegExp(r'[\x00-\x1f\x7f\n\r]').hasMatch(name)) {
      setState(() => _error = '昵称须为 2 至 24 个字，不能包含换行或控制字符。');
      return;
    }
    setState(() => _saving = true);
    final confirmed = await showPageConfirmation(
      context,
      title: '保存公开资料？',
      content: const Text(
        '昵称和头像会显示在评分、二手、论坛及个人主页，已登录社区的用户可以看到。学校姓名、学号、成绩和课表不会同步公开。',
      ),
      confirmLabel: '保存并公开',
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _saving = false);
      return;
    }
    try {
      var asset = _assetId;
      if (_image != null) {
        asset = await model.campus.uploadAsset(
          filename: _mime == 'image/jpeg' ? 'avatar.jpg' : 'avatar.png',
          bytes: _image!,
          mimeType: _mime,
        );
      }
      if (!mounted) return;
      // Retain a successful upload for retry if only the profile write fails.
      if (_image != null) {
        setState(() {
          _assetId = asset;
          _image = null;
        });
      }
      await model.saveProfile(
        displayName: name,
        avatarPreset: _preset,
        avatarAssetId: asset,
      );
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      if (error is CampusRepositoryException && error.statusCode == 409) {
        await model.loadProfile(refresh: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    final profile = model?.profile;
    return PageScaffold(
      title: '公开资料',
      child: _loading
          ? const CampusPageState(title: '正在加载公开资料', loading: true)
          : profile == null
          ? CampusPageState(
              title: '暂时无法编辑公开资料',
              description: _error ?? '请使用真实账号登录，社区服务暂不可用。',
              actionLabel: '重新加载',
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '在校园社区里认识彼此',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  '仅公开你主动设置的昵称和头像，不会公开学籍信息。',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
                Center(
                  child: _image != null
                      ? ClipOval(
                          child: Image.memory(
                            _image!,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CampusAuthorAvatar(
                          author: CampusAuthor(
                            id: '',
                            displayName: _name.text,
                            avatarPreset: _preset,
                            avatarAssetId: _assetId,
                          ),
                          radius: 44,
                          repository: model!.campus,
                          linkToProfile: false,
                        ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _saving ? null : _pick,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('选择照片'),
                    ),
                    if (widget.localAvatar != null)
                      TextButton(
                        onPressed: _saving ? null : _useLocal,
                        child: const Text('使用本机头像'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                PageCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const Key('community-nickname'),
                        controller: _name,
                        enabled: !_saving,
                        maxLength: 24,
                        decoration: const InputDecoration(
                          labelText: '公开昵称',
                          helperText: '不必填写学校姓名或学号',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '预设头像',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          15,
                          (index) => Semantics(
                            label: '预设头像 ${index + 1}',
                            selected:
                                _image == null &&
                                _assetId == null &&
                                _preset == index + 1,
                            button: true,
                            child: InkWell(
                              onTap: _saving
                                  ? null
                                  : () => setState(() {
                                      _preset = index + 1;
                                      _assetId = null;
                                      _image = null;
                                    }),
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 48,
                                height: 48,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    width: 2,
                                    color:
                                        _image == null &&
                                            _assetId == null &&
                                            _preset == index + 1
                                        ? pageAccent(context)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/avatars/avatar-${(index + 1).toString().padLeft(2, '0')}.jpg',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('community-profile-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '正在保存…' : '保存公开资料'),
                ),
                const SizedBox(height: 16),
                const Text(
                  '照片会在确认保存后上传。历史帖子也会显示更新后的资料；收藏和消息仍仅你本人可见。',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
    );
  }
}

class CommunityProfilePage extends StatefulWidget {
  const CommunityProfilePage({super.key, required this.profileId});
  final String profileId;
  @override
  State<CommunityProfilePage> createState() => _CommunityProfilePageState();
}

class _CommunityProfilePageState extends State<CommunityProfilePage> {
  CommunityViewModel? _model;
  CampusAuthor? _profile;
  final List<ForumThread> _threads = [];
  String? _cursor, _error;
  bool _started = false, _loading = true, _more = false;
  int _request = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model = CommunityScope.maybeOf(context);
    if (!_started) {
      _started = true;
      scheduleMicrotask(() => _load(true));
    }
  }

  Future<void> _load(bool reset) async {
    final version = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final model = _model;
      if (model == null) throw const CampusRepositoryException('社区服务暂不可用。');
      final profile = await model.repository.getCommunityProfile(
        profileId: widget.profileId,
      );
      final page = await model.repository.listProfileThreads(
        widget.profileId,
        cursor: reset ? null : _cursor,
      );
      if (!mounted || version != _request) return;
      setState(() {
        _profile = profile;
        if (reset) _threads.clear();
        final all = {
          for (final t in _threads) t.id: t,
          for (final t in page.items) t.id: t,
        };
        _threads
          ..clear()
          ..addAll(all.values);
        _cursor = page.nextCursor;
        _more = page.hasMore;
      });
    } catch (error) {
      if (mounted && version == _request) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && version == _request) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: '个人主页',
    child: RefreshIndicator(
      onRefresh: () => _load(true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_profile != null)
            PageCard(
              child: Column(
                children: [
                  CampusAuthorAvatar(
                    author: _profile!,
                    radius: 36,
                    linkToProfile: false,
                  ),
                  const SizedBox(height: 10),
                  CampusAuthorName(
                    author: _profile!,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '公开资料 · 仅展示正常公开的帖子',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const Text('发布的帖子', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (_error != null)
            CampusPageState(
              title: '暂时无法加载',
              description: _error,
              actionLabel: '重试',
              onAction: () => _load(true),
            ),
          if (_loading && _threads.isEmpty)
            const CampusPageState(title: '正在加载', loading: true)
          else if (_threads.isEmpty && _error == null)
            const CampusPageState(title: '还没有公开帖子'),
          for (final thread in _threads)
            ForumThreadCard(
              thread: thread,
              repository: _model?.campus,
              onTap: () async {
                await context.pushNamed(
                  'forum-thread',
                  pathParameters: {'threadId': thread.id},
                );
                if (mounted) await _load(true);
              },
            ),
          if (_more)
            TextButton(
              onPressed: _loading ? null : () => _load(false),
              child: Text(_loading ? '加载中…' : '加载更多'),
            ),
        ],
      ),
    ),
  );
}

class CommunityListPage extends StatefulWidget {
  const CommunityListPage({super.key, this.favorites = false});
  final bool favorites;
  @override
  State<CommunityListPage> createState() => _CommunityListPageState();
}

class _CommunityListPageState extends State<CommunityListPage> {
  CommunityViewModel? _model;
  final List<CommunityNotification> _messages = [];
  final List<CommunityFavorite> _favorites = [];
  final Set<String> _read = {}, _busy = {};
  String? _cursor, _error;
  String _watermark = '0';
  bool _started = false, _loading = true, _more = false, _reading = false;
  int _request = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model = CommunityScope.maybeOf(context);
    if (!_started) {
      _started = true;
      scheduleMicrotask(() => _load(true));
    }
  }

  Future<void> _load(bool reset) async {
    final version = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final model = _model;
      if (model == null) throw const CampusRepositoryException('请使用真实账号登录社区。');
      if (widget.favorites) {
        final page = await model.repository.listFavorites(
          cursor: reset ? null : _cursor,
        );
        if (!mounted || version != _request) return;
        setState(() {
          if (reset) _favorites.clear();
          final merged = {
            for (final f in _favorites) f.targetId: f,
            for (final f in page.items) f.targetId: f,
          };
          _favorites
            ..clear()
            ..addAll(merged.values);
          _cursor = page.nextCursor;
          _more = page.hasMore;
        });
      } else {
        final inbox = await model.repository.listNotifications(
          cursor: reset ? null : _cursor,
        );
        if (!mounted || version != _request) return;
        setState(() {
          if (reset) {
            _messages.clear();
            _read.clear();
            _watermark = inbox.readWatermark;
          }
          final merged = {
            for (final m in _messages) m.id: m,
            for (final m in inbox.page.items) m.id: m,
          };
          _messages
            ..clear()
            ..addAll(merged.values);
          _cursor = inbox.page.nextCursor;
          _more = inbox.page.hasMore;
        });
        model.setUnreadCount(inbox.unreadCount);
      }
    } catch (error) {
      if (mounted && version == _request) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && version == _request) setState(() => _loading = false);
    }
  }

  Future<void> _readAll() async {
    final model = _model;
    if (model == null || _reading || _loading) return;
    setState(() => _reading = true);
    final watermark = _watermark;
    try {
      final count = await model.repository.readAllNotifications(watermark);
      if (!mounted) return;
      setState(() {
        for (final m in _messages) {
          if (BigInt.parse(m.id) <= BigInt.parse(watermark)) _read.add(m.id);
        }
      });
      model.setUnreadCount(count);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _markRead(CommunityNotification message) async {
    if (message.isRead ||
        _read.contains(message.id) ||
        _busy.contains(message.id)) {
      return;
    }
    _busy.add(message.id);
    try {
      await _model!.repository.readNotification(message.id);
      if (mounted) {
        setState(() => _read.add(message.id));
        await _model!.refreshUnread(force: true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _busy.remove(message.id);
    }
  }

  Future<void> _openMessage(CommunityNotification message) async {
    unawaited(_markRead(message));
    if (!message.available || message.threadId == null) return;
    await context.pushNamed(
      'forum-thread',
      pathParameters: {'threadId': message.threadId!},
      queryParameters: {if (message.replyId != null) 'reply': message.replyId!},
    );
    if (mounted) await _load(true);
  }

  Future<void> _remove(CommunityFavorite favorite) async {
    if (_busy.contains(favorite.targetId)) return;
    setState(() => _busy.add(favorite.targetId));
    try {
      await _model!.repository.setForumFavorite(favorite.targetId, false);
      if (mounted) {
        setState(
          () => _favorites.removeWhere((f) => f.targetId == favorite.targetId),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(favorite.targetId));
    }
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empty = widget.favorites ? _favorites.isEmpty : _messages.isEmpty;
    return PageScaffold(
      title: widget.favorites ? '我的收藏' : '互动消息',
      actions: [
        if (!widget.favorites)
          TextButton(
            onPressed: _loading || _reading || _watermark == '0'
                ? null
                : _readAll,
            child: Text(_reading ? '处理中…' : '全部已读'),
          ),
      ],
      child: RefreshIndicator(
        onRefresh: () => _load(true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.favorites ? '仅你可见 · 论坛帖子' : '帖子和回复的互动提醒 · 仅你可见',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              CampusPageState(
                title: '暂时无法加载',
                description: _error,
                actionLabel: '重试',
                onAction: () => _load(true),
              ),
            if (_loading && empty)
              const CampusPageState(title: '正在加载', loading: true)
            else if (empty && _error == null)
              CampusPageState(
                title: widget.favorites ? '还没有收藏的帖子' : '还没有互动消息',
                description: widget.favorites
                    ? '在帖子详情点一下收藏，之后可以在这里找到。'
                    : '有人回复你的帖子或回复时，会在这里提醒你。',
              ),
            for (final m in _messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PageCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    key: ValueKey('community-message-${m.id}'),
                    contentPadding: const EdgeInsets.all(12),
                    isThreeLine: true,
                    leading: m.actor == null
                        ? const Icon(Icons.chat_bubble_outline_rounded)
                        : CampusAuthorAvatar(author: m.actor!, radius: 18),
                    title: Text(
                      m.actor == null
                          ? '内容暂不可见'
                          : '${m.actor!.displayName}${m.kind == 'reply_reply' ? '回复了你的回复' : '回复了你的帖子'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${m.available ? m.excerpt : '原内容已删除、隐藏或无法访问'}\n${campusFormatTime(m.createdAt)}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                    trailing: !m.isRead && !_read.contains(m.id)
                        ? Semantics(
                            label: '未读',
                            child: Icon(
                              Icons.check_circle_outline_rounded,
                              size: 8,
                              color: pageAccent(context),
                            ),
                          )
                        : null,
                    onTap: () => _openMessage(m),
                  ),
                ),
              ),
            for (final f in _favorites)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PageCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    key: ValueKey('community-favorite-${f.targetId}'),
                    contentPadding: const EdgeInsets.all(12),
                    title: Text(
                      f.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      f.available ? f.excerpt : '原内容已不可见，可以取消收藏。',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    trailing: IconButton(
                      tooltip: '取消收藏',
                      onPressed: _busy.contains(f.targetId)
                          ? null
                          : () => _remove(f),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    onTap: !f.available
                        ? null
                        : () async {
                            await context.pushNamed(
                              'forum-thread',
                              pathParameters: {'threadId': f.targetId},
                            );
                            if (mounted) await _load(true);
                          },
                  ),
                ),
              ),
            if (_more)
              TextButton(
                onPressed: _loading ? null : () => _load(false),
                child: Text(_loading ? '加载中…' : '加载更多'),
              ),
          ],
        ),
      ),
    );
  }
}
