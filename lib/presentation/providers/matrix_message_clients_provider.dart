import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/matrix_message_search_client.dart';
import '../../data/matrix_message_visibility_client.dart';
import 'auth_provider.dart';

final matrixMessageVisibilityClientProvider =
    Provider<MatrixMessageVisibilityClient>((ref) {
  return MatrixMessageVisibilityClient(ref.watch(matrixClientProvider));
});

final matrixMessageSearchClientProvider =
    Provider<MatrixMessageSearchClient>((ref) {
  return MatrixMessageSearchClient(ref.watch(matrixClientProvider));
});
