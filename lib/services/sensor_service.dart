// lib/services/sensor_service.dart
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/app_settings.dart';

enum SensoState { idle, monitoring, trigger, alarm }

class SensorEvent {
  final DateTime timestamp;
  final String   message;
  final bool     isAlarm;
  SensorEvent({required this.timestamp, required this.message, this.isAlarm = false});
}

class SensorService {
  final AppSettings settings;

  SensoState _state = SensoState.idle;
  SensoState get state => _state;

  final _stateController = StreamController<SensoState>.broadcast();
  Stream<SensoState> get stateStream => _stateController.stream;

  final _eventController = StreamController<SensorEvent>.broadcast();
  Stream<SensorEvent> get eventStream => _eventController.stream;

  // Live sensor readings (za SensorScreen)
  double accelMagnitude = 0.0;
  double gyroMagnitude  = 0.0;
  bool   stepActive     = false;

  final _readingController = StreamController<void>.broadcast();
  Stream<void> get readingStream => _readingController.stream;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _stepSub;

  Timer? _cooldownTimer;
  Timer? _responseTimer;
  bool   _inCooldown = false;

  // Callback za response dialog
  Function()? onTrigger;

  SensorService({required this.settings});

  // Provjera dostupnosti senzora
  static Future<Map<String, bool>> checkAvailability() async {
    final result = <String, bool>{
      'accel':      false,
      'gyro':       false,
      'step':       false,
      'stationary': false,
    };

    // Accelerometer
    try {
      final sub = accelerometerEventStream().listen((_) {});
      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      result['accel'] = true;
    } catch (_) {}

    // Gyroscope
    try {
      final sub = gyroscopeEventStream().listen((_) {});
      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      result['gyro'] = true;
    } catch (_) {}

    // Step detector
    try {
      // sensors_plus nema direktan step stream — koristimo userAccelerometer kao proxy
      // Pravi step_detector dostupan kroz platform channel; za sada označi kao available
      // ako accelerometer radi (sve Samsung uređaje imaju step detector)
      result['step'] = result['accel']!;
    } catch (_) {}

    // Stationary detect — samo SA9+
    // sensors_plus nema direktan pristup; detektujemo indirektno
    // Označi kao false — override ručno ako pronađemo
    result['stationary'] = false;

    return result;
  }

  void start() {
    if (_state != SensoState.idle) return;
    _setState(SensoState.monitoring);
    _log('Monitoring started 🟢');

    if (settings.accelEnabled && settings.accelAvailable) {
      _accelSub = userAccelerometerEventStream().listen((e) {
        accelMagnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        _readingController.add(null);
        _checkFall();
      });
    }

    if (settings.gyroEnabled && settings.gyroAvailable) {
      _gyroSub = gyroscopeEventStream().listen((e) {
        gyroMagnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        _readingController.add(null);
      });
    }
  }

  void stop() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _stepSub?.cancel();
    _cooldownTimer?.cancel();
    _responseTimer?.cancel();
    _setState(SensoState.idle);
    _log('Monitoring stopped ⏹');
  }

  void _checkFall() {
    if (_state != SensoState.monitoring) return;
    if (_inCooldown) return;

    final accelTrigger = settings.accelEnabled && settings.accelAvailable &&
        accelMagnitude > settings.fallThreshold;
    final gyroTrigger  = settings.gyroEnabled  && settings.gyroAvailable  &&
        gyroMagnitude  > settings.rotationThreshold;

    if (accelTrigger || gyroTrigger) {
      _trigger();
    }
  }

  void _trigger() {
    _setState(SensoState.trigger);
    _log('⚠️ Trigger — accel: ${accelMagnitude.toStringAsFixed(2)} m/s²');
    onTrigger?.call();

    _responseTimer = Timer(Duration(seconds: settings.responseWindow), () {
      if (_state == SensoState.trigger) {
        triggerAlarm();
      }
    });
  }

  void confirmOk() {
    if (_state != SensoState.trigger) return;
    _responseTimer?.cancel();
    _log('✅ Korisnik potvrdio — OK');
    _setState(SensoState.monitoring);
    _startCooldown();
  }

  void triggerAlarm() {
    _setState(SensoState.alarm);
    _log('🆘 ALARM — pad detektovan!', isAlarm: true);
    _startCooldown();
    // ntfy šalje NtfyService (poziva se iz HomeScreen)
  }

  void _startCooldown() {
    _inCooldown = true;
    _cooldownTimer = Timer(Duration(seconds: settings.cooldownSeconds), () {
      _inCooldown = false;
      if (_state == SensoState.alarm) _setState(SensoState.monitoring);
    });
  }

  void _setState(SensoState s) {
    _state = s;
    _stateController.add(s);
  }

  void _log(String msg, {bool isAlarm = false}) {
    _eventController.add(SensorEvent(
      timestamp: DateTime.now(),
      message: msg,
      isAlarm: isAlarm,
    ));
  }

  void dispose() {
    stop();
    _stateController.close();
    _eventController.close();
    _readingController.close();
  }
}
