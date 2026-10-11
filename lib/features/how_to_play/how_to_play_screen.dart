import 'package:flutter/material.dart';
import 'package:hangisi_daha/core/constants/app_radius.dart';
import 'package:hangisi_daha/core/constants/app_spacing.dart';
import 'package:hangisi_daha/core/theme/app_colors.dart';
import 'package:hangisi_daha/core/widgets/app_scaffold.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const _sections = [
    _RuleSection(
      icon: Icons.all_inclusive_rounded,
      title: 'KLASİK',
      lines: [
        'Her soru için 15 saniyen var.',
        'Doğru cevap: Skor +1 ve devam.',
        'Yanlış cevap veya süre bitimi: Oyun biter.',
        'Uzatma: Bu sorunun toplam süresini 45 saniyeye çıkarır.',
        'İpucu: Toplam süreyi 30 saniyeye çıkarır ve ipucu gösterir.',
        'Kalkan: Bir yanlış cevabı veya süre bitimini engeller.',
        'Her joker oyun başına 1 kez kullanılır; aynı soruda birlikte kullanılamaz.',
      ],
    ),
    _RuleSection(
      icon: Icons.timer_outlined,
      title: '60 SANİYE',
      lines: [
        '60 saniye aktif süreyle başlarsın.',
        'Doğru cevap: Skor +1, süre değişmez.',
        'Art arda yanlışlarda süre cezası -1, -2, -3 ve en fazla -4 saniyeye çıkar.',
        'Doğru cevap verdiğinde yanlış serisi cezası tekrar -1 saniyeden başlar.',
        'Yanlış cevap oyunu doğrudan bitirmez; süre bitince oyun biter.',
        'Joker yoktur.',
        'Zorluk Kolay → Orta → Zor döngüsünde ilerler.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBarTitle: 'Nasıl Oynanır',
      child: ListView(
        key: const Key('how-to-play-rules'),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
        children: [
          Text(
            'Modunu seç, doğru seçeneği bul ve en iyi skorunu yap.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.extraLarge),
          for (var index = 0; index < _sections.length; index++) ...[
            _RuleSectionCard(section: _sections[index]),
            if (index != _sections.length - 1)
              const SizedBox(height: AppSpacing.regular),
          ],
        ],
      ),
    );
  }
}

class _RuleSectionCard extends StatelessWidget {
  const _RuleSectionCard({required this.section});

  final _RuleSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(section.icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpacing.extraSmall),
                for (var index = 0; index < section.lines.length; index++) ...[
                  Text(
                    section.lines[index],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (index != section.lines.length - 1)
                    const SizedBox(height: AppSpacing.extraSmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleSection {
  const _RuleSection({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
}
