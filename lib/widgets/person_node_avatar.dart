import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/person_avatar_provider.dart';
import '../services/person_contact_avatar_service.dart';
import '../utils/person_avatar_utils.dart';

/// 관계망 사람 노드용 아바타 — 이니셜 기본, 연락처 사진은 설정 ON 시 오버레이.
class PersonNodeAvatar extends ConsumerStatefulWidget {
  const PersonNodeAvatar({
    super.key,
    required this.name,
    required this.size,
    this.accent,
    this.onDarkBackground = true,
    this.square = false,
  });

  final String name;
  final double size;
  final Color? accent;
  final bool onDarkBackground;
  final bool square;

  @override
  ConsumerState<PersonNodeAvatar> createState() => _PersonNodeAvatarState();
}

class _PersonNodeAvatarState extends ConsumerState<PersonNodeAvatar> {
  Uint8List? _directPhoto;
  bool _lookupStarted = false;

  @override
  void didUpdateWidget(covariant PersonNodeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      _directPhoto = null;
      _lookupStarted = false;
    }
  }

  void _ensureDirectLookup() {
    if (_lookupStarted || _directPhoto != null) return;
    if (!ref.read(contactPersonAvatarsEnabledProvider)) return;
    final name = sanitizeContactLabel(widget.name);
    if (ref.read(personAvatarCacheProvider).photoFor(name) != null) return;

    _lookupStarted = true;
    PersonContactAvatarService.lookupPhotoForName(name).then((photo) {
      if (!mounted || photo == null) return;
      setState(() => _directPhoto = photo);
      ref.read(personAvatarCacheProvider.notifier).mergePhotoForName(name, photo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(contactPersonAvatarsEnabledProvider);
    final cache = ref.watch(personAvatarCacheProvider);
    final name = sanitizeContactLabel(widget.name);
    final initial = personAvatarInitial(name);
    final bg = widget.accent ?? personAvatarColor(name);
    final cachedPhoto = enabled ? cache.photoFor(name) : null;
    final photo = cachedPhoto ?? (enabled ? _directPhoto : null);
    if (enabled && photo == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDirectLookup());
    }
    final fontSize = (widget.size * 0.42).clamp(10.0, 18.0);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: widget.square ? BoxShape.rectangle : BoxShape.circle,
        color: bg.withValues(alpha: widget.onDarkBackground ? 0.9 : 0.82),
        border: widget.square
            ? null
            : Border.all(
                color: Colors.white.withValues(alpha: widget.onDarkBackground ? 0.75 : 0.55),
                width: 1,
              ),
        boxShadow: widget.square
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: photo != null
          ? Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true)
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
    );
  }
}
