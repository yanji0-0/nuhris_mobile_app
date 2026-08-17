import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_refresh_provider.dart';
import 'api_client_provider.dart';

final dashboardProvider =
    AsyncNotifierProvider<DashboardController, Map<String, dynamic>?>(
      DashboardController.new,
    );

class DashboardController extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    ref.watch(appRefreshProvider);
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<Map<String, dynamic>?> _load() async {
    final api = ref.read(apiClientProvider);
    final dashboard = await api.getDashboard();
    final notifications = await api.getNotifications();
    return {'dashboard': dashboard, 'notifications': notifications};
  }
}
