import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_app/data/well_known_service.dart';

void main() {
  test('portal owner parses avatar url', () {
    final owner = PortalOwner.fromJson(const {
      'matrix_user_id': '@alice:portal.local',
      'display_name': 'Alice Chen',
      'avatar_url': 'mxc://portal.local/avatar',
    });

    expect(owner.matrixUserId, '@alice:portal.local');
    expect(owner.displayName, 'Alice Chen');
    expect(owner.avatarUrl, 'mxc://portal.local/avatar');
  });

  test('portal owner parses alternate profile field names', () {
    final owner = PortalOwner.fromJson(const {
      'mxid': '@alice:portal.local',
      'name': 'Alice Chen',
      'avatar': 'https://cdn.example.com/alice.png',
    });

    expect(owner.matrixUserId, '@alice:portal.local');
    expect(owner.displayName, 'Alice Chen');
    expect(owner.avatarUrl, 'https://cdn.example.com/alice.png');
  });

  test('discover owner returns online for valid owner response', () async {
    final service = WellKnownService(
      httpClient: MockClient((request) async {
        return http.Response(
          '{"matrix_user_id":"@alice:portal.local","display_name":"Alice Chen","avatar_url":"https://cdn.example.com/alice.png"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await service.discoverOwner('alice.portal.local');

    expect(result.availability, PortalAvailability.online);
    expect(result.owner?.matrixUserId, '@alice:portal.local');
    expect(result.owner?.displayName, 'Alice Chen');
    expect(result.owner?.avatarUrl, 'https://cdn.example.com/alice.png');
  });
}
