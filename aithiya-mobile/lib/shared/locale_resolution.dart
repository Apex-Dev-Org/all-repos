import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'providers/locale_provider.dart';

/// Effective `en` / `si` for services that are not under a [Localizations] scope.
String effectiveAppLanguageCode(BuildContext context) {
  final pref = context.read<LocaleProvider>().preference;
  if (pref != 'system') return pref;
  final code = Localizations.localeOf(context).languageCode;
  if (code == 'en' || code == 'si') return code;
  return 'en';
}
