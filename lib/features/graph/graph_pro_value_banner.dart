import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../providers/subscription_providers.dart';
import '../../services/graph_ai_orchestrator.dart';
import '../../services/local_memory_store.dart';
import '../subscription/paywall_sheet.dart';

/// 무료 사용자에게 Pro 가치를 부드럽게 안내합니다 (관계망 AI·인사이트).
class GraphProValueBanner extends ConsumerStatefulWidget {
  const GraphProValueBanner({super.key});

  static const int minMemories = 6;

  @override
  ConsumerState<GraphProValueBanner> createState() => _GraphProValueBannerState();
}

class _GraphProValueBannerState extends ConsumerState<GraphProValueBanner> {
  var _dismissed = false;

  @override
  void initState() {
    super.initState();
    _dismissed = readGraphProBannerDismissed(ref.read(preferencesProvider));
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || ref.watch(hasProEntitlementProvider)) return const SizedBox.shrink();

    final prefs = ref.read(preferencesProvider);
    final memories = ref.watch(memoryListProvider);
    if (memories.length < GraphProValueBanner.minMemories) return const SizedBox.shrink();

    final graphAiOn = isGraphAiActive(
      prefs: prefs,
      graphAiEnabled: ref.watch(graphAiEnabledProvider),
      privacyMode: ref.watch(privacyLocalModeProvider),
      guestMode: isLocalOnlyMode(
        prefs,
        privacyMode: ref.watch(privacyLocalModeProvider),
        guestMode: ref.watch(guestModeProvider),
      ),
      subscription: ref.watch(subscriptionStatusProvider),
    );
    if (graphAiOn) return const SizedBox.shrink();

    final t = ref.watch(translationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 20, color: scheme.secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['graph_pro_banner_title']!,
                    style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t['graph_pro_banner_body']!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: scheme.onSecondaryContainer.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => showProPaywall(context, ref, reasonKey: 'pro_reason_graph'),
                    child: Text(t['graph_pro_banner_cta']!),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: t['close']!,
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await writeGraphProBannerDismissed(prefs, true);
                if (mounted) setState(() => _dismissed = true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
