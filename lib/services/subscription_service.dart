import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../core/subscription_config.dart';
import '../models/subscription_status.dart';

typedef SubscriptionListener = void Function(SubscriptionStatus status);

/// Supabase 구독 상태 + RevenueCat(Play/App Store) 연동.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  bool _configured = false;
  SubscriptionListener? _listener;

  void setListener(SubscriptionListener? listener) => _listener = listener;

  Future<void> initialize() async {
    if (!AppEnv.isConfigured || !AppEnv.hasRevenueCat) return;
    if (_configured) return;

    final key = Platform.isIOS ? AppEnv.revenueCatIosKey : AppEnv.revenueCatAndroidKey;
    if (key.isEmpty) return;

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(key));
    _configured = true;

    Purchases.addCustomerInfoUpdateListener((info) {
      _applyRevenueCatInfo(info);
    });
  }

  Future<SubscriptionStatus> refreshEntitlements() async {
    if (!AppEnv.isConfigured) {
      final free = SubscriptionStatus.free();
      _listener?.call(free);
      return free;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final free = SubscriptionStatus.free();
      _listener?.call(free);
      return free;
    }

    if (AppEnv.devProBypass) {
      final dev = SubscriptionStatus(
        tier: 'pro',
        status: 'active',
        productId: 'dev_bypass',
      );
      _listener?.call(dev);
      return dev;
    }

    if (_configured) {
      try {
        final info = await Purchases.getCustomerInfo();
        _applyRevenueCatInfo(info);
        final active = info.entitlements.all[SubscriptionConfig.entitlementPro];
        if (active?.isActive == true) {
          return await refreshFromSupabase();
        }
      } catch (e) {
        debugPrint('RevenueCat refresh failed: $e');
      }
    }

    return refreshFromSupabase();
  }

  Future<SubscriptionStatus> refreshFromSupabase() async {
    if (!AppEnv.isConfigured) {
      final free = SubscriptionStatus.free();
      _listener?.call(free);
      return free;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final free = SubscriptionStatus.free();
      _listener?.call(free);
      return free;
    }

    if (AppEnv.devProBypass) {
      final dev = SubscriptionStatus(
        tier: 'pro',
        status: 'active',
        productId: 'dev_bypass',
      );
      _listener?.call(dev);
      return dev;
    }

    try {
      final subRes = await Supabase.instance.client
          .from('user_subscriptions')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      final monthKey = _monthKeyUtc(DateTime.now());
      final usageRes = await Supabase.instance.client
          .from('ai_usage_monthly')
          .select()
          .eq('user_id', user.id)
          .eq('month_key', monthKey)
          .maybeSingle();

      final status = SubscriptionStatus.fromMaps(
        subscription: subRes,
        usage: usageRes,
      );
      _listener?.call(status);
      return status;
    } catch (e) {
      debugPrint('Subscription refresh failed: $e');
      final free = SubscriptionStatus.free();
      _listener?.call(free);
      return free;
    }
  }

  Future<void> syncAfterLogin(String userId) async {
    if (_configured) {
      try {
        await Purchases.logIn(userId);
        final info = await Purchases.getCustomerInfo();
        _applyRevenueCatInfo(info);
      } catch (e) {
        debugPrint('RevenueCat login failed: $e');
      }
    }
    await refreshFromSupabase();
  }

  Future<void> syncAfterLogout() async {
    if (_configured) {
      try {
        await Purchases.logOut();
      } catch (e) {
        debugPrint('RevenueCat logout failed: $e');
      }
    }
    _listener?.call(SubscriptionStatus.free());
  }

  Future<Offerings?> fetchOfferings() async {
    if (!_configured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('Offerings fetch failed: $e');
      return null;
    }
  }

  Future<SubscriptionStatus?> purchasePackage(Package package) async {
    if (!_configured) return null;
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      _applyRevenueCatInfo(customerInfo);
      return await refreshFromSupabase();
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return null;
      rethrow;
    }
  }

  Future<SubscriptionStatus?> restorePurchases() async {
    if (!_configured) return null;
    try {
      final info = await Purchases.restorePurchases();
      _applyRevenueCatInfo(info);
      return await refreshFromSupabase();
    } catch (e) {
      debugPrint('Restore failed: $e');
      rethrow;
    }
  }

  void _applyRevenueCatInfo(CustomerInfo info) {
    final active = info.entitlements.all[SubscriptionConfig.entitlementPro];
    if (active?.isActive == true) {
      _listener?.call(
        SubscriptionStatus(
          tier: 'pro',
          status: active!.periodType == PeriodType.trial ? 'trialing' : 'active',
          expiresAt: active.expirationDate != null
              ? DateTime.tryParse(active.expirationDate!)
              : null,
          productId: active.productIdentifier,
        ),
      );
    } else {
      refreshFromSupabase();
    }
  }

  String _monthKeyUtc(DateTime dt) {
    final u = dt.toUtc();
    return '${u.year}-${u.month.toString().padLeft(2, '0')}';
  }
}
