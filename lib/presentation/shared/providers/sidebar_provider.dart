import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier managing desktop navigation sidebar expand/collapse state.
class SidebarNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Default to open on desktop displays
    return true;
  }

  void toggle() {
    state = !state;
  }

  void setExpanded(bool expanded) {
    state = expanded;
  }
}

/// Provider exposing whether the desktop sidebar is expanded.
final sidebarExpandedProvider =
    NotifierProvider<SidebarNotifier, bool>(SidebarNotifier.new);
