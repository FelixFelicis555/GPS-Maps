import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../ads/ad_service.dart';
import '../services/sarvam_service.dart';
import '../services/translate_service.dart';
import '../widgets/common.dart';
import '../utils/share.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});
  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  static const purple = Color(0xFF8E4A93);
  static const auto = 'Auto';

  String src = auto, dst = 'Hindi';
  final input = TextEditingController();
  String output = '';
  String? detected, error;
  bool busy = false, listening = false;
  Timer? _debounce;
  int _req = 0;

  final _tts = FlutterTts();
  final _stt = SpeechToText();
  bool _sttReady = false;
  final _player = AudioPlayer();
  final _recorder = AudioRecorder();
  Timer? _recLimit;
  String? _recPath;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recLimit?.cancel();
    _tts.stop();
    _stt.cancel();
    _player.dispose();
    _recorder.dispose();
    input.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        src = p.getString('tr_src') ?? src;
        dst = p.getString('tr_dst') ?? dst;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('tr_src', src);
      await p.setString('tr_dst', dst);
    } catch (_) {}
  }

  String _code(String name) =>
      kLanguages.firstWhere((l) => l.name == name).code;

  /// Effective source language name (explicit, or auto-detected).
  String? get _srcName =>
      src != auto ? src : (detected == null ? null : languageName(detected!));

  void _scheduleTranslate() {
    _debounce?.cancel();
    if (input.text.trim().isEmpty) {
      setState(() {
        output = '';
        error = null;
        detected = null;
        busy = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 800), _translate);
  }

  Future<void> _translate() async {
    _debounce?.cancel();
    final text = input.text.trim();
    if (text.isEmpty) return;
    final req = ++_req;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await TranslateService.translate(
        text,
        src == auto ? null : _code(src),
        _code(dst),
      );
      if (!mounted || req != _req) return;
      setState(() {
        output = r.text;
        detected = src == auto ? r.detected : null;
      });
    } on TranslateException catch (e) {
      if (mounted && req == _req) setState(() => error = e.message);
    } finally {
      if (mounted && req == _req) setState(() => busy = false);
    }
  }

  void _swap() {
    final from = _srcName;
    if (from == null) {
      _toast('Enter text first so the language can be detected.');
      return;
    }
    setState(() {
      final oldDst = dst;
      src = oldDst;
      dst = from;
      input.text = output;
      output = '';
      detected = null;
    });
    _save();
    _scheduleTranslate();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _speak(String text, String langName) async {
    if (text.trim().isEmpty) return;
    final iso = _code(langName).split('-').first;
    if (SarvamService.canSpeak(iso)) {
      try {
        final wav = await SarvamService.speak(text, iso);
        await _player.stop();
        await _player.play(BytesSource(wav));
        return;
      } catch (_) {
        /* fall back to the device voice */
      }
    }
    try {
      await _tts.setLanguage(_code(langName));
      await _tts.speak(text);
    } catch (_) {
      _toast('Text-to-speech is not available.');
    }
  }

  /// Sarvam voice input: record, then send the clip for transcription.
  /// (Sarvam's quick endpoint takes clips of up to ~30 s.)
  Future<void> _toggleSarvamMic() async {
    if (listening) {
      await _finishRecording();
      return;
    }
    try {
      final ok = await AdService.instance.guard(_recorder.hasPermission);
      if (!ok) {
        _toast('Microphone permission was denied.');
        return;
      }
      final path =
          '${Directory.systemTemp.path}/tr_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      _recPath = path;
      setState(() => listening = true);
      _recLimit = Timer(const Duration(seconds: 28), _finishRecording);
    } catch (_) {
      if (mounted) setState(() => listening = false);
      _toast('Could not start voice input.');
    }
  }

  Future<void> _finishRecording() async {
    _recLimit?.cancel();
    final path = await _recorder.stop() ?? _recPath;
    if (mounted) {
      setState(() {
        listening = false;
        busy = true;
      });
    }
    if (path == null) return;
    try {
      final iso = src == auto ? null : _code(src).split('-').first;
      final text = await SarvamService.transcribe(File(path), iso);
      if (!mounted) return;
      if (text.isEmpty) {
        setState(() => busy = false);
        _toast('Could not hear anything. Try again.');
        return;
      }
      input.text = text;
      input.selection = TextSelection.collapsed(offset: text.length);
      setState(() => busy = false);
      _translate();
    } catch (_) {
      if (mounted) setState(() => busy = false);
      _toast('Voice input failed. Check your connection.');
    } finally {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _toggleMic() async {
    final iso = src == auto ? null : _code(src).split('-').first;
    if (SarvamService.canTranscribe(iso)) {
      return _toggleSarvamMic();
    }
    if (listening) {
      await _stt.stop();
      setState(() => listening = false);
      return;
    }
    try {
      if (!_sttReady) {
        _sttReady = await AdService.instance.guard(
          () => _stt.initialize(
            onStatus: (s) {
              if ((s == 'done' || s == 'notListening') && mounted) {
                setState(() => listening = false);
              }
            },
            onError: (_) {
              if (mounted) setState(() => listening = false);
            },
          ),
        );
      }
      if (!_sttReady) {
        _toast('Speech recognition is unavailable or permission was denied.');
        return;
      }
      String? locale;
      if (src != auto) {
        final c = _code(src).split('-').first;
        for (final l in await _stt.locales()) {
          if (l.localeId.toLowerCase().startsWith(c)) {
            locale = l.localeId;
            break;
          }
        }
      }
      setState(() => listening = true);
      await _stt.listen(
        listenOptions: SpeechListenOptions(localeId: locale),
        onResult: (r) {
          input.text = r.recognizedWords;
          input.selection = TextSelection.collapsed(offset: input.text.length);
          setState(() {});
          if (r.finalResult) _translate();
        },
      );
    } catch (_) {
      if (mounted) setState(() => listening = false);
      _toast('Could not start voice input.');
    }
  }

  Widget _lang(String v, List<String> options, ValueChanged<String> f) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1DDF1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: DropdownButton<String>(
          value: v,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.keyboard_arrow_down),
          items: [
            for (final l in options) DropdownMenuItem(value: l, child: Text(l)),
          ],
          onChanged: (x) {
            setState(() => f(x!));
            _save();
            _scheduleTranslate();
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    BoxDecoration box() => BoxDecoration(
      color: const Color(0xFFFBF0FB),
      border: Border.all(color: const Color(0xFFEBCDEB)),
      borderRadius: BorderRadius.circular(16),
    );
    final names = [for (final l in kLanguages) l.name];
    return AppScaffold(
      title: 'Translator',
      body: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFAFD),
          borderRadius: BorderRadius.circular(24),
        ),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: box(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        flex: 3,
                        child: _lang(src, [auto, ...names], (v) => src = v),
                      ),
                      if (src == auto && detected != null)
                        Flexible(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              'Detected: ${languageName(detected!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  TextField(
                    controller: input,
                    maxLines: 4,
                    maxLength: 5000,
                    onChanged: (_) => _scheduleTranslate(),
                    decoration: const InputDecoration(
                      hintText: 'Tap to enter text',
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleMic,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: listening ? Colors.red : purple,
                          child: Icon(
                            listening ? Icons.stop : Icons.mic,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Listen',
                        onPressed: _srcName == null
                            ? null
                            : () => _speak(input.text, _srcName!),
                        icon: const Icon(Icons.volume_up, color: purple),
                      ),
                      IconButton(
                        tooltip: 'Paste',
                        onPressed: () async {
                          final d = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (d?.text?.isNotEmpty ?? false) {
                            input.text = d!.text!;
                            setState(() {});
                            _scheduleTranslate();
                          }
                        },
                        icon: const Icon(Icons.content_paste, color: purple),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          input.clear();
                          _scheduleTranslate();
                        },
                        icon: const Icon(Icons.cancel, color: Colors.black26),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Center(
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: purple),
                tooltip: 'Swap languages',
                onPressed: _swap,
                icon: const Icon(Icons.swap_vert),
              ),
            ),
            Container(
              height: 180,
              padding: const EdgeInsets.all(12),
              decoration: box(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: _lang(dst, names, (v) => dst = v)),
                    ],
                  ),
                  Expanded(
                    child: busy
                        ? const Center(child: CircularProgressIndicator())
                        : error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(error!, textAlign: TextAlign.center),
                                TextButton(
                                  onPressed: _translate,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: SelectableText(
                              output,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Listen',
                        onPressed: output.isEmpty
                            ? null
                            : () => _speak(output, dst),
                        icon: const Icon(Icons.volume_up, color: purple),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Copy',
                        onPressed: output.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: output),
                                );
                                if (context.mounted) _toast('Copied');
                              },
                        icon: const Icon(Icons.copy, color: purple),
                      ),
                      IconButton(
                        tooltip: 'Share',
                        onPressed: output.isEmpty
                            ? null
                            : () => guardedShare(ShareParams(text: output)),
                        icon: const Icon(Icons.share, color: purple),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: busy ? null : _translate,
                child: const Text('Translate', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
