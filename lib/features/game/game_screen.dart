import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hangisi_daha/app/router/app_routes.dart';
import 'package:hangisi_daha/core/constants/app_radius.dart';
import 'package:hangisi_daha/core/constants/app_spacing.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';
import 'package:hangisi_daha/core/theme/app_colors.dart';
import 'package:hangisi_daha/core/widgets/game_motion.dart';
import 'package:hangisi_daha/features/game/models/game_models.dart';
import 'package:hangisi_daha/features/game/models/game_state.dart';
import 'package:hangisi_daha/features/game/providers/game_controller.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Timer? _jokerAttentionTimer;
  var _jokerAttentionCheckStarted = false;
  var _highlightJokers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(gameControllerProvider.notifier).startGame();
      }
    });
  }

  @override
  void dispose() {
    _jokerAttentionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    if (game.phase == GamePhase.questionActive) {
      _scheduleJokerAttentionCheck();
    }

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
            GamePhase.initial || GamePhase.starting => const _LoadingView(),
            GamePhase.error => _ErrorView(
              message: game.errorMessage ?? 'Bir sorun oluştu.',
              retryLabel: game.retryAction == GameRetryAction.start
                  ? 'Yeni Oyun'
                  : 'Tekrar Dene',
              onRetry: () {
                ref.read(gameControllerProvider.notifier).retry();
              },
              onHome: _goHome,
            ),
            GamePhase.gameOver => _GameOverView(
              score: game.score,
              bestScore: game.bestScore,
              isNewRecord: game.isNewRecord,
              finishReason: game.finishReason,
              onPlayAgain: () {
                ref.read(gameControllerProvider.notifier).startGame();
              },
              onHome: _goHome,
            ),
            _ => _QuestionView(game: game, highlightJokers: _highlightJokers),
          },
        ),
      ),
    );
  }

  void _scheduleJokerAttentionCheck() {
    if (_jokerAttentionCheckStarted) return;
    _jokerAttentionCheckStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final preferences = await ref.read(
          localPreferencesRepositoryProvider.future,
        );
        if (!mounted || preferences.hasSeenClassicJokerHint) return;
        await preferences.setClassicJokerHintSeen();
        if (!mounted) return;
        setState(() => _highlightJokers = true);
        _jokerAttentionTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _highlightJokers = false);
        });
      } on Object {
        // Discoverability help is optional and must never block gameplay.
      }
    });
  }

  void _goHome() {
    context.goNamed(AppRoute.home.name);
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: AppSpacing.medium),
          Text('Oyun hazırlanıyor…'),
        ],
      ),
    );
  }
}

class _QuestionView extends ConsumerWidget {
  const _QuestionView({required this.game, required this.highlightJokers});

  final GameState game;
  final bool highlightJokers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = game.question;
    if (question == null) return const _LoadingView();

    final topOption = question.topOption;
    final bottomOption = question.bottomOption;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 720;
        final spacing = compact ? AppSpacing.small : AppSpacing.medium;
        final contentHeight = constraints.maxHeight.clamp(0.0, 760.0);

