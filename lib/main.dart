import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/config/app_config.dart';
import 'features/auth/presentation/session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = AppConfig.fromEnvironment();
    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          sessionRepositoryProvider.overrideWith(
            (ref) => ref.watch(wiredSessionRepositoryProvider),
          ),
        ],
        child: const MoodifyApp(),
      ),
    );
  } on FormatException catch (error) {
    runApp(ConfigurationApp(message: error.message));
  }
}
