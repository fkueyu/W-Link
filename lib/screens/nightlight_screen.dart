import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';

class NightlightScreen extends ConsumerWidget {
  const NightlightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(deviceStateProvider);
    final strings = ref.watch(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.read(currentDeviceSessionNotifierProvider);

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(
                  children: [
                    BouncyButton(
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
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
                    Expanded(
                      child: Text(
                        strings.nightlight,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: stateAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: FluxTheme.primary),
                  ),
                  error: (_, _) => Center(child: Text(strings.loadFailed)),
                  data: (state) => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    children: [
                      NightlightEditor(
                        value: state.nl,
                        strings: strings,
                        onChanged: (next) {
                          session.updateNightlight(next);
                        },
                      ),
                      const SizedBox(height: 28),
                      _NightlightTip(strings: strings),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NightlightTip extends StatelessWidget {
  const _NightlightTip({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FluxTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FluxTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: FluxTheme.primary,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            strings.scheduleTipTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: FluxTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.scheduleTipContent,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: FluxTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
