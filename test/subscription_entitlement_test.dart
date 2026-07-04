import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/core/app_maturity.dart';
import 'package:personal_cognitive/core/subscription_config.dart';
import 'package:personal_cognitive/models/subscription_status.dart';
import 'package:personal_cognitive/services/entitlement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('SubscriptionStatus.isProActive respects tier status and expiry', () {
    expect(SubscriptionStatus.free().isProActive, isFalse);
    expect(
      const SubscriptionStatus(tier: 'pro', status: 'active').isProActive,
      isTrue,
    );
    expect(
      const SubscriptionStatus(tier: 'pro', status: 'trialing').isProActive,
      isTrue,
    );
    expect(
      SubscriptionStatus(
        tier: 'pro',
        status: 'active',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      ).isProActive,
      isFalse,
    );
  });

  test('Pro quotas constants match server migration', () {
    expect(SubscriptionConfig.quotaChatMonthly, 500);
    expect(SubscriptionConfig.quotaEmbeddingMonthly, 300);
    expect(SubscriptionConfig.quotaVisionMonthly, 100);
  });

  test('canUseCloudFeatures requires pro when logged in path', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(
      canUseCloudFeatures(
        prefs,
        subscription: SubscriptionStatus.free(),
        guestMode: true,
      ),
      isFalse,
    );

    expect(
      canUseCloudFeatures(
        prefs,
        subscription: const SubscriptionStatus(tier: 'pro', status: 'active'),
        guestMode: true,
      ),
      isFalse,
    );
  });

  test('canUseCloudFeatures requires pro at production maturity', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(requiresProCloudForCloudFeatures, isTrue);
    expect(kAppCompletionPercent, greaterThanOrEqualTo(kProCloudGatePercent));
    // Supabase 미초기화 환경에서는 isConfigured/currentUser 검사로 false.
    expect(
      canUseCloudFeatures(
        prefs,
        subscription: SubscriptionStatus.free(),
        guestMode: false,
      ),
      isFalse,
    );
  });
}
