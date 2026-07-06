import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/env.dart';
import '../../core/subscription_config.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/subscription_service.dart';

Future<void> showProPaywall(
  BuildContext context,
  WidgetRef ref, {
  String? reasonKey,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _PaywallSheet(reasonKey: reasonKey),
  );
}

class _PaywallSheet extends ConsumerStatefulWidget {
  const _PaywallSheet({this.reasonKey});
  final String? reasonKey;

  @override
  ConsumerState<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<_PaywallSheet> {
  Offerings? _offerings;
  bool _loading = true;
  bool _purchasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final offerings = await SubscriptionService.instance.fetchOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
        _loading = false;
      });
    }
  }

  Future<void> _buy(Package package) async {
    setState(() {
      _purchasing = true;
      _error = null;
    });
    try {
      final status = await SubscriptionService.instance.purchasePackage(package);
      if (status != null && mounted) {
        ref.read(subscriptionStatusProvider.notifier).state = status;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(translationsProvider)['pro_welcome']!)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = ref.read(translationsProvider)['pro_purchase_error']!);
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _purchasing = true;
      _error = null;
    });
    try {
      final status = await SubscriptionService.instance.restorePurchases();
      if (status != null && mounted) {
        ref.read(subscriptionStatusProvider.notifier).state = status;
        if (status.isProActive) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = ref.read(translationsProvider)['pro_restore_error']!);
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final status = ref.watch(subscriptionStatusProvider);
    final packages = _offerings?.current?.availablePackages ?? [];
    final reason = widget.reasonKey != null ? t[widget.reasonKey!] : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: ListView(
          controller: controller,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t['pro_title']!,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: 12),
              Text(reason, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45)),
            ],
            const SizedBox(height: 8),
            Text(
              t['pro_local_ai_hint']!,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ...SubscriptionConfig.proBenefitKeys.map(
              (key) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t[key]!, style: const TextStyle(fontSize: 15, height: 1.45))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (status.isProActive)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(t['pro_already_active']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!AppEnv.hasRevenueCat || packages.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t['pro_store_pending']!, style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          final refreshed = await SubscriptionService.instance.refreshFromSupabase();
                          if (mounted) {
                            ref.read(subscriptionStatusProvider.notifier).state = refreshed;
                          }
                        },
                        child: Text(t['pro_refresh_status']!),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              ...packages.map((pkg) {
                final isAnnual = pkg.packageType == PackageType.annual;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _purchasing ? null : () => _buy(pkg),
                    child: Text(
                      isAnnual ? t['pro_buy_annual']!.replaceAll('{price}', pkg.storeProduct.priceString) : t['pro_buy_monthly']!.replaceAll('{price}', pkg.storeProduct.priceString),
                    ),
                  ),
                );
              }),
              TextButton(
                onPressed: _purchasing ? null : _restore,
                child: Text(t['pro_restore']!),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final refreshed = await SubscriptionService.instance.refreshFromSupabase();
                if (mounted) {
                  ref.read(subscriptionStatusProvider.notifier).state = refreshed;
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(t['pro_refresh_status']!),
            ),
            const SizedBox(height: 8),
            Text(
              t['pro_free_hint']!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              t['pro_subscription_legal']!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t['pro_continue_free']!),
            ),
          ],
        ),
      ),
    );
  }
}
