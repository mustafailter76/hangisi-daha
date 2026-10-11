import 'package:flutter/widgets.dart';
import 'package:hangisi_daha/core/constants/app_spacing.dart';

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.maxContentWidth = 720,
    super.key,
  });

  final Widget child;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = switch (width) {
      < 600 => AppSpacing.medium,
      < 1024 => AppSpacing.extraLarge,
      _ => AppSpacing.extraLarge + AppSpacing.medium,
    };

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxContentWidth + (horizontalPadding * 2),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}
