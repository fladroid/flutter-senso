// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/app_theme.dart';
import '../services/sensor_service.dart';
import '../services/ntfy_service.dart';
import 'settings_screen.dart';
import '../services/translation_service.dart';

class HomeScreen extends StatefulWidget {
  final AppSettings settings;
  const HomeScreen({super.key, required this.settings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SensorService _sensor;
  late NtfyService   _ntfy;
  final _tr = TranslationService();

  final List<SensorEvent> _events = [];
  StreamSubscription? _stateSub;
  StreamSubscription? _eventSub;
  StreamSubscription? _readingSub;

  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _sensor = SensorService(settings: widget.settings);
    _ntfy   = NtfyService(settings: widget.settings);

    _sensor.onTrigger = _showTriggerDialog;

    _stateSub   = _sensor.stateStream.listen((_) => setState(() {}));
    _eventSub   = _sensor.eventStream.listen((e) {
      setState(() {
        _events.insert(0, e);
        if (_events.length > 50) _events.removeLast();
      });
    });
    _readingSub = _sensor.readingStream.listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _eventSub?.cancel();
    _readingSub?.cancel();
    _sensor.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_sensor.state == SensoState.idle) {
      _sensor.start();
      _ntfy.sendStart();
    } else {
      _sensor.stop();
      _ntfy.sendStop();
    }
  }

  void _showTriggerDialog() {
    if (_dialogShown) return;
    _dialogShown = true;

    int remaining = widget.settings.responseWindow;
    Timer? countdownTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (remaining <= 1) {
              t.cancel();
              if (ctx.mounted) Navigator.of(ctx).pop();
            } else {
              setDialogState(() => remaining--);
            }
          });

          final t = AppTheme();
          return AlertDialog(
            backgroundColor: const Color(0xFFFFF3CD),
            title: Text('⚠️ Senso',
                style: TextStyle(fontSize: t.headerSize, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${_tr.t("trigger_body")}\n\n'
                    'Akcel: ${_sensor.triggerAccel.toStringAsFixed(2)} m/s²\n'
                    'Gyro:  ${_sensor.triggerGyro.toStringAsFixed(2)} rad/s',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: t.bodySize + 2)),
                const SizedBox(height: 16),
                Text('Alarm za: ${remaining}s',
                    style: TextStyle(fontSize: t.captionSize, color: t.inkMedium)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: remaining / widget.settings.responseWindow,
                  color: t.accent,
                  backgroundColor: t.border,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(ctx).pop();
                    _sensor.confirmOk();
                    _ntfy.sendOk();
                    _dialogShown = false;
                  },
                  child: Text('DA, U REDU SAM',
                      style: TextStyle(fontSize: t.bodySize + 1,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      _dialogShown = false;
      if (_sensor.state == SensoState.trigger) {
        _sensor.triggerAlarm();
        _ntfy.sendAlarm();
      }
    });
  }

  String get _stateLabel {
    switch (_sensor.state) {
      case SensoState.idle:       return 'IDLE';
      case SensoState.monitoring: return 'MONITORING';
      case SensoState.trigger:    return 'TRIGGER ⚠️';
      case SensoState.alarm:      return 'ALARM 🆘';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    final isMonitoring = _sensor.state != SensoState.idle;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        title: Text('📡  Senso v1.0.3',
            style: TextStyle(fontSize: t.headerSize,
                fontWeight: FontWeight.bold, color: t.ink)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: t.inkMedium),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => SettingsScreen(settings: widget.settings)));
              setState(() {});
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // Status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
              ),
              child: Column(
                children: [
                  Text(_stateLabel,
                      style: TextStyle(fontSize: t.headerSize,
                          fontWeight: FontWeight.bold, color: t.ink)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMonitoring ? t.destructive : t.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _toggle,
                      child: Text(isMonitoring ? 'STOP' : 'START',
                          style: TextStyle(fontSize: t.bodySize + 2,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Live readings
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _reading('Akcelerometar',
                      '${_sensor.accelMagnitude.toStringAsFixed(2)} m/s²',
                      widget.settings.accelEnabled && widget.settings.accelAvailable),
                  _reading('Gyroscope',
                      '${_sensor.gyroMagnitude.toStringAsFixed(2)} rad/s',
                      widget.settings.gyroEnabled && widget.settings.gyroAvailable),
                  _reading('Step detector',
                      _sensor.stepActive ? '✅ aktivan' : '⬜ miruje',
                      widget.settings.stepEnabled && widget.settings.stepAvailable),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Event log header
            Align(
              alignment: Alignment.centerLeft,
              child: Text('─── Zadnji događaji ───',
                  style: TextStyle(fontSize: t.captionSize, color: t.inkFaint)),
            ),
            const SizedBox(height: 8),

            // Event log
            Expanded(
              child: ListView.builder(
                itemCount: _events.length,
                itemBuilder: (_, i) {
                  final e = _events[i];
                  final time =
                      '${e.timestamp.hour.toString().padLeft(2, '0')}:'
                      '${e.timestamp.minute.toString().padLeft(2, '0')}:'
                      '${e.timestamp.second.toString().padLeft(2, '0')}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(time,
                            style: TextStyle(fontSize: t.captionSize,
                                color: t.inkFaint)),
                        const SizedBox(width: 8),
                        if (e.isAlarm)
                          Text('🆘 ',
                              style: TextStyle(fontSize: t.captionSize)),
                        Expanded(
                          child: Text(e.message,
                              style: TextStyle(
                                  fontSize: t.captionSize,
                                  color: e.isAlarm ? t.destructive : t.inkMedium)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reading(String label, String value, bool active) {
    final t = AppTheme();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(fontSize: t.captionSize,
                    color: active ? t.inkMedium : t.inkFaint)),
          ),
          Text(active ? value : 'disabled',
              style: TextStyle(
                  fontSize: t.captionSize,
                  color: active ? t.ink : t.inkFaint,
                  fontStyle: active ? FontStyle.normal : FontStyle.italic)),
        ],
      ),
    );
  }
}
