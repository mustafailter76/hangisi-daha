import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/features/how_to_play/how_to_play_screen.dart';

void main() {
  testWidgets('shows separate and complete Classic and 60-second rules', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HowToPlayScreen()));

    expect(find.text('KLASİK'), findsOneWidget);
    expect(find.text('Her soru için 15 saniyen var.'), findsOneWidget);
    expect(find.text('Doğru cevap: Skor +1 ve devam.'), findsOneWidget);
    expect(
      find.text('Yanlış cevap veya süre bitimi: Oyun biter.'),
      findsOneWidget,
    );
    expect(
      find.text('Uzatma: Bu sorunun toplam süresini 45 saniyeye çıkarır.'),
      findsOneWidget,
    );
    expect(
      find.text('İpucu: Toplam süreyi 30 saniyeye çıkarır ve ipucu gösterir.'),
      findsOneWidget,
    );
    expect(
      find.text('Kalkan: Bir yanlış cevabı veya süre bitimini engeller.'),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('how-to-play-rules')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('60 SANİYE'), findsOneWidget);
    expect(find.text('60 saniye aktif süreyle başlarsın.'), findsOneWidget);
    expect(find.text('Doğru cevap: Skor +1, süre değişmez.'), findsOneWidget);
    expect(
      find.text(
        'Art arda yanlışlarda süre cezası -1, -2, -3 ve en fazla -4 saniyeye çıkar.',
      ),
      findsOneWidget,
    );
    expect(find.text('Joker yoktur.'), findsOneWidget);
    expect(find.textContaining('Kolay → Orta → Zor'), findsOneWidget);
  });
}
