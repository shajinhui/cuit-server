import 'package:flutter_test/flutter_test.dart';

import 'package:chengxin_youyou/features/push/push_service.dart';

void main() {
  test(
    'parses a community reply target and preserves its deep link payload',
    () {
      const target = PushNotificationTarget(
        threadId: 'thread-1',
        replyId: 'reply-2',
      );

      expect(
        PushNotificationTarget.fromData({
          'type': 'community_reply',
          'thread_id': 'thread-1',
          'reply_id': 'reply-2',
        }),
        isNotNull,
      );
      expect(
        PushNotificationTarget.fromLocalPayload(target.toPayload())?.threadId,
        'thread-1',
      );
      expect(
        PushNotificationTarget.fromLocalPayload(target.toPayload())?.replyId,
        'reply-2',
      );
    },
  );

  test('ignores unrelated or malformed push payloads', () {
    expect(PushNotificationTarget.fromData({}), isNull);
    expect(
      PushNotificationTarget.fromData({
        'type': 'announcement',
        'thread_id': 'thread-1',
      }),
      isNull,
    );
    expect(PushNotificationTarget.fromLocalPayload('{bad json}'), isNull);
  });
}
