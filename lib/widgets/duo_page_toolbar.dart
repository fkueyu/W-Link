import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n.dart';
import '../providers/providers.dart';
import '../services/duo_toolbar_service.dart';
import 'duo_system_toolbar.dart';

/// 二级页面统一的系统返回与页面动作；原生不可用时由builder保留页面入口。
class DuoPageToolbar extends ConsumerWidget {
  const DuoPageToolbar({
    super.key,
    required this.builder,
    this.primaryLabel,
    this.primarySymbol = 'plus',
    this.onPrimary,
    this.primaryEnabled = true,
    this.primaryDestructive = false,
    this.primaryBusy = false,
    this.menu = const [],
    this.onMenuSelected,
  });

  final Widget Function(BuildContext, bool) builder;
  final String? primaryLabel;
  final String primarySymbol;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;
  final bool primaryDestructive;
  final bool primaryBusy;
  final List<DuoToolbarMenuEntry> menu;
  final ValueChanged<String>? onMenuSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useSystemToolbar =
        ref.watch(duoToolbarReadyProvider).valueOrNull ?? false;
    final strings = ref.watch(l10nProvider);
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    return Stack(
      fit: StackFit.expand,
      children: [
        builder(context, useSystemToolbar),
        if (useSystemToolbar)
          DuoSystemToolbar(
            visible: current,
            backLabel: strings is ZhStrings ? '返回' : 'Back',
            onBack: () => Navigator.of(context).maybePop(),
            addLabel: primaryLabel ?? '',
            addSymbol: primarySymbol,
            addEnabled: primaryEnabled && !primaryBusy,
            addDestructive: primaryDestructive,
            addBusy: primaryBusy,
            showPrimary: onPrimary != null,
            onAdd: onPrimary ?? () {},
            moreLabel: strings.moreActions,
            showMenu: menu.isNotEmpty,
            menu: menu,
            onMenuSelected: (id) {
              if (menu.any((entry) => entry.id == id && entry.enabled)) {
                onMenuSelected?.call(id);
              }
            },
          ),
      ],
    );
  }
}
