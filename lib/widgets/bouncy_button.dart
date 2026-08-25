import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 弹性缩放按钮
/// 提供类似 iOS 的按压回弹交互效果
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleTarget;
  final Duration duration;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool? selected;

  const BouncyButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleTarget = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.selected,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _showFocusHighlight = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      upperBound: 1.0,
      lowerBound: widget.scaleTarget,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    HapticFeedback.lightImpact();
    _controller.reverse();
  }

  void _handleTapUp(_) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.forward();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.forward();
  }

  bool get _isEnabled => widget.onTap != null || widget.onLongPress != null;

  void _activate() {
    if (widget.onTap == null) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _isEnabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: widget.onTap == null ? null : _activate,
      onLongPress: widget.onLongPress,
      child: FocusableActionDetector(
        enabled: widget.onTap != null,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (show) {
          if (_showFocusHighlight == show) return;
          setState(() => _showFocusHighlight = show);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _showFocusHighlight
                  ? const Color(0xFFAF47FF)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onLongPress: widget.onLongPress,
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
          ),
        ),
      ),
    );
  }
}
