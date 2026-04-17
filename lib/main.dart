// lib/main.dart
import 'package:flutter/material.dart';
import 'models/app_settings.dart';
import 'services/app_theme.dart';
import 'services/sensor_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = AppSettings();
  await settings.load();

  // Provjera dostupnosti senzora
  final availability = await SensorService.checkAvailability();
  settings.accelAvailable      = availability['accel']      ?? false;
  settings.gyroAvailable        = availability['gyro']       ?? false;
  settings.stepAvailable        = availability['step']       ?? false;
  settings.stationaryAvailable  = availability['stationary'] ?? false;

  // Init tema
  AppTheme().init(settings.fontSize, settings.contrast);

  runApp(SensoApp(settings: settings));
}

class SensoApp extends StatelessWidget {
  final AppSettings settings;
  const SensoApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return MaterialApp(
      title: 'Senso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: t.background,
        colorScheme: ColorScheme.light(
          primary:   t.accent,
          secondary: t.accent,
          surface:   t.surface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: t.background,
          foregroundColor: t.ink,
          elevation: 0,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? t.accent : t.inkFaint),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? t.accent.withAlpha(80)
                  : t.border),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: t.ink,       fontSize: t.bodySize),
          bodySmall:  TextStyle(color: t.inkMedium, fontSize: t.captionSize),
        ),
      ),
      home: HomeScreen(settings: settings),
    );
  }
}
