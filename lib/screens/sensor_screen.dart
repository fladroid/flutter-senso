// lib/screens/sensor_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/app_theme.dart';
import '../services/app_settings.dart';
import '../services/sensor_service.dart';

class SensorScreen extends StatefulWidget {
  final SensorAvailability availability;
  const SensorScreen({super.key, required this.availability});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  StreamSubscription? _accelSub, _gyroSub;
  double _accelMag = 0, _gyroMag = 0;
  double _accelMax = 0, _gyroMax = 0;

  @override
  void initState() {
    super.initState();
    if (widget.availability.accelerometer) {
      _accelSub = userAccelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen((e) {
        final m = sqrt(e.x*e.x + e.y*e.y + e.z*e.z);
        setState(() { _accelMag = m; if (m > _accelMax) _accelMax = m; });
      });
    }
    if (widget.availability.gyroscope) {
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen((e) {
        final m = sqrt(e.x*e.x + e.y*e.y + e.z*e.z);
        setState(() { _gyroMag = m; if (m > _gyroMax) _gyroMax = m; });
      });
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    super.dispose();
  }

  Widget _sensorCard(String label, bool available, double value, double maxValue,
      double threshold, String unit) {
    final t = AppTheme();
    final aboveThreshold = value > threshold;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: aboveThreshold && available ? const Color(0xFFFFE0E0) : t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: aboveThreshold && available ? Colors.red : t.border, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: t.bodySize, fontWeight: FontWeight.bold, color: t.ink)),
          if (!available)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: t.border, borderRadius: BorderRadius.circular(4)),
              child: Text('Not available', style: TextStyle(fontSize: t.captionSize, color: t.inkFaint)),
            ),
        ]),
        const SizedBox(height: 8),
        Text(
          available ? '${value.toStringAsFixed(3)} $unit' : '— $unit',
          style: TextStyle(
            fontSize: t.headerSize,
            fontWeight: FontWeight.bold,
            color: available ? (aboveThreshold ? Colors.red : t.accent) : t.inkFaint,
          ),
        ),
        const SizedBox(height: 4),
        if (available) ...[
          LinearProgressIndicator(
            value: (value / (threshold * 2)).clamp(0.0, 1.0),
            color: aboveThreshold ? Colors.red : t.accent,
            backgroundColor: t.border,
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Threshold: $threshold $unit',
              style: TextStyle(fontSize: t.captionSize, color: t.inkLight)),
            Text('Max: ${maxValue.toStringAsFixed(3)} $unit',
              style: TextStyle(fontSize: t.captionSize, color: t.inkLight)),
          ]),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    final s = AppSettings();
    final av = widget.availability;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        title: Text('Sensor Monitor', style: TextStyle(fontSize: t.headerSize, color: t.ink)),
        actions: [
          TextButton(
            onPressed: () => setState(() { _accelMax = 0; _gyroMax = 0; }),
            child: Text('Reset max', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sensorCard('Accelerometer (linear)',
            av.accelerometer, _accelMag, _accelMax, s.fallThreshold, 'm/s²'),
          _sensorCard('Gyroscope',
            av.gyroscope, _gyroMag, _gyroMax, s.rotationThreshold, 'rad/s'),

          // Step detector status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Step Detector',
                style: TextStyle(fontSize: t.bodySize, fontWeight: FontWeight.bold, color: t.ink)),
              av.stepDetector
                ? Text('Available ✅', style: TextStyle(fontSize: t.bodySize, color: t.positive))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(4)),
                    child: Text('Not available', style: TextStyle(fontSize: t.captionSize, color: t.inkFaint)),
                  ),
            ]),
          ),

          // Stationary detect status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Stationary Detect',
                style: TextStyle(fontSize: t.bodySize, fontWeight: FontWeight.bold, color: t.ink)),
              av.stationary
                ? Text('Available ✅', style: TextStyle(fontSize: t.bodySize, color: t.positive))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(4)),
                    child: Text('Not available', style: TextStyle(fontSize: t.captionSize, color: t.inkFaint)),
                  ),
            ]),
          ),

          const SizedBox(height: 12),
          Center(child: Text(
            'Pomakni uređaj da vidiš live vrijednosti.\nCrveno = iznad threshold-a.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: t.captionSize, color: t.inkLight),
          )),
        ],
      ),
    );
  }
}
