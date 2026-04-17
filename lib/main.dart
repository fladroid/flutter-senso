// lib/main.dart
import 'package:flutter/material.dart';
import 'services/app_settings.dart';
import 'services/app_theme.dart';
import 'services/sensor_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings().load();
  final settings = AppSettings();
  AppTheme().init(settings.fontSize, settings.contrast);
  final availability = await SensorAvailability.check();
  runApp(SensoApp(availability: availability));
}

class SensoApp extends StatelessWidget {
  final SensorAvailability availability;
  const SensoApp({super.key, required this.availability});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return MaterialApp(
      title: 'Senso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: t.background,
        colorScheme: ColorScheme.light(
          primary: t.accent,
          onPrimary: t.accentText,
          surface: t.surface,
          onSurface: t.ink,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: t.background,
          foregroundColor: t.ink,
          elevation: 0,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.accent : t.inkFaint,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? t.accent.withOpacity(0.4)
                : t.border,
          ),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: t.ink, fontSize: t.bodySize),
          bodySmall:  TextStyle(color: t.inkMedium, fontSize: t.captionSize),
        ),
      ),
      home: HomeScreen(availability: availability),
    );
  }
}
