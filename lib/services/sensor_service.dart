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

  final _stateController   = StreamController<SensoState>.broadcast();
  final _eventController   = StreamController<SensorEvent>.broadcast();
  final _readingController = StreamController<void>.broadcast();

  Stream<SensoState> get stateStream  => _stateController.stream;
  Stream<SensorEvent> get eventStream => _eventController.stream;
  Stream<void> get readingStream      => _readingController.stream;

  double accelMagnitude = 0.0;
  double gyroMagnitude  = 0.0;
  bool   stepActive     = false;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _stepSub;
  Timer? _cooldownTimer;
  Timer? _responseTimer;
  Timer? _pollingTimer;
  bool   _inCooldown = false;

  // Buffered readings između polling intervala
  double _accelBuf = 0.0;
  double _gyroBuf  = 0.0;

  Function()? onTrigger;

  SensorService({required this.settings});

  static Future<Map<String, bool>> checkAvailability() async {
    final result = <String, bool>{
      'accel':      false,
      'gyro':       false,
      'step':       false,
      'stationary': false,
    };

    try {
      final sub = accelerometerEventStream().listen((_) {});
      await Future.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
      result['accel'] = true;
    } catch (_) {}

    try {
      final sub = gyroscopeEventStream().listen((_) {});
      await Future.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
      result['gyro'] = true;
    } catch (_) {}

    // Step detector — dostupan ako accelerometer radi (svi Samsung uređaji)
    result['step'] = result['accel']!;

    // Stationary detect — sensors_plus nema direktan stream, ostaje false
    result['stationary'] = false;

    return result;
  }

  void start() {
    if (_state != SensoState.idle) return;
    _setState(SensoState.monitoring);
    _log('Monitoring started 🟢');

    final interval = Duration(milliseconds: settings.pollingIntervalMs);

    // Accelerometer — buffer max vrijednost
    if (settings.accelEnabled && settings.accelAvailable) {
      _accelSub = userAccelerometerEventStream().listen((e) {
        final m = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (m > _accelBuf) _accelBuf = m;
      });
    }

    // Gyroscope — buffer max vrijednost
    if (settings.gyroEnabled && settings.gyroAvailable) {
      _gyroSub = gyroscopeEventStream().listen((e) {
        final m = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (m > _gyroBuf) _gyroBuf = m;
      });
    }

    // Step detector
    if (settings.stepEnabled && settings.stepAvailable) {
      _stepSub = accelerometerEventStream().listen((e) {
        // Koristimo akcelerometar za procjenu koraka — magnitude > 1.2 = hoda
        final m = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        stepActive = m > 1.2 && m < 3.0;
      });
    }

    // Polling timer — provjera thresholda na svakih N ms
    _pollingTimer = Timer.periodic(interval, (_) {
      accelMagnitude = _accelBuf;
      gyroMagnitude  = _gyroBuf;
      _accelBuf = 0.0;
      _gyroBuf  = 0.0;
      _readingController.add(null);
      _checkFall();
    });
  }

  void stop() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _stepSub?.cancel();
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    _responseTimer?.cancel();
    accelMagnitude = 0.0;
    gyroMagnitude  = 0.0;
    stepActive     = false;
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

    // Step filter — ako hoda, nije pad (ako je step sensor aktivan i uključen)
    if (settings.stepEnabled && settings.stepAvailable && stepActive) return;

    if (accelTrigger || gyroTrigger) {
      _trigger();
    }
  }

  void _trigger() {
    _setState(SensoState.trigger);
    _log('⚠️ Trigger — ${accelMagnitude.toStringAsFixed(2)} m/s² / ${gyroMagnitude.toStringAsFixed(2)} rad/s');
    onTrigger?.call();

    _responseTimer = Timer(Duration(seconds: settings.responseWindow), () {
      if (_state == SensoState.trigger) triggerAlarm();
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
    _log('Pad detektovan!', isAlarm: true);
    _startCooldown();
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
      message:   msg,
      isAlarm:   isAlarm,
    ));
  }

  void dispose() {
    stop();
    _stateController.close();
    _eventController.close();
    _readingController.close();
  }
}
