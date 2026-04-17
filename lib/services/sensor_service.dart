// lib/services/sensor_service.dart
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Provjerava dostupnost senzora na uređaju pri startu.
class SensorAvailability {
  bool accelerometer = false;
  bool gyroscope     = false;
  bool stepDetector  = false;
  bool stationary    = false;

  static Future<SensorAvailability> check() async {
    final result = SensorAvailability();

    // Accelerometer
    try {
      final sub = accelerometerEventStream().listen((_) {});
      await Future.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
      result.accelerometer = true;
    } catch (_) {}

    // Gyroscope
    try {
      final sub = gyroscopeEventStream().listen((_) {});
      await Future.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
      result.gyroscope = true;
    } catch (_) {}

    // Step detector — sensors_plus nema direktan stream, koristimo userAccelerometer kao proxy
    // Step detector se čita kroz userAccelerometerEventStream — dostupan na SA55
    try {
      final sub = userAccelerometerEventStream().listen((_) {});
      await Future.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
      result.stepDetector = true;
    } catch (_) {}

    // stationary_detect — nema direktan sensors_plus stream; pokušaj fallback
    // Na SA55 i S7+ nije dostupan kroz sensors_plus — greyed out by default
    result.stationary = false;

    return result;
  }
}

/// Glavni service za monitoring senzora i detekciju pada.
class SensorService {
  final void Function(double accel, double gyro) onSensorUpdate;
  final void Function() onFallDetected;

  final double fallThreshold;
  final double rotationThreshold;
  final bool useGyro;
  final bool useStep;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;

  double _lastAccelMag = 0;
  double _lastGyroMag  = 0;
  bool   _inCooldown   = false;
  bool   _stepActive   = false;

  SensorService({
    required this.onSensorUpdate,
    required this.onFallDetected,
    required this.fallThreshold,
    required this.rotationThreshold,
    required this.useGyro,
    required this.useStep,
  });

  void start() {
    _accelSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((e) {
      _lastAccelMag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      onSensorUpdate(_lastAccelMag, _lastGyroMag);
      _checkFall();
    });

    if (useGyro) {
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 50),
      ).listen((e) {
        _lastGyroMag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      });
    }
  }

  void stop() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub  = null;
  }

  void setStepActive(bool active) => _stepActive = active;

  void _checkFall() {
    if (_inCooldown) return;
    // Filter: ako su koraci aktivni, manja šansa pada
    if (useStep && _stepActive) return;

    final accelTrigger = _lastAccelMag > fallThreshold;
    final gyroTrigger  = !useGyro || _lastGyroMag > rotationThreshold;

    if (accelTrigger && gyroTrigger) {
      _inCooldown = true;
      onFallDetected();
    }
  }

  void resetCooldown(int cooldownSeconds) {
    Future.delayed(Duration(seconds: cooldownSeconds), () {
      _inCooldown = false;
    });
  }

  double get accelMag => _lastAccelMag;
  double get gyroMag  => _lastGyroMag;
}
