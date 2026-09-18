import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appProvider = AppProvider();
  await appProvider.init();

  runApp(
    ChangeNotifierProvider.value(
      value: appProvider,
      child: const MaidApp(),
    ),
  );
}

class MaidApp extends StatelessWidget {
  const MaidApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // ==========================================
    // ☀️ ULTRA-CLEAN GLASSMORPHIC LIGHT THEME
    // ==========================================
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4F46E5), // Modern Indigo Accent
        brightness: Brightness.light,
        surface: const Color(0xFFFFFFFF),
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        primary: const Color(0xFF4F46E5),
        onPrimary: Colors.white,
        secondary: const Color(0xFF0284C7),
        onSecondary: Colors.white,
        tertiary: const Color(0xFF7C3AED),
        onTertiary: Colors.white,
        outline: const Color(0xFFCBD5E1),
        shadow: const Color(0xFF64748B),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.82),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.95), width: 1.2),
        ),
        shadowColor: const Color(0xFF64748B).withValues(alpha: 0.10),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.95), width: 1.5),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Color(0xFF334155),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.88),
        elevation: 0,
        indicatorColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4F46E5),
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF4F46E5), size: 24);
          }
          return const IconThemeData(color: Color(0xFF64748B), size: 22);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.85),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8),
        ),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        hintStyle: TextStyle(color: const Color(0xFF94A3B8).withValues(alpha: 0.9), fontSize: 13),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Color(0xFF1E293B)),
        bodyMedium: TextStyle(color: Color(0xFF334155)),
        bodySmall: TextStyle(color: Color(0xFF64748B)),
      ),
      fontFamily: 'Roboto',
    );

    // ==========================================
    // 🌙 REFINED MIDNIGHT DARK GLASSMORPHIC THEME
    // ==========================================
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0F19),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF818CF8),
        brightness: Brightness.dark,
        surface: const Color(0xFF131B2E),
        surfaceContainerHighest: const Color(0xFF1E293B),
        primary: const Color(0xFF818CF8),
        onPrimary: const Color(0xFF0B0F19),
        secondary: const Color(0xFF38BDF8),
        onSecondary: const Color(0xFF0B0F19),
        tertiary: const Color(0xFFA78BFA),
        outline: const Color(0xFF334155),
        shadow: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF131B2E).withValues(alpha: 0.72),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF131B2E).withValues(alpha: 0.95),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Color(0xFFCBD5E1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF131B2E).withValues(alpha: 0.96),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: Color(0xFF1E293B), width: 1.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0B0F19).withValues(alpha: 0.85),
        elevation: 0,
        indicatorColor: const Color(0xFF818CF8).withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF818CF8),
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF818CF8), size: 24);
          }
          return const IconThemeData(color: Color(0xFF94A3B8), size: 22);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B).withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.8),
        ),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        hintStyle: TextStyle(color: const Color(0xFF64748B).withValues(alpha: 0.8), fontSize: 13),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Color(0xFFF1F5F9)),
        bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
        bodySmall: TextStyle(color: Color(0xFF94A3B8)),
      ),
      fontFamily: 'Roboto',
    );

    return MaterialApp(
      title: 'Maid Assistant',
      debugShowCheckedModeBanner: false,
      themeMode: provider.themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const SplashScreen(),
    );
  }
}
