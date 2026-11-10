import 'package:flutter/material.dart';

/// Design tokens extracted from dsh-Go source code (AGPL, design-reference
/// only — see docs/design/dsh-source-spec.md for the full audit).
abstract final class AppSpace {
  static const double screen = 16;
  static const double group = 24;
  static const double groupToCard = 8;
  static const double rowSingle = 52;
  static const double rowDouble = 64;
  static const double readingWidth = 720;
  // dsh live: drawer = 31% screen width, flush-left full-height
  static const double drawerWidthFraction = 0.31;
  static const double drawerMinWidth = 280;
  static const double drawerMaxWidth = 420;
}

abstract final class AppRadius {
  static const double card = 20;
  static const double sheet = 28;
  static const double composer = 28;  // dsh: AppShape.radiusXl
  static const double tag = 8;
  static const double pill = 99;
}

/// Key geometry (dsh composer.dart):
/// keySize=36, gap=6, outer pad LTRB(6,6,6,6), single-line h=48,
/// font 15/1.45.
abstract final class AppKeys {
  static const double size = 36;
  static const double gap = 6;
  static const double outerPad = 6;
  static const double textPadNoLeading = 18;
  static const double sendIcon = 20;
  static const double stopIcon = 18;
  static const double barHeight = 56;
  static const double roundKeySize = 44;
  static const double roundKeyIcon = 22;
}

abstract final class AppMotion {
  static const Duration press = Duration(milliseconds: 110);
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration emphasized = Duration(milliseconds: 350);
  static const Duration entrance = Duration(milliseconds: 240);
  static const Duration breathe = Duration(milliseconds: 1200);
}

abstract final class ZColors {
  // light
  static const misty = Color(0xFF3D6B9E);
  static const lightBg = Color(0xFFEFF1F4);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightPc = Color(0xFFD9E9E9);
  static const lightOnPc = Color(0xFF0F3D42);
  static const lightOutline = Color(0xFFE1E3E3);
  static const success = Color(0xFF2E7D43);
  static const successText = Color(0xFF14662E);
  static const danger = Color(0xFFB3261E);
  static const ink = Color(0xFF26282E);
  static const diffAdd = Color(0xFF3E9E5C);
  static const diffDel = Color(0xFFD25454);

  // dsh-Go measured page gradient (135°) + single accent
  static const bgGradTop = Color(0xFFD6E8F2);
  static const bgGradBottom = Color(0xFFF7F9FA);
  static const accent = Color(0xFF1B4A5F); // dsh live: deep navy-teal
  static const greenDot = Color(0xFF3EC173);
  static const warnSurface = Color(0xFFFDECEA);
  static const drawerBg = Color(0xFFF0F4F8);
  static const chipUnselBg = Color(0xFFE2EAF0);
  static const sessionHighlight = Color(0xFFDAE6EE);
  static const bodyText = Color(0xFF1E2A32);
  static const metaText = Color(0xFF61727C);
  static const warnText = Color(0xFF9A3324);

  // dark
  static const darkBg = Color(0xFF11141A);
  static const darkSurface = Color(0xFF1A1E26);
  static const darkPrimary = Color(0xFF8FC6CC);
  static const darkOnPrimary = Color(0xFF06272B);
  static const darkPc = Color(0xFF124A50);
  static const darkOnPc = Color(0xFFCDE9EC);
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
      b == Brightness.dark ? darkSuccess : greenDot;

  /// Session row selected bg (dsh: primary@0.09 light / @0.18 dark).
  static Color sessionSelected(Brightness b, Color primary) =>
      primary.withValues(alpha: b == Brightness.dark ? 0.18 : 0.09);

  /// Filter chip unselected bg (dsh: onSurface@5% light / white@7% dark).
  static Color chipUnselected(Brightness b, Color onSurface) =>
      b == Brightness.dark
          ? Colors.white.withValues(alpha: 0.07)
          : onSurface.withValues(alpha: 0.05);
}

abstract final class ZTrack {
  static const double display = -0.02;
  static const double title = -0.01;
  static const double body = 0.0;
  static const double label = 0.08;
}

const tabularNumbers = [FontFeature.tabularFigures()];
