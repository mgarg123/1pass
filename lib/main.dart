import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/storage/hive_setup.dart';
import 'core/config/storage_mode.dart';
import 'features/auth/ui/auth_gate.dart';
import 'core/storage/autofill_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive (must be first — config is stored here)
  await HiveSetup.init();
  
  // Load environment variables (may contain Supabase credentials)
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env file may not exist in local-only mode — that's fine
  }

  // Only initialize Supabase if the user has chosen cloud sync mode
  final modeConfig = StorageModeConfig.load();
  if (modeConfig == null || modeConfig.isCloud) {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );
    }
  }

  // Process any pending autofill saves queued by SaveAuthActivity
  await AutofillCacheService.processPendingSaves();

  // Ensure autofill cache is up to date on startup
  await AutofillCacheService.writeCache();

  runApp(
    const ProviderScope(
      child: OnePassApp(),
    ),
  );
}


class OnePassApp extends StatelessWidget {
  const OnePassApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Next-Gen OLED Black & Neon Violet theme
    final baseTheme = ThemeData.dark(useMaterial3: true);
    final primaryColor = const Color(0xFF8B5CF6); // Neon Violet
    final backgroundColor = Colors.black; // True OLED Black
    final surfaceColor = const Color(0xFF111111); // Very dark charcoal
    final inputColor = const Color(0xFF1A1A1A); // Slightly lighter for inputs

    return MaterialApp(
      title: '1Pass',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          surface: surfaceColor,
          background: backgroundColor,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
          displayLarge: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          displayMedium: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          titleLarge: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
          bodyLarge: GoogleFonts.inter(color: Colors.white70),
          bodyMedium: GoogleFonts.inter(color: Colors.white70),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: backgroundColor,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF222222), width: 1),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          labelStyle: const TextStyle(color: Colors.white54),
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIconColor: Colors.white54,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: primaryColor.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), // Pill-shaped
            textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
