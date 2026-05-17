import 'package:flutter/material.dart';

import '../../../core/widgets/auth_gate.dart';
import '../../../shared/widgets/background_scaffold.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onboardingComplete});

  final bool onboardingComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AuthGate(onboardingComplete: widget.onboardingComplete),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final logoH = (mq.height * 0.18).clamp(96.0, 160.0);

    return BackgroundScaffold(
      body: Center(
        child: Image.asset(
          'assets/images/aithiya_logo.png',
          height: logoH,
        ),
      ),
    );
  }
}
