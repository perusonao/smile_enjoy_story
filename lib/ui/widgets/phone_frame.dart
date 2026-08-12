import 'package:flutter/material.dart';

import '../theme.dart';

/// Centers [child] to a phone-ish column width on wide (desktop web)
/// viewports; fills the screen as-is on narrow (phone) viewports (§5).
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= phoneWidth) return child;
    return ColoredBox(
      color: SesTheme.primaryBlue.withValues(alpha: 0.04),
      child: Center(
        child: SizedBox(
          width: phoneWidth,
          child: Material(
            elevation: 4,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: child,
          ),
        ),
      ),
    );
  }
}
