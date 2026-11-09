import 'package:flutter/material.dart';

/// Design-system v1.1 quantified tokens (§3 §4 §6).
/// Spacing is a multiple of 4; radii step 20/28/8; numbers in lists are
/// tabular.
abstract final class AppSpace {
  static const double screen = 16; // page content left/right
  static const double group = 24; // between groups
  static const double groupToCard = 8; // group label → card
  static const double rowSingle = 52; // single-line row height
  static const double rowDouble = 64; // two-line row height
  static const double readingWidth = 720; // max centered content column
}

abstract final class AppRadius {
  static const double card = 20;
  static const double sheet = 28;
  static const double tag = 8;
  static const double pill = 99;
}

/// Motion per Apple §8: springs damping 1.0 / response .3-.4; press
/// 0.97 on tap-down; list entrance fade+8px, stagger ≤30ms, first 8.
abstract final class AppMotion {
  static const Duration press = Duration(milliseconds: 110);
  static const Duration entrance = Duration(milliseconds: 240);
  static const Duration breathe = Duration(milliseconds: 1200);
}

/// Exact palette from design-system §2.2 (light) + dark counterparts.
abstract final class ZColors {
  // light
  static const misty = Color(0xFF3D6B9E);
  static const lightBg = Color(0xFFEFF1F4);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightPc = Color(0xFFE4EAF1);
  static const lightOnPc = Color(0xFF2B4A6E);
  static const lightOutline = Color(0xFFE1E3E3);
  static const success = Color(0xFF2E7D43);
  static const successText = Color(0xFF14662E);
  static const danger = Color(0xFFB3261E);
  static const ink = Color(0xFF26282E); // filter-chip selected fill
  static const diffAdd = Color(0xFF3E9E5C);
  static const diffDel = Color(0xFFD25454);

  // dark
  static const darkBg = Color(0xFF11141A);
  static const darkSurface = Color(0xFF1A1E26);
  static const darkPrimary = Color(0xFF8FB3D9);
  static const darkOnPrimary = Color(0xFF0E1420);
  static const darkPc = Color(0xFF2B4A6E);
  static const darkOnPc = Color(0xFFD9E4F0);
  static const darkOutline = Color(0xFF2A2F3A);
  static const darkSuccess = Color(0xFF7BD88F);

  static Color bg(Brightness b) => b == Brightness.dark ? darkBg : lightBg;
  static Color surface(Brightness b) =>
      b == Brightness.dark ? darkSurface : lightSurface;
  static Color pc(Brightness b) => b == Brightness.dark ? darkPc : lightPc;
  static Color onPc(Brightness b) => b == Brightness.dark ? darkOnPc : lightOnPc;
  static Color outline(Brightness b) =>
      b == Brightness.dark ? darkOutline : lightOutline;
  static Color okDot(Brightness b) =>
      b == Brightness.dark ? darkSuccess : success;
}

/// Type-scale tracking (Apple §15): tight large titles, relaxed micro
/// labels — never one value everywhere.
abstract final class ZTrack {
  static const double display = -0.02;
  static const double title = -0.01;
  static const double body = 0.0;
  static const double label = 0.08;
}

const tabularNumbers = [FontFeature.tabularFigures()];
