import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/core.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';

/// 预设列表页面
class PresetsListScreen extends ConsumerStatefulWidget {
  const PresetsListScreen({super.key});

  @override
  ConsumerState<PresetsListScreen> createState() => _PresetsListScreenState();
}

class _PresetsListScreenState extends ConsumerState<PresetsListScreen> {
  String _searchQuery = '';
  bool _mutationInFlight = false;
  final Map<WledApiService, Set<int>> _savedSlots = {};

  bool _isTargetCurrent(WledApiService api, String? deviceId) =>
      mounted &&
      identical(ref.read(wledApiProvider), api) &&
      ref.read(currentDeviceIdProvider) == deviceId;

  int? _availableSlot(Iterable<int> usedIds) {
    final used = usedIds.toSet();
    for (var id = 1; id <= 250; id++) {
      if (!used.contains(id)) return id;
    }
    return null;
  }

  String _message(bool zh, String chinese, String english) =>
      zh ? chinese : english;

  Future<void> _mutate(
    WledApiService api,
    String? deviceId,
    Future<void> Function() action,
  ) async {
    if (_mutationInFlight || !_isTargetCurrent(api, deviceId)) {
      throw StateError('device changed or operation in progress');
    }
    setState(() => _mutationInFlight = true);
    try {
      await action();
      // Both the screen and its selected device can change while IO is pending.
      if (_isTargetCurrent(api, deviceId)) ref.invalidate(presetsProvider);
    } finally {
      if (mounted) setState(() => _mutationInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presetsAsync = ref.watch(presetsProvider);
    final stateAsync = ref.watch(deviceStateProvider);
    final api = ref.watch(wledApiProvider);
    final canCreate =
        api != null &&
        !presetsAsync.isLoading &&
        !presetsAsync.hasError &&
        presetsAsync.hasValue &&
        !_mutationInFlight;

    final currentPs = stateAsync.valueOrNull?.ps ?? -1;
    final currentPl = stateAsync.valueOrNull?.pl ?? -1;
    final l10n = ref.watch(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DuoPageToolbar(
      primaryLabel: l10n.savePreset,
      primarySymbol: 'square.and.arrow.down',
      primaryEnabled: canCreate,
      onPrimary: () => _showSavePresetDialog(context, api),
      menu: [
        DuoToolbarMenuEntry(
          id: 'refresh',
          title: l10n is ZhStrings ? '刷新' : 'Refresh',
          symbol: 'arrow.clockwise',
        ),
      ],
      onMenuSelected: (id) {
        if (id == 'refresh') ref.invalidate(presetsProvider);
      },
      builder: (context, useSystemToolbar) => Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // iOS Style Navigation Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Row(
                    children: [
                      if (!useSystemToolbar) ...[
                        BouncyButton(
                          semanticLabel: l10n is ZhStrings ? '返回' : 'Back',
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Text(
                          l10n.presets,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                        ),
                      ),
                      if (!useSystemToolbar)
                        BouncyButton(
                          semanticLabel: l10n is ZhStrings ? '刷新' : 'Refresh',
                          onTap: () => ref.invalidate(presetsProvider),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.refresh_rounded, size: 24),
                          ),
                        ),
                    ],
                  ),
                ),

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: l10n.searchPresetsHint,
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: isDark ? Colors.white38 : Colors.black38,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setState(
                          () => _searchQuery = value.toLowerCase().trim(),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Playlist Status
                if (currentPl >= 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: FluxTheme.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.playlist_play_rounded,
                              color: FluxTheme.accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '播放列表运行中',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  currentPl == 0
                                      ? '预设循环模式'
                                      : '播放列表 #$currentPl',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          BouncyButton(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              api?.stopPlaylist();
                              ref
                                  .read(currentDeviceSessionNotifierProvider)
                                  .refresh();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '停止',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: -0.1),

                // Presets List
                Expanded(
                  child: presetsAsync.when(
                    loading: () => const SkeletonListView(itemHeight: 70),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: FluxTheme.error,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '加载失败',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          BouncyButton(
                            onTap: () => ref.invalidate(presetsProvider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: FluxTheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '重试',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    data: (presets) {
                      if (presets.isEmpty) {
                        return EmptyState(
                          icon: Icons.bookmark_border_rounded,
                          title: l10n.noPresets,
                          message: l10n.noPresetsMsg,
                        );
                      }
                      final filteredPresets = presets.where((p) {
                        if (_searchQuery.isEmpty) return true;
                        return p.name.toLowerCase().contains(_searchQuery) ||
                            p.id.toString().contains(_searchQuery);
                      }).toList();

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filteredPresets.length,
                        itemBuilder: (context, index) {
                          final preset = filteredPresets[index];
                          final isSelected = currentPs == preset.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child:
                                _PresetTile(
                                      preset: preset,
                                      isSelected: isSelected,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        ref
                                            .read(
                                              currentDeviceSessionNotifierProvider,
                                            )
                                            .optimisticUpdate(
                                              (s) => s.copyWith(ps: preset.id),
                                              () => api!.loadPreset(preset.id),
                                            );
                                        Navigator.pop(context);
                                      },
                                      onLongPress: () {
                                        if (!_mutationInFlight && api != null) {
                                          _showPresetOptions(
                                            context,
                                            preset,
                                            api,
                                          );
                                        }
                                      },
                                    )
                                    .animate()
                                    .fadeIn(delay: (index * 30).ms)
                                    .slideX(begin: 0.05, curve: Curves.easeOut),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: useSystemToolbar
            ? null
            : BouncyButton(
                    onTap: canCreate
                        ? () => _showSavePresetDialog(context, api)
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.8),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                color: FluxTheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.savePreset,
                                style: const TextStyle(
                                  color: FluxTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 500.ms)
                  .slideY(begin: 0.5, curve: Curves.easeOutBack),
      ),
    );
  }

  void _showMutationDialog(_PresetMutationDialog dialog) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => FluxDialogCard(
        isDark: Theme.of(dialogContext).brightness == Brightness.dark,
        child: dialog,
      ),
    );
  }

  void _showSavePresetDialog(BuildContext context, WledApiService? api) {
    final presets = ref.read(presetsProvider);
    if (api == null ||
        _mutationInFlight ||
        presets.isLoading ||
        presets.hasError ||
        !presets.hasValue) {
      return;
    }
    final zh = ref.read(l10nProvider) is ZhStrings;
    final deviceId = ref.read(currentDeviceIdProvider);
    final used = {
      ...presets.requireValue.map((p) => p.id),
      ...?_savedSlots[api],
    };
    if (_availableSlot(used) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _message(
              zh,
              '预设槽位已满（最多250个），请先删除一个预设。',
              'All 250 preset slots are full. Delete a preset first.',
            ),
          ),
        ),
      );
      return;
    }
    _showMutationDialog(
      _PresetMutationDialog(
        zh: zh,
        onSubmit: (name) => _mutate(api, deviceId, () async {
          // A dialog's initial list can be stale. Confirm slots immediately
          // before writing, and reserve our successful writes until refreshed.
          final current = await api.getPresets();
          if (!_isTargetCurrent(api, deviceId)) {
            throw StateError('device changed');
          }
          final id = _availableSlot({
            ...used,
            ...current.keys.map(int.tryParse).whereType<int>(),
            ...?_savedSlots[api],
          });
          if (id == null) {
            throw _PresetOperationError(
              _message(
                zh,
                '预设槽位已满（最多250个），请先删除一个预设。',
                'All 250 preset slots are full. Delete a preset first.',
              ),
            );
          }
          await api.savePreset(id, name: name);
          (_savedSlots[api] ??= {}).add(id);
        }),
      ),
    );
  }

  void _showPresetOptions(
    BuildContext context,
    WledPreset preset,
    WledApiService api,
  ) {
    HapticFeedback.mediumImpact();
    final zh = ref.read(l10nProvider) is ZhStrings;
    final deviceId = ref.read(currentDeviceIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: ListTile(
          leading: const Icon(
            Icons.delete_forever_rounded,
            color: Colors.redAccent,
          ),
          title: Text(
            _message(zh, '删除预设', 'Delete preset'),
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () {
            Navigator.pop(sheetContext);
            if (_isTargetCurrent(api, deviceId)) {
              _showDeleteConfirm(context, preset, api, deviceId, zh);
            }
          },
        ),
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    WledPreset preset,
    WledApiService api,
    String? deviceId,
    bool zh,
  ) {
    _showMutationDialog(
      _PresetMutationDialog(
        zh: zh,
        preset: preset,
        onSubmit: (_) => _mutate(api, deviceId, () async {
          await api.deletePreset(preset.id);
          _savedSlots[api]?.remove(preset.id);
        }),
      ),
    );
  }
}

class _PresetOperationError implements Exception {
  const _PresetOperationError(this.message);
  final String message;
}

/// Owns form state for the lifetime of the dialog route, including its exit.
class _PresetMutationDialog extends StatefulWidget {
  const _PresetMutationDialog({
    required this.zh,
    required this.onSubmit,
    this.preset,
  });
  final bool zh;
  final WledPreset? preset;
  final Future<void> Function(String name) onSubmit;

  @override
  State<_PresetMutationDialog> createState() => _PresetMutationDialogState();
}

class _PresetMutationDialogState extends State<_PresetMutationDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  bool get _deleting => widget.preset != null;
  String _text(String zh, String en) => widget.zh ? zh : en;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _controller.text.trim();
    if (!_deleting && name.isEmpty) {
      setState(() => _error = _text('请输入预设名称', 'Enter a preset name'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(name);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is _PresetOperationError
              ? error.message
              : error is StateError
              ? _text(
                  '设备已切换或操作进行中，请关闭后重试。',
                  'Device changed or another operation is in progress. Close and retry.',
                )
              : _text(
                  '${_deleting ? '删除' : '保存'}失败，请检查设备连接后重试。',
                  '${_deleting ? 'Delete' : 'Save'} failed. Check the connection and retry.',
                );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _deleting
                ? Icons.warning_amber_rounded
                : Icons.bookmark_add_rounded,
            color: _deleting ? Colors.orangeAccent : FluxTheme.primary,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            _deleting
                ? _text('确定删除？', 'Delete preset?')
                : _text('保存当前为预设', 'Save current state'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 12),
          if (_deleting)
            Text(
              _text(
                '将删除预设 "${widget.preset!.name}"',
                'Delete preset "${widget.preset!.name}"',
              ),
              textAlign: TextAlign.center,
            )
          else
            TextField(
              controller: _controller,
              enabled: !_busy,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _text('预设名称', 'Preset name'),
                prefixIcon: const Icon(Icons.edit_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: FluxTheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 8),
            Text(
              _deleting
                  ? _text('正在删除…', 'Deleting…')
                  : _text('正在保存…', 'Saving…'),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(_text('取消', 'Cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _deleting
                        ? Colors.redAccent
                        : FluxTheme.primary,
                  ),
                  child: Text(
                    _deleting ? _text('删除', 'Delete') : _text('保存', 'Save'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final WledPreset preset;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PresetTile({
    required this.preset,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BouncyButton(
      onTap: onTap,
      onLongPress: onLongPress,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? FluxTheme.primary.withValues(alpha: 0.1)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${preset.id}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? FluxTheme.primary
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name.isEmpty ? '预设 ${preset.id}' : preset.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? FluxTheme.primary : null,
                    ),
                  ),
                  if (preset.name.isNotEmpty)
                    Text(
                      'ID: ${preset.id}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: FluxTheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
