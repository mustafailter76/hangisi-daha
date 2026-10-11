import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hangisi_daha/core/constants/app_radius.dart';
import 'package:hangisi_daha/core/constants/app_spacing.dart';
import 'package:hangisi_daha/core/theme/app_colors.dart';

abstract final class GameMotionDurations {
  static const tap = Duration(milliseconds: 90);
  static const answerCorrect = Duration(milliseconds: 250);
  static const answerWrong = Duration(milliseconds: 210);
  static const answerTerminalWrong = Duration(milliseconds: 240);
  static const scorePop = Duration(milliseconds: 230);
  static const feedback = Duration(milliseconds: 200);
  static const timeDelta = Duration(milliseconds: 450);
  static const gameOverEntrance = Duration(milliseconds: 260);
  static const finalScoreEntrance = Duration(milliseconds: 340);
}

enum AnswerMotion { none, correct, incorrect, terminalIncorrect }

class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.982,
    this.markerKey = const Key('pressable-scale-motion'),
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;
  final Key markerKey;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  var _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = _reducedMotion(context);
    return Listener(
      key: widget.markerKey,
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: !reducedMotion && _pressed ? widget.pressedScale : 1,
        duration: reducedMotion ? Duration.zero : GameMotionDurations.tap,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class AnswerMotionEffect extends StatelessWidget {
  const AnswerMotionEffect({
    required this.motion,
    required this.child,
    super.key,
  });

  final AnswerMotion motion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (motion == AnswerMotion.none || _reducedMotion(context)) return child;
    final duration = switch (motion) {
      AnswerMotion.correct => GameMotionDurations.answerCorrect,
      AnswerMotion.terminalIncorrect => GameMotionDurations.answerTerminalWrong,
      _ => GameMotionDurations.answerWrong,
    };
    return TweenAnimationBuilder<double>(
      key: ValueKey(motion),
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, value, animatedChild) {
        final scale = motion == AnswerMotion.correct
            ? 1 + (math.sin(math.pi * value) * 0.028)
            : motion == AnswerMotion.terminalIncorrect
            ? 1 - (math.sin(math.pi * value) * 0.008)
            : 1.0;
        final wrongStrength = motion == AnswerMotion.terminalIncorrect
            ? 6.0
            : 4.0;
        final offset =
            {
              AnswerMotion.incorrect,
              AnswerMotion.terminalIncorrect,
            }.contains(motion)
            ? math.sin(value * math.pi * 5) * (1 - value) * wrongStrength
            : 0.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: Transform.scale(scale: scale, child: animatedChild),
        );
      },
      child: KeyedSubtree(
        key: Key(
          motion == AnswerMotion.correct
              ? 'correct-answer-motion'
              : 'wrong-answer-motion',
        ),
        child: child,
      ),
    );
  }
}

class ScorePop extends StatelessWidget {
  const ScorePop({required this.score, required this.child, super.key});

  final int score;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = _reducedMotion(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(score),
      tween: Tween(begin: score > 0 && !reducedMotion ? 0 : 1, end: 1),
      duration: reducedMotion ? Duration.zero : GameMotionDurations.scorePop,
      curve: Curves.easeOut,
      builder: (context, value, animatedChild) => Transform.scale(
        scale: 1 + (math.sin(math.pi * value) * 0.18),
        child: animatedChild,
      ),
      child: KeyedSubtree(key: const Key('score-pop-motion'), child: child),
    );
  }
}

class TimeDeltaMotion extends StatelessWidget {
  const TimeDeltaMotion({
    required this.adjustmentMs,
    required this.eventKey,
    super.key,
  });

  final int? adjustmentMs;
  final Object? eventKey;

