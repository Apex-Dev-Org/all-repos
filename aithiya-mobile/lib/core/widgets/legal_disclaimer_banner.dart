import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Persistent legal disclaimer required for the product.
class LegalDisclaimerBanner extends StatelessWidget {
  const LegalDisclaimerBanner({super.key, this.compact = false});

  /// Shorter one-line variant for dense layouts (e.g. above the chat input).
  final bool compact;

  /// English fallback when localizations are unavailable (e.g. tests).
  static const String fullText =
      'This tool provides legal information for educational purposes and does '
      'not constitute official legal advice. Always consult a qualified Sri '
      'Lankan attorney.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy =
        AppLocalizations.of(context)?.legalDisclaimerFull ?? fullText;
    return Material(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 8 : 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.gavel_outlined,
              size: compact ? 18 : 22,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                copy,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
