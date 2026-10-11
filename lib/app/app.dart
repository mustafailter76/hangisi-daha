import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangisi_daha/app/router/app_router.dart';
import 'package:hangisi_daha/core/constants/app_spacing.dart';
import 'package:hangisi_daha/core/startup/startup_providers.dart';
import 'package:hangisi_daha/core/theme/app_theme.dart';

class HangisiDahaApp extends ConsumerWidget {
  const HangisiDahaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routerState = ref.watch(appRouterProvider);

    return routerState.when(
      data: (router) => MaterialApp.router(
        title: 'Hangisi Daha?',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: router,
      ),
      loading: () => const _StartupApp(),
      error: (error, stackTrace) => _StartupApp(
        showError: true,
        onRetry: () {
          ref.invalidate(startupDestinationProvider);
          ref.invalidate(appRouterProvider);
        },
      ),
    );
  }
}

class _StartupApp extends StatelessWidget {
  const _StartupApp({this.showError = false, this.onRetry});

  final bool showError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hangisi Daha?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: showError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Bağlantı kurulamadı. Lütfen tekrar deneyin.'),
                      const SizedBox(height: AppSpacing.medium),
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
