// lib/services/ntfy_service.dart
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';

class NtfyService {
  final AppSettings settings;
  NtfyService({required this.settings});

  Future<void> sendAlarm() => _send(
    title: '🆘 Senso — Pad detektovan!',
    message: 'Korisnik nije odgovorio. Provjeri!',
    priority: 'urgent',
    tags: 'sos,bell',
  );

  Future<void> sendOk() => _send(
    title: '✅ Senso — Korisnik OK',
    message: 'Korisnik potvrdio da je dobro.',
    priority: 'low',
    tags: 'check',
  );

  Future<void> sendStart() => _send(
    title: 'Senso — Monitoring 🟢',
    message: 'Detekcija pada pokrenuta.',
    priority: 'low',
    tags: 'eyes',
  );

  Future<void> sendStop() => _send(
    title: 'Senso — Zaustavljeno ⏹',
    message: 'Monitoring zaustavljen.',
    priority: 'low',
    tags: 'stop_button',
  );

  Future<void> _send({
    required String title,
    required String message,
    required String priority,
    required String tags,
  }) async {
    final sent = await _tryUrl(settings.ntfyPrimaryUrl, title, message, priority, tags);
    if (!sent) {
      await _tryUrl(settings.ntfyFallbackUrl, title, message, priority, tags);
    }
  }

  Future<bool> _tryUrl(String url, String title, String message,
      String priority, String tags) async {
    try {
      final headers = <String, String>{
        'Title':    title,
        'Priority': priority,
        'Tags':     tags,
        'Content-Type': 'text/plain',
      };
      if (settings.ntfyToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${settings.ntfyToken}';
      }
      final res = await http.post(
        Uri.parse(url),
        headers: headers,
        body: message,
      ).timeout(const Duration(seconds: 3));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
