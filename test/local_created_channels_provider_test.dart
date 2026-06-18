import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/local_created_channels_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('created channel cache is scoped by authenticated user', () async {
    SharedPreferences.setMockInitialValues({});
    final client = Client('LocalCreatedChannelsUserScopeTest')
      ..setUserId('@old:p2p-im.com');

    final ownerContainer = ProviderContainer(
      overrides: [
        matrixClientProvider.overrideWithValue(client),
        authStateNotifierProvider.overrideWith(_OwnerAuthNotifier.new),
      ],
    );
    addTearDown(ownerContainer.dispose);

    await ownerContainer.read(authStateNotifierProvider.future);
    await ownerContainer
        .read(localCreatedChannelsProvider.notifier)
        .cacheCreatedChannel(
          const AsChannel(
            channelId: 'owner-channel',
            roomId: '!owner:p2p-im.com',
            homeDomain: 'p2p-im.com',
            name: '旧账号频道',
          ),
          DateTime.utc(2026, 6, 18),
        );

    final nextUserContainer = ProviderContainer(
      overrides: [
        matrixClientProvider.overrideWithValue(client),
        authStateNotifierProvider.overrideWith(_NextUserAuthNotifier.new),
      ],
    );
    addTearDown(nextUserContainer.dispose);

    await nextUserContainer.read(authStateNotifierProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(nextUserContainer.read(localCreatedChannelsProvider), isEmpty);
  });

  test('created channel cache removes dissolved channel locally', () async {
    SharedPreferences.setMockInitialValues({});
    final client = Client('LocalCreatedChannelsRemoveTest')
      ..setUserId('@owner:p2p-im.com');
    final container = ProviderContainer(
      overrides: [
        matrixClientProvider.overrideWithValue(client),
        authStateNotifierProvider.overrideWith(_OwnerAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authStateNotifierProvider.future);
    final notifier = container.read(localCreatedChannelsProvider.notifier);
    await notifier.cacheCreatedChannel(
      const AsChannel(
        channelId: 'owner-channel',
        roomId: '!owner:p2p-im.com',
        homeDomain: 'p2p-im.com',
        name: '我创建的频道',
      ),
      DateTime.utc(2026, 6, 18),
    );

    expect(container.read(localCreatedChannelsProvider), hasLength(1));

    await notifier.removeChannel('owner-channel');

    expect(container.read(localCreatedChannelsProvider), isEmpty);
  });
}

class _OwnerAuthNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async {
    return const AuthState(
      isLoggedIn: true,
      userId: '@owner:p2p-im.com',
      homeserver: 'https://p2p-im.com',
    );
  }
}

class _NextUserAuthNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async {
    return const AuthState(
      isLoggedIn: true,
      userId: '@next:p2p-im.com',
      homeserver: 'https://p2p-im.com',
    );
  }
}
