import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hangisi_daha/app/router/app_routes.dart';
import 'package:hangisi_daha/core/constants/app_radius.dart';
import 'package:hangisi_daha/core/constants/app_spacing.dart';
import 'package:hangisi_daha/core/theme/app_colors.dart';
import 'package:hangisi_daha/core/widgets/game_motion.dart';
import 'package:hangisi_daha/features/local_content/local_content_providers.dart';
import 'package:hangisi_daha/features/time_attack/models/time_attack_models.dart';
import 'package:hangisi_daha/features/time_attack/models/time_attack_state.dart';
import 'package:hangisi_daha/features/time_attack/providers/time_attack_controller.dart';

typedef TimeAttackImagePreloader =
    Future<void> Function(BuildContext context, List<String> imagePaths);

final timeAttackImagePreloaderProvider = Provider<TimeAttackImagePreloader>((
  ref,
) {
  return (context, imagePaths) async {
    await Future.wait(
      imagePaths.map((path) async {
        try {
          await precacheImage(AssetImage(path), context, onError: (_, _) {});
        } on Object {
          // The card's errorBuilder is the render-ready fallback. A broken
          // image must not leave the question in PREPARING forever.
        }
      }),
    );
  };
});

class TimeAttackScreen extends ConsumerStatefulWidget {
  const TimeAttackScreen({super.key});

  @override
  ConsumerState<TimeAttackScreen> createState() => _TimeAttackScreenState();
}

class _TimeAttackScreenState extends ConsumerState<TimeAttackScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  String? _scheduledQuestionInstanceId;
  late final Ticker _timerFrameTicker;
  var _timeoutSubmitScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerFrameTicker = createTicker((_) => _refreshVisibleTimer());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(timeAttackControllerProvider.notifier).startOrRecover();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerFrameTicker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshVisibleTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(timeAttackControllerProvider);
    final activeQuestionCount =
        ref
            .watch(localGameplayQuestionsProvider)
            .asData
            ?.value
            .where((question) => question.isActive)
            .length ??
        0;
    _schedulePreparation(game);
    _syncTimerTicker(game);

    return PopScope(
      canPop: !game.blocksBackNavigation,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && game.blocksBackNavigation) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Aktif oyun bitmeden geri çıkılamaz.'),
              ),
            );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: switch (game.phase) {
            TimeAttackPhase.initial || TimeAttackPhase.starting =>
              const _PreparingView(label: 'Oyun hazırlanıyor…'),
            TimeAttackPhase.preparing => const _PreparingView(
              label: 'Soru hazırlanıyor…',
            ),
            TimeAttackPhase.error => _ErrorView(
              message: game.errorMessage ?? 'Bir sorun oluştu.',
              retryLabel: game.retryAction == TimeAttackRetryAction.start
                  ? 'Yeni Oyun'
                  : 'Tekrar Dene',
              onRetry: () {
                _scheduledQuestionInstanceId = null;
                ref.read(timeAttackControllerProvider.notifier).retry();
              },
              onHome: _goHome,
            ),
            TimeAttackPhase.gameOver => _GameOverView(
              game: game,
              activeQuestionCount: activeQuestionCount,
              onPlayAgain: () {
                _scheduledQuestionInstanceId = null;
                ref
                    .read(timeAttackControllerProvider.notifier)
                    .startOrRecover();
              },
              onHome: _goHome,
            ),
            _ => _QuestionView(game: game),
          },
        ),
      ),
    );
  }

  void _syncTimerTicker(TimeAttackState game) {
    if (game.phase == TimeAttackPhase.active) {
      if (!_timerFrameTicker.isActive) _timerFrameTicker.start();
    } else {
      if (_timerFrameTicker.isActive) _timerFrameTicker.stop();
      _timeoutSubmitScheduled = false;
    }
  }

  void _refreshVisibleTimer() {
    if (!mounted) return;
    final controller = ref.read(timeAttackControllerProvider.notifier);
    controller.refreshElapsed();
    final game = ref.read(timeAttackControllerProvider);
    if (game.phase != TimeAttackPhase.active ||
        game.displayedRemainingMs != 0 ||
        _timeoutSubmitScheduled) {
      return;
    }
    _timeoutSubmitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timeoutSubmitScheduled = false;
      ref.read(timeAttackControllerProvider.notifier).submitTimeoutIfExpired();
    });
  }

  void _schedulePreparation(TimeAttackState game) {
    final question = game.question;
    if (game.phase != TimeAttackPhase.preparing || question == null) return;
    if (_scheduledQuestionInstanceId == question.instanceId) return;
    _scheduledQuestionInstanceId = question.instanceId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final preloader = ref.read(timeAttackImagePreloaderProvider);
      await ref.read(timeAttackControllerProvider.notifier).prepareQuestion((
        current,
      ) {
        return preloader(context, [
          current.top.imagePath,
          current.bottom.imagePath,
        ]);
      });
    });
  }

  void _goHome() {
    context.goNamed(AppRoute.home.name);
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('time-attack-preparing'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 30,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(label),
        ],
      ),
    );
  }
}

