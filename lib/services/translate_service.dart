import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'sarvam_service.dart';

class Language {
  final String name, code;
  const Language(this.name, this.code);
}

const kLanguages = <Language>[
  Language('English', 'en'),
  Language('Hindi', 'hi'),
  Language('Telugu', 'te'),
  Language('Tamil', 'ta'),
  Language('Kannada', 'kn'),
  Language('Malayalam', 'ml'),
  Language('Marathi', 'mr'),
  Language('Bengali', 'bn'),
  Language('Gujarati', 'gu'),
  Language('Punjabi', 'pa'),
  Language('Urdu', 'ur'),
  Language('Spanish', 'es'),
  Language('French', 'fr'),
  Language('German', 'de'),
  Language('Italian', 'it'),
  Language('Portuguese', 'pt'),
  Language('Russian', 'ru'),
  Language('Arabic', 'ar'),
  Language('Chinese (Simplified)', 'zh-CN'),
  Language('Japanese', 'ja'),
  Language('Korean', 'ko'),
  Language('Turkish', 'tr'),
  Language('Dutch', 'nl'),
  Language('Indonesian', 'id'),
  Language('Thai', 'th'),
  Language('Vietnamese', 'vi'),
];

String languageName(String code) {
  for (final l in kLanguages) {
    if (l.code.toLowerCase() == code.toLowerCase() ||
        l.code.split('-').first == code.split('-').first) {
      return l.name;
    }
  }
  return code;
}

class TranslationResult {
  final String text;

  /// ISO code of the detected source language, when known.
  final String? detected;
  const TranslationResult(this.text, [this.detected]);
}

class TranslateException implements Exception {
  final String message;
  const TranslateException(this.message);
  @override
  String toString() => message;
}

class TranslateService {
  /// [from] null = auto-detect. Uses Google Cloud Translation when a Maps/Cloud
  /// key is configured and the API is enabled, otherwise falls back to the free
  /// MyMemory service.
  static Future<TranslationResult> translate(
    String text,
    String? from,
    String to,
  ) async {
    if (SarvamService.canTranslate(from, to)) {
      try {
        return await _sarvam(text, from, to);
      } catch (_) {
        /* fall through to the next service */
      }
    }
    if (kMapsApiKey.isNotEmpty) {
      try {
        return await _google(text, from, to);
      } catch (_) {
        /* fall through to MyMemory */
      }
    }
    return _myMemory(text, from, to);
  }

  static Future<TranslationResult> _sarvam(
    String text,
    String? from,
    String to,
  ) async {
    final out = StringBuffer();
    String? detected;
    for (final part in _chunks(text, SarvamService.maxChars)) {
      if (part.trim().isEmpty) {
        out.write(part);
        continue;
      }
      final (t, d) = await SarvamService.translate(part, from, to);
      out.write(t);
      detected ??= d?.split('-').first;
    }
    return TranslationResult(out.toString(), detected);
  }

  static Future<TranslationResult> _google(
    String text,
    String? from,
    String to,
  ) async {
    final res = await http
        .post(
          Uri.https('translation.googleapis.com', '/language/translate/v2', {
            'key': kMapsApiKey,
          }),
          body: {'q': text, 'target': to, 'format': 'text', 'source': ?from},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw const TranslateException('google failed');
    final t = (jsonDecode(res.body)['data']['translations'] as List).first;
    return TranslationResult(
      t['translatedText'] as String,
      t['detectedSourceLanguage'] as String?,
    );
  }

  static Future<TranslationResult> _myMemory(
    String text,
    String? from,
    String to,
  ) async {
    final parts = _chunks(text, 450);
    final out = StringBuffer();
    String? detected;
    for (final part in parts) {
      if (part.trim().isEmpty) {
        out.write(part);
        continue;
      }
      try {
        final res = await http
            .get(
              Uri.https('api.mymemory.translated.net', '/get', {
                'q': part,
                'langpair': '${from ?? 'Autodetect'}|$to',
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) {
          throw const TranslateException('Translation service is unavailable.');
        }
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final status = int.tryParse('${j['responseStatus']}') ?? 0;
        if (status != 200) {
          throw TranslateException(
            status == 429
                ? 'Daily free translation limit reached.'
                : 'Could not translate this text.',
          );
        }
        out.write(_unescape(j['responseData']['translatedText'] as String));
        detected ??= j['responseData']['detectedLanguage'] as String?;
      } on TranslateException {
        rethrow;
      } catch (_) {
        throw const TranslateException(
          'Could not translate. Check your connection.',
        );
      }
    }
    return TranslationResult(out.toString(), detected);
  }

  /// Splits on sentence boundaries, keeping each chunk under [max] chars.
  static List<String> _chunks(String s, int max) {
    if (s.length <= max) return [s];
    final out = <String>[];
    var cur = StringBuffer();
    for (final m in RegExp(r'[^.!?\n।]+[.!?\n।]*\s*').allMatches(s)) {
      var piece = m.group(0)!;
      while (piece.length > max) {
        if (cur.isNotEmpty) {
          out.add(cur.toString());
          cur = StringBuffer();
        }
        out.add(piece.substring(0, max));
        piece = piece.substring(max);
      }
      if (cur.length + piece.length > max) {
        out.add(cur.toString());
        cur = StringBuffer();
      }
      cur.write(piece);
    }
    if (cur.isNotEmpty) out.add(cur.toString());
    return out;
  }

  static String _unescape(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
