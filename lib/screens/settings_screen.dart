import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/core.dart';
import '../widgets/widgets.dart';
import '../providers/settings_provider.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // iOS Style Header
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
                      l10n.settings,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ],
                ),
              ),

              // Main List
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    // Interface Section
                    _buildSectionTitle(l10n.interfaceAndLanguage),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildSelectionTile(
                            context: context,
                            title: l10n.language,
                            icon: Icons.language_rounded,
                            iconColor: Colors.blueAccent,
                            value: _getLanguageName(settings.language, l10n),
                            onTap: () => _showLanguagePicker(
                              context,
                              settingsNotifier,
                              settings.language,
                              l10n,
                              isDark,
                            ),
                          ),
                          _buildSelectionTile(
                            context: context,
                            title: l10n.theme,
                            icon: Icons.palette_rounded,
                            iconColor: Colors.purpleAccent,
                            value: _getThemeModeName(settings.themeMode, l10n),
                            onTap: () => _showThemePicker(
                              context,
                              settingsNotifier,
                              settings.themeMode,
                              l10n,
                              isDark,
                            ),
                            isLast: true,
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 32),

                    // Experimental Features
                    _buildSectionTitle(l10n.experimental),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildToggleTile(
                            context: context,
                            title: l10n.testMode,
                            subtitle: l10n.testModeSubtitle,
                            icon: Icons.bug_report_rounded,
                            iconColor: Colors.amber,
                            value: false,
                            onChanged: (v) {},
                            isLast: true,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                    const SizedBox(height: 32),

                    // About Section
                    _buildSectionTitle(l10n.aboutWLink),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildValueTile(
                            context: context,
                            title: l10n.appVersion,
                            icon: Icons.info_outline_rounded,
                            iconColor: Colors.tealAccent,
                            value: 'v${AppConstants.appVersion}',
                          ),
                          _buildValueTile(
                            context: context,
                            title: l10n.projectUrl,
                            icon: Icons.code_rounded,
                            iconColor: Colors.orangeAccent,
                            value: 'GitHub / fkueyu',
                            onTap: () async {
                              final url = Uri.parse(
                                'https://github.com/fkueyu/W-Link',
                              );
                              if (await canLaunchUrl(url)) {
                                await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            isLast: true,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                    const SizedBox(height: 48),
                    BouncyButton(
                      onTap: () => _confirmReset(context, ref, l10n, isDark),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            l10n.resetData,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLanguageName(LanguageOption lang, AppStrings l10n) {
    switch (lang) {
      case LanguageOption.zh:
        return l10n.langZH;
      case LanguageOption.en:
        return l10n.langEN;
      case LanguageOption.system:
        return l10n.langSystem;
    }
  }

  String _getThemeModeName(ThemeModeOption mode, AppStrings l10n) {
    switch (mode) {
      case ThemeModeOption.light:
        return l10n.themeLight;
      case ThemeModeOption.dark:
        return l10n.themeDark;
      case ThemeModeOption.system:
        return l10n.themeSystem;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String value,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 56,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
      ],
    );
  }

  Widget _buildToggleTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: FluxTheme.primary,
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 56,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
      ],
    );
  }

  Widget _buildValueTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String value,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          trailing: Text(
            value,
            style: const TextStyle(
              color: FluxTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 56,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
      ],
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    SettingsNotifier notifier,
    LanguageOption currentValue,
    AppStrings l10n,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPickerSheet(
        context: context,
        title: l10n.language,
        options: [
          _PickerOption(l10n.langSystem, LanguageOption.system),
          _PickerOption(l10n.langZH, LanguageOption.zh),
          _PickerOption(l10n.langEN, LanguageOption.en),
        ],
        currentValue: currentValue,
        onSelected: (val) {
          notifier.setLanguage(val as LanguageOption);
          Navigator.pop(context);
        },
        isDark: isDark,
      ),
    );
  }

  void _showThemePicker(
    BuildContext context,
    SettingsNotifier notifier,
    ThemeModeOption currentValue,
    AppStrings l10n,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPickerSheet(
        context: context,
        title: l10n.theme,
        options: [
          _PickerOption(l10n.themeSystem, ThemeModeOption.system),
          _PickerOption(l10n.themeLight, ThemeModeOption.light),
          _PickerOption(l10n.themeDark, ThemeModeOption.dark),
        ],
        currentValue: currentValue,
        onSelected: (val) {
          notifier.setThemeMode(val as ThemeModeOption);
          Navigator.pop(context);
        },
        isDark: isDark,
      ),
    );
  }

  Widget _buildPickerSheet({
    required BuildContext context,
    required String title,
    required List<_PickerOption> options,
    required dynamic currentValue,
    required Function(dynamic) onSelected,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? FluxTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            ...options.map(
              (opt) => ListTile(
                title: Text(
                  opt.label,
                  style: TextStyle(
                    fontWeight: opt.value == currentValue
                        ? FontWeight.w900
                        : FontWeight.w500,
                    color: opt.value == currentValue ? FluxTheme.primary : null,
                  ),
                ),
                trailing: opt.value == currentValue
                    ? const Icon(Icons.check_rounded, color: FluxTheme.primary)
                    : null,
                onTap: () => onSelected(opt.value),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmReset(
    BuildContext context,
    WidgetRef ref,
    AppStrings l10n,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) =>
          Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? FluxTheme.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.resetConfirmTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.resetConfirmContent,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
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
                                  backgroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.clear();
                                  if (!ctx.mounted) {
                                    return;
                                  }
                                  Navigator.pop(ctx);
                                  AppToast.success(context, l10n.resetSuccess);
                                },
                                child: Text(l10n.resetData),
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

class _PickerOption {
  final String label;
  final dynamic value;
  _PickerOption(this.label, this.value);
}
