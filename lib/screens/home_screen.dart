// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/app_settings.dart';
import '../services/app_theme.dart';
import '../services/sensor_service.dart';
import '../services/ntfy_service.dart';
import 'settings_screen.dart';
import 'sensor_screen.dart';

enum MonitorState { idle, monitoring, trigger, alarm }

class LogEntry {
  final DateTime time;
  final String message;
  final bool isAlert;
  LogEntry(this.message, {this.isAlert = false}) : time = DateTime.now();
}

class HomeScreen extends StatefulWidget {
  final SensorAvailability availability;
  const HomeScreen({super.key, required this.availability});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  MonitorState _state = MonitorState.idle;
  SensorService? _service;
  Timer? _triggerTimer;
  int _triggerCountdown = 0;
  double _accelMag = 0;
  double _gyroMag  = 0;
  final List<LogEntry> _log = [];

  void _addLog(String msg, {bool alert = false}) {
    setState(() {
      _log.insert(0, LogEntry(msg, isAlert: alert));
      if (_log.length > 50) _log.removeLast();
    });
  }

  void _startMonitoring() {
    final s = AppSettings();
    _service = SensorService(
      onSensorUpdate: (a, g) => setState(() { _accelMag = a; _gyroMag = g; }),
      onFallDetected: _onFallDetected,
      fallThreshold:      s.accelEnabled ? s.fallThreshold     : 999,
      rotationThreshold:  s.gyroEnabled  ? s.rotationThreshold : 999,
      useGyro: s.gyroEnabled && widget.availability.gyroscope,
      useStep: s.stepEnabled && widget.availability.stepDetector,
    );
    _service!.start();
    WakelockPlus.enable();
    setState(() => _state = MonitorState.monitoring);
    _addLog('Monitoring started 🟢');
    NtfyService.sendStart();
  }

  void _stopMonitoring() {
    _service?.stop();
    _service = null;
    _triggerTimer?.cancel();
    WakelockPlus.disable();
    setState(() { _state = MonitorState.idle; _accelMag = 0; _gyroMag = 0; });
    _addLog('Monitoring stopped ⏹');
    NtfyService.sendStop();
  }

