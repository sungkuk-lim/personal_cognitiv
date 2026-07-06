import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/app_providers.dart';

/// 설정에서 열리는 모담넷 이용 가이드 PDF 뷰어.
class UserGuidePdfScreen extends ConsumerStatefulWidget {
  const UserGuidePdfScreen({super.key, required this.title});

  final String title;

  @override
  ConsumerState<UserGuidePdfScreen> createState() => _UserGuidePdfScreenState();
}

class _UserGuidePdfScreenState extends ConsumerState<UserGuidePdfScreen> {
  late final PdfControllerPinch _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openAsset('assets/guides/modamnet_user_guide.pdf'),
    );
    _controller.loadingState.addListener(_onLoadState);
  }

  void _onLoadState() {
    if (!mounted) return;
    final state = _controller.loadingState.value;
    setState(() {
      _loading = state == PdfLoadingState.loading;
      if (state == PdfLoadingState.error) {
        _error = 'PDF를 불러오지 못했습니다.';
      }
    });
  }

  @override
  void dispose() {
    _controller.loadingState.removeListener(_onLoadState);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _downloadPdf() async {
    final t = ref.read(translationsProvider);
    
    try {
      // 권한 요청 (Android 10 이하는 STORAGE, 11 이상은 별도 처리가 필요할 수 있으나 보통 Downloads 폴더는 가능)
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('저장 공간 권한이 필요합니다.')),
            );
          }
          return;
        }
      }

      final bytes = await rootBundle.load('assets/guides/modamnet_user_guide.pdf');
      final buffer = bytes.buffer.asUint8List();

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) throw Exception('Download directory not found');

      final fileName = widget.title.contains('가이드') 
          ? 'modamnet_user_guide.pdf' 
          : 'features_graph_settings.pdf';
      
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(buffer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t['download_success'] ?? '다운로드 폴더에 저장되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t['download_failed'] ?? '다운로드에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: t['download_pdf'] ?? 'PDF 다운로드',
            onPressed: _downloadPdf,
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyLarge))
          : Stack(
              children: [
                PdfViewPinch(
                  controller: _controller,
                  scrollDirection: Axis.vertical,
                ),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
