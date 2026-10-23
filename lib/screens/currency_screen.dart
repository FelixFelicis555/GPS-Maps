import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../services/currency_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../utils/share.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});
  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  static const maroon = Color(0xFF9E2A35);
  Rates? rates;
  String? error;
  bool loading = true;
  String from = 'USD', to = 'INR';
  final ctl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _restore();
    _load();
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        from = p.getString('fx_from') ?? from;
        to = p.getString('fx_to') ?? to;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('fx_from', from);
      await p.setString('fx_to', to);
    } catch (_) {}
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await CurrencyService.load(forceRefresh: force);
      if (!mounted) return;
      setState(() => rates = r);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load exchange rates.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get _ok =>
      rates != null &&
      rates!.perUsd.containsKey(from) &&
      rates!.perUsd.containsKey(to);

  double get amount => parseNum(ctl.text) ?? 0;
  double get result => _ok ? rates!.convert(amount, from, to) : 0;

  Future<void> _pick(bool isFrom) async {
    if (rates == null) return;
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _CurrencyPicker(codes: rates!.perUsd.keys.toList()..sort()),
    );
    if (code == null) return;
    setState(() => isFrom ? from = code : to = code);
    _save();
  }

  void _swap() {
    setState(() {
      // Keep the converted value as the new amount, like most converters.
      if (_ok && amount != 0) {
        ctl.text = fmtNum(result, maxDecimals: 4, group: false);
      }
      final t = from;
      from = to;
      to = t;
    });
    _save();
  }

  Widget _selector(String code, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${CurrencyService.flag(code)} $code',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final updated = rates == null
        ? ''
        : '${rates!.fromCache ? 'Cached' : 'Updated'} ${fmtDate2(rates!.updated)}';
    return AppScaffold(
      title: 'Currency converter',
      actions: [
        IconButton(
          tooltip: 'Refresh rates',
          onPressed: loading ? null : () => _load(force: true),
          icon: const Icon(Icons.refresh, color: kBlue),
        ),
      ],
      body: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: ListView(
          children: [
            if (loading && rates == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (rates == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(error ?? 'No rates available'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(radius: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyService.names[from] ?? from,
                            style: const TextStyle(fontSize: 12),
                          ),
                          TextField(
                            controller: ctl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: kInk,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: '0',
                            ),
                          ),
                        ],
                      ),
                    ),
                    _selector(from, () => _pick(true)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: maroon,
                  child: IconButton(
                    tooltip: 'Swap',
                    icon: const Icon(Icons.swap_vert, color: Colors.white),
                    onPressed: _swap,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(
                  color: const Color(0xFFFBEAEA),
                  radius: 18,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyService.names[to] ?? to,
                            style: const TextStyle(fontSize: 12),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _ok ? fmtNum(result, maxDecimals: 2) : '--',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: kInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _selector(to, () => _pick(false)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _ok
                    ? '1 $from = ${fmtNum(rates!.convert(1, from, to), maxDecimals: 4)} $to\n$updated · Rates by ExchangeRate-API'
                    : 'Rate unavailable for $from → $to',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !_ok
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text:
                                      '${fmtNum(amount)} $from = ${fmtNum(result, maxDecimals: 2)} $to',
                                ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied')),
                                );
                              }
                            },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: maroon),
                      onPressed: !_ok
                          ? null
                          : () => guardedShare(
                              ShareParams(
                                text:
                                    '${fmtNum(amount)} $from = ${fmtNum(result, maxDecimals: 2)} $to',
                              ),
                            ),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String fmtDate2(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _CurrencyPicker extends StatefulWidget {
  final List<String> codes;
  const _CurrencyPicker({required this.codes});
  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.codes.where((c) {
      final s = q.toLowerCase();
      return c.toLowerCase().contains(s) ||
          (CurrencyService.names[c] ?? '').toLowerCase().contains(s);
    }).toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => q = v),
                decoration: InputDecoration(
                  hintText: 'Search currency',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  return ListTile(
                    leading: Text(
                      CurrencyService.flag(c),
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(c),
                    subtitle: Text(CurrencyService.names[c] ?? ''),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
