import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/campus_preview_repository.dart';

/// 记录投票调用，用来证明「点选项」确实会打到服务端接口。
class _RecordingRepository extends CampusPreviewRepository {
  final List<(String, String)> votes = <(String, String)>[];

  @override
  Future<ForumPoll> voteForumPoll({
    required String threadId,
    required String optionId,
  }) {
    votes.add((threadId, optionId));
    return super.voteForumPoll(threadId: threadId, optionId: optionId);
  }
}

/// 线上 GET /api/v1/forum/threads/7fd85e7f-... 的真实响应（2026-11-10 14:04 抓取）。
const Map<String, dynamic> _serverThreadJson = <String, dynamic>{
  'id': '7fd85e7f-2167-4053-9e54-4baf0450e6fd',
  'category_id': 'general',
  'category': <String, dynamic>{'id': 'general', 'name': '日常'},
  'title': '五女一',
  'body': '',
  'author': <String, dynamic>{
    'id': 'p_1',
    'display_name': '友友',
    'avatar_preset': 1,
  },
  'image_asset_ids': <String>[],
  'reply_count': 0,
  'like_count': 0,
  'reactions': <dynamic>[],
  'my_reaction': null,
  'poll': <String, dynamic>{
    'question': '五女一',
    'total_votes': 0,
    'my_option_id': null,
    'options': <dynamic>[
      <String, dynamic>{
        'id': '3cc1c893-f142-47de-b72b-8da7ee5f9341',
        'label': '张元英',
        'count': 0,
        'percent': 0,
      },
      <String, dynamic>{
        'id': 'a43310f7-c4b0-4991-8423-fecef908a33d',
        'label': '柳智敏',
        'count': 0,
        'percent': 0,
      },
    ],
  },
  'linked_content': null,
  'my_like': false,
  'is_pinned': false,
  'is_locked': false,
  'status': 'normal',
  'version': 1,
  'created_at': '2026-11-08T10:37:13.000Z',
  'last_activity_at': '2026-11-08T10:37:13.000Z',
  'capabilities': <String, dynamic>{'can_edit': false},
};

void main() {
  test('线上真实响应能解析出结构化投票', () {
    final thread = ForumThread.fromJson(_serverThreadJson);
    expect(thread.title, '五女一');
    expect(thread.body, isEmpty);
    expect(thread.poll, isNotNull);
    expect(thread.poll!.question, '五女一');
    expect(thread.poll!.options.map((option) => option.label), ['张元英', '柳智敏']);
    expect(
      thread.poll!.options.first.id,
      '3cc1c893-f142-47de-b72b-8da7ee5f9341',
    );
    expect(thread.poll!.myOptionId, isNull);
  });

  testWidgets('点击投票选项会提交到服务端接口', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final thread = ForumThread.fromJson(_serverThreadJson);
    final repository = _RecordingRepository();
    repository.seedForumPoll(thread.id, thread.poll!);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForumPollCard(
              poll: thread.poll,
              repository: repository,
              threadId: thread.id,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('forum-poll-card')), findsOneWidget);
    expect(find.text('张元英'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('forum-poll-option-张元英')));
    await tester.pumpAndSettle();

    expect(repository.votes.length, 1);
    expect(repository.votes.single.$1, thread.id);
    expect(repository.votes.single.$2, '3cc1c893-f142-47de-b72b-8da7ee5f9341');
    expect(find.text('1人参与'), findsOneWidget);
  });
}
