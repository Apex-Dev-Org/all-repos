import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/onboarding/screens/welcome_screen.dart';
import '../../shared/widgets/background_scaffold.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.onboardingComplete});

  /// Boolean pref that flips to `true` once the user finishes the welcome
  /// flow. Kept separate from the locale pref so that programmatic locale
  /// changes (or pre-seeded values on reinstall) never silently skip
  /// onboarding.
  static const onboardingCompletePrefKey = 'onboarding_complete_v1';

  final bool onboardingComplete;

  @override
  Widget build(BuildContext context) {
    if (!onboardingComplete) {
      return const WelcomeScreen();
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.unknown) {
          return const BackgroundScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.status == AuthStatus.authenticated) {
          return const ChatScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
