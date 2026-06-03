import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_call_session_store.dart';
import '../call/voice_call_controller.dart';
import 'as_client_provider.dart';
import 'as_call_session_store_provider.dart';

final voiceCallControllerProvider = Provider<VoiceCallController>((ref) {
  final asClient = ref.watch(asClientProvider);
  final controller = MatrixVoiceCallController(
    asClient: asClient,
    asCallSessionStore: DeferredAsCallSessionStore(
      () => ref.read(asCallSessionStoreProvider.future),
    ),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
