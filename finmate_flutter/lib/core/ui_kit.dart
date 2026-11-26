import 'dart:async';

import 'package:flutter/material.dart';

/// Scales its child down slightly while pressed, then springs back.
/// Uses [Listener] so it never steals taps from the wrapped widget.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;

  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fade + slide-up entrance animation, with an optional stagger [delay].
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.offsetY = 16,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _timer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final bool shadow;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.gradient,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? scheme.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.24 : 0.055),
                  blurRadius: 30,
                  spreadRadius: -8,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class GradientPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  const GradientPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gradient = LinearGradient(
      colors: [scheme.primary, scheme.tertiary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final content = AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null ? 0.55 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.32),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: scheme.onPrimary, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
    return onPressed == null ? content : PressableScale(child: content);
  }
}

class PlayfulIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const PlayfulIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.9),
                    scheme.tertiary.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(icon, color: scheme.onPrimary, size: 44),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class FinLogo extends StatelessWidget {
  final double size;
  final bool showName;

  const FinLogo({super.key, this.size = 52, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(Icons.account_balance_wallet_rounded,
          color: scheme.onPrimary, size: size * 0.48),
    );
    if (!showName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Text(
          'FinMate',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}
