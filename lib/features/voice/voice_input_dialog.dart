import 'package:flutter/material.dart';

import 'voice_input_session.dart';
import 'voice_stt_engine.dart';

enum VoiceInputMode { voice, keyboard }

String normalizeSpeechText(String raw) {
  final words = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.trim().isNotEmpty)
      .toList();
  if (words.isEmpty) return '';

  final dedupConsecutive = <String>[];
  for (final w in words) {
    if (dedupConsecutive.isEmpty || dedupConsecutive.last != w) {
      dedupConsecutive.add(w);
    }
  }
  final collapsed = _collapseRepeatedBlocks(dedupConsecutive);
  return collapsed.join(' ');
}

String mergeSpeechTranscript(String committed, String recognized, {String previousPartial = ''}) {
  final base = normalizeSpeechText(committed);
  final now = normalizeSpeechText(recognized);
  final prev = normalizeSpeechText(previousPartial);
  if (now.isEmpty) return base;
  if (base.isEmpty) return now;
  if (base == now) return base;
  if (now.startsWith(base)) return now;
  if (base.endsWith(now)) return base;

  final baseTokens = base.split(' ');
  final nowTokens = now.split(' ');

  if (now.contains(base)) return now;

  if (prev.isNotEmpty && now.startsWith(prev)) {
    final delta = normalizeSpeechText(now.substring(prev.length));
    if (delta.isEmpty || base.endsWith(delta)) return base;
    return normalizeSpeechText('$base $delta');
  }

  var overlap = 0;
  final max = baseTokens.length < nowTokens.length ? baseTokens.length : nowTokens.length;
  for (var k = 1; k <= max; k++) {
    final tail = baseTokens.sublist(baseTokens.length - k).join(' ');
    final head = nowTokens.sublist(0, k).join(' ');
    if (tail == head) overlap = k;
  }
  final merged = [...baseTokens, ...nowTokens.sublist(overlap)].join(' ');
  return normalizeSpeechText(merged);
}

List<String> _collapseRepeatedBlocks(List<String> tokens) {
  var list = List<String>.from(tokens);
  var changed = true;
  while (changed) {
    changed = false;
    for (var size = 1; size <= list.length ~/ 2; size++) {
      var i = 0;
      while (i + size * 2 <= list.length) {
        final a = list.sublist(i, i + size).join(' ');
        final b = list.sublist(i + size, i + size * 2).join(' ');
        if (a == b) {
          list.removeRange(i + size, i + size * 2);
          changed = true;
        } else {
          i++;
        }
      }
    }
  }
  return list;
}

class VoiceInputDialog extends StatefulWidget {
  final VoiceSttEngine engine;
  final String localeId;
  final VoiceInputSession session;
  final String title;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;
  final String listeningLabel;
  final String? cloudListeningLabel;
  final String voiceModeLabel;
  final String keyboardModeLabel;
  final int maxLines;
  final ValueChanged<bool>? onListeningChanged;
  final void Function(VoidCallback handler) onBindSpeechDone;
  final void Function(VoidCallback handler) onUnbindSpeechDone;

