// lib/services/app_settings.dart
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  late SharedPreferences _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- ntfy ---
  String get ntfyPrimaryUrl   => _prefs.getString('ntfy_primary_url')  ?? 'https://ntfy-balsam.dynu.net/senso_guard';
  String get ntfyFallbackUrl  => _prefs.getString('ntfy_fallback_url') ?? 'https://ntfy.sh/senso_guard';
  String get ntfyToken        => _prefs.getString('ntfy_token')        ?? '';
  set ntfyPrimaryUrl(String v)  => _prefs.setString('ntfy_primary_url', v);
  set ntfyFallbackUrl(String v) => _prefs.setString('ntfy_fallback_url', v);
  set ntfyToken(String v)       => _prefs.setString('ntfy_token', v);

  // --- detekcija ---
  double get fallThreshold      => _prefs.getDouble('fall_threshold')      ?? 2.5;
  double get rotationThreshold  => _prefs.getDouble('rotation_threshold')  ?? 3.0;
  int    get responseWindow     => _prefs.getInt('response_window')        ?? 5;
  int    get cooldownSeconds    => _prefs.getInt('cooldown_seconds')       ?? 30;
  set fallThreshold(double v)     => _prefs.setDouble('fall_threshold', v);
  set rotationThreshold(double v) => _prefs.setDouble('rotation_threshold', v);
  set responseWindow(int v)       => _prefs.setInt('response_window', v);
  set cooldownSeconds(int v)      => _prefs.setInt('cooldown_seconds', v);

  // --- senzori (on/off) ---
  bool get accelEnabled       => _prefs.getBool('sensor_accel_enabled')       ?? true;
  bool get gyroEnabled        => _prefs.getBool('sensor_gyro_enabled')        ?? true;
  bool get stepEnabled        => _prefs.getBool('sensor_step_enabled')        ?? true;
  bool get stationaryEnabled  => _prefs.getBool('sensor_stationary_enabled')  ?? true;
  set accelEnabled(bool v)      => _prefs.setBool('sensor_accel_enabled', v);
  set gyroEnabled(bool v)       => _prefs.setBool('sensor_gyro_enabled', v);
  set stepEnabled(bool v)       => _prefs.setBool('sensor_step_enabled', v);
  set stationaryEnabled(bool v) => _prefs.setBool('sensor_stationary_enabled', v);

  // --- display ---
  String get fontSize  => _prefs.getString('font_size') ?? 'medium';
  String get contrast  => _prefs.getString('contrast')  ?? 'normal';
  set fontSize(String v) => _prefs.setString('font_size', v);
  set contrast(String v) => _prefs.setString('contrast', v);
}
