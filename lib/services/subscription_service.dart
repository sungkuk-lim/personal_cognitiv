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
///
/// 구매 직후: RC entitlement → 로컬 Pro 즉시 반영 → `sync_own_pro_entitlement` →
/// 웹훅 지연 시에도 AI 쿼터/서버 게이트가 깨지지 않도록 폴링.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  bool _configured = false;
  SubscriptionListener? _listener;
  SubscriptionStatus? _lastKnownProFromStore;

  void setListener(SubscriptionListener? listener) => _listener = listener;

  bool get isStoreLinked => _configured && AppEnv.hasRevenueCat;

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
      return _emit(SubscriptionStatus.free());
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return _emit(SubscriptionStatus.free());
    }

    if (AppEnv.devProBypass) {
      return _emit(_devPro());
    }

    SubscriptionStatus? fromStore;
    if (_configured) {
      try {
        final info = await Purchases.getCustomerInfo();
        fromStore = _statusFromCustomerInfo(info);
        if (fromStore != null && fromStore.isProActive) {
          _lastKnownProFromStore = fromStore;
          await _syncOwnProToSupabase(fromStore);
        }
      } catch (e) {
        debugPrint('RevenueCat refresh failed: $e');
      }
    }

    final fromDb = await _fetchSupabaseStatus();
    return _emit(_mergePreferringActivePro(store: fromStore, db: fromDb));
  }

  Future<SubscriptionStatus> refreshFromSupabase() async {
    if (!AppEnv.isConfigured) {
      return _emit(SubscriptionStatus.free());
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return _emit(SubscriptionStatus.free());
    }

    if (AppEnv.devProBypass) {
      return _emit(_devPro());
    }

    final fromDb = await _fetchSupabaseStatus();
    if (!fromDb.isProActive && _lastKnownProFromStore?.isProActive == true) {
      await _syncOwnProToSupabase(_lastKnownProFromStore!);
      final again = await _fetchSupabaseStatus();
      return _emit(_mergePreferringActivePro(store: _lastKnownProFromStore, db: again));
    }
    return _emit(fromDb);
  }

  Future<void> syncAfterLogin(String userId) async {
    if (_configured) {
      try {
        await Purchases.logIn(userId);
        final info = await Purchases.getCustomerInfo();
        final fromStore = _statusFromCustomerInfo(info);
        if (fromStore != null && fromStore.isProActive) {
          _lastKnownProFromStore = fromStore;
          _listener?.call(fromStore);
          await _syncOwnProToSupabase(fromStore);
        }
      } catch (e) {
        debugPrint('RevenueCat login failed: $e');
      }
    }
    await refreshEntitlements();
  }

  Future<void> syncAfterLogout() async {
    _lastKnownProFromStore = null;
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
      final fromStore = _statusFromCustomerInfo(customerInfo);
      if (fromStore != null && fromStore.isProActive) {
        _lastKnownProFromStore = fromStore;
        _listener?.call(fromStore);
        await _syncOwnProToSupabase(fromStore);
        return await _pollSupabaseUntilPro(fallback: fromStore);
      }
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
      final fromStore = _statusFromCustomerInfo(info);
      if (fromStore != null && fromStore.isProActive) {
        _lastKnownProFromStore = fromStore;
        _listener?.call(fromStore);
        await _syncOwnProToSupabase(fromStore);
        return await _pollSupabaseUntilPro(fallback: fromStore);
      }
      return await refreshFromSupabase();
    } catch (e) {
      debugPrint('Restore failed: $e');
      rethrow;
    }
  }

  void _applyRevenueCatInfo(CustomerInfo info) {
    final fromStore = _statusFromCustomerInfo(info);
    if (fromStore != null && fromStore.isProActive) {
      _lastKnownProFromStore = fromStore;
      _listener?.call(fromStore);
      // ignore: discarded_futures
      _syncOwnProToSupabase(fromStore);
    } else {
      // ignore: discarded_futures
      refreshFromSupabase();
    }
  }

  SubscriptionStatus? _statusFromCustomerInfo(CustomerInfo info) {
    final active = info.entitlements.all[SubscriptionConfig.entitlementPro];
    if (active?.isActive != true) return null;
    return SubscriptionStatus(
      tier: 'pro',
      status: active!.periodType == PeriodType.trial ? 'trialing' : 'active',
      expiresAt: active.expirationDate != null ? DateTime.tryParse(active.expirationDate!) : null,
      productId: active.productIdentifier,
    );
  }

  Future<void> _syncOwnProToSupabase(SubscriptionStatus status) async {
    if (!AppEnv.isConfigured || !status.isProActive) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.rpc(
        'sync_own_pro_entitlement',
        params: {
          'p_status': status.status,
          'p_expires_at': status.expiresAt?.toUtc().toIso8601String(),
          'p_product_id': status.productId,
          'p_store': Platform.isIOS ? 'app_store' : 'play',
        },
      );
    } catch (e) {
      debugPrint('sync_own_pro_entitlement failed (deploy migration 006?): $e');
    }
  }

  Future<SubscriptionStatus> _pollSupabaseUntilPro({
    required SubscriptionStatus fallback,
    int attempts = 5,
  }) async {
    for (var i = 0; i < attempts; i++) {
      final db = await _fetchSupabaseStatus();
      if (db.isProActive) {
        return _emit(_mergePreferringActivePro(store: fallback, db: db));
      }
      await Future<void>.delayed(Duration(milliseconds: 400 + i * 300));
      await _syncOwnProToSupabase(fallback);
    }
    // 서버 반영이 늦어도 스토어 기준 Pro 유지 (사용량만 0으로 시작)
    return _emit(fallback);
  }

  Future<SubscriptionStatus> _fetchSupabaseStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return SubscriptionStatus.free();
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

      return SubscriptionStatus.fromMaps(subscription: subRes, usage: usageRes);
    } catch (e) {
      debugPrint('Subscription fetch failed: $e');
      return SubscriptionStatus.free();
    }
  }

  /// RC가 Pro인데 DB가 free면 Pro 유지 + DB 사용량만 병합.
  SubscriptionStatus _mergePreferringActivePro({
    SubscriptionStatus? store,
    required SubscriptionStatus db,
  }) {
    if (store != null && store.isProActive) {
      return SubscriptionStatus(
        tier: 'pro',
        status: store.status,
        expiresAt: store.expiresAt ?? db.expiresAt,
        productId: store.productId ?? db.productId,
        chatUsed: db.chatUsed,
        embeddingUsed: db.embeddingUsed,
        visionUsed: db.visionUsed,
      );
    }
    if (db.isProActive) return db;
    if (_lastKnownProFromStore?.isProActive == true) {
      final s = _lastKnownProFromStore!;
      return SubscriptionStatus(
        tier: 'pro',
        status: s.status,
        expiresAt: s.expiresAt,
        productId: s.productId,
        chatUsed: db.chatUsed,
        embeddingUsed: db.embeddingUsed,
        visionUsed: db.visionUsed,
      );
    }
    return db;
  }

  SubscriptionStatus _devPro() => const SubscriptionStatus(
        tier: 'pro',
        status: 'active',
        productId: 'dev_bypass',
      );

  SubscriptionStatus _emit(SubscriptionStatus status) {
    _listener?.call(status);
    return status;
  }

  String _monthKeyUtc(DateTime dt) {
    final u = dt.toUtc();
    return '${u.year}-${u.month.toString().padLeft(2, '0')}';
  }
}