  @override
  Widget build(BuildContext context) {
    final (label, color, marker) = switch (adjustmentMs) {
      -1000 => ('-1 sn', AppColors.error, 'time-delta-minus-one'),
      -2000 => ('-2 sn', AppColors.error, 'time-delta-minus-two'),
      -3000 => ('-3 sn', AppColors.error, 'time-delta-minus-three'),
      -4000 => ('-4 sn', AppColors.error, 'time-delta-minus-four'),
      _ => (null, null, null),
    };
    if (label == null || color == null || marker == null) {
      return const SizedBox.shrink(key: Key('time-delta-none'));
    }
    final reducedMotion = _reducedMotion(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey((eventKey, adjustmentMs)),
      tween: Tween(begin: reducedMotion ? 1 : 0, end: 1),
      duration: reducedMotion ? Duration.zero : GameMotionDurations.timeDelta,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final fade = ((value - 0.35) / 0.65).clamp(0.0, 1.0);
        return Opacity(
          opacity: reducedMotion ? 1 : 1 - fade,
          child: Transform.translate(
            offset: Offset(0, 7 * value),
            child: Transform.scale(
              scale: reducedMotion
                  ? 1
                  : 0.86 + (math.sin(math.pi * value) * 0.18),
              child: child,
            ),
          ),
        );
      },
      child: Semantics(
        liveRegion: true,
        label: '${label.replaceAll(' sn', ' saniye')} süre cezası',
        child: Text(
          label,
          key: Key(marker),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class JokerAttentionMotion extends StatelessWidget {
  const JokerAttentionMotion({
    required this.active,
    required this.child,
    super.key,
  });

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = _reducedMotion(context);
    if (!active || reducedMotion) {
      return KeyedSubtree(
        key: Key(
          reducedMotion
              ? 'joker-attention-reduced-motion'
              : 'joker-attention-idle',
        ),
        child: child,
      );
    }
    return TweenAnimationBuilder<double>(
      key: const Key('joker-attention-motion'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      builder: (context, value, animatedChild) {
        final pulse = math.sin(value * math.pi * 4).abs();
        return Transform.scale(
          scale: 1 + (pulse * 0.012),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.large),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12 * pulse),
                  blurRadius: 14 * pulse,
                  spreadRadius: 1.5 * pulse,
                ),
              ],
            ),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}

class CriticalTimerMotion extends StatefulWidget {
  const CriticalTimerMotion({
    required this.remainingMs,
    required this.child,
    this.thresholdMs = 10000,
    super.key,
  });

  final int remainingMs;
  final Widget child;
  final int thresholdMs;

  @override
  State<CriticalTimerMotion> createState() => _CriticalTimerMotionState();
}

class _CriticalTimerMotionState extends State<CriticalTimerMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _critical => widget.remainingMs <= widget.thresholdMs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(CriticalTimerMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remainingMs != widget.remainingMs) _syncAnimation();
  }

  void _syncAnimation() {
    if (_critical && !_reducedMotion(context)) {
      _controller.duration = widget.remainingMs <= 5000
          ? const Duration(milliseconds: 500)
          : const Duration(milliseconds: 700);
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_critical) return widget.child;
    final strength = widget.remainingMs <= 5000 ? 0.05 : 0.025;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: 1 + (_controller.value * strength),
        child: child,
      ),
      child: KeyedSubtree(
        key: const Key('critical-timer-motion'),
        child: widget.child,
      ),
    );
  }
}

class HighlightPulse extends StatelessWidget {
  const HighlightPulse({
    required this.highlighted,
    required this.child,
    this.markerKey = const Key('highlight-pulse-motion'),
    super.key,
  });

  final bool highlighted;
  final Widget child;
  final Key markerKey;

  @override
  Widget build(BuildContext context) {
    if (!highlighted) return child;
    final reducedMotion = _reducedMotion(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(highlighted),
      tween: Tween(begin: reducedMotion ? 1 : 0, end: 1),
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, value, animatedChild) => Transform.scale(
        scale: 1 + (math.sin(math.pi * value) * 0.08),
        child: animatedChild,
      ),
      child: KeyedSubtree(key: markerKey, child: child),
    );
  }
}

class AppearMotion extends StatelessWidget {
  const AppearMotion({
    required this.child,
    required this.markerKey,
    this.duration = GameMotionDurations.feedback,
    this.slideY = 8,
    this.beginScale = 1,
    super.key,
  });

  final Widget child;
  final Key markerKey;
  final Duration duration;
  final double slideY;
  final double beginScale;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = _reducedMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reducedMotion ? 1 : 0, end: 1),
      duration: reducedMotion ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, slideY * (1 - value)),
          child: Transform.scale(
            scale: beginScale + ((1 - beginScale) * value),
            child: animatedChild,
          ),
        ),
      ),
      child: KeyedSubtree(key: markerKey, child: child),
    );
  }
}

class ShieldImpactMotion extends StatelessWidget {
  const ShieldImpactMotion({
    required this.active,
    required this.child,
    super.key,
  });

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active || _reducedMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(active),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, animatedChild) {
        final impact = math.sin(math.pi * value);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.scale(scale: 1 - (impact * 0.006), child: animatedChild),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const Key('shield-absorbed-motion'),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: impact * 0.07),
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

class NewRecordCelebration extends StatelessWidget {
  const NewRecordCelebration({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = _reducedMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reducedMotion ? 1 : 0, end: 1),
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        final entrance = math.min(1.0, value * 3);
        final sparkOpacity =
            (reducedMotion
                    ? 0.0
                    : (math.sin(math.pi * value) * 0.9).clamp(0, 1))
                .toDouble();
        return SizedBox(
          height: 62,
          child: Stack(
            key: const Key('new-record-celebration'),
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              for (final spark in const [
                (-0.42, -0.25, 13.0),
                (-0.24, 0.42, 10.0),
                (0.28, -0.38, 11.0),
                (0.43, 0.25, 13.0),
              ])
                FractionalTranslation(
                  translation: Offset(spark.$1, spark.$2 - (value * 0.12)),
                  child: Opacity(
                    opacity: sparkOpacity,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: spark.$3,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              Transform.scale(
                scale: 0.82 + (0.18 * entrance),
                child: animatedChild,
              ),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

Widget newRecordBanner(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.medium,
      vertical: AppSpacing.small,
    ),
    decoration: BoxDecoration(
      color: AppColors.secondary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.medium),
      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
    ),
    child: Text(
      'Yeni Rekor!',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.secondary,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

bool _reducedMotion(BuildContext context) {
  return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
