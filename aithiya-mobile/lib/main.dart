import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/env.dart';
import 'core/services/logger_service.dart';
import 'core/widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _installGlobalErrorHandlers();

  try {
    await _bootstrap();
  } catch (error, stackTrace) {
    AppLogger.instance.fatal('App startup failed', error, stackTrace);
    runApp(_StartupFailureApp(message: _startupFailureMessage(error)));
  }
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.instance.fatal(
      'Flutter framework error',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.fatal('Unhandled async error', error, stack);
    return true;
  };
}

Future<void> _bootstrap() async {
  await dotenv.load(fileName: '.env');
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete =
      prefs.getBool(AuthGate.onboardingCompletePrefKey) ?? false;

  if (Env.supabaseUrl.isEmpty || Env.supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing SUPABASE_URL or SUPABASE_ANON_KEY. Copy .env.example to .env.',
    );
  }

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  runApp(
    AithiyaApp(prefs: prefs, onboardingComplete: onboardingComplete),
  );
}

String _startupFailureMessage(Object error) {
  final text = error.toString();
  if (text.contains('FileNotFoundError') ||
      text.contains('Unable to load asset')) {
    return '.env was not found. Copy .env.example to .env, then fill in SUPABASE_URL and SUPABASE_ANON_KEY.';
  }
  if (text.contains('EmptyEnvFileError')) {
    return '.env is empty. Copy .env.example to .env, then fill in SUPABASE_URL and SUPABASE_ANON_KEY.';
  }
  if (text.contains('SUPABASE_URL') || text.contains('SUPABASE_ANON_KEY')) {
    return 'Missing SUPABASE_URL or SUPABASE_ANON_KEY. Copy .env.example to .env and fill in your Supabase project values.';
  }
  return 'The app could not finish startup. Check flutter run logs for details.';
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF101418),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFFFB4AB),
                      size: 40,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Startup configuration error',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFFE1E3E6),
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
