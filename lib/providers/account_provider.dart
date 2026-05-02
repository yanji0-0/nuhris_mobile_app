import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client_provider.dart';

final accountProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  return await api.getAccount();
});

final profilePhotoProvider = FutureProvider.autoDispose<String?>((ref) async {
  final api = ref.read(apiClientProvider);
  return await api.getProfilePhotoUrl();
});
