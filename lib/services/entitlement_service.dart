import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_maturity.dart';
import '../core/env.dart';
import '../models/subscription_status.dart';
import '../services/local_memory_store.dart';
import '../providers/app_providers.dart';
import '../providers/subscription_providers.dart';
import '../features/subscription/paywall_sheet.dart';

/// Pro 클라우드·AI 사용 가능 여부.
bool hasProEntitlement(SubscriptionStatus status) {
  if (AppEnv.devProBypass) return true;
  return status.isProActive;
}

/// 클라우드 저장·동기화·AI — Pro 필요 (게스트/프라이버시는 로컬).
bool canUseCloudFeatures(
  SharedPreferences prefs, {
  required SubscriptionStatus subscription,
  bool privacyMode = false,
  bool guestMode = false,
}) {
  if (isLocalOnlyMode(prefs, privacyMode: privacyMode, guestMode: guestMode)) {
    return false;
  }
  if (!AppEnv.isConfigured) return false;
  if (Supabase.instance.client.auth.currentUser == null) return false;
  if (!requiresProCloudForCloudFeatures) return true;
  return hasProEntitlement(subscription);
}

Future<bool> requireProOrShowPaywall(
  BuildContext context,
  WidgetRef ref, {
  String? reasonKey,
}) async {
  final status = ref.read(subscriptionStatusProvider);
  if (hasProEntitlement(status)) return true;
  if (!context.mounted) return false;
  await showProPaywall(context, ref, reasonKey: reasonKey);
  if (!context.mounted) return false;
  return hasProEntitlement(ref.read(subscriptionStatusProvider));
}

/// 클라우드 AI 저장·검색 전: Pro 없으면 Paywall → 거절 시 false(로컬 fallback).
Future<bool> ensureCloudAccessForAction(
  BuildContext context,
  WidgetRef ref, {
  required String reasonKey,
}) async {
  final prefs = ref.read(preferencesProvider);
  if (isLocalOnlyMode(
    prefs,
    privacyMode: ref.read(privacyLocalModeProvider),
    guestMode: ref.read(guestModeProvider),
  )) {
    return false;
  }
  if (canUseCloudFeatures(
    prefs,
    subscription: ref.read(subscriptionStatusProvider),
    privacyMode: ref.read(privacyLocalModeProvider),
    guestMode: ref.read(guestModeProvider),
  )) {
    return true;
  }
  return requireProOrShowPaywall(context, ref, reasonKey: reasonKey);
}
