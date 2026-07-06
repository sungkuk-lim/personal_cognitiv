import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../utils/memory_save_refinement.dart';
import '../../utils/ocr_utils.dart';

Future<MemoryRefinementResult?> showMemoryRefinementSheet(
  BuildContext context, {
  required DateTime initialDate,
  required String initialSummary,
  required String localeCode,
  required MemoryPlaceMode initialPlaceMode,
  String? initialCustomPlace,
  String? capturePlaceLabel,
  bool captureAvailable = false,
}) {
  return showModalBottomSheet<MemoryRefinementResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _MemoryRefinementSheet(
      initialDate: initialDate,
      initialSummary: initialSummary,
      localeCode: localeCode,
      initialPlaceMode: initialPlaceMode,
      initialCustomPlace: initialCustomPlace,
      capturePlaceLabel: capturePlaceLabel,
      captureAvailable: captureAvailable,
    ),
  );
}

class _MemoryRefinementSheet extends ConsumerStatefulWidget {
  const _MemoryRefinementSheet({
    required this.initialDate,
    required this.initialSummary,
    required this.localeCode,
    required this.initialPlaceMode,
    this.initialCustomPlace,
    this.capturePlaceLabel,
    required this.captureAvailable,
  });

  final DateTime initialDate;
  final String initialSummary;
  final String localeCode;
  final MemoryPlaceMode initialPlaceMode;
  final String? initialCustomPlace;
  final String? capturePlaceLabel;
  final bool captureAvailable;

  @override
  ConsumerState<_MemoryRefinementSheet> createState() => _MemoryRefinementSheetState();
}

class _MemoryRefinementSheetState extends ConsumerState<_MemoryRefinementSheet> {
  late DateTime _selectedDate;
  late MemoryPlaceMode _placeMode;
  late TextEditingController _placeController;
  late TextEditingController _summaryController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _placeMode = widget.captureAvailable || widget.initialPlaceMode != MemoryPlaceMode.captureHere
        ? widget.initialPlaceMode
        : MemoryPlaceMode.none;
    _placeController = TextEditingController(text: widget.initialCustomPlace ?? '');
    _summaryController = TextEditingController(text: widget.initialSummary);
  }

  @override
  void dispose() {
    _placeController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  String get _hereLabel {
    final raw = widget.capturePlaceLabel?.trim() ?? '';
    if (raw.isEmpty) {
      return widget.localeCode == 'ko' ? '지금 위치' : 'Current location';
    }
    if (isLatLngLabel(raw)) {
      return widget.localeCode == 'ko' ? '지금 위치' : 'Current location';
    }
    return raw;
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _confirm() {
    final t = ref.read(translationsProvider);
    if (_placeMode == MemoryPlaceMode.custom) {
      final custom = _placeController.text.trim();
      if (custom.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t['refine_place_custom_required']!)),
        );
        return;
      }
    }
    if (_placeMode == MemoryPlaceMode.captureHere && !widget.captureAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['refine_place_gps_unavailable']!)),
      );
      return;
    }

    Navigator.pop(
      context,
      MemoryRefinementResult(
        date: _selectedDate,
        placeMode: _placeMode,
        customPlace: _placeMode == MemoryPlaceMode.custom ? _placeController.text.trim() : null,
        summary: _summaryController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMMEEEEd(widget.localeCode).add_jm();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                t['refine_title']!,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                t['refine_subtitle']!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(t['refine_date']!, Icons.calendar_today_rounded),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                t['refine_date_hint']!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateFmt.format(_selectedDate),
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.edit_calendar_rounded, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader(t['refine_place']!, Icons.place_rounded),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                t['refine_place_choose']!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _PlaceModeTile(
                    selected: _placeMode == MemoryPlaceMode.none,
                    icon: Icons.not_listed_location_outlined,
                    title: t['refine_place_none']!,
                    subtitle: t['refine_place_none_hint']!,
                    onTap: () => setState(() => _placeMode = MemoryPlaceMode.none),
                  ),
                  if (widget.captureAvailable) ...[
                    const SizedBox(height: 8),
                    _PlaceModeTile(
                      selected: _placeMode == MemoryPlaceMode.captureHere,
                      icon: Icons.my_location_rounded,
                      title: t['refine_place_here']!,
                      subtitle: _hereLabel,
                      onTap: () => setState(() => _placeMode = MemoryPlaceMode.captureHere),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _PlaceModeTile(
                    selected: _placeMode == MemoryPlaceMode.custom,
                    icon: Icons.edit_location_alt_outlined,
                    title: t['refine_place_custom']!,
                    subtitle: t['refine_place_hint']!,
                    onTap: () => setState(() => _placeMode = MemoryPlaceMode.custom),
                  ),
                ],
              ),
            ),
            if (_placeMode == MemoryPlaceMode.custom) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _placeController,
                  autofocus: widget.initialCustomPlace?.trim().isEmpty ?? true,
                  decoration: InputDecoration(
                    hintText: t['refine_place_hint'],
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildSectionHeader(t['refine_summary']!, Icons.short_text_rounded),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _summaryController,
                maxLines: 2,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: FilledButton(
                onPressed: _confirm,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  t['refine_confirm']!,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceModeTile extends StatelessWidget {
  const _PlaceModeTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
