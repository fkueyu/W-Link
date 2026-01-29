import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../core/core.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import 'package:http/http.dart' as http;

/// 色标数据模型
class ColorStop {
  int position; // 0-255
  Color color;

  ColorStop({required this.position, required this.color});

  List<int> toList() => [
    position,
    (color.r * 255).round(),
    (color.g * 255).round(),
    (color.b * 255).round(),
  ];
}

/// 自定义调色板编辑器页面
class CustomPaletteEditorScreen extends ConsumerStatefulWidget {
  const CustomPaletteEditorScreen({super.key});

  @override
  ConsumerState<CustomPaletteEditorScreen> createState() =>
      _CustomPaletteEditorScreenState();
}

class _CustomPaletteEditorScreenState
    extends ConsumerState<CustomPaletteEditorScreen> {
  final List<ColorStop> _colorStops = [
    ColorStop(position: 0, color: Colors.blue),
    ColorStop(position: 128, color: Colors.purple),
    ColorStop(position: 255, color: Colors.indigo),
  ];

  int _selectedSlot = 0;
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final currentDevice = ref.watch(currentDeviceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(
                  children: [
                    BouncyButton(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_left_rounded, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      l10n.customPalette,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const Spacer(),
                    _buildSlotPicker(isDark, l10n),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionTitle(l10n.previewPalette, isDark),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: _buildGradient(),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: -5,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${l10n.paletteSlot} $_selectedSlot',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle(
                          '${l10n.color} (${_colorStops.length})',
                          isDark,
                        ),
                        BouncyButton(
                          onTap: _addColorStop,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: FluxTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  color: FluxTheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.addColorStop,
                                  style: const TextStyle(
                                    color: FluxTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_colorStops.isEmpty)
                      _buildEmptyState(isDark, l10n)
                    else
                      ...List.generate(_colorStops.length, (index) {
                        final stop = _colorStops[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child:
                              GlassCard(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        BouncyButton(
                                          onTap: () => _pickColor(index),
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: stop.color,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: stop.color.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  blurRadius: 10,
                                                  spreadRadius: -2,
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.colorize_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${l10n.colorPosition}: ${stop.position}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Slider(
                                                value: stop.position.toDouble(),
                                                min: 0,
                                                max: 255,
                                                activeColor: stop.color,
                                                onChanged: (val) => setState(
                                                  () => stop.position = val
                                                      .round(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        BouncyButton(
                                          onTap: () => _removeColorStop(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: (index * 50).ms)
                                  .slideX(begin: 0.05),
                        );
                      }),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          BouncyButton(
                onTap: _isUploading || _colorStops.length < 2
                    ? null
                    : () => _uploadPalette(currentDevice?.ip),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: _colorStops.length < 2
                            ? Colors.grey.withValues(alpha: 0.2)
                            : FluxTheme.primary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          if (_colorStops.length >= 2)
                            BoxShadow(
                              color: FluxTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                        ],
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_upload_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l10n.uploadPalette,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 600.ms)
              .slideY(begin: 0.5, curve: Curves.easeOutBack),
    );
  }

  Widget _buildSlotPicker(bool isDark, AppStrings l10n) {
    return PopupMenuButton<int>(
      onSelected: (val) => setState(() => _selectedSlot = val),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      itemBuilder: (context) => List.generate(
        10,
        (i) => PopupMenuItem(
          value: i,
          child: Row(
            children: [
              Icon(
                i == _selectedSlot
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: i == _selectedSlot ? FluxTheme.primary : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                '${l10n.paletteSlot} $i',
                style: TextStyle(
                  fontWeight: i == _selectedSlot
                      ? FontWeight.w900
                      : FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: FluxTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.storage_rounded,
              color: FluxTheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '#$_selectedSlot',
              style: const TextStyle(
                color: FluxTheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppStrings l10n) {
    return GlassCard(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.palette_outlined,
            size: 64,
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noColorStops,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.minColorStopsMsg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  LinearGradient _buildGradient() {
    if (_colorStops.isEmpty) {
      return const LinearGradient(colors: [Colors.grey, Colors.grey]);
    }
    final sorted = List<ColorStop>.from(_colorStops)
      ..sort((a, b) => a.position.compareTo(b.position));
    return LinearGradient(
      colors: sorted.map((s) => s.color).toList(),
      stops: sorted.map((s) => s.position / 255).toList(),
    );
  }

  void _addColorStop() {
    HapticFeedback.selectionClick();
    setState(
      () => _colorStops.add(
        ColorStop(
          position: 128,
          color: Colors.primaries[_colorStops.length % Colors.primaries.length],
        ),
      ),
    );
  }

  void _removeColorStop(int index) {
    HapticFeedback.mediumImpact();
    setState(() => _colorStops.removeAt(index));
  }

  Future<void> _pickColor(int index) async {
    final stop = _colorStops[index];
    final l10n = ref.read(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<Color>(
      context: context,
      builder: (context) =>
          Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '选择颜色',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ColorPicker(
                          color: stop.color,
                          onColorChanged: (color) =>
                              setState(() => stop.color = color),
                          pickersEnabled: const {
                            ColorPickerType.wheel: true,
                            ColorPickerType.accent: false,
                            ColorPickerType.primary: false,
                          },
                          enableShadesSelection: false,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  l10n.cancel,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: FluxTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.pop(context, stop.color),
                                child: Text(l10n.ok),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack)
              .fadeIn(),
    );

    if (result != null) {
      setState(() => _colorStops[index].color = result);
    }
  }

  Future<void> _uploadPalette(String? deviceIp) async {
    if (deviceIp == null || _colorStops.length < 2) {
      return;
    }
    final l10n = ref.read(l10nProvider);
    setState(() => _isUploading = true);
    try {
      final sorted = List<ColorStop>.from(_colorStops)
        ..sort((a, b) => a.position.compareTo(b.position));
      final paletteData = <int>[];
      for (final stop in sorted) {
        paletteData.addAll(stop.toList());
      }
      final uri = Uri.parse('http://$deviceIp/upload');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromString(
            'data',
            jsonEncode(paletteData),
            filename: '/palette$_selectedSlot.json',
          ),
        );
      final response = await request.send().timeout(
        const Duration(seconds: 10),
      );
      if (mounted) {
        if (response.statusCode == 200) {
          AppToast.success(context, l10n.uploadSuccess);
        } else {
          AppToast.error(context, l10n.uploadFailed);
        }
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '${l10n.uploadFailed}: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
