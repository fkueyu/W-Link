import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/core.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';
import '../widgets/smart_slider.dart';

/// 分段管理页面
class SegmentsListScreen extends ConsumerStatefulWidget {
  const SegmentsListScreen({super.key});

  @override
  ConsumerState<SegmentsListScreen> createState() => _SegmentsListScreenState();
}

class _SegmentsListScreenState extends ConsumerState<SegmentsListScreen> {
  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(deviceStateProvider);
    final api = ref.watch(wledApiProvider);
    final l10n = ref.watch(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          bottom: false,
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
                      l10n.segments,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 8),
                    BouncyButton(
                      onTap: () => _showAddSegmentDialog(context, api),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FluxTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: FluxTheme.primary,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Info Row
              stateAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
                data: (state) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _buildMiniInfo(
                        'LEDs',
                        '${state.info.leds.count}',
                        isDark,
                      ),
                      const SizedBox(width: 12),
                      _buildMiniInfo(
                        l10n.segments,
                        '${state.seg.length}',
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),

              // List
              Expanded(
                child: stateAsync.when(
                  loading: () => const SkeletonListView(itemHeight: 120),
                  error: (e, s) => Center(child: Text('Error: $e')),
                  data: (state) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: state.seg.length,
                    itemBuilder: (context, index) {
                      final segment = state.seg[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child:
                            _SegmentCard(
                                  segment: segment,
                                  index: index,
                                  api: api!,
                                  isDark: isDark,
                                  l10n: l10n,
                                  onDelete: () =>
                                      _confirmDelete(context, segment.id, api),
                                )
                                .animate()
                                .fadeIn(delay: (index * 50).ms)
                                .slideY(begin: 0.1),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showAddSegmentDialog(BuildContext context, WledApiService? api) {
    final state = ref.read(deviceStateProvider).valueOrNull;
    if (api == null || state == null) return;

    final totalLeds = state.info.leds.count;
    if (totalLeds == 0) return;

    // 找到当前最大的 stop 值作为新分段的起点
    // 同时也确定下一个分段的 ID
    int lastStop = 0;
    int maxId = -1;
    for (final seg in state.seg) {
      if (seg.stop > lastStop) lastStop = seg.stop;
      if (seg.id > maxId) maxId = seg.id;
    }

    if (lastStop >= totalLeds) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已达到 LED 总数上限')));
      return;
    }

    final nextId = maxId + 1;

    // 添加一个覆盖剩余部分的新分段，明确指出 ID
    ref
        .read(deviceStateProvider.notifier)
        .optimisticUpdate(
          (s) => s.copyWith(
            seg: [
              ...s.seg,
              WledSegment(
                id: nextId,
                start: lastStop,
                stop: totalLeds,
                on: true,
                col: [
                  [255, 160, 0],
                ],
              ),
            ],
          ),
          () => api.setSegmentState(
            nextId,
            start: lastStop,
            stop: totalLeds,
            on: true,
          ),
        );
  }

  void _confirmDelete(BuildContext context, int segmentId, WledApiService api) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
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
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orangeAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '删除分段？',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '确定要删除分段 #$segmentId 吗？',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  '取消',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  api.deleteSegment(segmentId);
                                  ref
                                      .read(deviceStateProvider.notifier)
                                      .refresh();
                                },
                                child: const Text('删除'),
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
  }
}

class _SegmentCard extends ConsumerWidget {
  final WledSegment segment;
  final int index;
  final WledApiService api;
  final bool isDark;
  final AppStrings l10n;
  final VoidCallback onDelete;

  const _SegmentCard({
    required this.segment,
    required this.index,
    required this.api,
    required this.isDark,
    required this.l10n,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceStateProvider).valueOrNull;
    if (state == null) return const SizedBox();
    final color = segment.col.isNotEmpty && segment.col.first.length >= 3
        ? Color.fromARGB(
            255,
            segment.col.first[0],
            segment.col.first[1],
            segment.col.first[2],
          )
        : FluxTheme.primary;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Row 1: Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: segment.on
                        ? color.withValues(alpha: 0.15)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03)),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: segment.on ? color : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    segment.n.isEmpty ? '${l10n.segment} $index' : segment.n,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: segment.on,
                  activeTrackColor: color,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    ref
                        .read(deviceStateProvider.notifier)
                        .optimisticUpdate(
                          (s) => s.copyWith(
                            seg: s.seg
                                .map(
                                  (seg) => seg.id == segment.id
                                      ? seg.copyWith(on: val)
                                      : seg,
                                )
                                .toList(),
                          ),
                          () => api.setSegmentState(segment.id, on: val),
                        );
                  },
                ),
                BouncyButton(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),

          // Row 2: Range & Grouping
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRangeRow(context, ref, state, l10n),
                const SizedBox(height: 20),
                _buildSlider(
                  l10n.grouping,
                  segment.grp.toDouble(),
                  1,
                  255,
                  (v) => ref
                      .read(deviceStateProvider.notifier)
                      .optimisticUpdate(
                        (s) => s.copyWith(
                          seg: s.seg
                              .map(
                                (seg) => seg.id == segment.id
                                    ? seg.copyWith(grp: v.round())
                                    : seg,
                              )
                              .toList(),
                        ),
                        () => api.setSegmentState(segment.id, grp: v.round()),
                      ),
                ),
                const SizedBox(height: 16),
                _buildSlider(
                  l10n.spacing,
                  segment.spc.toDouble(),
                  0,
                  255,
                  (v) => ref
                      .read(deviceStateProvider.notifier)
                      .optimisticUpdate(
                        (s) => s.copyWith(
                          seg: s.seg
                              .map(
                                (seg) => seg.id == segment.id
                                    ? seg.copyWith(spc: v.round())
                                    : seg,
                              )
                              .toList(),
                        ),
                        () => api.setSegmentState(segment.id, spc: v.round()),
                      ),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeRow(
    BuildContext context,
    WidgetRef ref,
    WledState state,
    AppStrings l10n,
  ) {
    // 检查是否为 2D 模式 (通过 info 中的矩阵配置判断)
    final is2D = state.info.leds.matrix != null;

    if (!is2D) {
      return Row(
        children: [
          Expanded(
            child: _buildRangeInput(
              context,
              l10n.start,
              segment.start,
              state.info.leds.count,
              (v) => ref
                  .read(deviceStateProvider.notifier)
                  .optimisticUpdate(
                    (s) => s.copyWith(
                      seg: s.seg
                          .map(
                            (seg) => seg.id == segment.id
                                ? seg.copyWith(start: v)
                                : seg,
                          )
                          .toList(),
                    ),
                    () => api.setSegmentState(segment.id, start: v),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: _buildRangeInput(
              context,
              l10n.stop,
              segment.stop,
              state.info.leds.count,
              (v) => ref
                  .read(deviceStateProvider.notifier)
                  .optimisticUpdate(
                    (s) => s.copyWith(
                      seg: s.seg
                          .map(
                            (seg) => seg.id == segment.id
                                ? seg.copyWith(stop: v)
                                : seg,
                          )
                          .toList(),
                    ),
                    () => api.setSegmentState(segment.id, stop: v),
                  ),
            ),
          ),
        ],
      );
    } else {
      // 2D 矩阵布局
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildRangeInput(
                  context,
                  'Start X',
                  segment.start,
                  state.info.leds.matrix?.width ?? 255,
                  (v) => ref
                      .read(deviceStateProvider.notifier)
                      .optimisticUpdate(
                        (s) => s.copyWith(
                          seg: s.seg
                              .map(
                                (seg) => seg.id == segment.id
                                    ? seg.copyWith(start: v)
                                    : seg,
                              )
                              .toList(),
                        ),
                        () => api.setSegmentState(segment.id, start: v),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRangeInput(
                  context,
                  'Stop X',
                  segment.stop,
                  state.info.leds.matrix?.width ?? 255,
                  (v) => ref
                      .read(deviceStateProvider.notifier)
                      .optimisticUpdate(
                        (s) => s.copyWith(
                          seg: s.seg
                              .map(
                                (seg) => seg.id == segment.id
                                    ? seg.copyWith(stop: v)
                                    : seg,
                              )
                              .toList(),
                        ),
                        () => api.setSegmentState(segment.id, stop: v),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRangeInput(
                  context,
                  'Start Y',
                  segment.startY,
                  state.info.leds.matrix?.height ?? 255,
                  (v) => ref
                      .read(deviceStateProvider.notifier)
                      .optimisticUpdate(
                        (s) => s.copyWith(
                          seg: s.seg
                              .map(
                                (seg) => seg.id == segment.id
                                    ? seg.copyWith(startY: v)
                                    : seg,
                              )
                              .toList(),
                        ),
                        () => api.setSegmentState(segment.id, startY: v),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRangeInput(
                  context,
                  'Stop Y',
                  segment.stopY,
                  state.info.leds.matrix?.height ?? 255,
                  (v) => ref
                      .read(deviceStateProvider.notifier)
                      .optimisticUpdate(
                        (s) => s.copyWith(
                          seg: s.seg
                              .map(
                                (seg) => seg.id == segment.id
                                    ? seg.copyWith(stopY: v)
                                    : seg,
                              )
                              .toList(),
                        ),
                        () => api.setSegmentState(segment.id, stopY: v),
                      ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildRangeInput(
    BuildContext context,
    String label,
    int value,
    int maxLeds,
    ValueChanged<int> onChanged,
  ) {
    return BouncyButton(
      onTap: () => _editValue(context, label, value, maxLeds, onChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _editValue(
    BuildContext context,
    String label,
    int currentValue,
    int maxLeds,
    ValueChanged<int> onChanged,
  ) {
    final controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改$label'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: InputDecoration(
            hintText: '范围: 0 - $maxLeds',
            suffixText: 'LED',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text);
              if (newValue != null && newValue >= 0 && newValue <= maxLeds) {
                onChanged(newValue);
                Navigator.pop(ctx);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChangeEnd, {
    bool isLast = false,
  }) {
    return SmartSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      activeColor: segment.on ? FluxTheme.primary : Colors.grey,
      onChangeEnd: onChangeEnd,
    );
  }
}
