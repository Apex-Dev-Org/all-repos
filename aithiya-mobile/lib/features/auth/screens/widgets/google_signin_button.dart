import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();
    return OutlinedButton.icon(
      onPressed: auth.isBusy
          ? null
          : () async {
              await context.read<AuthProvider>().signInWithGoogle();
              if (!context.mounted) return;
              final msg = context.read<AuthProvider>().errorMessage;
              if (msg != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        side: const BorderSide(color: Colors.black12),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      icon: auth.isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
            )
          : const Icon(Icons.g_mobiledata, color: Colors.blue, size: 28), // fallback styling
      label: Text(
        l10n.continueWithGoogle,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
