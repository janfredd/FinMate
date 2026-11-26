import 'package:flutter/material.dart';

/// Smooth slide-from-right + fade route used for every push transition.
Route<T> slideFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final offset = Tween<Offset>(
        begin: const Offset(0.12, 0),
        end: Offset.zero,
      ).animate(curved);
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.85, curve: Curves.easeOut),
      );
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}
