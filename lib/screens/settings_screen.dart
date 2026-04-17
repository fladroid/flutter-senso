// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../services/app_theme.dart';
import '../services/sensor_service.dart';

class SettingsScreen extends StatefulWidget {
  final SensorAvailability availability;
  const SettingsScreen({super.key, required this.availability});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = AppSettings();
  late TextEditingController _primaryCtrl, _fallbackCtrl, _tokenCtrl;

  @override
  void initState() {
    super.initState();
    _primaryCtrl  = TextEditingController(text: s.ntfyPrimaryUrl);
    _fallbackCtrl = TextEditingController(text: s.ntfyFallbackUrl);
    _tokenCtrl    = TextEditingController(text: s.ntfyToken);
  }

  @override
  void dispose() {
    _primaryCtrl.dispose();
    _fallbackCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _save() {
    s.ntfyPrimaryUrl  = _primaryCtrl.text.trim();
    s.ntfyFallbackUrl = _fallbackCtrl.text.trim();
    s.ntfyToken       = _tokenCtrl.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved.')));
  }

  Widget _sectionHeader(String title) {
    final t = AppTheme();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
      child: Text(title.toUpperCase(),
        style: TextStyle(fontSize: t.captionSize, color: t.inkLight,
          fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _sensorTile(String label, bool available, bool value, void Function(bool) onChanged) {
    final t = AppTheme();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontSize: t.bodySize,
        color: available ? t.ink : t.inkFaint)),
      subtitle: available ? null : Text('Not available on this device',
        style: TextStyle(fontSize: t.captionSize, color: t.inkFaint)),
      value: available && value,
      onChanged: available ? (v) { setState(() => onChanged(v)); } : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    final av = widget.availability;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontSize: t.headerSize, color: t.ink)),
        actions: [
          TextButton(onPressed: _save,
            child: Text('Save', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── SENZORI ──────────────────────────────────────────
          _sectionHeader('Senzori'),
          _sensorTile('Accelerometer', av.accelerometer, s.accelEnabled,
            (v) => s.accelEnabled = v),
          _sensorTile('Gyroscope', av.gyroscope, s.gyroEnabled,
            (v) => s.gyroEnabled = v),
          _sensorTile('Step Detector', av.stepDetector, s.stepEnabled,
            (v) => s.stepEnabled = v),
          _sensorTile('Stationary Detect', av.stationary, s.stationaryEnabled,
            (v) => s.stationaryEnabled = v),

          Divider(color: t.border, height: 32),

          // ── DETEKCIJA ─────────────────────────────────────────
          _sectionHeader('Detekcija'),

          // Response window
          Text('Response window', style: TextStyle(fontSize: t.bodySize, color: t.ink)),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 3,  label: Text('3s')),
              ButtonSegment(value: 5,  label: Text('5s')),
              ButtonSegment(value: 10, label: Text('10s')),
            ],
            selected: {s.responseWindow},
            onSelectionChanged: (v) => setState(() => s.responseWindow = v.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.selected) ? t.accent : t.surface),
              foregroundColor: WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.selected) ? Colors.white : t.ink),
            ),
          ),
          const SizedBox(height: 16),

          // Fall threshold
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Fall threshold', style: TextStyle(fontSize: t.bodySize, color: t.ink)),
            Text('${s.fallThreshold.toStringAsFixed(1)} m/s²',
              style: TextStyle(fontSize: t.bodySize, color: t.accent, fontWeight: FontWeight.bold)),
          ]),
          Slider(
            value: s.fallThreshold, min: 1.0, max: 5.0, divisions: 8,
            activeColor: t.accent,
            onChanged: (v) => setState(() => s.fallThreshold = double.parse(v.toStringAsFixed(1))),
          ),

          // Rotation threshold
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Rotation threshold', style: TextStyle(fontSize: t.bodySize, color: t.ink)),
            Text('${s.rotationThreshold.toStringAsFixed(1)} rad/s',
              style: TextStyle(fontSize: t.bodySize, color: t.accent, fontWeight: FontWeight.bold)),
          ]),
          Slider(
            value: s.rotationThreshold, min: 1.0, max: 8.0, divisions: 14,
            activeColor: t.accent,
            onChanged: (v) => setState(() => s.rotationThreshold = double.parse(v.toStringAsFixed(1))),
          ),

          Divider(color: t.border, height: 32),

          // ── NOTIFIKACIJE ──────────────────────────────────────
          _sectionHeader('Notifikacije'),
          _field('Primary ntfy URL', _primaryCtrl),
          const SizedBox(height: 10),
          _field('Fallback ntfy URL', _fallbackCtrl),
          const SizedBox(height: 10),
          _field('ntfy Token', _tokenCtrl, obscure: true),

          Divider(color: t.border, height: 32),

          // ── DISPLAY ───────────────────────────────────────────
          _sectionHeader('Display'),

          Text('Font size', style: TextStyle(fontSize: t.bodySize, color: t.ink)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'small',  label: Text('Small')),
              ButtonSegment(value: 'medium', label: Text('Medium')),
              ButtonSegment(value: 'large',  label: Text('Large')),
            ],
            selected: {s.fontSize},
            onSelectionChanged: (v) => setState(() { s.fontSize = v.first; AppTheme().setSize(v.first); }),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.selected) ? t.accent : t.surface),
              foregroundColor: WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.selected) ? Colors.white : t.ink),
            ),
          ),
          const SizedBox(height: 16),

          Text('Contrast', style: TextStyle(fontSize: t.bodySize, color: t.ink)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'normal', label: Text('Normal')),
              ButtonSegment(value: 'high',   label: Text('High')),
            ],
            selected: {s.contrast},
            onSelectionChanged: (v) => setState(() { s.contrast = v.first; AppTheme().setContrast(v.first); }),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.selected) ? t.accent : t.surface),
              foregroundColor: WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.selected) ? Colors.white : t.ink),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool obscure = false}) {
    final t = AppTheme();
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(fontSize: t.bodySize, color: t.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: t.captionSize, color: t.inkLight),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.accent, width: 2)),
        filled: true,
        fillColor: t.surface,
      ),
    );
  }
}
