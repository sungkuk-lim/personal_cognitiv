import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const Duration speechListenFor = Duration(minutes: 30);
const Duration speechPauseFor = Duration(seconds: 15);

class VoiceInputDialog extends StatefulWidget {
  final stt.SpeechToText speech;
  final String localeId;
  final String title;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;
  final String listeningLabel;
  final int maxLines;
  final ValueChanged<bool>? onListeningChanged;
  final void Function(VoidCallback handler) onBindSpeechDone;
  final void Function(VoidCallback handler) onUnbindSpeechDone;

  const VoiceInputDialog({
    super.key,
    required this.speech,
    required this.localeId,
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.listeningLabel,
    required this.maxLines,
    required this.onBindSpeechDone,
    required this.onUnbindSpeechDone,
    this.onListeningChanged,
  });

  @override
  State<VoiceInputDialog> createState() => _VoiceInputDialogState();
}

class _VoiceInputDialogState extends State<VoiceInputDialog> {
  late final TextEditingController _controller;
  late final VoidCallback _speechDoneHandler;
  bool _keepListening = true;
  bool _isListening = false;
  String _committed = '';
  int _sessionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _speechDoneHandler = () {
      if (!_keepListening || !mounted) return;
      Future.delayed(const Duration(milliseconds: 250), () {
        if (_keepListening && mounted && !widget.speech.isListening) {
          _startListening();
        }
      });
    };
    widget.onBindSpeechDone(_speechDoneHandler);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  @override
  void dispose() {
    _keepListening = false;
    _sessionGeneration++;
    widget.onUnbindSpeechDone(_speechDoneHandler);
    widget.speech.stop();
    widget.onListeningChanged?.call(false);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!_keepListening || !mounted || widget.speech.isListening) return;
    final session = ++_sessionGeneration;
    await widget.speech.listen(
      onResult: (result) {
        if (!_keepListening || !mounted || session != _sessionGeneration) return;
        setState(() {
          if (result.finalResult) {
            _committed = ('$_committed ${result.recognizedWords}').trim();
            _controller.text = _committed;
          } else {
            final partial = result.recognizedWords.trim();
            _controller.text = _committed.isEmpty ? partial : '$_committed $partial';
          }
        });
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: speechListenFor,
        pauseFor: speechPauseFor,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        localeId: widget.localeId,
      ),
    );
    if (!_keepListening || !mounted || session != _sessionGeneration) return;
    setState(() => _isListening = true);
    widget.onListeningChanged?.call(true);
  }

  void _stopListening() {
    if (!_keepListening && !_isListening) return;
    _keepListening = false;
    _sessionGeneration++;
    widget.speech.stop();
    if (mounted) setState(() => _isListening = false);
    widget.onListeningChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isListening)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.mic, color: Theme.of(context).colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.listeningLabel, style: const TextStyle(fontSize: 13))),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _controller,
              decoration: InputDecoration(hintText: _isListening ? widget.listeningLabel : widget.hint),
              maxLines: widget.maxLines,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _stopListening();
            Navigator.pop(context);
          },
          child: Text(widget.cancelLabel),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _controller.text.trim();
            _stopListening();
            Navigator.pop(context, text);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
