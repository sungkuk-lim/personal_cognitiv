import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription_status.dart';
import '../services/subscription_service.dart';

final subscriptionStatusProvider = StateProvider<SubscriptionStatus>(
  (ref) => SubscriptionStatus.free(),
);

final hasProEntitlementProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionStatusProvider).isProActive;
});

final subscriptionRefreshProvider = FutureProvider.autoDispose<void>((ref) async {
  final status = await SubscriptionService.instance.refreshEntitlements();
  ref.read(subscriptionStatusProvider.notifier).state = status;
});
