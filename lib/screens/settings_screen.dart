// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../main.dart' show themeNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../services/app_theme.dart';
import '../services/translation_service.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  const SettingsScreen({super.key, required this.settings});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _theme = AppTheme();
  final _tr    = TranslationService();
  late TextEditingController _primaryCtrl;
  late TextEditingController _fallbackCtrl;
  late TextEditingController _tokenCtrl;

  @override
  void initState() {
    super.initState();
    _primaryCtrl  = TextEditingController(text: widget.settings.ntfyPrimaryUrl);
    _fallbackCtrl = TextEditingController(text: widget.settings.ntfyFallbackUrl);
    _tokenCtrl    = TextEditingController(text: widget.settings.ntfyToken);
  }

  @override
  void dispose() {
    _primaryCtrl.dispose(); _fallbackCtrl.dispose(); _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.settings.ntfyPrimaryUrl  = _primaryCtrl.text.trim();
    widget.settings.ntfyFallbackUrl = _fallbackCtrl.text.trim();
    widget.settings.ntfyToken       = _tokenCtrl.text.trim();
    await widget.settings.save();
    AppTheme().init(widget.settings.fontSize, widget.settings.contrast);
    TranslationService().setLanguage(widget.settings.language);
    themeNotifier.value++; // triggera rebuild MaterialApp teme
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final s = widget.settings;

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(child: Column(children: [
        // Top bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border))),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('‹',
                  style: TextStyle(fontSize: 26, color: t.inkLight))),
            const SizedBox(width: 16),
            Text(_tr.t('settings_title'),
                style: TextStyle(fontFamily: 'monospace',
                    fontSize: t.headerSize * 0.85,
                    fontWeight: FontWeight.bold, color: t.ink)),
            const Spacer(),
            GestureDetector(
              onTap: _save,
              child: Text(_tr.t('settings_save'),
                  style: TextStyle(fontSize: t.bodySize,
                      color: t.accent, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),

        // Content
        Expanded(child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── SENZORI ──────────────────────────────────
            _section(_tr.t('section_sensors')),
            _sensorTile('sensor_accel',      s.accelAvailable,      s.accelEnabled,      (v) => s.accelEnabled = v),
            _sensorTile('sensor_gyro',       s.gyroAvailable,       s.gyroEnabled,       (v) => s.gyroEnabled = v),
            _sensorTile('sensor_step',       s.stepAvailable,       s.stepEnabled,       (v) => s.stepEnabled = v),
            _sensorTile('sensor_stationary', s.stationaryAvailable, s.stationaryEnabled, (v) => s.stationaryEnabled = v),

            _divider(),

            // ── DETEKCIJA ─────────────────────────────────
            _section(_tr.t('section_detection')),

            // Polling interval
            _row(
              child: Row(children: [
                Expanded(child: Text(_tr.t('polling_interval'),
                    style: TextStyle(fontSize: t.bodySize, color: t.ink))),
                DropdownButton<int>(
                  value: s.pollingIntervalMs,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: t.bodySize, color: t.ink),
                  items: [100, 200, 500, 1000].map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(v < 1000 ? '${v}ms' : '1s'),
                  )).toList(),
                  onChanged: (v) => setState(() => s.pollingIntervalMs = v!),
                ),
              ]),
            ),

            // Response window
            _row(
              child: Row(children: [
                Expanded(child: Text(_tr.t('response_window'),
                    style: TextStyle(fontSize: t.bodySize, color: t.ink))),
                DropdownButton<int>(
                  value: s.responseWindow,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: t.bodySize, color: t.ink),
                  items: [3, 5, 10].map((v) => DropdownMenuItem(
                    value: v,
                    child: Text('${v}s'),
                  )).toList(),
                  onChanged: (v) => setState(() => s.responseWindow = v!),
                ),
              ]),
            ),

            _slider(
              label: _tr.t('fall_threshold'),
              value: s.fallThreshold, unit: 'm/s²',
              min: 1.0, max: 30.0,
              onChanged: (v) => setState(() =>
                  s.fallThreshold = double.parse(v.toStringAsFixed(1))),
            ),

            _slider(
              label: _tr.t('rotation_threshold'),
              value: s.rotationThreshold, unit: 'rad/s',
              min: 1.0, max: 10.0,
              onChanged: (v) => setState(() =>
                  s.rotationThreshold = double.parse(v.toStringAsFixed(1))),
            ),

            // Cooldown
            _row(
              child: Row(children: [
                Expanded(child: Text(_tr.t('cooldown'),
                    style: TextStyle(fontSize: t.bodySize, color: t.ink))),
                DropdownButton<int>(
                  value: s.cooldownSeconds,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: t.bodySize, color: t.ink),
                  items: [3, 5, 10, 30, 60].map((v) => DropdownMenuItem(
                    value: v,
                    child: Text('\${v}s'),
                  )).toList(),
                  onChanged: (v) => setState(() => s.cooldownSeconds = v!),
                ),
              ]),
            ),

            _divider(),

            // ── TEST MODE ─────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_tr.t('test_mode'),
                  style: TextStyle(fontSize: t.bodySize,
                      color: t.ink, fontWeight: FontWeight.w600)),
              subtitle: Text(_tr.t('test_mode_subtitle'),
                  style: TextStyle(fontSize: t.captionSize, color: t.inkFaint)),
              value: s.testMode,
              onChanged: (v) => setState(() => s.testMode = v),
            ),

            _divider(),

            // ── NOTIFIKACIJE ──────────────────────────────
            _section(_tr.t('section_notifications')),
            _textField(_tr.t('ntfy_primary'),  _primaryCtrl),
            _textField(_tr.t('ntfy_fallback'), _fallbackCtrl),
            _textField(_tr.t('ntfy_token'),    _tokenCtrl, obscure: true),

            _divider(),

            // ── DISPLAY ───────────────────────────────────
            _section(_tr.t('section_display')),

            // Jezik
            _row(child: Row(children: [
              Expanded(child: Text(_tr.t('language'),
                  style: TextStyle(fontSize: t.bodySize, color: t.ink))),
              DropdownButton<String>(
                value: s.language,
                underline: const SizedBox(),
                style: TextStyle(fontSize: t.bodySize, color: t.ink),
                items: TranslationService.languages.map((l) =>
                    DropdownMenuItem(value: l['code'], child: Text(l['label']!))
                ).toList(),
                onChanged: (v) => setState(() {
                  s.language = v!;
                  TranslationService().setLanguage(v);
                }),
              ),
            ])),

            // Font size
            _row(child: Row(children: [
              Expanded(child: Text(_tr.t('font_size'),
                  style: TextStyle(fontSize: t.bodySize, color: t.ink))),
              DropdownButton<String>(
                value: s.fontSize,
                underline: const SizedBox(),
                style: TextStyle(fontSize: t.bodySize, color: t.ink),
                items: [
                  DropdownMenuItem(value: 'malo',  child: Text(_tr.t('font_small'))),
                  DropdownMenuItem(value: 'srednje', child: Text(_tr.t('font_medium'))),
                  DropdownMenuItem(value: 'veliko',  child: Text(_tr.t('font_large'))),
                ],
                onChanged: (v) => setState(() {
                  s.fontSize = v!;
                  AppTheme().setSize(v);
                }),
              ),
            ])),

            // Contrast
            _row(child: Row(children: [
              Expanded(child: Text(_tr.t('contrast'),
                  style: TextStyle(fontSize: t.bodySize, color: t.ink))),
              DropdownButton<String>(
                value: s.contrast,
                underline: const SizedBox(),
                style: TextStyle(fontSize: t.bodySize, color: t.ink),
                items: [
                  DropdownMenuItem(value: 'normalno', child: Text(_tr.t('contrast_normal'))),
                  DropdownMenuItem(value: 'visoki',   child: Text(_tr.t('contrast_high'))),
                ],
                onChanged: (v) => setState(() {
                  s.contrast = v!;
                  AppTheme().setContrast(v);
                }),
              ),
            ])),

            const SizedBox(height: 24),

            // Reset na defaulte
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restore, size: 16),
                label: Text(_tr.t('reset_defaults'),
                    style: TextStyle(fontSize: t.captionSize)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.destructive,
                  side: BorderSide(color: t.destructive.withAlpha(120)),
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (!mounted) return;
                  Navigator.pop(context);
                },
              ),
            ),

            const SizedBox(height: 16),
            Text('Senso v1.1.0  |  com.fladroid.senso',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: t.captionSize, color: t.inkFaint)),
            const SizedBox(height: 16),
          ],
        )),
      ])),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 6),
    child: Text(title,
        style: TextStyle(fontSize: _theme.captionSize,
            fontWeight: FontWeight.bold,
            color: _theme.accent,
            letterSpacing: 0.8)),
  );

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Divider(color: _theme.border, height: 1),
  );

  Widget _row({required Widget child}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: child,
  );

  Widget _sensorTile(String key, bool available, bool value,
      Function(bool) onChanged) {
    final t = _theme;
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(_tr.t(key),
          style: TextStyle(fontSize: t.bodySize,
              color: available ? t.ink : t.inkFaint)),
      subtitle: available ? null : Text(_tr.t('sensor_not_available'),
          style: TextStyle(fontSize: t.captionSize,
              color: t.inkFaint, fontStyle: FontStyle.italic)),
      value: available && value,
      onChanged: available ? (v) => setState(() => onChanged(v)) : null,
    );
  }

  Widget _slider({
    required String label, required double value, required String unit,
    required double min, required double max, required Function(double) onChanged,
  }) {
    final t = _theme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(fontSize: t.bodySize, color: t.ink))),
        Text('${value.toStringAsFixed(1)} $unit',
            style: TextStyle(fontSize: t.bodySize,
                color: t.accent, fontWeight: FontWeight.bold)),
      ]),
      Slider(
        value: value, min: min, max: max,
        activeColor: t.accent, inactiveColor: t.border,
        onChanged: onChanged,
      ),
    ]);
  }

  Widget _textField(String label, TextEditingController ctrl,
      {bool obscure = false}) {
    final t = _theme;
    return Padding(
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
              borderSide: BorderSide(color: t.accent, width: 1.5)),
          isDense: true,
        ),
      ),
    );
  }
}