  void _onFallDetected() {
    final s = AppSettings();
    setState(() { _state = MonitorState.trigger; _triggerCountdown = s.responseWindow; });
    _addLog('⚠️ Trigger: accel ${_accelMag.toStringAsFixed(2)} m/s²', alert: true);
    _showTriggerDialog();
    _triggerTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_triggerCountdown <= 1) {
        t.cancel();
        _sendAlarm();
      } else {
        setState(() => _triggerCountdown--);
      }
    });
  }

  void _sendAlarm() {
    setState(() => _state = MonitorState.alarm);
    _addLog('🆘 ALARM poslan!', alert: true);
    NtfyService.sendAlarm(_accelMag, _gyroMag);
    _service?.resetCooldown(AppSettings().cooldownSeconds);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _state = MonitorState.monitoring);
    });
  }

  void _userOk() {
    _triggerTimer?.cancel();
    Navigator.of(context, rootNavigator: true).pop();
    _addLog('✅ Korisnik OK');
    NtfyService.sendOk();
    _service?.resetCooldown(AppSettings().cooldownSeconds);
    setState(() => _state = MonitorState.monitoring);
  }

  void _showTriggerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) {
          // Sync countdown to dialog
          _triggerTimer?.cancel();
          _triggerTimer = Timer.periodic(const Duration(seconds: 1), (t) {
            if (_triggerCountdown <= 1) {
              t.cancel();
              if (mounted) Navigator.of(context, rootNavigator: true).pop();
              _sendAlarm();
            } else {
              setState(() => _triggerCountdown--);
              setD(() {});
            }
          });
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              backgroundColor: const Color(0xFFFFF3CD),
              title: const Text('⚠️ SENSO', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Pad detektovan!\nJesi li dobro?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                Text('Alarm za: $_triggerCountdown s',
                  style: const TextStyle(fontSize: 16, color: Colors.red)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _triggerCountdown / AppSettings().responseWindow,
                  color: Colors.orange,
                  backgroundColor: Colors.orange.shade100,
                ),
              ]),
              actions: [
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5A27),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _userOk,
                    child: const Text('✅  DA, U REDU SAM',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color get _stateColor {
    final t = AppTheme();
    switch (_state) {
      case MonitorState.monitoring: return t.background.withGreen(220);
      case MonitorState.trigger:    return const Color(0xFFFFF3CD);
      case MonitorState.alarm:      return const Color(0xFFFFE0E0);
      case MonitorState.idle:       return t.background;
    }
  }

  @override
  void dispose() {
    _service?.stop();
    _triggerTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    final isMonitoring = _state == MonitorState.monitoring ||
                         _state == MonitorState.trigger ||
                         _state == MonitorState.alarm;

    return Scaffold(
      backgroundColor: _stateColor,
      appBar: AppBar(
        backgroundColor: _stateColor,
        title: Text('📡  SENSO',
          style: TextStyle(fontSize: t.headerSize, fontWeight: FontWeight.bold, color: t.ink)),
        actions: [
          IconButton(
            icon: Icon(Icons.sensors, color: t.inkMedium),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => SensorScreen(availability: widget.availability))),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: t.inkMedium),
            onPressed: () async {
              await Navigator.push(context,
                MaterialPageRoute(builder: (_) => SettingsScreen(availability: widget.availability)));
              setState(() {}); // refresh nakon settings
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // --- Status card ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border),
            ),
            child: Column(children: [
              Text(
                _state == MonitorState.idle       ? 'IDLE'       :
                _state == MonitorState.monitoring  ? 'MONITORING'  :
                _state == MonitorState.trigger     ? 'TRIGGER ⚠️'  : 'ALARM 🆘',
                style: TextStyle(
                  fontSize: t.headerSize,
                  fontWeight: FontWeight.bold,
                  color: _state == MonitorState.alarm   ? t.destructive :
                         _state == MonitorState.trigger  ? Colors.orange  : t.ink,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMonitoring ? t.destructive : t.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isMonitoring ? _stopMonitoring : _startMonitoring,
                  child: Text(
                    isMonitoring ? 'STOP' : 'START',
                    style: TextStyle(fontSize: t.bodySize + 2, color: Colors.white,
                      fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // --- Live senzori ---
          if (isMonitoring) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Akcelerometar:  ${_accelMag.toStringAsFixed(2)} m/s²',
                  style: TextStyle(fontSize: t.bodySize, color: t.ink)),
                const SizedBox(height: 4),
                Text('Gyroscope:      ${_gyroMag.toStringAsFixed(2)} rad/s',
                  style: TextStyle(fontSize: t.bodySize, color: t.ink)),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // --- Log ---
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('─── Zadnji događaji ───',
                  style: TextStyle(fontSize: t.captionSize, color: t.inkLight)),
              ),
              Expanded(
                child: _log.isEmpty
                  ? Center(child: Text('Nema događaja.',
                      style: TextStyle(color: t.inkFaint, fontSize: t.captionSize)))
                  : ListView.builder(
                      itemCount: _log.length,
                      itemBuilder: (_, i) {
                        final e = _log[i];
                        final hm = '${e.time.hour.toString().padLeft(2,'0')}:'
                                   '${e.time.minute.toString().padLeft(2,'0')}:'
                                   '${e.time.second.toString().padLeft(2,'0')}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('$hm  ${e.message}',
                            style: TextStyle(
                              fontSize: t.captionSize,
                              color: e.isAlert ? t.destructive : t.inkMedium,
                              fontWeight: e.isAlert ? FontWeight.bold : FontWeight.normal,
                            )),
                        );
                      },
                    ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
