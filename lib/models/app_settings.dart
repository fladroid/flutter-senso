// lib/models/app_settings.dart
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  // Senzori — dostupnost (hardware check)
  bool accelAvailable      = false;
  bool gyroAvailable       = false;
  bool stepAvailable       = false;
  bool stationaryAvailable = false;

  // Senzori — enabled/disabled (user setting)
  bool accelEnabled      = true;
  bool gyroEnabled       = true;
  bool stepEnabled       = true;
  bool stationaryEnabled = true;

  // Detekcija
  double fallThreshold     = 20.0;
  double rotationThreshold = 5.0;
  int    responseWindow    = 5;
  int    cooldownSeconds   = 5;
  int    pollingIntervalMs = 200; // ms: 100, 200, 500, 1000

  // ntfy
  String ntfyPrimaryUrl  = 'https://ntfy-balsam.dynu.net/senso_guard';
  String ntfyFallbackUrl = 'https://ntfy.sh/senso_guard';
  String ntfyToken       = '';

  // Test mode — notifikacije se ne šalju
  bool testMode = false;

  // Display
  String fontSize = 'medium';
  String contrast = 'normal';
  String language = 'hr';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    accelEnabled      = p.getBool('sensor_accel_enabled')      ?? true;
    gyroEnabled       = p.getBool('sensor_gyro_enabled')       ?? true;
    stepEnabled       = p.getBool('sensor_step_enabled')       ?? true;
    stationaryEnabled = p.getBool('sensor_stationary_enabled') ?? true;
    fallThreshold     = p.getDouble('fall_threshold')          ?? 2.5;
    rotationThreshold = p.getDouble('rotation_threshold')      ?? 3.0;
    responseWindow    = p.getInt('response_window')            ?? 5;
    cooldownSeconds   = p.getInt('cooldown_seconds')           ?? 5;
    ntfyPrimaryUrl    = p.getString('ntfy_primary_url')  ?? 'https://ntfy-balsam.dynu.net/senso_guard';
    ntfyFallbackUrl   = p.getString('ntfy_fallback_url') ?? 'https://ntfy.sh/senso_guard';
    ntfyToken         = p.getString('ntfy_token')        ?? '';
    testMode          = p.getBool('test_mode')           ?? false;
    fontSize          = p.getString('font_size')         ?? 'medium';
    contrast          = p.getString('contrast')          ?? 'normal';
    language          = p.getString('language')          ?? 'hr';
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('sensor_accel_enabled',      accelEnabled);
    await p.setBool('sensor_gyro_enabled',       gyroEnabled);
    await p.setBool('sensor_step_enabled',       stepEnabled);
    await p.setBool('sensor_stationary_enabled', stationaryEnabled);
    await p.setDouble('fall_threshold',          fallThreshold);
    await p.setDouble('rotation_threshold',      rotationThreshold);
    await p.setInt('response_window',            responseWindow);
    await p.setInt('cooldown_seconds',           cooldownSeconds);
    await p.setString('ntfy_primary_url',        ntfyPrimaryUrl);
    await p.setString('ntfy_fallback_url',       ntfyFallbackUrl);
    await p.setString('ntfy_token',              ntfyToken);
    await p.setBool('test_mode',                 testMode);
    await p.setString('font_size',               fontSize);
    await p.setString('contrast',                contrast);
    await p.setString('language',                language);
  }
}
