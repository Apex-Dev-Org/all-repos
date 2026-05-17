import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/theme.dart';
import 'core/api/api_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/onboarding/screens/splash_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/chat/data/remote_chat_repository.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/subscription/providers/subscription_provider.dart';
import 'l10n/app_localizations.dart';
import 'shared/providers/locale_provider.dart';

/// Root widget: theme, providers, and auth routing.
class AithiyaApp extends StatelessWidget {
  const AithiyaApp({
    super.key,
    required this.prefs,
    required this.onboardingComplete,
  });

  final SharedPreferences prefs;
  final bool onboardingComplete;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
        Provider<AuthRepository>(
          create: (_) => AuthRepository(Supabase.instance.client),
        ),
        Provider<ApiClient>(
          create: (_) => ApiClient(
            getAccessToken: () async =>
                Supabase.instance.client.auth.currentSession?.accessToken,
          ),
          dispose: (_, api) => api.close(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => AuthProvider(
            repository: ctx.read<AuthRepository>(),
            apiClient: ctx.read<ApiClient>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              SubscriptionProvider(prefs, apiClient: ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ChatProvider(
            repository: RemoteChatRepository(ctx.read<ApiClient>()),
          ),
        ),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProv, _) {
          return MaterialApp(
            onGenerateTitle: (ctx) =>
                AppLocalizations.of(ctx)?.appTitle ?? 'Aithiya',
            locale: localeProv.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            // en/si UIs are laid out LTR; locale-based RTL would pin narrow
            // scroll content to the visual right and leave a white strip on the left.
            builder: (context, child) => Directionality(
              textDirection: TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            ),
            home: SplashScreen(onboardingComplete: onboardingComplete),
          );
        },
      ),
    );
  }
}
