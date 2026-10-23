import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config.dart';

class SarvamException implements Exception {
  final String message;
  const SarvamException(this.message);
  @override
  String toString() => message;
}

/// Sarvam AI (Indian languages) via the `sarvam` Supabase edge function, which
/// holds the Sarvam key. Used only when Supabase is configured and the
/// languages involved are supported; callers fall back to other services.
class SarvamService {
  static const _text = {
    'en': 'en-IN',
    'hi': 'hi-IN',
    'te': 'te-IN',
    'ta': 'ta-IN',
    'kn': 'kn-IN',
    'ml': 'ml-IN',
    'mr': 'mr-IN',
    'bn': 'bn-IN',
    'gu': 'gu-IN',
    'pa': 'pa-IN',
    'ur': 'ur-IN',
  };

  /// Languages the text-to-speech model can speak (no Urdu).
  static const _speech = {
    'en',
    'hi',
    'te',
    'ta',
    'kn',
    'ml',
    'mr',
    'bn',
    'gu',
    'pa',
  };

  /// Translation/auto-detect model limit per request.
  static const maxChars = 900;

  static bool get enabled => routingConfigured;

  static String? code(String? iso) => iso == null ? null : _text[iso];

  /// Source null = auto-detect (needs a target the auto-detect model covers).
  static bool canTranslate(String? from, String to) {
    if (!enabled || _text[to] == null) return false;
    if (from == null) return to != 'ur';
    return _text[from] != null;
  }

  static bool canSpeak(String iso) => enabled && _speech.contains(iso);

  /// Speech-to-text; source null = let Sarvam detect the language.
  static bool canTranscribe(String? from) =>
      enabled && (from == null || _text[from] != null);

  static Uri get _url => Uri.parse('$kSupabaseUrl/functions/v1/sarvam');
  static Map<String, String> get _auth => {
    'apikey': kSupabaseAnonKey,
    'Authorization': 'Bearer $kSupabaseAnonKey',
  };

  static Future<Map<String, dynamic>> _json(Map<String, dynamic> body) async {
    final res = await http
        .post(
          _url,
          headers: {..._auth, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  static Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> j = {};
    try {
      j = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode != 200) {
      throw SarvamException('${j['error'] ?? 'sarvam_${res.statusCode}'}');
    }
    return j;
  }

  /// Returns the translated text and the detected/used source code (e.g. en-IN).
  static Future<(String, String?)> translate(
    String text,
    String? from,
    String to,
  ) async {
    final j = await _json({
      'op': 'translate',
      'text': text,
      'from': code(from) ?? 'auto',
      'to': code(to),
    });
    return (j['text'] as String, j['detected'] as String?);
  }

  /// WAV bytes for [text] spoken in [iso].
  static Future<Uint8List> speak(String text, String iso) async {
    final j = await _json({'op': 'tts', 'text': text, 'lang': code(iso)});
    return base64Decode(j['audio'] as String);
  }

  /// Transcribes a recorded audio file.
  static Future<String> transcribe(File audio, String? iso) async {
    final req = http.MultipartRequest('POST', _url)
      ..headers.addAll(_auth)
      ..fields['op'] = 'stt'
      ..fields['lang'] = code(iso) ?? 'unknown'
      ..files.add(await http.MultipartFile.fromPath('file', audio.path));
    final res = await http.Response.fromStream(
      await req.send().timeout(const Duration(seconds: 40)),
    );
    return (_decode(res)['transcript'] as String?)?.trim() ?? '';
  }
}
