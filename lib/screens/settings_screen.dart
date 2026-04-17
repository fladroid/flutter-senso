// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _primaryUrlCtrl;
  late TextEditingController _fallbackUrlCtrl;
  late TextEditingController _tokenCtrl;

  @override
  void initState() {
    super.initState();
    _primaryUrlCtrl  = TextEditingController(text: widget.settings.ntfyPrimaryUrl);
    _fallbackUrlCtrl = TextEditingController(text: widget.settings.ntfyFallbackUrl);
    _tokenCtrl       = TextEditingController(text: widget.settings.ntfyToken);
  }

  @override
  void dispose() {
    _primaryUrlCtrl.dispose();
    _fallbackUrlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.settings.ntfyPrimaryUrl  = _primaryUrlCtrl.text.trim();
    widget.settings.ntfyFallbackUrl = _fallbackUrlCtrl.text.trim();
    widget.settings.ntfyToken       = _tokenCtrl.text.trim();
    await widget.settings.save();
    AppTheme().init(widget.settings.fontSize, widget.settings.contrast);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    final s = widget.settings;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: TextStyle(fontSize: t.headerSize, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save',
                style: TextStyle(color: t.accent, fontSize: t.bodySize,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── SENZORI ──────────────────────────────────────────
          _sectionHeader('Senzori', t),
          _sensorSwitch(
            label: 'Accelerometer',
            available: s.accelAvailable,
            value: s.accelEnabled,
            onChanged: (v) => setState(() => s.accelEnabled = v),
            t: t,
          ),
          _sensorSwitch(
            label: 'Gyroscope',
            available: s.gyroAvailable,
            value: s.gyroEnabled,
            onChanged: (v) => setState(() => s.gyroEnabled = v),
            t: t,
          ),
          _sensorSwitch(
            label: 'Step detector',
            available: s.stepAvailable,
            value: s.stepEnabled,
            onChanged: (v) => setState(() => s.stepEnabled = v),
            t: t,
          ),
          _sensorSwitch(
            label: 'Stationary detect',
            available: s.stationaryAvailable,
            value: s.stationaryEnabled,
            onChanged: (v) => setState(() => s.stationaryEnabled = v),
            t: t,
          ),

          const SizedBox(height: 16),

          // ── DETEKCIJA ─────────────────────────────────────────
          _sectionHeader('Detekcija', t),

          // Response window
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Response window',
                      style: TextStyle(fontSize: t.bodySize, color: t.ink)),
                ),
                DropdownButton<int>(
                  value: s.responseWindow,
                  items: [3, 5, 10].map((v) => DropdownMenuItem(
                    value: v,
                    child: Text('${v}s',
                        style: TextStyle(fontSize: t.bodySize, color: t.ink)),
                  )).toList(),
                  onChanged: (v) => setState(() => s.responseWindow = v!),
                ),
              ],
            ),
          ),

          // Fall threshold
          _sliderRow(
            label: 'Fall threshold',
            value: s.fallThreshold,
            unit: 'm/s²',
            min: 1.0, max: 5.0,
            onChanged: (v) => setState(() => s.fallThreshold = double.parse(v.toStringAsFixed(1))),
            t: t,
          ),

          // Rotation threshold
          _sliderRow(
            label: 'Rotation threshold',
            value: s.rotationThreshold,
            unit: 'rad/s',
            min: 1.0, max: 8.0,
            onChanged: (v) => setState(() => s.rotationThreshold = double.parse(v.toStringAsFixed(1))),
            t: t,
          ),

          const SizedBox(height: 16),

          // ── NTFY ─────────────────────────────────────────────
          _sectionHeader('Notifikacije', t),
          _textField('Primary URL', _primaryUrlCtrl, t),
          _textField('Fallback URL', _fallbackUrlCtrl, t),
          _textField('Token', _tokenCtrl, t, obscure: true),

          const SizedBox(height: 16),

          // ── DISPLAY ───────────────────────────────────────────
          _sectionHeader('Display', t),

          // Font size
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text('Font size',
                    style: TextStyle(fontSize: t.bodySize, color: t.ink))),
                DropdownButton<String>(
                  value: s.fontSize,
                  items: ['small', 'medium', 'large'].map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, style: TextStyle(fontSize: t.bodySize, color: t.ink)),
                  )).toList(),
                  onChanged: (v) => setState(() => s.fontSize = v!),
                ),
              ],
            ),
          ),

          // Contrast
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text('Contrast',
                    style: TextStyle(fontSize: t.bodySize, color: t.ink))),
                DropdownButton<String>(
                  value: s.contrast,
                  items: ['normal', 'high'].map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, style: TextStyle(fontSize: t.bodySize, color: t.ink)),
                  )).toList(),
                  onChanged: (v) => setState(() => s.contrast = v!),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text('Senso v1.0.0  |  com.fladroid.senso',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: t.captionSize, color: t.inkFaint)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, AppTheme t) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(fontSize: t.bodySize, fontWeight: FontWeight.bold,
                color: t.accent)),
        Divider(color: t.border, height: 8),
      ],
    ),
  );

  Widget _sensorSwitch({
    required String label,
    required bool available,
    required bool value,
    required Function(bool) onChanged,
    required AppTheme t,
  }) =>
    SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: TextStyle(fontSize: t.bodySize,
              color: available ? t.ink : t.inkFaint)),
      subtitle: available
          ? null
          : Text('Not available on this device',
              style: TextStyle(fontSize: t.captionSize, color: t.inkFaint,
                  fontStyle: FontStyle.italic)),
      value: available && value,
      onChanged: available ? onChanged : null,
    );

  Widget _sliderRow({
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    required Function(double) onChanged,
    required AppTheme t,
  }) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label,
                style: TextStyle(fontSize: t.bodySize, color: t.ink))),
            Text('${value.toStringAsFixed(1)} $unit',
                style: TextStyle(fontSize: t.bodySize,
                    color: t.accent, fontWeight: FontWeight.bold)),
          ]),
          Slider(
            value: value, min: min, max: max,
            activeColor: t.accent,
            inactiveColor: t.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );

  Widget _textField(String label, TextEditingController ctrl, AppTheme t,
      {bool obscure = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(fontSize: t.bodySize, color: t.ink),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: t.captionSize, color: t.inkMedium),
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: t.border)),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: t.accent)),
          isDense: true,
        ),
      ),
    );
}
