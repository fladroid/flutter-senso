// lib/services/ntfy_service.dart
import 'package:http/http.dart' as http;
import 'app_settings.dart';

class NtfyService {
  static Future<void> send({
    required String title,
    required String priority,
    required String tags,
    String message = '',
  }) async {
    final s = AppSettings();
    final success = await _post(s.ntfyPrimaryUrl, s.ntfyToken, title, priority, tags, message);
    if (!success) {
      await _post(s.ntfyFallbackUrl, '', title, priority, tags, message);
    }
  }

  static Future<bool> _post(String url, String token, String title,
      String priority, String tags, String message) async {
    try {
      final headers = <String, String>{
        'Title': title,
        'Priority': priority,
        'Tags': tags,
        'Content-Type': 'text/plain',
      };
      if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final res = await http.post(
        Uri.parse(url),
        headers: headers,
        body: message.isEmpty ? title : message,
      ).timeout(const Duration(seconds: 3));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<void> sendAlarm(double accel, double gyro) => send(
    title: '🆘 Senso — Pad detektovan!',
    priority: 'urgent',
    tags: 'sos,bell',
    message: 'Accel: ${accel.toStringAsFixed(2)} m/s²  Gyro: ${gyro.toStringAsFixed(2)} rad/s',
  );

  static Future<void> sendOk()    => send(title: '✅ Senso — Korisnik OK',    priority: 'low',  tags: 'check');
  static Future<void> sendStart() => send(title: 'Senso — Monitoring 🟢',     priority: 'low',  tags: 'eyes');
  static Future<void> sendStop()  => send(title: 'Senso — Zaustavljeno ⏹',   priority: 'low',  tags: 'stop_button');
}