  const VoiceInputDialog({
    super.key,
    required this.engine,
    required this.localeId,
    required this.session,
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.listeningLabel,
    this.cloudListeningLabel,
    required this.voiceModeLabel,
    required this.keyboardModeLabel,
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
  late final FocusNode _focusNode;
  late VoiceInputMode _mode;
  bool _keepListening = true;
  bool _isListening = false;
  String _committed = '';
  int _sessionGeneration = 0;
  String _lastPartial = '';
  bool _suppressControllerListener = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.session.displayDraft.trim();
    final saved = widget.session.committed.trim();
    _committed = draft.isNotEmpty ? draft : saved;
    _controller = TextEditingController(text: _committed);
    _focusNode = FocusNode();
    _mode = widget.session.preferKeyboard ? VoiceInputMode.keyboard : VoiceInputMode.voice;
    _keepListening = _mode == VoiceInputMode.voice;
    _controller.addListener(_onControllerChanged);
    _speechDoneHandler = () {
      if (!_keepListening || !mounted || _mode != VoiceInputMode.voice) return;
      Future.delayed(const Duration(milliseconds: 250), () {
        if (_keepListening && mounted && _mode == VoiceInputMode.voice && !widget.engine.isListening) {
          _startListening();
        }
      });
    };
    widget.onBindSpeechDone(_speechDoneHandler);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mode == VoiceInputMode.voice) {
        _startListening();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _onControllerChanged() {
    if (_suppressControllerListener) return;
    _committed = _controller.text;
    widget.session.sync(
      committed: _committed,
      display: _controller.text,
      preferKeyboard: _mode == VoiceInputMode.keyboard,
    );
  }

  void _syncSession() {
    widget.session.sync(
      committed: _committed,
      display: _controller.text,
      preferKeyboard: _mode == VoiceInputMode.keyboard,
    );
  }

  void _commitControllerText() {
    _committed = _controller.text;
    _syncSession();
  }

  @override
  void dispose() {
    _commitControllerText();
    _controller.removeListener(_onControllerChanged);
    _keepListening = false;
    _sessionGeneration++;
    widget.onUnbindSpeechDone(_speechDoneHandler);
    widget.engine.stop();
    widget.onListeningChanged?.call(false);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!_keepListening || !mounted || _mode != VoiceInputMode.voice || widget.engine.isListening) return;
    final session = ++_sessionGeneration;
    await widget.engine.listen(
      localeId: widget.localeId,
      onResult: (recognized, finalResult) {
        if (!_keepListening || !mounted || session != _sessionGeneration || _mode != VoiceInputMode.voice) {
          return;
        }
        setState(() {
          final normalized = normalizeSpeechText(recognized);
          if (normalized.isEmpty) return;
          final base = normalizeSpeechText(_controller.text);
          if (finalResult) {
            _committed = mergeSpeechTranscript(
              base,
              normalized,
              previousPartial: _lastPartial,
            );
            _lastPartial = '';
          } else {
            _lastPartial = normalized;
            _committed = mergeSpeechTranscript(base, normalized);
          }
          _suppressControllerListener = true;
          _controller.text = _committed;
          _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
          _suppressControllerListener = false;
          _syncSession();
        });
      },
    );
    if (!_keepListening || !mounted || session != _sessionGeneration) return;
    setState(() => _isListening = true);
    widget.onListeningChanged?.call(true);
  }

  void _pauseListening() {
    _sessionGeneration++;
    widget.engine.stop();
    if (mounted) setState(() => _isListening = false);
    widget.onListeningChanged?.call(false);
  }

  void _stopListening() {
    if (!_keepListening && !_isListening) return;
    _keepListening = false;
    _pauseListening();
  }

  void _switchToKeyboard() {
    _commitControllerText();
    _keepListening = false;
    _pauseListening();
    setState(() => _mode = VoiceInputMode.keyboard);
    _syncSession();
    _focusNode.requestFocus();
  }

  void _switchToVoice() {
    _commitControllerText();
    setState(() {
      _mode = VoiceInputMode.voice;
      _keepListening = true;
      _lastPartial = '';
    });
    _syncSession();
    _startListening();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeListeningLabel = widget.engine.isCloudBacked && widget.cloudListeningLabel != null
        ? widget.cloudListeningLabel!
        : widget.listeningLabel;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<VoiceInputMode>(
              segments: [
                ButtonSegment(
                  value: VoiceInputMode.voice,
                  icon: const Icon(Icons.mic_rounded, size: 18),
                  label: Text(widget.voiceModeLabel),
                ),
                ButtonSegment(
                  value: VoiceInputMode.keyboard,
                  icon: const Icon(Icons.keyboard_rounded, size: 18),
                  label: Text(widget.keyboardModeLabel),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                final next = selection.first;
                if (next == _mode) return;
                if (next == VoiceInputMode.keyboard) {
                  _switchToKeyboard();
                } else {
                  _switchToVoice();
                }
              },
            ),
            const SizedBox(height: 12),
            if (_mode == VoiceInputMode.voice && _isListening)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.mic, color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(activeListeningLabel, style: const TextStyle(fontSize: 13))),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: _mode == VoiceInputMode.voice && _isListening ? activeListeningLabel : widget.hint,
              ),
              maxLines: widget.maxLines,
              autofocus: _mode == VoiceInputMode.keyboard,
              onTap: () {
                if (_mode == VoiceInputMode.voice) _switchToKeyboard();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _commitControllerText();
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
