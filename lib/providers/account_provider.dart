import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_refresh_provider.dart';
import 'api_client_provider.dart';

final accountProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(appRefreshProvider);
  final api = ref.read(apiClientProvider);
  return await api.getAccount();
});

final profilePhotoProvider = FutureProvider.autoDispose<String?>((ref) async {
  ref.watch(appRefreshProvider);
  final api = ref.read(apiClientProvider);
  return await api.getProfilePhotoUrl();
});