        return Center(
          child: ConstrainedBox(
            key: const Key('game-content'),
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox(
              height: contentHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                  vertical: spacing,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 190),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween(
                            begin: const Offset(0, 0.012),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          ),
                      child: child,
                    ),
                  ),
                  child: ShieldImpactMotion(
                    key: ValueKey(question.id),
                    active: game.shieldAbsorbed,
                    child: Column(
                      children: [
                        _ScoreBadge(score: game.score),
                        SizedBox(height: spacing),
                        JokerAttentionMotion(
                          active: highlightJokers,
                          child: _JokerBar(
                            game: game,
                            compact: compact,
                            onActivate: (type) {
                              ref
                                  .read(gameControllerProvider.notifier)
                                  .activateJoker(type);
                            },
                          ),
                        ),
                        SizedBox(height: spacing),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, cardConstraints) {
                              final cardHeight = cardConstraints.maxHeight
                                  .clamp(0.0, 260.0);
                              return Align(
                                child: _OptionCard(
                                  key: Key('option-${topOption.name}-card'),
                                  option: topOption,
                                  name: question.nameFor(topOption),
                                  imageUrl: question.imagePathFor(topOption),
                                  displayValue: game.answeredQuestion
                                      ?.displayValueFor(topOption),
                                  height: cardHeight,
                                  visualState: _visualStateFor(game, topOption),
                                  motion: _answerMotionFor(game, topOption),
                                  showProgress:
                                      game.phase == GamePhase.submitting &&
                                      game.selectedOption == topOption,
                                  onTap: game.acceptsAnswerInput
                                      ? () => ref
                                            .read(
                                              gameControllerProvider.notifier,
                                            )
                                            .selectOption(topOption)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: spacing),
                        Text(
                          question.questionText,
                          key: const Key('question-text'),
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
                        if (game.hintText case final hint?) ...[
                          const SizedBox(height: AppSpacing.small),
                          AppearMotion(
                            markerKey: const Key('hint-panel-motion'),
                            duration: const Duration(milliseconds: 220),
                            child: _HintPanel(hint: hint, compact: compact),
                          ),
                        ],
                        if (game.jokerErrorMessage case final message?) ...[
                          const SizedBox(height: AppSpacing.small),
                          _JokerErrorNotice(
                            message: message,
                            canRetry: game.jokerRequestType != null,
                            onRetry: game.jokerRequestType == null
                                ? null
                                : () {
                                    ref
                                        .read(gameControllerProvider.notifier)
                                        .activateJoker(game.jokerRequestType!);
                                  },
                          ),
                        ],
                        SizedBox(height: compact ? 4 : AppSpacing.small),
                        _GameStatus(game: game),
                        SizedBox(height: spacing),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, cardConstraints) {
                              final cardHeight = cardConstraints.maxHeight
                                  .clamp(0.0, 260.0);
                              return Align(
                                child: _OptionCard(
                                  key: Key('option-${bottomOption.name}-card'),
                                  option: bottomOption,
                                  name: question.nameFor(bottomOption),
                                  imageUrl: question.imagePathFor(bottomOption),
                                  displayValue: game.answeredQuestion
                                      ?.displayValueFor(bottomOption),
                                  height: cardHeight,
                                  visualState: _visualStateFor(
                                    game,
                                    bottomOption,
                                  ),
                                  motion: _answerMotionFor(game, bottomOption),
                                  showProgress:
                                      game.phase == GamePhase.submitting &&
                                      game.selectedOption == bottomOption,
                                  onTap: game.acceptsAnswerInput
                                      ? () => ref
                                            .read(
                                              gameControllerProvider.notifier,
                                            )
                                            .selectOption(bottomOption)
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
            ),
          ),
        );
      },
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('game-score'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 19,
            color: AppColors.secondary,
          ),
          const SizedBox(width: AppSpacing.small),
          ScorePop(
            score: score,
            child: Text(
              'Skor: $score',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JokerBar extends StatelessWidget {
  const _JokerBar({
    required this.game,
    required this.compact,
    required this.onActivate,
  });

  final GameState game;
  final bool compact;
  final ValueChanged<ClassicJokerType> onActivate;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('classic-joker-controls'),
      children: [
        for (final type in ClassicJokerType.values) ...[
          if (type != ClassicJokerType.extension)
            const SizedBox(width: AppSpacing.small),
          Expanded(
            child: _JokerControl(
              type: type,
              compact: compact,
              game: game,
              onTap: game.canActivateJoker(type)
                  ? () => onActivate(type)
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _JokerControl extends StatelessWidget {
  const _JokerControl({
    required this.type,
    required this.compact,
    required this.game,
    required this.onTap,
  });

  final ClassicJokerType type;
  final bool compact;
  final GameState game;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPending =
        game.isJokerActivationPending && game.jokerRequestType == type;
    final isActive = game.jokers.currentQuestionJoker == type;
    final isUsed = game.jokers.isUsed(type);
    final isRetry =
        !isPending &&
        game.jokerRequestId != null &&
        game.jokerRequestType == type;
    final enabled = onTap != null;
    final isLocked = !enabled && !isPending && !isActive && !isRetry && !isUsed;
    final (label, helper, icon) = switch (type) {
      ClassicJokerType.extension => (
        'Uzatma',
        '45 sn',
        Icons.more_time_rounded,
      ),
      ClassicJokerType.hint => (
        'İpucu',
        '30 sn + ipucu',
        Icons.lightbulb_outline_rounded,
      ),
      ClassicJokerType.shield => (
        'Kalkan',
        '1 hatayı kurtar',
        Icons.shield_outlined,
      ),
    };
    final status = isPending
        ? 'Bekle'
        : isActive
        ? 'Aktif'
        : isRetry
        ? 'Tekrar'
        : isLocked
        ? 'Kilitli'
        : isUsed
        ? 'Kullanıldı'
        : 'Hazır';
    final accent = isActive
        ? AppColors.success
        : isPending || isRetry
        ? AppColors.secondary
        : AppColors.primary;
    final background = isActive || isPending || isRetry
        ? accent.withValues(alpha: 0.12)
        : enabled
        ? AppColors.surface.withValues(alpha: 0.94)
        : AppColors.elevatedSurface;
    final stateIcon = isPending
        ? null
        : isUsed && !isActive
        ? Icons.check_rounded
        : isLocked
        ? Icons.lock_outline_rounded
        : isActive
        ? Icons.check_circle_outline_rounded
        : icon;

    return Semantics(
      excludeSemantics: true,
      button: enabled,
      enabled: enabled,
      label: '$label jokeri, $status. $helper. Oyun başına bir kez.',
      onTap: enabled ? onTap : null,
      child: PressableScale(
        enabled: enabled,
        pressedScale: 0.97,
        markerKey: Key('joker-${type.name}-press-motion'),
        child: AnimatedOpacity(
          opacity: enabled || isActive || isPending || isRetry ? 1 : 0.5,
          duration: const Duration(milliseconds: 160),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('joker-${type.name}-button'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: HighlightPulse(
                highlighted: type == ClassicJokerType.shield && isActive,
                markerKey: const Key('shield-activation-motion'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: compact ? 46 : 50,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: isActive || isPending || isRetry
                          ? accent.withValues(alpha: 0.72)
                          : enabled
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.outline,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.18),
                              blurRadius: 10,
                            ),
                          ]
                        : enabled
                        ? const [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isPending)
                        SizedBox.square(
                          dimension: compact ? 17 : 18,
                          child: CircularProgressIndicator(
                            key: Key('joker-${type.name}-pending'),
                            strokeWidth: 2.2,
                            color: accent,
                          ),
                        )
                      else
                        Icon(
                          stateIcon,
                          size: compact ? 19 : 21,
                          color: enabled || isActive
                              ? accent
                              : scheme.onSurfaceVariant,
                        ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: enabled || isActive
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintPanel extends StatelessWidget {
  const _HintPanel({required this.hint, required this.compact});

  final String hint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('joker-hint-panel'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            size: 19,
            color: AppColors.secondary,
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              hint,
              key: const Key('joker-hint-text'),
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JokerErrorNotice extends StatelessWidget {
  const _JokerErrorNotice({
    required this.message,
    required this.canRetry,
    required this.onRetry,
  });

  final String message;
  final bool canRetry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('joker-error-notice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (canRetry)
            TextButton(
              key: const Key('joker-retry-button'),
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
        ],
      ),
    );
  }
}

enum _OptionVisualState { normal, selected, correct, incorrect, disabled }

_OptionVisualState _visualStateFor(GameState game, GameOption option) {
  if (game.phase == GamePhase.questionActive) {
    return _OptionVisualState.normal;
  }
  if (game.phase == GamePhase.submitting) {
    return game.selectedOption == option
        ? _OptionVisualState.selected
        : _OptionVisualState.disabled;
  }

  final correctOption = game.answeredQuestion?.correctOption;
  if (correctOption == option) return _OptionVisualState.correct;
  if (game.selectedOption == option) return _OptionVisualState.incorrect;
  return _OptionVisualState.disabled;
}

AnswerMotion _answerMotionFor(GameState game, GameOption option) {
  if (game.selectedOption != option) return AnswerMotion.none;
  if (game.phase == GamePhase.showingCorrectResult) {
    return AnswerMotion.correct;
  }
  if (game.phase == GamePhase.showingIncorrectResult) {
    return game.nextQuestion == null
        ? AnswerMotion.terminalIncorrect
        : AnswerMotion.incorrect;
  }
  return AnswerMotion.none;
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.name,
    required this.imageUrl,
    required this.height,
    required this.visualState,
    required this.motion,
    required this.showProgress,
    this.displayValue,
    this.onTap,
    super.key,
  });

  final GameOption option;
  final String name;
  final String imageUrl;
  final double height;
  final _OptionVisualState visualState;
  final AnswerMotion motion;
  final bool showProgress;
  final String? displayValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const success = AppColors.success;
    final (border, stateOverlay, shadowColor) = switch (visualState) {
      _OptionVisualState.normal => (
        AppColors.outline,
        Colors.transparent,
        AppColors.shadow,
      ),
      _OptionVisualState.selected => (
        scheme.primary,
        scheme.primary.withValues(alpha: 0.12),
        scheme.primary.withValues(alpha: 0.2),
      ),
      _OptionVisualState.correct => (
        success,
        success.withValues(alpha: 0.13),
        success.withValues(alpha: 0.24),
      ),
      _OptionVisualState.incorrect => (
        scheme.error,
        scheme.error.withValues(alpha: 0.17),
        scheme.error.withValues(alpha: 0.24),
      ),
      _OptionVisualState.disabled => (
        AppColors.outline,
        Colors.black.withValues(alpha: 0.2),
        AppColors.shadow.withValues(alpha: 0.5),
      ),
    };
    final stateLabel = switch (visualState) {
      _OptionVisualState.correct => ', doğru seçenek',
      _OptionVisualState.incorrect => ', seçilen yanlış seçenek',
      _OptionVisualState.selected => ', seçildi',
      _ => '',
    };

    return Semantics(
      button: onTap != null,
      label: '${option.name.toUpperCase()} seçeneği: $name$stateLabel',
      child: PressableScale(
        enabled: onTap != null,
        markerKey: Key('option-${option.name}-press-motion'),
        child: AnswerMotionEffect(
          motion: motion,
          child: AnimatedScale(
            scale: visualState == _OptionVisualState.selected ? 0.985 : 1,
            duration: const Duration(milliseconds: 140),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: height,
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface,
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(
                  color: border,
                  width: visualState == _OptionVisualState.normal ? 1 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _QuestionImage(imageUrl: imageUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x22000000),
                          Color(0xD9000000),
                        ],
                        stops: [0.35, 0.62, 1],
                      ),
                    ),
                  ),
                  if (stateOverlay != Colors.transparent)
                    ColoredBox(color: stateOverlay),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Text(
                        option.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (visualState == _OptionVisualState.correct)
                    const Positioned(
                      right: 12,
                      top: 12,
                      child: _ResultBadge(
                        key: Key('correct-option-indicator'),
                        icon: Icons.check_rounded,
                        label: null,
                        color: success,
                      ),
                    )
                  else if (visualState == _OptionVisualState.incorrect)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _ResultBadge(
                        key: const Key('incorrect-option-indicator'),
                        icon: Icons.close_rounded,
                        label: 'Seçimin',
                        color: scheme.error,
                      ),
                    )
                  else if (showProgress)
                    Positioned(
                      right: 14,
                      top: 14,
                      child: Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.58),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Positioned(
                    left: AppSpacing.medium,
                    right: AppSpacing.medium,
                    bottom: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            key: Key('option-${option.name}-name'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                        if (displayValue != null) ...[
                          const SizedBox(width: AppSpacing.small),
                          Container(
                            key: Key('option-${option.name}-display-value'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.66),
                              borderRadius: BorderRadius.circular(
                                AppRadius.small,
                              ),
                              border: Border.all(color: Colors.white54),
                            ),
                            child: Text(
                              displayValue!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(onTap: onTap),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.elevatedSurface,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 40,
          color: AppColors.textSecondary,
        ),
      ),
    );

    if (imageUrl.isEmpty) return fallback;

    return Image.asset(
      imageUrl,
      key: const Key('option-full-bleed-image'),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: GameMotionDurations.feedback,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _GameStatus extends StatelessWidget {
  const _GameStatus({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = game.shieldAbsorbed
        ? (
            key: const Key('shield-absorbed-feedback'),
            icon: Icons.shield_rounded,
            text: 'Kalkan seni korudu',
            color: AppColors.primary,
          )
        : switch (game.phase) {
            GamePhase.showingCorrectResult => (
              key: const Key('correct-feedback'),
              icon: Icons.check_rounded,
              text: 'Doğru seçim',
              color: AppColors.success,
            ),
            GamePhase.showingIncorrectResult => (
              key: const Key('incorrect-feedback'),
              icon: Icons.close_rounded,
              text: 'Yanlış seçim',
              color: scheme.error,
            ),
            GamePhase.timeout => (
              key: const Key('timeout-feedback'),
              icon: Icons.timer_off_rounded,
              text: 'Süre doldu',
              color: scheme.error,
            ),
            _ => null,
          };

    final timerColor = game.remainingSeconds <= 5
        ? AppColors.secondary
        : AppColors.primary;
    return SizedBox(
      height: 52,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: result == null
              ? CriticalTimerMotion(
                  remainingMs: game.remainingSeconds * 1000,
                  thresholdMs: 5000,
                  child: HighlightPulse(
                    highlighted: game.questionAllowanceSeconds > 15,
                    markerKey: const Key('extension-timer-pulse'),
                    child: TweenAnimationBuilder<Color?>(
                      key: const Key('game-timer'),
                      tween: ColorTween(end: timerColor),
                      duration: const Duration(milliseconds: 220),
                      builder: (context, color, child) => SizedBox.square(
                        dimension: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              key: const Key('game-timer-ring'),
                              value:
                                  (game.remainingSeconds /
                                          game.questionAllowanceSeconds)
                                      .clamp(0, 1),
                              strokeWidth: 4.5,
                              strokeCap: StrokeCap.round,
                              color: color,
                              backgroundColor: AppColors.elevatedSurface,
                            ),
                            Text(
                              '${game.remainingSeconds}',
                              key: const Key('game-timer-value'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  key: result.key,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                    vertical: AppSpacing.small,
                  ),
                  decoration: BoxDecoration(
                    color: result.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: result.color.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(result.icon, color: result.color),
                      const SizedBox(width: AppSpacing.small),
                      Text(
                        result.text,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: result.color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _GameOverView extends StatelessWidget {
  const _GameOverView({
    required this.score,
    required this.bestScore,
    required this.isNewRecord,
    required this.finishReason,
    required this.onPlayAgain,
    required this.onHome,
  });

  final int score;
  final int bestScore;
  final bool isNewRecord;
  final ClassicFinishReason? finishReason;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AppearMotion(
            markerKey: const Key('game-over-entrance-motion'),
            duration: const Duration(milliseconds: 220),
            beginScale: 0.97,
            slideY: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Oyun Bitti',
                  key: const Key('game-over-title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (finishReason ==
                    ClassicFinishReason.questionPoolCompleted) ...[
                  const SizedBox(height: AppSpacing.small),
                  const Text(
                    'Tebrikler! Tüm soru havuzunu tamamladın.',
                    key: Key('classic-question-pool-completed-message'),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (isNewRecord && score > 0) ...[
                  const SizedBox(height: AppSpacing.medium),
                  NewRecordCelebration(child: newRecordBanner(context)),
                ],
                const SizedBox(height: AppSpacing.large),
                AppearMotion(
                  markerKey: const Key('game-over-score-entrance-motion'),
                  duration: GameMotionDurations.finalScoreEntrance,
                  beginScale: 0.82,
                  slideY: 2,
                  child: Text(
                    '$score',
                    key: const Key('game-over-score'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 72,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'DOĞRU',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                    vertical: AppSpacing.regular,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Text(
                    'Rekorun: $bestScore',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.extraLarge),
                FilledButton(
                  key: const Key('play-again-button'),
                  onPressed: onPlayAgain,
                  child: const Text('Tekrar Oyna'),
                ),
                const SizedBox(height: AppSpacing.medium),
                OutlinedButton(
                  key: const Key('game-home-button'),
                  onPressed: onHome,
                  child: const Text('Ana Sayfa'),
                ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton(onPressed: onRetry, child: Text(retryLabel)),
              const SizedBox(height: AppSpacing.medium),
              OutlinedButton(onPressed: onHome, child: const Text('Ana Sayfa')),
            ],
          ),
        ),
      ),
    );
  }
}
