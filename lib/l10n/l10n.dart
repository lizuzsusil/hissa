import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

/// Short-hand accessor for the active [AppLocalizations], e.g.
/// `context.l10n.expenses`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}