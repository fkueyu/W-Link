import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/core.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';

/// 效果列表页面
class EffectsListScreen extends ConsumerStatefulWidget {
  const EffectsListScreen({super.key});

  @override
  ConsumerState<EffectsListScreen> createState() => _EffectsListScreenState();
}

class _EffectsListScreenState extends ConsumerState<EffectsListScreen> {
  String _searchQuery = '';
  bool _showFavorites = false;

  @override
  Widget build(BuildContext context) {
    final effectsAsync = ref.watch(effectsProvider);
    final stateAsync = ref.watch(deviceStateProvider);
    final api = ref.watch(wledApiProvider);
    final favsService = ref.watch(favoritesServiceProvider);
    final favs = favsService.favoriteEffects;
    final l10n = ref.watch(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentFx = stateAsync.valueOrNull?.seg.isNotEmpty == true
        ? stateAsync.valueOrNull!.seg.first.fx
        : 0;

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
                      l10n.selectEffect,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const Spacer(),
                    BouncyButton(
                      onTap: () =>
                          setState(() => _showFavorites = !_showFavorites),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _showFavorites
                              ? FluxTheme.primary.withValues(alpha: 0.1)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.05)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _showFavorites
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: _showFavorites
                              ? FluxTheme.primary
                              : (isDark ? Colors.white70 : Colors.black54),
                          size: 24,
                        ),
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
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: l10n.searchEffectHint,
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
                      contentPadding: const EdgeInsets.only(bottom: 4),
                    ),
                    onChanged: (value) => setState(
                      () => _searchQuery = value.toLowerCase().trim(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // List
              Expanded(
                child: effectsAsync.when(
                  loading: () => const SkeletonListView(itemHeight: 70),
                  error: (e, s) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: FluxTheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.loadFailed,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        BouncyButton(
                          onTap: () => ref.invalidate(effectsProvider),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: FluxTheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              l10n.retry,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  data: (effects) {
                    final isZh = l10n is ZhStrings;
                    final filteredEffects = effects.asMap().entries.where((e) {
                      if (_showFavorites && !favs.contains(e.key)) return false;
                      if (_searchQuery.isEmpty) return true;
                      final eng = e.value.toLowerCase();
                      final zh = isZh
                          ? getEffectChineseName(e.value).toLowerCase()
                          : '';
                      return eng.contains(_searchQuery) ||
                          zh.contains(_searchQuery);
                    }).toList();

                    if (filteredEffects.isEmpty) {
                      return EmptyState(
                        icon: _showFavorites
                            ? Icons.star_border_rounded
                            : Icons.search_off_rounded,
                        title: _showFavorites
                            ? l10n.noFavorites
                            : l10n.noResults,
                        message: _showFavorites
                            ? l10n.noFavoritesMsg
                            : l10n.noResultsMsg,
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      itemCount: filteredEffects.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEffects[index];
                        final fxIdx = entry.key;
                        final name = entry.value;
                        final isSelected = currentFx == fxIdx;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child:
                              _EffectTile(
                                    englishName: name,
                                    chineseName: isZh
                                        ? getEffectChineseName(name)
                                        : name,
                                    index: fxIdx,
                                    isFavorite: favs.contains(fxIdx),
                                    onFavoriteToggle: () =>
                                        favsService.toggleEffectFavorite(fxIdx),
                                    isSelected: isSelected,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      ref
                                          .read(deviceStateProvider.notifier)
                                          .optimisticUpdate((s) {
                                            if (s.seg.isEmpty) return s;
                                            final newSeg = s.seg.first.copyWith(
                                              fx: fxIdx,
                                            );
                                            return s.copyWith(
                                              seg: [newSeg, ...s.seg.skip(1)],
                                            );
                                          }, () => api!.setEffect(fxIdx));
                                      Navigator.pop(context);
                                    },
                                  )
                                  .animate()
                                  .fadeIn(delay: (index * 15).ms)
                                  .slideX(begin: 0.05),
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
}

class _EffectTile extends StatelessWidget {
  final String englishName;
  final String chineseName;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _EffectTile({
    required this.englishName,
    required this.chineseName,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BouncyButton(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
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
                  '$index',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isSelected
                        ? FluxTheme.primary
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chineseName,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      fontSize: 16,
                      color: isSelected ? FluxTheme.primary : null,
                    ),
                  ),
                  if (chineseName != englishName)
                    Text(
                      englishName,
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
              )
            else
              BouncyButton(
                onTap: onFavoriteToggle,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFavorite
                        ? Colors.amber
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1)),
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
