import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/features/local_content/local_content_loader.dart';

final localContentLoaderProvider = Provider<LocalContentLoader>((ref) {
  return LocalContentLoader(rootBundle);
});

final localGameplayQuestionsProvider =
    FutureProvider<List<LocalGameplayQuestion>>((ref) {
      return ref.watch(localContentLoaderProvider).load();
    });
