import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRefreshProvider = NotifierProvider<AppRefreshController, int>(
  AppRefreshController.new,
);

class AppRefreshController extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() {
    state = state + 1;
  }
}
