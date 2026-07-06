import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 앱 내 개인정보 처리방침·이용약관 뷰어.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  static const privacyAsset = 'assets/legal/privacy.md';
  static const termsAsset = 'assets/legal/terms.md';

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  String _body = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await rootBundle.loadString(widget.assetPath);
      if (mounted) setState(() {
        _body = text;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _body = '';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _body.isEmpty
              ? const Center(child: Text('문서를 불러오지 못했습니다.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: _buildSections(theme),
                ),
    );
  }

  List<Widget> _buildSections(ThemeData theme) {
    final widgets = <Widget>[];
    for (final line in _body.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            trimmed.substring(2),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            trimmed.substring(3),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ));
      } else if (trimmed.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• '),
              Expanded(child: Text(trimmed.substring(2), style: const TextStyle(height: 1.45))),
            ],
          ),
        ));
      } else if (trimmed.startsWith('|')) {
        continue;
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SelectableText(trimmed, style: const TextStyle(height: 1.5)),
        ));
      }
    }
    return widgets;
  }
}

void openLegalDocument(BuildContext context, {required String title, required String assetPath}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalDocumentScreen(title: title, assetPath: assetPath),
    ),
  );
}
