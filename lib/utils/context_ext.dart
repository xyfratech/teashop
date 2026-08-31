import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'formatters.dart';

extension AppContext on BuildContext {
  /// Currency formatter using the shop's configured symbol.
  Money get money => Money(read<AppState>().currency);
}
