import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../utils/share.dart';

class BillSplitterScreen extends StatefulWidget {
  const BillSplitterScreen({super.key});
  @override
  State<BillSplitterScreen> createState() => _BillSplitterScreenState();
}

class _BillSplitterScreenState extends State<BillSplitterScreen> {
  static const slate = Color(0xFF5F7C8A);
  static const symbols = ['\$', '€', '£', '₹', '¥', 'AED'];
  static const presets = [0, 10, 15, 20];

  final billCtl = TextEditingController();
  final taxCtl = TextEditingController();
  double tipPct = 10;
  bool custom = false;
  int people = 2;
  bool roundUp = false;
  String symbol = '\$';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    billCtl.dispose();
    taxCtl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        tipPct = p.getDouble('bill_tip') ?? tipPct;
        custom =
            !presets.contains(tipPct.round()) ||
            tipPct != tipPct.roundToDouble();
        people = p.getInt('bill_people') ?? people;
        roundUp = p.getBool('bill_round') ?? roundUp;
        symbol = p.getString('bill_symbol') ?? symbol;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('bill_tip', tipPct);
      await p.setInt('bill_people', people);
      await p.setBool('bill_round', roundUp);
      await p.setString('bill_symbol', symbol);
    } catch (_) {}
  }

  void _set(VoidCallback f) {
    setState(f);
    _save();
  }

  double get bill => parseNum(billCtl.text) ?? 0;
  double get taxPct => (parseNum(taxCtl.text) ?? 0).clamp(0, 100).toDouble();
  double get tax => bill * taxPct / 100;
  // Tip is calculated on the pre-tax amount, the usual convention.
  double get tip => bill * tipPct / 100;
  double get total => bill + tax + tip;
  double get exactPerPerson => total / people;
  double get perPerson =>
      roundUp ? exactPerPerson.ceilToDouble() : exactPerPerson;
  double get collected => perPerson * people;

  String money(double v) => '$symbol${fmtNum(v, maxDecimals: 2)}';

  String get summary =>
      'Bill ${money(bill)}'
      '${taxPct > 0 ? ' + tax ${money(tax)}' : ''}'
      ' + tip ${money(tip)} (${fmtNum(tipPct, maxDecimals: 1)}%)'
      ' = ${money(total)}\n'
      'Split $people ways: ${money(perPerson)} each';

  Widget card(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: cardDecoration(radius: 14),
    child: child,
  );

  Widget tipBtn(String t, bool on, VoidCallback f) => Expanded(
    child: GestureDetector(
      onTap: f,
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? slate : const Color(0xFFE6ECF2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: on ? Colors.white : Colors.black87,
          ),
        ),
      ),
    ),
  );

  Widget field(
    TextEditingController c,
    String hint,
    IconData icon, {
    double size = 28,
    String? prefix,
    String? suffix,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFE6ECF2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: TextField(
      controller: c,
      onChanged: (_) => setState(() {}),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        icon: Icon(icon, color: slate),
        prefixText: prefix,
        suffixText: suffix,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Bill splitter',
      actions: [
        TextButton(
          onPressed: () {
            billCtl.clear();
            taxCtl.clear();
            _set(() {
              people = 2;
              tipPct = 10;
              custom = false;
              roundUp = false;
            });
          },
          child: const Text('Reset'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Bill amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: symbol,
                      isDense: true,
                      underline: const SizedBox(),
                      items: [
                        for (final s in symbols)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => _set(() => symbol = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                field(billCtl, '0', Icons.receipt_long, prefix: '$symbol '),
                const SizedBox(height: 12),
                const Text(
                  'Tax (optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                field(
                  taxCtl,
                  '0',
                  Icons.account_balance_outlined,
                  size: 18,
                  suffix: '%',
                ),
              ],
            ),
          ),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '% Tip',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    for (final p in presets)
                      tipBtn(
                        '$p%',
                        !custom && tipPct == p,
                        () => _set(() {
                          custom = false;
                          tipPct = p.toDouble();
                        }),
                      ),
                  ],
                ),
                if (custom)
                  Slider(
                    value: tipPct.clamp(0, 50).toDouble(),
                    max: 50,
                    divisions: 100,
                    activeColor: slate,
                    label: '${fmtNum(tipPct, maxDecimals: 1)}%',
                    onChanged: (v) => _set(() => tipPct = v),
                  ),
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: custom
                            ? slate
                            : const Color(0xFFE6ECF2),
                        foregroundColor: custom ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _set(() => custom = true),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(
                        custom
                            ? 'Custom ${fmtNum(tipPct, maxDecimals: 1)}%'
                            : 'Custom %',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Split between',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: slate),
                      onPressed: people > 1 ? () => _set(() => people--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6ECF2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '$people ${people == 1 ? 'person' : 'people'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: slate),
                      onPressed: people < 50
                          ? () => _set(() => people++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                Slider(
                  value: people.clamp(1, 20).toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  activeColor: slate,
                  onChanged: (v) => _set(() => people = v.round()),
                ),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeThumbColor: slate,
                    title: const Text('Round up each share'),
                    value: roundUp,
                    onChanged: (v) => _set(() => roundUp = v),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: slate,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sumRow(Icons.receipt_outlined, 'Bill', bill),
                if (taxPct > 0) ...[
                  const SizedBox(height: 8),
                  _sumRow(
                    Icons.account_balance_outlined,
                    'Tax (${fmtNum(taxPct, maxDecimals: 2)}%)',
                    tax,
                  ),
                ],
                const SizedBox(height: 8),
                _sumRow(Icons.payments_outlined, 'Tip amount', tip),
                const SizedBox(height: 8),
                _sumRow(Icons.summarize_outlined, 'Total', total),
                const Divider(color: Colors.white24),
                const Text(
                  'Each person pays',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    money(perPerson),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (roundUp && bill > 0)
                  Text(
                    'Collects ${money(collected)} (${money(collected - total)} extra tip)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        onPressed: bill <= 0
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: summary),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied')),
                                  );
                                }
                              },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: slate,
                        ),
                        onPressed: bill <= 0
                            ? null
                            : () => guardedShare(ShareParams(text: summary)),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumRow(IconData i, String l, double v) => Row(
    children: [
      Icon(i, color: Colors.white70, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          l,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
      Text(
        money(v),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
