import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/location_permission_service.dart';

class LocationPermissionTile extends ConsumerStatefulWidget {
  const LocationPermissionTile({super.key});

  @override
  ConsumerState<LocationPermissionTile> createState() => _LocationPermissionTileState();
}

class _LocationPermissionTileState extends ConsumerState<LocationPermissionTile> with WidgetsBindingObserver {
  AppLocationAccess? _access;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final access = await LocationPermissionService.currentAccess();
    if (mounted) setState(() => _access = access);
  }

  String _statusLabel(Map<String, String> t, AppLocationAccess access) {
    switch (access) {
      case AppLocationAccess.always:
        return t['location_status_always'] ?? t['location_status_granted']!;
      case AppLocationAccess.whileInUse:
        return t['location_status_while_in_use'] ?? t['location_status_granted']!;
      case AppLocationAccess.denied:
        return t['location_status_denied']!;
      case AppLocationAccess.deniedForever:
        return t['location_status_denied_forever']!;
      case AppLocationAccess.serviceDisabled:
        return t['location_status_service_disabled']!;
    }
  }

  String _actionLabel(Map<String, String> t, AppLocationAccess access) {
    switch (access) {
      case AppLocationAccess.always:
      case AppLocationAccess.whileInUse:
        return t['location_manage']!;
      case AppLocationAccess.denied:
        return t['location_allow']!;
      case AppLocationAccess.deniedForever:
      case AppLocationAccess.serviceDisabled:
        return t['location_open_settings']!;
    }
  }

  Future<void> _onAction() async {
    if (_busy) return;
    setState(() => _busy = true);
    final t = ref.read(translationsProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final access = _access ?? await LocationPermissionService.currentAccess();
      switch (access) {
        case AppLocationAccess.always:
        case AppLocationAccess.whileInUse:
          await LocationPermissionService.openAppSettings();
        case AppLocationAccess.denied:
          final result = await LocationPermissionService.requestAccess();
          if (!mounted) return;
          if (LocationPermissionService.hasForegroundAccess(result)) {
            messenger.showSnackBar(SnackBar(content: Text(t['location_granted_snack']!)));
          } else if (result == AppLocationAccess.deniedForever) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(t['location_status_denied_forever']!),
                action: SnackBarAction(
                  label: t['location_open_settings']!,
                  onPressed: LocationPermissionService.openAppSettings,
                ),
              ),
            );
          } else if (result == AppLocationAccess.serviceDisabled) {
            await LocationPermissionService.openLocationSettings();
          }
        case AppLocationAccess.deniedForever:
          await LocationPermissionService.openAppSettings();
        case AppLocationAccess.serviceDisabled:
          await LocationPermissionService.openLocationSettings();
      }
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.read(translationsProvider);
    final access = _access;

    return ListTile(
      leading: const Icon(Icons.location_on_outlined),
      title: Text(t['location_permission']!),
      subtitle: Text(
        access == null ? t['location_permission_hint']! : _statusLabel(t, access),
      ),
      trailing: _busy
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(
              onPressed: access == null ? null : _onAction,
              child: Text(access == null ? '...' : _actionLabel(t, access)),
            ),
      onTap: access == null || _busy ? null : _onAction,
    );
  }
}
