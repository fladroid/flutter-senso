// lib/services/translation_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  Map<String, dynamic> _all = {};
  Map<String, dynamic> _tr  = {};
  String _language = 'en';

  static const List<Map<String, String>> languages = [
    {'code': 'en',     'label': 'English'},
    {'code': 'de',     'label': 'Deutsch'},
    {'code': 'hr',     'label': 'Hrvatski'},
    {'code': 'sr_lat', 'label': 'Srpski (lat)'},
    {'code': 'sr_cyr', 'label': 'Српски (ћир)'},
  ];

  Future<void> load(String language) async {
    if (_all.isEmpty) {
      final raw = await rootBundle.loadString('assets/translations.json');
      _all = json.decode(raw) as Map<String, dynamic>;
    }
    _language = language;
    _tr = (_all[language] ?? _all['en']) as Map<String, dynamic>;
  }

  void setLanguage(String language) {
    _language = language;
    _tr = (_all[language] ?? _all['en']) as Map<String, dynamic>;
  }

  String t(String key, {Map<String, String>? params}) {
    String text = _tr[key] as String? ?? key;
    if (params != null) {
      params.forEach((k, v) => text = text.replaceAll('{$k}', v));
    }
    return text;
  }

  String get language => _language;
}
