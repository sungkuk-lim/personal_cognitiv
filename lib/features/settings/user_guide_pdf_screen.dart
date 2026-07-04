import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// 설정에서 열리는 모담넷 이용 가이드 PDF 뷰어.
class UserGuidePdfScreen extends StatefulWidget {
  const UserGuidePdfScreen({super.key, required this.title});

  final String title;

  @override
  State<UserGuidePdfScreen> createState() => _UserGuidePdfScreenState();
}

class _UserGuidePdfScreenState extends State<UserGuidePdfScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
