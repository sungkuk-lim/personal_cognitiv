import 'package:flutter/material.dart';

import '../services/graph_achievements_service.dart';

Future<void> showAchievementUnlockDialog(
  BuildContext context, {
  required GraphAchievement achievement,
  required String localeCode,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'achievement',
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, _, _) => _AchievementUnlockCard(achievement: achievement, localeCode: localeCode),
    transitionBuilder: (context, animation, _, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween<double>(begin: 0.82, end: 1).animate(curve), child: child),
      );
    },
  );
}

class _AchievementUnlockCard extends StatelessWidget {
  const _AchievementUnlockCard({required this.achievement, required this.localeCode});

  final GraphAchievement achievement;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isKo = localeCode == 'ko';
    final title = isKo ? achievement.titleKo : achievement.titleEn;
    final description = isKo ? achievement.descriptionKo : achievement.descriptionEn;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.tertiaryContainer.withValues(alpha: 0.9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, value, child) => Transform.scale(scale: value, child: child),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(_iconFor(achievement.iconName), color: theme.colorScheme.onPrimary, size: 34),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isKo ? '달성!' : 'Unlocked!',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => Navigator.pop(context), child: Text(isKo ? '확인' : 'OK')),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String name) => switch (name) {
        'hub' => Icons.hub_rounded,
        'map' => Icons.map_rounded,
        'people' => Icons.people_rounded,
        'place' => Icons.place_rounded,
        'memory' => Icons.auto_stories_rounded,
        'study' => Icons.school_rounded,
        _ => Icons.emoji_events_rounded,
      };
}
