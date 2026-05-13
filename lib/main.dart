import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';

const _supabaseUrl = 'https://srdkxmiakrpxggumguzc.supabase.co';
const _supabaseAnonKey = 'sb_publishable_wzt_skaBck9370ifCl5ceQ__y5SdWWF';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  FlutterNativeSplash.remove();
  runApp(const ToiletApp());
}

class ToiletApp extends StatelessWidget {
  const ToiletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '화장실 급해요',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme:
            GoogleFonts.notoSansKrTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme:
            GoogleFonts.notoSansKrTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
