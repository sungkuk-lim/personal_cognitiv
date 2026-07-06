import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import 'local_memory_store.dart';
import 'subscription_service.dart';

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.success,
    this.message = '',
  });

  final bool success;
  final String message;
}

/// Google Play 정책: 앱 내 계정·기억 데이터 삭제 요청.
Future<AccountDeletionResult> deleteUserAccountAndData({
  required SharedPreferences prefs,
}) async {
  if (!AppEnv.isConfigured) {
    return const AccountDeletionResult(
      success: false,
      message: 'cloud_not_configured',
    );
  }

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    return const AccountDeletionResult(success: false, message: 'not_signed_in');
  }

  try {
    await client.rpc('delete_user_account');
  } catch (e) {
    debugPrint('delete_user_account RPC failed (run migration 005): $e');
    try {
      await client.from('memories').delete().eq('user_id', user.id);
      await client.from('ai_usage_monthly').delete().eq('user_id', user.id);
      await client.from('user_subscriptions').delete().eq('user_id', user.id);
    } catch (e2) {
      debugPrint('Fallback delete failed: $e2');
      return AccountDeletionResult(success: false, message: e2.toString());
    }
  }

  try {
    final bucket = client.storage.from('memory_images');
    final files = await bucket.list(path: user.id);
    if (files.isNotEmpty) {
      await bucket.remove(files.map((f) => '${user.id}/${f.name}').toList());
    }
  } catch (e) {
    debugPrint('Storage cleanup skipped: $e');
  }

  await LocalMemoryStore(prefs).clearAll();
  await SubscriptionService.instance.syncAfterLogout();
  await client.auth.signOut();

  return const AccountDeletionResult(success: true);
}
