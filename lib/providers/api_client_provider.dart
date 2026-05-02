import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/api_client_contract.dart';

final apiClientProvider = Provider<AppApiClient>((ref) => ApiClient.instance);