class _QuestionView extends ConsumerWidget {
  const _QuestionView({required this.game});

  final TimeAttackState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = game.question;
    if (question == null) {
      return const _PreparingView(label: 'Soru hazırlanıyor…');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 700;
        final spacing = compact ? AppSpacing.small : AppSpacing.medium;
        final contentHeight = constraints.maxHeight.clamp(0.0, 760.0);
        return Center(
          child: ConstrainedBox(
            key: const Key('time-attack-content'),
            constraints: const BoxConstraints(maxWidth: 600),
            child: SizedBox(
              height: contentHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                  vertical: spacing,
                ),
                child: Column(
                  children: [
                    _StatusBar(game: game),
                    SizedBox(height: spacing),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final cardHeight = cardConstraints.maxHeight.clamp(
                            0.0,
                            250.0,
                          );
                          return Align(
                            child: _OptionCard(
                              key: const Key('time-attack-top-card'),
                              option: question.top,
                              imageUrl: question.top.imagePath,
                              height: cardHeight,
                              visualState: _visualState(
                                game,
                                TimeAttackPosition.top,
                              ),
                              motion: _answerMotion(
                                game,
                                TimeAttackPosition.top,
                              ),
                              displayValue: game.reveal?.displayValueAt(
                                TimeAttackPosition.top,
                              ),
                              onTap: game.acceptsAnswer
                                  ? () => ref
                                        .read(
                                          timeAttackControllerProvider.notifier,
                                        )
                                        .selectPosition(TimeAttackPosition.top)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: spacing),
                    Text(
                      question.questionText,
                      key: const Key('time-attack-question-text'),
                      textAlign: TextAlign.center,
                      maxLines: compact ? 3 : 4,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (compact
                                  ? Theme.of(context).textTheme.titleMedium
                                  : Theme.of(context).textTheme.titleLarge)
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    _Feedback(game: game),
                    SizedBox(height: spacing),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final cardHeight = cardConstraints.maxHeight.clamp(
                            0.0,
                            250.0,
                          );
                          return Align(
                            child: _OptionCard(
                              key: const Key('time-attack-bottom-card'),
                              option: question.bottom,
                              imageUrl: question.bottom.imagePath,
                              height: cardHeight,
                              visualState: _visualState(
                                game,
                                TimeAttackPosition.bottom,
                              ),
                              motion: _answerMotion(
                                game,
                                TimeAttackPosition.bottom,
                              ),
                              displayValue: game.reveal?.displayValueAt(
                                TimeAttackPosition.bottom,
                              ),
                              onTap: game.acceptsAnswer
                                  ? () => ref
                                        .read(
                                          timeAttackControllerProvider.notifier,
                                        )
                                        .selectPosition(
                                          TimeAttackPosition.bottom,
                                        )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.game});

  final TimeAttackState game;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('time-attack-status'),
      alignment: WrapAlignment.center,
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.small,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CriticalTimerMotion(
              remainingMs: game.displayedRemainingMs,
              child: _StatusChip(
                key: const Key('time-attack-timer'),
                icon: Icons.timer_outlined,
                label: '${game.displayedRemainingSeconds}',
                accent: game.displayedRemainingMs <= 10000
                    ? AppColors.error
                    : AppColors.primary,
              ),
            ),
            Positioned(
              top: -8,
              right: -12,
              child: IgnorePointer(
                child: TimeDeltaMotion(
                  adjustmentMs: game.feedbackAdjustmentMs,
                  eventKey: game.question?.instanceId,
                ),
              ),
            ),
          ],
        ),
        ScorePop(
          score: game.score,
          child: _StatusChip(
            key: const Key('time-attack-score'),
            icon: Icons.local_fire_department_rounded,
            label: 'Skor: ${game.score}',
            accent: AppColors.secondary,
          ),
        ),
        _StatusChip(
          key: const Key('time-attack-wrong-count'),
          icon: Icons.close_rounded,
          label: 'Yanlış: ${game.wrongCount}',
          accent: AppColors.error,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.accent,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

enum _OptionVisualState { normal, selected, correct, incorrect, disabled }

_OptionVisualState _visualState(
  TimeAttackState game,
  TimeAttackPosition position,
) {
  if (game.phase == TimeAttackPhase.active) return _OptionVisualState.normal;
  if (game.reveal?.correctPosition == position) {
    return _OptionVisualState.correct;
  }
  if (game.selectedPosition == position) {
    return _OptionVisualState.incorrect;
  }
  return _OptionVisualState.disabled;
}

AnswerMotion _answerMotion(TimeAttackState game, TimeAttackPosition position) {
  if (game.selectedPosition != position) return AnswerMotion.none;
  if (game.phase == TimeAttackPhase.feedbackCorrect) {
    return AnswerMotion.correct;
  }
  if (game.phase == TimeAttackPhase.feedbackIncorrect) {
    return AnswerMotion.incorrect;
  }
  return AnswerMotion.none;
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.imageUrl,
    required this.height,
    required this.visualState,
    required this.motion,
    required this.displayValue,
    required this.onTap,
    super.key,
  });

  final TimeAttackOption option;
  final String imageUrl;
  final double height;
  final _OptionVisualState visualState;
  final AnswerMotion motion;
  final String? displayValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, overlay) = switch (visualState) {
      _OptionVisualState.normal => (AppColors.outline, Colors.transparent),
      _OptionVisualState.selected => (
        AppColors.primary,
        AppColors.primary.withValues(alpha: 0.12),
      ),
      _OptionVisualState.correct => (
        AppColors.success,
        AppColors.success.withValues(alpha: 0.15),
      ),
      _OptionVisualState.incorrect => (
        AppColors.error,
        AppColors.error.withValues(alpha: 0.18),
      ),
      _OptionVisualState.disabled => (
        AppColors.outline,
        Colors.black.withValues(alpha: 0.22),
      ),
    };
    return Semantics(
      button: onTap != null,
      label: '${option.position.name} seçenek: ${option.name}',
      child: PressableScale(
        enabled: onTap != null,
        markerKey: Key('time-attack-${option.position.name}-press-motion'),
        child: AnswerMotionEffect(
          motion: motion,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.large),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: border, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      imageUrl,
                      key: Key('time-attack-${option.position.name}-image'),
                      fit: BoxFit.cover,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded) return child;
                            return AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: GameMotionDurations.feedback,
                              child: child,
                            );
                          },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.elevatedSurface,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 42,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xD9000000)],
                        ),
                      ),
                    ),
                    ColoredBox(color: overlay),
                    Positioned(
                      left: AppSpacing.medium,
                      right: AppSpacing.medium,
                      bottom: AppSpacing.medium,
                      child: Column(
                        children: [
                          Text(
                            option.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  shadows: const [Shadow(blurRadius: 6)],
                                ),
                          ),
                          if (displayValue case final value?) ...[
                            const SizedBox(height: 4),
                            Text(
                              value,
                              key: Key(
                                'time-attack-${option.position.name}-value',
                              ),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (visualState == _OptionVisualState.correct)
                      const Positioned(
                        top: 12,
                        right: 12,
                        child: Icon(
                          Icons.check_circle_rounded,
                          key: Key('time-attack-correct-indicator'),
                          color: AppColors.success,
                          size: 30,
                        ),
                      ),
                    if (visualState == _OptionVisualState.incorrect)
                      const Positioned(
                        top: 12,
                        right: 12,
                        child: Icon(
                          Icons.cancel_rounded,
                          key: Key('time-attack-incorrect-indicator'),
                          color: AppColors.error,
                          size: 30,
                        ),
                      ),
                    if (visualState == _OptionVisualState.selected)
                      const Center(
                        child: SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.game});

  final TimeAttackState game;

  @override
  Widget build(BuildContext context) {
    final data = switch (game.phase) {
      TimeAttackPhase.feedbackCorrect => (
        'Doğru!',
        AppColors.success,
        Icons.check_circle_rounded,
      ),
      TimeAttackPhase.feedbackIncorrect => (
        'Yanlış, devam!',
        AppColors.error,
        Icons.cancel_rounded,
      ),
      TimeAttackPhase.feedbackTimeout => (
        'Süre doldu',
        AppColors.error,
        Icons.timer_off_rounded,
      ),
      _ => null,
    };
    if (data == null) return const SizedBox(height: 24);
    return AppearMotion(
      key: ValueKey(game.phase),
      markerKey: const Key('time-attack-feedback-motion'),
      duration: GameMotionDurations.feedback,
      beginScale: 0.96,
      slideY: 2,
      child: Row(
        key: const Key('time-attack-feedback'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.$3, color: data.$2, size: 20),
          const SizedBox(width: AppSpacing.small),
          Text(
            data.$1,
            style: TextStyle(color: data.$2, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _GameOverView extends StatelessWidget {
  const _GameOverView({
    required this.game,
    required this.activeQuestionCount,
    required this.onPlayAgain,
    required this.onHome,
  });

  final TimeAttackState game;
  final int activeQuestionCount;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final reason = switch (game.finishReason) {
      TimeAttackFinishReason.wrongPenaltyExpired =>
        'Yanlış cezasıyla süre bitti',
      TimeAttackFinishReason.questionPoolCompleted => 'Soru havuzu tamamlandı',
      _ => 'Süre doldu',
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AppearMotion(
            markerKey: const Key('time-attack-game-over-entrance-motion'),
            duration: const Duration(milliseconds: 220),
            beginScale: 0.97,
            slideY: 4,
            child: Column(
              children: [
                Text(
                  'Oyun Bitti',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(reason, key: const Key('time-attack-finish-reason')),
                if (game.finishReason ==
                    TimeAttackFinishReason.questionPoolCompleted) ...[
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    '$activeQuestionCount sorunun tamamını yanıtladın',
                    key: const Key('time-attack-pool-completed-count'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    'Kalan süre: ${game.displayedRemainingSeconds} sn',
                    key: const Key('time-attack-game-over-remaining-time'),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                AppearMotion(
                  markerKey: const Key(
                    'time-attack-game-over-score-entrance-motion',
                  ),
                  duration: GameMotionDurations.finalScoreEntrance,
                  beginScale: 0.82,
                  slideY: 2,
                  child: Text(
                    '${game.score}',
                    key: const Key('time-attack-game-over-score'),
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                const Text('Skor'),
                const SizedBox(height: AppSpacing.small),
                Text('Yanlış: ${game.wrongCount}'),
                if (game.personalBestUpdated && game.score > 0) ...[
                  const SizedBox(height: AppSpacing.medium),
                  NewRecordCelebration(child: newRecordBanner(context)),
                ],
                const SizedBox(height: AppSpacing.large),
                FilledButton(
                  key: const Key('time-attack-play-again'),
                  onPressed: onPlayAgain,
                  child: const Text('Tekrar Oyna'),
                ),
                TextButton(onPressed: onHome, child: const Text('Ana Sayfa')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    required this.onHome,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48),
            const SizedBox(height: AppSpacing.medium),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.large),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
            TextButton(onPressed: onHome, child: const Text('Ana Sayfa')),
          ],
        ),
      ),
    );
  }
}
