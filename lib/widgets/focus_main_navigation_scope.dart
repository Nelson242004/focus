import 'package:flutter/widgets.dart';

typedef FocusTabOpener = void Function(int index);

class FocusMainNavigationScope extends InheritedWidget {
  final FocusTabOpener openTab;

  const FocusMainNavigationScope({
    super.key,
    required this.openTab,
    required super.child,
  });

  static FocusTabOpener of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FocusMainNavigationScope>();
    assert(scope != null, 'FocusMainNavigationScope not found in context');
    return scope!.openTab;
  }

  static FocusTabOpener? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FocusMainNavigationScope>()
        ?.openTab;
  }

  @override
  bool updateShouldNotify(FocusMainNavigationScope oldWidget) {
    return openTab != oldWidget.openTab;
  }
}
