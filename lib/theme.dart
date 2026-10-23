import 'package:flutter/material.dart';

const kBg = Color(0xFFEEF2FB);
const kBlue = Color(0xFF1976D2);
const kInk = Color(0xFF0E1330);

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: kBg,
  colorScheme: ColorScheme.fromSeed(seedColor: kBlue),
  appBarTheme: const AppBarTheme(
    backgroundColor: kBg,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleSpacing: 0,
    foregroundColor: Colors.black,
    titleTextStyle: TextStyle(
      color: Colors.black,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  ),
);

BoxDecoration cardDecoration({
  Color color = Colors.white,
  double radius = 16,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: const [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ],
);
