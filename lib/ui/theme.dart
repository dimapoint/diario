import 'package:flutter/material.dart';

const _seed = Color(0xFFB4532A); // terracota

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 1,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Serif de lectura para lo que escribís (texto libre y destacados).
const diaryFontFamily = 'Literata';

extension DiaryText on BuildContext {
  TextStyle get diaryBody => Theme.of(this).textTheme.bodyLarge!.copyWith(
        fontFamily: diaryFontFamily,
        fontSize: 17,
        height: 1.55,
      );

  TextStyle get diaryHighlight => Theme.of(this).textTheme.titleMedium!.copyWith(
        fontFamily: diaryFontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 1.35,
      );
}

/// Ancho a partir del cual se usan dos paneles.
const wideBreakpoint = 840.0;

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideBreakpoint;
