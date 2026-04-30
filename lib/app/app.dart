import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ai_powered_coach_2026/core/theme/theme_mode_controller.dart';
import 'router.dart';

class CoachApp extends ConsumerWidget {
  const CoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    const primaryViolet = Color(0xFF6B5BFF);
    const accentBlue = Color(0xFF2EC5FF);
    const deepNavy = Color(0xFF090F2B);

    final lightColorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryViolet,
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF5B4BDB),
          secondary: const Color(0xFF7A6BFF),
          tertiary: accentBlue,
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF1A1D45),
          onPrimary: Colors.white,
          outline: const Color(0xFFCEC7FF),
        );
    final darkColorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryViolet,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF8F80FF),
          secondary: const Color(0xFFB18CFF),
          tertiary: accentBlue,
          surface: deepNavy,
          onSurface: const Color(0xFFECEFFF),
          onPrimary: const Color(0xFF161045),
          outline: const Color(0xFF4A4F87),
        );

    final lightBaseTheme = ThemeData(
      colorScheme: lightColorScheme,
      useMaterial3: true,
    );
    final darkBaseTheme = ThemeData(
      colorScheme: darkColorScheme,
      useMaterial3: true,
    );

    final lightTheme = lightBaseTheme.copyWith(
      scaffoldBackgroundColor: const Color(0xFFFCFBFF),
      textTheme: GoogleFonts.dmSansTextTheme(lightBaseTheme.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1E2253),
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F6FF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF5A5F8A),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: Color(0xFF9297BE)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD5D0FF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD5D0FF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6153E4), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDB5B6D), width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDB5B6D), width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: const Color(0xFF5B4BDB),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF5248C7),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2A2E63),
          side: const BorderSide(color: Color(0xFFC9C4FF)),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDCD6FF)),
        ),
      ),
    );

    final darkTheme = darkBaseTheme.copyWith(
      scaffoldBackgroundColor: deepNavy,
      textTheme: GoogleFonts.dmSansTextTheme(darkBaseTheme.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFF0F2FF),
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111A46),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFFBEC4EF),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: Color(0xFF8F95C3)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3D4688)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3D4688)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF8E7EFF), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF7285), width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF7285), width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: const Color(0xFF6D60F8),
          foregroundColor: const Color(0xFFEFF1FF),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFAAA0FF),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE7E9FF),
          side: const BorderSide(color: Color(0xFF525B9F)),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF101943),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF2E3B83)),
        ),
      ),
    );

    return MaterialApp.router(
      title: 'AI Powered Coach',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: router,
    );
  }
}
