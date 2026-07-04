// ignore_for_file: avoid_print
/// 모담넷 이용 가이드 PDF 생성
/// 실행: dart run scripts/generate_user_guide_pdf.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final root = Directory.current;
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    print('프로젝트 루트에서 실행하세요: dart run scripts/generate_user_guide_pdf.dart');
    exit(1);
  }

  final fontFile = _resolveKoreanFont(root.path);
  if (fontFile == null) {
    print('한글 폰트 없음. 다음 중 하나를 준비하세요:');
    print('  - assets/fonts/NotoSansKR-Regular.ttf');
    print('  - assets/fonts/NotoSansCJKkr-Regular.ttf');
    print('  - scripts/setup_guide_font.ps1 실행 (Windows: 맑은 고딕 복사)');
    exit(1);
  }
  print('폰트: ${fontFile.path}');

  final mdPath = '${root.path}/docs/MODAMNET_USER_GUIDE.md';
  final md = File(mdPath).readAsStringSync();
  final fontBytes = ByteData.sublistView(fontFile.readAsBytesSync());
  final font = pw.Font.ttf(fontBytes);
  final bold = pw.Font.ttf(fontBytes);

  final doc = pw.Document(
    title: '모담넷(MemoryOS) 이용 가이드',
    author: 'MemoryOS',
  );

  final widgets = _parseMarkdown(md, font, bold);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (_) => widgets,
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
        ),
      ),
    ),
  );

  final outDir = Directory('${root.path}/assets/guides');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final outPath = '${outDir.path}/modamnet_user_guide.pdf';
  await File(outPath).writeAsBytes(await doc.save());
  print('생성 완료: $outPath');
}

List<pw.Widget> _parseMarkdown(String md, pw.Font font, pw.Font bold) {
  final out = <pw.Widget>[];
  final lines = md.split('\n');
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed.isEmpty || trimmed == '---') {
      i++;
      continue;
    }

    if (trimmed.startsWith('# ')) {
      out.add(pw.SizedBox(height: 8));
      out.add(pw.Text(
        trimmed.substring(2),
        style: pw.TextStyle(font: bold, fontSize: 22, color: PdfColors.indigo900),
      ));
      out.add(pw.SizedBox(height: 12));
      i++;
      continue;
    }

    if (trimmed.startsWith('## ')) {
      out.add(pw.SizedBox(height: 16));
      out.add(pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.indigo200, width: 1)),
        ),
        child: pw.Text(
          trimmed.substring(3),
          style: pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.indigo800),
        ),
      ));
      out.add(pw.SizedBox(height: 8));
      i++;
      continue;
    }

    if (trimmed.startsWith('### ')) {
      out.add(pw.SizedBox(height: 10));
      out.add(pw.Text(
        trimmed.substring(4),
        style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.grey800),
      ));
      out.add(pw.SizedBox(height: 4));
      i++;
      continue;
    }

    if (trimmed.startsWith('|')) {
      final tableLines = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        tableLines.add(lines[i].trim());
        i++;
      }
      out.add(_buildTable(tableLines, font, bold));
      out.add(pw.SizedBox(height: 8));
      continue;
    }

    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      final bullets = <String>[];
      while (i < lines.length) {
        final t = lines[i].trim();
        if (t.startsWith('- ') || t.startsWith('* ')) {
          bullets.add(_stripMd(t.substring(2)));
          i++;
        } else {
          break;
        }
      }
      out.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: bullets
            .map(
              (b) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3, left: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: pw.TextStyle(font: font, fontSize: 10)),
                    pw.Expanded(child: pw.Text(b, style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 1.35))),
                  ],
                ),
              ),
            )
            .toList(),
      ));
      continue;
    }

    if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
      final items = <String>[];
      while (i < lines.length && RegExp(r'^\d+\.\s').hasMatch(lines[i].trim())) {
        items.add(_stripMd(lines[i].trim().replaceFirst(RegExp(r'^\d+\.\s'), '')));
        i++;
      }
      out.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var n = 0; n < items.length; n++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3, left: 4),
              child: pw.Text('${n + 1}. ${items[n]}', style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 1.35)),
            ),
        ],
      ));
      continue;
    }

    out.add(pw.Text(
      _stripMd(trimmed),
      style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 1.4),
    ));
    out.add(pw.SizedBox(height: 4));
    i++;
  }

  return out;
}

pw.Widget _buildTable(List<String> rows, pw.Font font, pw.Font bold) {
  if (rows.length < 2) return pw.SizedBox();
  final parsed = rows
      .where((r) => !RegExp(r'^\|[\s\-:|]+\|$').hasMatch(r))
      .map((r) => r.split('|').where((c) => c.trim().isNotEmpty).map((c) => _stripMd(c.trim())).toList())
      .where((r) => r.isNotEmpty)
      .toList();

  if (parsed.isEmpty) return pw.SizedBox();

  return pw.Table.fromTextArray(
    headers: parsed.first,
    data: parsed.length > 1 ? parsed.sublist(1) : [],
    headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.indigo900),
    cellStyle: pw.TextStyle(font: font, fontSize: 8, lineSpacing: 1.2),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo50),
    cellAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
  );
}

File? _resolveKoreanFont(String rootPath) {
  const candidates = [
    'assets/fonts/NotoSansKR-Regular.ttf',
    'assets/fonts/NotoSansCJKkr-Regular.ttf',
    r'C:\Windows\Fonts\malgun.ttf',
  ];
  for (final rel in candidates) {
    final path = rel.contains(':') ? rel : '$rootPath/$rel';
    final file = File(path);
    if (file.existsSync() && file.lengthSync() > 500_000) {
      return file;
    }
  }
  return null;
}

String _stripMd(String s) {
  return s
      .replaceAll('**', '')
      .replaceAll('「', '')
      .replaceAll('」', '')
      .replaceAll('*', '')
      .trim();
}
