import 'package:flutter/material.dart';
import 'package:hangisi_daha/core/responsive/responsive_content.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    this.appBarTitle,
    this.appBarActions,
    super.key,
  });

  final Widget child;
  final String? appBarTitle;
  final List<Widget>? appBarActions;

  @override
  Widget build(BuildContext context) {
    final hasAppBar =
        appBarTitle != null || (appBarActions?.isNotEmpty ?? false);
    return Scaffold(
      appBar: !hasAppBar
          ? null
          : AppBar(
              title: appBarTitle == null ? null : Text(appBarTitle!),
              actions: appBarActions,
            ),
      body: SafeArea(child: ResponsiveContent(child: child)),
    );
  }
}
