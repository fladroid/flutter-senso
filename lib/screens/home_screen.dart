// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/app_theme.dart';
import '../services/sensor_service.dart';
import '../services/ntfy_service.dart';
import '../services/translation_service.dart';
import 'settings_screen.dart';

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
  final _theme = AppTheme();

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
    _stateSub  = _sensor.stateStream.listen((_) => setState(() {}));
    _eventSub  = _sensor.eventStream.listen((e) => setState(() {
      _events.insert(0, e);
      if (_events.length > 50) _events.removeLast();
    }));
    _readingSub = _sensor.readingStream.listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    _stateSub?.cancel(); _eventSub?.cancel(); _readingSub?.cancel();
    _sensor.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_sensor.state == SensoState.idle) {
      _sensor.start(); _ntfy.sendStart();
    } else {
      _sensor.stop(); _ntfy.sendStop();
    }
  }

  void _showTriggerDialog() {
    if (_dialogShown) return;
    _dialogShown = true;
    int remaining = widget.settings.responseWindow;
    Timer? countdown;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) {
          countdown ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (remaining <= 1) {
              t.cancel();
              if (ctx.mounted) Navigator.of(ctx).pop('timeout');
            } else {
              setDS(() => remaining--);
            }
          });
          final th = AppTheme();
          return Dialog(
            backgroundColor: const Color(0xFFFFFBF0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_tr.t('trigger_title'),
                    style: TextStyle(fontSize: th.headerSize,
                        fontWeight: FontWeight.bold, color: th.ink)),
                const SizedBox(height: 16),
                Text(_tr.t('trigger_body'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: th.bodySize + 2, color: th.inkMedium)),
                const SizedBox(height: 20),
                Text(_tr.t('trigger_alarm_in', params: {'s': '$remaining'}),
                    style: TextStyle(fontSize: th.captionSize, color: th.inkLight)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: remaining / widget.settings.responseWindow,
                    minHeight: 6,
                    color: th.accent,
                    backgroundColor: th.border,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: th.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      countdown?.cancel();
                      Navigator.of(ctx).pop('ok');
                    },
                    child: Text(_tr.t('trigger_ok'),
                        style: TextStyle(fontSize: th.bodySize + 1,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    ).then((result) {
      _dialogShown = false;
      if (result == 'ok') {
        _sensor.confirmOk(); _ntfy.sendOk();
      } else {
        if (_sensor.state == SensoState.trigger) {
          _sensor.triggerAlarm(); _ntfy.sendAlarm();
        }
      }
    });
  }

  Color get _bgColor {
    switch (_sensor.state) {
      case SensoState.monitoring: return _theme.accent.withAlpha(18);
      case SensoState.trigger:    return const Color(0xFFFFF8E1);
      case SensoState.alarm:      return const Color(0xFFFFF0F0);
      default:                    return _theme.background;
    }
  }

  String get _stateLabel {
    switch (_sensor.state) {
      case SensoState.idle:       return _tr.t('state_idle');
      case SensoState.monitoring: return _tr.t('state_monitoring');
      case SensoState.trigger:    return _tr.t('state_trigger');
      case SensoState.alarm:      return _tr.t('state_alarm');
    }
  }

  Color get _stateLabelColor {
    switch (_sensor.state) {
      case SensoState.monitoring: return _theme.accent;
      case SensoState.trigger:    return const Color(0xFF8B6000);
      case SensoState.alarm:      return _theme.destructive;
      default:                    return _theme.inkLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _sensor.state != SensoState.idle;
    final s = widget.settings;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(s),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                const SizedBox(height: 16),
                _buildStatusCard(isActive),
                const SizedBox(height: 12),
                _buildReadings(s),
                const SizedBox(height: 12),
                _buildEventLogHeader(),
                const SizedBox(height: 6),
                Expanded(child: _buildEventLog()),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar(AppSettings s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _theme.border))),
      child: Row(children: [
        Text('📡', style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Text('Senso v1.0.0',
            style: TextStyle(fontFamily: 'monospace',
                fontSize: _theme.headerSize * 0.85,
                fontWeight: FontWeight.bold, color: _theme.ink)),
        if (s.testMode) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withAlpha(30),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFF9800).withAlpha(80)),
            ),
            child: Text('TEST',
                style: TextStyle(fontSize: _theme.captionSize,
                    color: const Color(0xFFBF6000),
                    fontWeight: FontWeight.bold)),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(
                builder: (_) => SettingsScreen(settings: widget.settings)));
            setState(() {
              TranslationService().setLanguage(widget.settings.language);
              AppTheme().init(widget.settings.fontSize, widget.settings.contrast);
              _ntfy = NtfyService(settings: widget.settings);
            });
          },
          child: Text('⚙', style: TextStyle(fontSize: 22, color: _theme.inkLight)),
        ),
      ]),
    );
  }

  Widget _buildStatusCard(bool isActive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: _theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _theme.border),
      ),
      child: Column(children: [
        Text(_stateLabel,
            style: TextStyle(fontSize: _theme.headerSize,
                fontWeight: FontWeight.bold, color: _stateLabelColor)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? _theme.destructive : _theme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: _toggle,
            child: Text(
                isActive ? _tr.t('btn_stop') : _tr.t('btn_start'),
                style: TextStyle(fontSize: _theme.bodySize + 2,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _buildReadings(AppSettings s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: _theme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _theme.border),
      ),
      child: Column(children: [
        _readingRow(_tr.t('sensor_accel'),
            '${_sensor.accelMagnitude.toStringAsFixed(2)} m/s²',
            s.accelEnabled && s.accelAvailable),
        _readingRow(_tr.t('sensor_gyro'),
            '${_sensor.gyroMagnitude.toStringAsFixed(2)} rad/s',
            s.gyroEnabled && s.gyroAvailable),
        _readingRow(_tr.t('sensor_step'),
            _sensor.stepActive ? '✅' : '—',
            s.stepEnabled && s.stepAvailable),
      ]),
    );
  }

  Widget _readingRow(String label, String value, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: TextStyle(fontSize: _theme.captionSize,
                  color: active ? _theme.inkMedium : _theme.inkFaint)),
        ),
        Text(active ? value : _tr.t('sensor_disabled'),
            style: TextStyle(
                fontSize: _theme.captionSize,
                color: active ? _theme.ink : _theme.inkFaint,
                fontStyle: active ? FontStyle.normal : FontStyle.italic)),
      ]),
    );
  }

  Widget _buildEventLogHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(_tr.t('last_events'),
          style: TextStyle(fontSize: _theme.captionSize, color: _theme.inkFaint)),
    );
  }

  Widget _buildEventLog() {
    return ListView.builder(
      itemCount: _events.length,
      itemBuilder: (_, i) {
        final e = _events[i];
        final time = '${e.timestamp.hour.toString().padLeft(2, '0')}:'
            '${e.timestamp.minute.toString().padLeft(2, '0')}:'
            '${e.timestamp.second.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Text(time, style: TextStyle(
                fontSize: _theme.captionSize, color: _theme.inkFaint,
                fontFamily: 'monospace')),
            const SizedBox(width: 8),
            Expanded(child: Text(e.message,
                style: TextStyle(
                    fontSize: _theme.captionSize,
                    color: e.isAlarm ? _theme.destructive : _theme.inkMedium))),
          ]),
        );
      },
    );
  }
}
