// lib/services/sensor_service.dart
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/app_settings.dart';
import 'translation_service.dart';

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

  // Live vrijednosti
  double accelMagnitude = 0.0;
  double gyroMagnitude  = 0.0;
  bool   stepActive     = false;

  // Vrijednosti pri triggeru — za dialog
  double triggerAccel = 0.0;
  double triggerGyro  = 0.0;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  Timer? _cooldownTimer;
  Timer? _responseTimer;
  Timer? _pollingTimer;
  bool   _inCooldown = false;

  // Buffer max između polling intervala
  double _accelBuf = 0.0;
  double _gyroBuf  = 0.0;

  // Step detector — varijancom: pamtimo zadnjih N vrijednosti
  final List<double> _accelHistory = [];
  static const int _historySize = 10;

  final _tr = TranslationService();
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

    result['step']       = result['accel']!;
    result['stationary'] = false;

    return result;
  }

  void start() {
    if (_state != SensoState.idle) return;
    _setState(SensoState.monitoring);
    _log(_tr.t('log_monitoring_start'));

    final interval = Duration(milliseconds: settings.pollingIntervalMs);

    // Accelerometer — buffer max + history za step detection
    if (settings.accelEnabled && settings.accelAvailable) {
      _accelSub = userAccelerometerEventStream().listen((e) {
        final m = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (m > _accelBuf) _accelBuf = m;
        // History za step detection
        _accelHistory.add(m);
        if (_accelHistory.length > _historySize) _accelHistory.removeAt(0);
      });
    }

    // Gyroscope
    if (settings.gyroEnabled && settings.gyroAvailable) {
      _gyroSub = gyroscopeEventStream().listen((e) {
        final m = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (m > _gyroBuf) _gyroBuf = m;
      });
    }

    // Polling timer
    _pollingTimer = Timer.periodic(interval, (_) {
      accelMagnitude = _accelBuf;
      gyroMagnitude  = _gyroBuf;
      _accelBuf = 0.0;
      _gyroBuf  = 0.0;

      // Step detection — varijancom magnitude
      // Hod = ritmične oscilacije = visoka varijanca u kratkom periodu (0.3-2.5 m/s²)
      if (settings.stepEnabled && settings.stepAvailable && _accelHistory.length >= 5) {
        final avg = _accelHistory.reduce((a, b) => a + b) / _accelHistory.length;
        final variance = _accelHistory.map((v) => (v - avg) * (v - avg))
            .reduce((a, b) => a + b) / _accelHistory.length;
        // Hod: varijanca 0.1-2.0, prosječna magnitude 0.3-2.5
        final newStepActive = variance > 0.1 && variance < 2.0 && avg > 0.3 && avg < 2.5;
      if (newStepActive != stepActive) {
        stepActive = newStepActive;
        _log(stepActive ? _tr.t('log_step_active') : _tr.t('log_step_idle'));
      } else {
        stepActive = newStepActive;
      }
      } else {
        stepActive = false;
      }

      _readingController.add(null);
      _checkFall();
    });
  }

  void stop() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    _responseTimer?.cancel();
    accelMagnitude = 0.0;
    gyroMagnitude  = 0.0;
    stepActive     = false;
    _accelHistory.clear();
    _setState(SensoState.idle);
    _log(_tr.t('log_monitoring_stop'));
  }

  void _checkFall() {
    if (_state != SensoState.monitoring) return;
    if (_inCooldown) return;

    final accelTrigger = settings.accelEnabled && settings.accelAvailable &&
        accelMagnitude > settings.fallThreshold;
    final gyroTrigger  = settings.gyroEnabled  && settings.gyroAvailable  &&
        gyroMagnitude  > settings.rotationThreshold;

    // Step filter
    if (settings.stepEnabled && settings.stepAvailable && stepActive) return;

    if (accelTrigger || gyroTrigger) {
      _trigger();
    }
  }

  void _trigger() {
    // Sačuvaj vrijednosti pri triggeru za dialog
    triggerAccel = accelMagnitude;
    triggerGyro  = gyroMagnitude;

    _setState(SensoState.trigger);
    _log(_tr.t('log_trigger', params: {'val': '${triggerAccel.toStringAsFixed(2)} / ${triggerGyro.toStringAsFixed(2)}'}));
    onTrigger?.call();

    _responseTimer = Timer(Duration(seconds: settings.responseWindow), () {
      if (_state == SensoState.trigger) triggerAlarm();
    });
  }

  void confirmOk() {
    if (_state != SensoState.trigger) return;
    _responseTimer?.cancel();
    _log(_tr.t('log_user_ok'));
    _setState(SensoState.monitoring);
    _startCooldown();
  }

  void triggerAlarm() {
    _setState(SensoState.alarm);
    _log(_tr.t('log_alarm'), isAlarm: true);
    _startCooldown();
  }

  void _startCooldown() {
    _inCooldown = true;
    _cooldownTimer = Timer(Duration(seconds: settings.cooldownSeconds), () {
      _inCooldown = false;
      if (_state == SensoState.alarm) _setState(SensoState.monitoring);
      // _inCooldown je false bez obzira na state
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
