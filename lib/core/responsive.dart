import 'package:flutter/material.dart';

/// Responsive breakpoints and utilities
class AppBreakpoints {
  static const double mobileSm = 320;
  static const double mobileMd = 375;
  static const double mobileLg = 428;
  static const double tabletSm = 600;
  static const double tabletMd = 768;
  static const double tabletLg = 1024;
  static const double desktop = 1280;
}

enum DeviceType { mobileSmall, mobile, mobileLarge, tablet, desktop }

enum ScreenSize { compact, medium, expanded }

class Responsive {
  static DeviceType getDeviceType(double width) {
    if (width < AppBreakpoints.mobileMd) return DeviceType.mobileSmall;
    if (width < AppBreakpoints.mobileLg) return DeviceType.mobile;
    if (width < AppBreakpoints.tabletSm) return DeviceType.mobileLarge;
    if (width < AppBreakpoints.desktop) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  static ScreenSize getScreenSize(double width) {
    if (width < AppBreakpoints.tabletSm) return ScreenSize.compact;
    if (width < AppBreakpoints.desktop) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  static bool isMobile(double width) => width < AppBreakpoints.tabletSm;
  static bool isTablet(double width) => width >= AppBreakpoints.tabletSm && width < AppBreakpoints.desktop;
  static bool isDesktop(double width) => width >= AppBreakpoints.desktop;
  static bool isCompact(double width) => width < AppBreakpoints.tabletSm;
  static bool isMedium(double width) => width >= AppBreakpoints.tabletSm && width < AppBreakpoints.desktop;
  static bool isExpanded(double width) => width >= AppBreakpoints.desktop;

  /// Returns a value based on screen width
  static T value<T>(double width, {required T compact, T? medium, T? expanded}) {
    if (isCompact(width)) return compact;
    if (isMedium(width)) return medium ?? compact;
    return expanded ?? medium ?? compact;
  }

  /// Returns padding based on screen width
  static EdgeInsets screenPadding(double width) {
    if (isCompact(width)) return const EdgeInsets.symmetric(horizontal: AppSpacing.md);
    if (isMedium(width)) return const EdgeInsets.symmetric(horizontal: AppSpacing.xl);
    return const EdgeInsets.symmetric(horizontal: AppSpacing.xl * 2);
  }

  /// Max content width for large screens
  static double maxContentWidth = 680;

  /// Constrain content width for larger screens
  static Widget constrainWidth(Widget child, double screenWidth) {
    if (screenWidth > maxContentWidth) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      );
    }
    return child;
  }
}

/// Spacing constants (alias for AppTokens spacing)
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Adaptive layout builder
class AdaptiveLayout extends StatelessWidget {
  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;

  const AdaptiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (Responsive.isExpanded(width) && expanded != null) {
      return expanded!(context);
    }
    if (Responsive.isMedium(width) && medium != null) {
      return medium!(context);
    }
    return compact!(context);
  }
}

/// Responsive grid columns
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 12.0,
    this.runSpacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (width < AppBreakpoints.mobileMd) {
      crossAxisCount = 2;
    } else if (width < AppBreakpoints.tabletSm) {
      crossAxisCount = 4;
    } else if (width < AppBreakpoints.desktop) {
      crossAxisCount = 5;
    } else {
      crossAxisCount = 6;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
