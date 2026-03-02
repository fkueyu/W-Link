import 'dart:convert';
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
import 'effects_list_screen.dart';
import 'palettes_list_screen.dart';

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
                  data: (state) {
                    final segments = state.seg
                        .where((s) => s.stop > 0)
                        .toList();

                    // 为了让 2D 和 1D 界面的分段卡片展现出直观的物理顺序（按坐标自上而下、自左而右排列），而不是按创建 ID 的错乱顺序排列
                    segments.sort((a, b) {
                      if (a.startY != b.startY) {
                        return a.startY.compareTo(b.startY);
                      }
                      return a.start.compareTo(b.start);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: segments.length,
                      itemBuilder: (context, index) {
                        final segment = segments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _SegmentCard(
                            segment: segment,
                            index: index,
                            api: api!,
                            isDark: isDark,
                            l10n: l10n,
                            onDelete: () =>
                                _confirmDelete(context, segment.id, api),
                          ),
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

    final is2D = state.info.leds.matrix != null;
    final maxWidth = is2D ? state.info.leds.matrix!.width : totalLeds;
    final maxHeight = is2D ? state.info.leds.matrix!.height : 1;

    // 找到下一个分段的 ID
    int maxId = -1;
    for (final seg in state.seg) {
      if (seg.id > maxId) maxId = seg.id;
    }
    final nextId = maxId + 1;

    int newStart = 0;
    int newStop = maxWidth;
    int newStartY = 0;
    int newStopY = is2D ? maxHeight : 0;

    // 记录如果需要让位大分段，应该修改的段的 ID 及更新后的尺寸
    int? segmentToShrinkId;
    Map<String, int>? shrinkUpdates;

    if (is2D) {
      // 2D 智能分段：寻找面积最大的一块，沿最长边平分
      WledSegment? largestSeg;
      int maxArea = -1;
      for (final seg in state.seg) {
        final w = seg.stop - seg.start;
        final h = seg.stopY - seg.startY;
        final area = w * h;
        if (area > maxArea) {
          maxArea = area;
          largestSeg = seg;
        }
      }

      if (largestSeg != null) {
        final w = largestSeg.stop - largestSeg.start;
        final h = largestSeg.stopY - largestSeg.startY;

        if (w >= h) {
          // 沿 X 轴平分
          final midX = largestSeg.start + (w ~/ 2);
          // 缩小旧分段
          segmentToShrinkId = largestSeg.id;
          shrinkUpdates = {
            'start': largestSeg.start,
            'stop': midX,
            'startY': largestSeg.startY,
            'stopY': largestSeg.stopY,
          };
          // 新分段占据后半部分
          newStart = midX;
          newStop = largestSeg.stop;
          newStartY = largestSeg.startY;
          newStopY = largestSeg.stopY;
        } else {
          // 沿 Y 轴平分 (高 > 宽)
          final midY = largestSeg.startY + (h ~/ 2);
          // 缩小旧分段
          segmentToShrinkId = largestSeg.id;
          shrinkUpdates = {
            'start': largestSeg.start,
            'stop': largestSeg.stop,
            'startY': largestSeg.startY,
            'stopY': midY,
          };
          // 新分段占据下半部分
          newStart = largestSeg.start;
          newStop = largestSeg.stop;
          newStartY = midY;
          newStopY = largestSeg.stopY;
        }
      }
    } else {
      // 1D 智能分段：先找空隙，找不到空隙再对半切分最大块
      // 1. 寻找空隙
      final sortedSegs = List<WledSegment>.from(state.seg)
        ..sort((a, b) => a.start.compareTo(b.start));

      int largestGapStart = -1;
      int largestGapStop = -1;
      int largestGapLen = -1;

      int currentCursor = 0;
      for (final seg in sortedSegs) {
        if (seg.start > currentCursor) {
          final gapLen = seg.start - currentCursor;
          if (gapLen > largestGapLen) {
            largestGapLen = gapLen;
            largestGapStart = currentCursor;
            largestGapStop = seg.start;
          }
        }
        if (seg.stop > currentCursor) {
          currentCursor = seg.stop;
        }
      }
      // 检查尾部空隙
      if (totalLeds > currentCursor) {
        final gapLen = totalLeds - currentCursor;
        if (gapLen > largestGapLen) {
          largestGapLen = gapLen;
          largestGapStart = currentCursor;
          largestGapStop = totalLeds;
        }
      }

      if (largestGapLen > 0) {
        // 找到了空隙，放在最大空隙处
        newStart = largestGapStart;
        newStop = largestGapStop;
      } else {
        // 2. 没有空隙，找到最长的一个段，对半切
        WledSegment? longestSeg;
        int maxLen = -1;
        for (final seg in state.seg) {
          if (seg.len > maxLen) {
            maxLen = seg.len;
            longestSeg = seg;
          }
        }

        if (longestSeg != null && maxLen > 1) {
          final mid = longestSeg.start + (maxLen ~/ 2);
          segmentToShrinkId = longestSeg.id;
          shrinkUpdates = {
            'start': longestSeg.start,
            'stop': mid,
            'startY': longestSeg.startY,
            'stopY': longestSeg.stopY,
          };

          newStart = mid;
          newStop = longestSeg.stop;
        } else if (longestSeg != null && maxLen == 1) {
          // 只剩下一个灯珠了，没法再拆
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已达到可拆分极限')));
          return;
        }
      }
    }

    // 定义一组预设的美观颜色，根据 nextId 循环分配，让新分段在视觉上更容易区分
    final presetColors = [
      [255, 160, 0], // 橙色
      [0, 200, 255], // 青色
      [200, 0, 255], // 紫色
      [0, 255, 100], // 绿色
      [255, 0, 100], // 粉白
      [255, 230, 0], // 黄色
    ];
    final selectedColor = presetColors[nextId % presetColors.length];

    // 构造将要在状态中添加的新节点及受影响老节点
    final newSegment = WledSegment(
      id: nextId,
      start: newStart,
      stop: newStop,
      startY: newStartY,
      stopY: newStopY,
      on: true,
      col: [selectedColor],
    );

    ref
        .read(deviceStateProvider.notifier)
        .optimisticUpdate(
          (s) {
            final updatedSegs = s.seg.map((seg) {
              if (seg.id == segmentToShrinkId && shrinkUpdates != null) {
                return seg.copyWith(
                  start: shrinkUpdates['start'] ?? seg.start,
                  stop: shrinkUpdates['stop'] ?? seg.stop,
                  startY: shrinkUpdates['startY'] ?? seg.startY,
                  stopY: shrinkUpdates['stopY'] ?? seg.stopY,
                );
              }
              return seg;
            }).toList();
            updatedSegs.add(newSegment);
            return s.copyWith(seg: updatedSegs);
          },
          () async {
            // 将修改已有分段和创建新分段合并为一次性批量请求
            final batchPayload = <Map<String, dynamic>>[];

            if (segmentToShrinkId != null && shrinkUpdates != null) {
              final shrinkMap = <String, dynamic>{
                'id': segmentToShrinkId,
                'start': shrinkUpdates['start'],
                'stop': shrinkUpdates['stop'],
              };
              if (is2D) {
                shrinkMap['startY'] = shrinkUpdates['startY'];
                shrinkMap['stopY'] = shrinkUpdates['stopY'];
              }
              batchPayload.add(shrinkMap);
            }

            final newSegMap = <String, dynamic>{
              'id': nextId,
              'start': newStart,
              'stop': newStop,
              'on': true,
              'col': [
                selectedColor,
                [0, 0, 0],
                [0, 0, 0],
              ],
            };

            if (is2D) {
              newSegMap['startY'] = newStartY;
              newSegMap['stopY'] = newStopY;
            }
            batchPayload.add(newSegMap);

            debugPrint(
              '[SmartSegment] Batch Payload: ${jsonEncode(batchPayload)}',
            );

            return api.updateMultipleSegments(batchPayload);
          },
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

                                  ref
                                      .read(deviceStateProvider.notifier)
                                      .optimisticUpdate(
                                        (s) => s.copyWith(
                                          seg: s.seg
                                              .where((s) => s.id != segmentId)
                                              .toList(),
                                        ),
                                        () => api.deleteSegment(segmentId),
                                      );
                                  // 强制拉取最新状态（跳过保护窗口）
                                  Future.delayed(
                                    const Duration(milliseconds: 500),
                                    () => ref
                                        .read(deviceStateProvider.notifier)
                                        .forceRefresh(),
                                  );
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

          // ── Per-Segment Controls ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // 亮度
                _buildSlider(
                  l10n.brightness,
                  (segment.bri ?? 255).toDouble(),
                  0,
                  255,
                  (v) => ref
                      .read(deviceStateProvider.notifier)
                      .optimisticUpdate(
                        (s) => s.copyWith(
                          seg: s.seg
                              .map(
                                (seg) => seg.id == segment.id
                                    ? seg.copyWith(bri: v.round())
                                    : seg,
                              )
                              .toList(),
                        ),
                        () => api.setSegmentState(segment.id, bri: v.round()),
                      ),
                ),
                const SizedBox(height: 12),

                // 颜色 · 效果 · 调色板
                Row(
                  children: [
                    // 颜色色块
                    BouncyButton(
                      onTap: () =>
                          _showSegmentColorPicker(context, ref, segment, api),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 效果按钮
                    Expanded(
                      child: _buildMiniActionTile(
                        context,
                        Icons.auto_awesome_rounded,
                        _getEffectLabel(ref, segment.fx),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EffectsListScreen(segmentId: segment.id),
                          ),
                        ),
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 调色板按钮
                    Expanded(
                      child: _buildMiniActionTile(
                        context,
                        Icons.palette_rounded,
                        _getPaletteLabel(ref, segment.pal),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PalettesListScreen(segmentId: segment.id),
                          ),
                        ),
                        isDark,
                      ),
                    ),
                  ],
                ),

                // 速度/强度 (仅当 fx != 0 时显示)
                if (segment.fx != 0) ...[
                  const SizedBox(height: 12),
                  _buildSlider(
                    l10n is ZhStrings ? '速度' : 'Speed',
                    segment.sx.toDouble(),
                    0,
                    255,
                    (v) => ref
                        .read(deviceStateProvider.notifier)
                        .optimisticUpdate(
                          (s) => s.copyWith(
                            seg: s.seg
                                .map(
                                  (seg) => seg.id == segment.id
                                      ? seg.copyWith(sx: v.round())
                                      : seg,
                                )
                                .toList(),
                          ),
                          () => api.setSegmentState(segment.id, sx: v.round()),
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildSlider(
                    l10n is ZhStrings ? '强度' : 'Intensity',
                    segment.ix.toDouble(),
                    0,
                    255,
                    (v) => ref
                        .read(deviceStateProvider.notifier)
                        .optimisticUpdate(
                          (s) => s.copyWith(
                            seg: s.seg
                                .map(
                                  (seg) => seg.id == segment.id
                                      ? seg.copyWith(ix: v.round())
                                      : seg,
                                )
                                .toList(),
                          ),
                          () => api.setSegmentState(segment.id, ix: v.round()),
                        ),
                  ),
                ],
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),

          // Row 2: Range & Grouping (collapsible)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              initiallyExpanded: false,
              title: Text(
                l10n is ZhStrings ? '高级' : 'Advanced',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              iconColor: isDark ? Colors.white38 : Colors.black38,
              collapsedIconColor: isDark ? Colors.white24 : Colors.black26,
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

  // ── Helper Methods ──

  void _showSegmentColorPicker(
    BuildContext context,
    WidgetRef ref,
    WledSegment seg,
    WledApiService api,
  ) {
    final current = seg.col.isNotEmpty && seg.col.first.length >= 3
        ? Color.fromARGB(
            255,
            seg.col.first[0],
            seg.col.first[1],
            seg.col.first[2],
          )
        : FluxTheme.primary;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ColorPickerSheet(
        initialColor: current,
        onColorChanged: (color) {
          final rgb = [
            (color.r * 255).round(),
            (color.g * 255).round(),
            (color.b * 255).round(),
          ];
          ref.read(deviceStateProvider.notifier).optimisticUpdate((s) {
            final segs = s.seg.toList();
            final idx = segs.indexWhere((s) => s.id == seg.id);
            if (idx == -1) return s;
            final cols = segs[idx].col.toList();
            if (cols.isNotEmpty) {
              cols[0] = rgb;
            } else {
              cols.add(rgb);
            }
            segs[idx] = segs[idx].copyWith(col: cols);
            return s.copyWith(seg: segs);
          }, () => api.setSegmentState(seg.id, col: [rgb]));
        },
      ),
    );
  }

  Widget _buildMiniActionTile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    bool isDark,
  ) {
    return BouncyButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  String _getEffectLabel(WidgetRef ref, int fx) {
    final effects = ref.read(effectsProvider).valueOrNull;
    if (effects == null || fx >= effects.length) return 'FX $fx';
    final l10n = ref.read(l10nProvider);
    if (l10n is ZhStrings) return getEffectChineseName(effects[fx]);
    return effects[fx];
  }

  String _getPaletteLabel(WidgetRef ref, int pal) {
    final palettes = ref.read(palettesProvider).valueOrNull;
    if (palettes == null || pal >= palettes.length) return 'Pal $pal';
    final l10n = ref.read(l10nProvider);
    if (l10n is ZhStrings) return getPaletteChineseName(palettes[pal]);
    return palettes[pal];
  }
}
