import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/legal_consent_service.dart';
import 'legal_document_screen.dart';

/// 최초 실행 시 개인정보·이용약관 동의 (Google Play / GDPR).
Future<void> showLegalConsentIfNeeded(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(preferencesProvider);
  if (readLegalConsentAccepted(prefs)) return;
  if (!context.mounted) return;

  final t = ref.read(translationsProvider);
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(t['legal_consent_title']!),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t['legal_consent_body']!, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 12),
            _LegalLink(
              label: t['privacy_policy']!,
              onTap: () => openLegalDocument(
                ctx,
                title: t['privacy_policy']!,
                assetPath: LegalDocumentScreen.privacyAsset,
              ),
            ),
            _LegalLink(
              label: t['terms_of_service']!,
              onTap: () => openLegalDocument(
                ctx,
                title: t['terms_of_service']!,
                assetPath: LegalDocumentScreen.termsAsset,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t['legal_consent_decline']!),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t['legal_consent_accept']!),
        ),
      ],
    ),
  );

  if (accepted == true) {
    await writeLegalConsentAccepted(prefs);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t['legal_consent_required']!)),
    );
    await showLegalConsentIfNeeded(context, ref);
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
      onPressed: onTap,
      child: Text('› $label'),
    );
  }
}
