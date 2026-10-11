import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hangisi_daha/app/router/app_routes.dart';
import 'package:hangisi_daha/core/audio/sound_effects_controller.dart';
import 'package:hangisi_daha/core/constants/app_radius.dart';
import 'package:hangisi_daha/core/constants/app_spacing.dart';
import 'package:hangisi_daha/core/theme/app_colors.dart';
import 'package:hangisi_daha/core/widgets/app_scaffold.dart';
import 'package:hangisi_daha/core/widgets/game_motion.dart';
import 'package:hangisi_daha/features/game/providers/game_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalBests = ref.watch(personalBestsProvider);
    final soundEffects = ref.watch(soundEffectsControllerProvider);
    final soundEnabled = soundEffects.value ?? true;

    return AppScaffold(
      appBarActions: [
        IconButton(
          key: const Key('sound-effects-button'),
          tooltip: soundEnabled
              ? 'Ses efektlerini kapat'
              : 'Ses efektlerini aç',
          onPressed: soundEffects.isLoading
              ? null
              : () => _toggleSound(context, ref, !soundEnabled),
          icon: Icon(
            soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.small),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          key: const Key('home-content'),
          padding: const EdgeInsets.only(
            top: AppSpacing.large,
            bottom: AppSpacing.large,
          ),
          children: [
            Text(
              'Hangisi Daha?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              'İki seçenek. Tek doğru cevap.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.extraLarge),
            _BestScorePanel(personalBests: personalBests),
            const SizedBox(height: AppSpacing.large),
            _PressableStartButton(onPressed: () => _selectGameMode(context)),
            const SizedBox(height: AppSpacing.medium),
            _SecondaryActions(compact: constraints.maxWidth < 430),
          ],
        ),
      ),
    );
  }

  Future<void> _selectGameMode(BuildContext context) async {
    final route = await showModalBottomSheet<AppRoute>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => const _ModeSelectionSheet(),
    );
    if (route != null && context.mounted) {
      await context.pushNamed(route.name);
    }
  }

  Future<void> _toggleSound(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    try {
      await ref
          .read(soundEffectsControllerProvider.notifier)
          .setEnabled(enabled);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ses ayarı kaydedilemedi. Lütfen tekrar deneyin.'),
          ),
        );
      }
    }
  }
}

class _BestScorePanel extends StatelessWidget {
  const _BestScorePanel({required this.personalBests});

  final AsyncValue<LocalPersonalBests> personalBests;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('best-score-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: AppSpacing.medium,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.secondary,
                size: 21,
              ),
              const SizedBox(width: AppSpacing.small),
              Text(
                'EN İYİ SKORLARIN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BestScoreValue(
                  key: const Key('classic-best-score'),
                  label: 'KLASİK',
                  value: personalBests.when(
                    data: (bests) => '${bests.classicScore}',
                    loading: () => '…',
                    error: (error, stackTrace) => '—',
                  ),
                ),
              ),
              Container(width: 1, height: 52, color: AppColors.outline),
              Expanded(
                child: _BestScoreValue(
                  key: const Key('time-attack-best-score'),
                  label: '60 SANİYE',
                  value: personalBests.when(
                    data: (bests) => bests.timeAttackScore > 0
                        ? '${bests.timeAttackScore}'
                        : 'Henüz skor yok',
                    loading: () => '…',
                    error: (error, stackTrace) => '—',
                  ),
                  compactValue: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BestScoreValue extends StatelessWidget {
  const _BestScoreValue({
    required this.label,
    required this.value,
    this.compactValue = false,
    super.key,
  });

  final String label;
  final String value;
  final bool compactValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.extraSmall),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: compactValue && value.length > 3
                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  )
                : Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelectionSheet extends StatelessWidget {
  const _ModeSelectionSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        0,
        AppSpacing.large,
        AppSpacing.large,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Oyun Modunu Seç',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.large),
              _ModeOption(
                key: const Key('classic-mode-option'),
                pressMarkerKey: const Key('classic-mode-press-motion'),
                icon: Icons.all_inclusive_rounded,
                title: 'KLASİK',
                description: 'Doğru bildikçe devam et.',
                onTap: () => Navigator.pop(context, AppRoute.game),
              ),
              const SizedBox(height: AppSpacing.regular),
              _ModeOption(
                key: const Key('time-attack-mode-option'),
                pressMarkerKey: const Key('time-attack-mode-press-motion'),
                icon: Icons.timer_outlined,
                title: '60 SANİYE',
                description: 'Süre bitmeden olabildiğince yüksek skor yap.',
                onTap: () => Navigator.pop(context, AppRoute.timeAttack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.pressMarkerKey,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Key pressMarkerKey;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      markerKey: pressMarkerKey,
      child: Material(
        color: AppColors.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          side: const BorderSide(color: AppColors.outline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Row(
              children: [
                Icon(icon, size: 30, color: AppColors.primary),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: AppSpacing.extraSmall),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableStartButton extends StatelessWidget {
  const _PressableStartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      markerKey: const Key('start-game-press-motion'),
      child: FilledButton.icon(
        key: const Key('start-game-button'),
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow_rounded, size: 29),
        label: const Text('Başla'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(62),
          textStyle: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final howTo = OutlinedButton.icon(
      onPressed: () => context.pushNamed(AppRoute.howToPlay.name),
      icon: const Icon(Icons.help_outline_rounded),
      label: const Text('Nasıl Oynanır'),
    );
    return SizedBox(
      width: double.infinity,
      child: compact ? howTo : Center(child: howTo),
    );
  }
}
