import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hangisi_daha/app/router/app_routes.dart';
import 'package:hangisi_daha/core/constants/app_radius.dart';
import 'package:hangisi_daha/core/constants/app_spacing.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';
import 'package:hangisi_daha/core/theme/app_colors.dart';
import 'package:hangisi_daha/core/widgets/app_scaffold.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = [
    _OnboardingPageData(
      icon: Icons.compare_arrows_rounded,
      title: 'Hangisi Daha?',
      message: 'İki seçenekten doğru olanı seç.',
      description:
          'Hangisinin daha büyük, hızlı, eski ya da uzun olduğunu tahmin et.',
    ),
    _OnboardingPageData(
      icon: Icons.all_inclusive_rounded,
      title: 'Klasik',
      message: 'Doğru bildikçe devam et.',
      description:
          'Her soru için 15 saniyen var. Yanlış cevap veya süre bitimi oyunu bitirir; jokerler sana yardım eder.',
    ),
    _OnboardingPageData(
      icon: Icons.timer_outlined,
      title: '60 Saniye',
      message: 'Süreyle yarış, skorunu yükselt.',
      description:
          'Doğru cevapta skor +1, süre değişmez. Art arda yanlışlarda süre cezası 1 saniyeden 4 saniyeye kadar artar; doğru cevap cezayı sıfırlar.',
    ),
  ];

  final _pageController = PageController();
  var _currentPage = 0;
  var _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_currentPage < _pages.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repository = await ref.read(
        localPreferencesRepositoryProvider.future,
      );
      await repository.setOnboardingCompleted();

      if (mounted) context.goNamed(AppRoute.home.name);
    } on Object {
      if (mounted) {
        setState(() {
          _errorMessage = 'İlerleme kaydedilemedi. Lütfen tekrar deneyin.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return AppScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    key: const Key('onboarding-pages'),
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (page) => setState(() {
                      _currentPage = page;
                      _errorMessage = null;
                    }),
                    itemBuilder: (context, index) =>
                        _OnboardingPage(data: _pages[index], page: index + 1),
                  ),
                ),
                _PageIndicator(
                  pageCount: _pages.length,
                  currentPage: _currentPage,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('onboarding-primary-button'),
                    onPressed: _isSaving ? null : _continue,
                    child: _isSaving
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isLastPage ? 'Oyuna Hazırım' : 'Devam'),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.page});

  final _OnboardingPageData data;
  final int page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.extraLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            key: Key('onboarding-illustration-$page'),
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: AppColors.outline),
            ),
            child: Icon(data.icon, size: 42, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.extraLarge),
          Text(
            data.title,
            key: Key('onboarding-title-$page'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            data.message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.medium),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              data.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.pageCount, required this.currentPage});

  final int pageCount;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final selected = index == currentPage;
        return AnimatedContainer(
          key: Key('onboarding-indicator-${index + 1}'),
          duration: const Duration(milliseconds: 180),
          width: selected ? 28 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : AppColors.outline,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.message,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String message;
  final String description;
}
