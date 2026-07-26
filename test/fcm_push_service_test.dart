import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/services/fcm_push_service.dart';
import 'package:personal_cognitive/services/notification_service.dart';

void main() {
  test('FCM service singleton and token pref key are stable', () {
    expect(FcmPushService.instance, same(FcmPushService.instance));
    expect(prefFcmToken, 'fcm_device_token');
  });

  test('NotificationService singleton is ready for FCM bridge', () {
    expect(NotificationService.instance, same(NotificationService.instance));
  });
}
