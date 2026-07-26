import 'package:flutter/material.dart';

/// 관계망 신뢰·출처 안내 — 하단 배너 「안내」 탭 시.
void showGraphTrustSheet(
  BuildContext context, {
  required Map<String, String> t,
  required bool graphAiOn,
}) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t['graph_trust_sheet_title']!,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TrustBlock(
                icon: Icons.hub_outlined,
                title: t['graph_trust_sheet_source_title']!,
                body: t['graph_trust_sheet_source_body']!,
              ),
              const SizedBox(height: 10),
              _TrustBlock(
                icon: Icons.edit_note_outlined,
                title: t['graph_trust_sheet_fix_title']!,
                body: t['graph_trust_sheet_fix_body']!,
              ),
              if (graphAiOn) ...[
                const SizedBox(height: 10),
                _TrustBlock(
                  icon: Icons.auto_awesome_outlined,
                  title: t['graph_trust_sheet_ai_title']!,
                  body: t['graph_trust_sheet_ai_body']!,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t['got_it']!),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _TrustBlock extends StatelessWidget {
  const _TrustBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
