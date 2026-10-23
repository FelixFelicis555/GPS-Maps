import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class UnitConverterScreen extends StatefulWidget {
  const UnitConverterScreen({super.key});
  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  // factor = how many base units in 1 of this unit (temperature is special-cased)
  static const cats = <String, (IconData, Map<String, double>)>{
    'Length': (
      Icons.straighten,
      {
        'Kilometer': 1000,
        'Meter': 1,
        'Centimeter': .01,
        'Millimeter': .001,
        'Mile': 1609.344,
        'Yard': .9144,
        'Foot': .3048,
        'Inch': .0254,
        'Nautical mile': 1852,
      },
    ),
    'Weight': (
      Icons.scale,
      {
        'Tonne': 1000,
        'Kilogram': 1,
        'Gram': .001,
        'Milligram': .000001,
        'Pound': .45359237,
        'Ounce': .028349523125,
        'Stone': 6.35029318,
      },
    ),
    'Temperature': (
      Icons.thermostat,
      {'Celsius': 1, 'Fahrenheit': 1, 'Kelvin': 1},
    ),
    'Volume': (
      Icons.science_outlined,
      {
        'Liter': 1,
        'Milliliter': .001,
        'Cubic meter': 1000,
        'Gallon (US)': 3.785411784,
        'Quart (US)': .946352946,
        'Pint (US)': .473176473,
        'Cup (US)': .2365882365,
        'Fluid ounce (US)': .0295735296,
        'Tablespoon (US)': .0147867648,
        'Teaspoon (US)': .00492892159,
        'Gallon (UK)': 4.54609,
      },
    ),
    'Area': (
      Icons.crop_square,
      {
        'Square kilometer': 1e6,
        'Hectare': 10000,
        'Square meter': 1,
        'Square mile': 2589988.110336,
        'Acre': 4046.8564224,
        'Square yard': .83612736,
        'Square foot': .09290304,
        'Square inch': .00064516,
      },
    ),
    'Speed': (
      Icons.speed,
      {
        'm/s': 1,
        'km/h': 1 / 3.6,
        'mph': .44704,
        'Knot': .514444444,
        'ft/s': .3048,
      },
    ),
    'Time': (
      Icons.schedule,
      {
        'Year': 31557600,
        'Month': 2629800,
        'Week': 604800,
        'Day': 86400,
        'Hour': 3600,
        'Minute': 60,
        'Second': 1,
        'Millisecond': .001,
      },
    ),
    'Data': (
      Icons.sd_storage,
      {
        'Terabyte': 1e12,
        'Gigabyte': 1e9,
        'Megabyte': 1e6,
        'Kilobyte': 1e3,
        'Byte': 1,
        'Bit': .125,
        'Tebibyte': 1099511627776,
        'Gibibyte': 1073741824,
        'Mebibyte': 1048576,
        'Kibibyte': 1024,
      },
    ),
    'Pressure': (
      Icons.compress,
      {
        'Pascal': 1,
        'Kilopascal': 1000,
        'Bar': 100000,
        'Millibar': 100,
        'Atmosphere': 101325,
        'PSI': 6894.757293168,
        'mmHg': 133.322387415,
      },
    ),
    'Energy': (
      Icons.bolt,
      {
        'Joule': 1,
        'Kilojoule': 1000,
        'Calorie': 4.184,
        'Kilocalorie': 4184,
        'Watt-hour': 3600,
        'Kilowatt-hour': 3600000,
        'BTU': 1055.05585262,
      },
    ),
  };

  String cat = 'Length';
  late String from = cats[cat]!.$2.keys.first,
      to = cats[cat]!.$2.keys.elementAt(1);
  final ctl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString('unit_cat');
      if (c == null || !cats.containsKey(c)) return;
      final u = cats[c]!.$2.keys;
      final f = p.getString('unit_from'), t = p.getString('unit_to');
      if (!mounted) return;
      setState(() {
        cat = c;
        from = u.contains(f) ? f! : u.first;
        to = u.contains(t) ? t! : u.elementAt(1);
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('unit_cat', cat);
      await p.setString('unit_from', from);
      await p.setString('unit_to', to);
    } catch (_) {}
  }

  double get value => parseNum(ctl.text) ?? 0;

  double convert(double v, String f, String t) {
    if (cat == 'Temperature') {
      final c = switch (f) {
        'Fahrenheit' => (v - 32) * 5 / 9,
        'Kelvin' => v - 273.15,
        _ => v,
      };
      return switch (t) {
        'Fahrenheit' => c * 9 / 5 + 32,
        'Kelvin' => c + 273.15,
        _ => c,
      };
    }
    final m = cats[cat]!.$2;
    return v * m[f]! / m[t]!;
  }

  double get result => convert(value, from, to);

  void pick(String c) {
    setState(() {
      cat = c;
      from = cats[c]!.$2.keys.first;
      to = cats[c]!.$2.keys.elementAt(1);
    });
    _save();
  }

  Widget dd(String v, ValueChanged<String> f) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4CC),
      borderRadius: BorderRadius.circular(10),
    ),
    child: DropdownButton<String>(
      value: v,
      underline: const SizedBox(),
      items: [
        for (final k in cats[cat]!.$2.keys)
          DropdownMenuItem(value: k, child: Text(k)),
      ],
      onChanged: (x) {
        setState(() => f(x!));
        _save();
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFC21A);
    final units = cats[cat]!.$2.keys.toList();
    return AppScaffold(
      title: 'Unit converter',
      body: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(24),
        ),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: cardDecoration(
                color: const Color(0xFFFFFBEB),
                radius: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in cats.entries)
                        ChoiceChip(
                          avatar: Icon(e.value.$1, size: 16),
                          label: Text(e.key),
                          selected: cat == e.key,
                          selectedColor: yellow,
                          onSelected: (_) => pick(e.key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: cardDecoration(
                color: const Color(0xFFFFF8DC),
                radius: 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('From', style: TextStyle(fontSize: 12)),
                        TextField(
                          controller: ctl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,\-]'),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
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
                  dd(from, (x) => from = x),
                ],
              ),
            ),
            Center(
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: yellow,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.swap_vert),
                onPressed: () {
                  setState(() {
                    ctl.text = fmtNum(result, maxDecimals: 6, group: false);
                    final t = from;
                    from = to;
                    to = t;
                  });
                  _save();
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: cardDecoration(
                color: const Color(0xFFFFF8DC),
                radius: 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('To', style: TextStyle(fontSize: 12)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            fmtNum(result, maxDecimals: 6),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: fmtNum(result, maxDecimals: 6, group: false),
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Copied')));
                      }
                    },
                  ),
                  dd(to, (x) => to = x),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${fmtNum(value, maxDecimals: 6)} $from equals',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: cardDecoration(radius: 14),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    for (final u in units.where((u) => u != from))
                      ListTile(
                        dense: true,
                        title: Text(u),
                        trailing: Text(
                          fmtNum(convert(value, from, u), maxDecimals: 6),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () {
                          setState(() => to = u);
                          _save();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
