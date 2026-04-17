// lib/services/ntfy_service.dart
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import 'translation_service.dart';

class NtfyService {
  final AppSettings settings;
  final _tr = TranslationService();

  NtfyService({required this.settings});

  Future<void> sendAlarm() => _send(
    title: _tr.t('ntfy_alarm_title'),
    message: _tr.t('ntfy_alarm_body'),
    priority: 'urgent', tags: 'sos,bell',
  );

  Future<void> sendOk() => _send(
    title: _tr.t('ntfy_ok_title'),
    message: _tr.t('ntfy_ok_body'),
    priority: 'low', tags: 'check',
  );

  Future<void> sendStart() => _send(
    title: _tr.t('ntfy_start_title'),
    message: _tr.t('ntfy_start_body'),
    priority: 'low', tags: 'eyes',
  );

  Future<void> sendStop() => _send(
    title: _tr.t('ntfy_stop_title'),
    message: _tr.t('ntfy_stop_body'),
    priority: 'low', tags: 'stop_button',
  );

  Future<void> _send({
    required String title, required String message,
    required String priority, required String tags,
  }) async {
    if (settings.testMode) return; // test mode — ne šalji
    final sent = await _tryUrl(settings.ntfyPrimaryUrl, title, message, priority, tags);
    if (!sent) await _tryUrl(settings.ntfyFallbackUrl, title, message, priority, tags);
  }

  Future<bool> _tryUrl(String url, String title, String message,
      String priority, String tags) async {
    try {
      final headers = <String, String>{
        'Title': title, 'Priority': priority, 'Tags': tags,
        'Content-Type': 'text/plain',
      };
      if (settings.ntfyToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${settings.ntfyToken}';
      }
      final res = await http.post(
        Uri.parse(url), headers: headers, body: message,
      ).timeout(const Duration(seconds: 3));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) { return false; }
  }
}
