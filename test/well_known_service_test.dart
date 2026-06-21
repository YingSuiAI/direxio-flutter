import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/local_endpoint_resolver.dart';
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

  test('discover owner accepts the Matrix client HTTP wrapper', () async {
    final client = Client(
      'WellKnownMatrixHttpWrapperTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"matrix_user_id":"@alice:portal.local","display_name":"Alice Chen"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final service = WellKnownService(httpClient: client.httpClient);

    final result = await service.discoverOwner('alice.portal.local');

    expect(result.availability, PortalAvailability.online);
    expect(result.owner?.matrixUserId, '@alice:portal.local');
    expect(result.owner?.displayName, 'Alice Chen');
  });

  test('discover owner uses configured local endpoint mapping', () async {
    final requestedUris = <Uri>[];
    final service = WellKnownService(
      localEndpointResolver:
          LocalEndpointResolver.parse('node-b.test:8448=127.0.0.1:28008'),
      httpClient: MockClient((request) async {
        requestedUris.add(request.url);
        return http.Response(
          '{"matrix_user_id":"@owner:node-b.test:8448","display_name":"Owner B"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await service.discoverOwner('node-b.test:8448');

    expect(result.availability, PortalAvailability.online);
    expect(result.owner?.matrixUserId, '@owner:node-b.test:8448');
    expect(requestedUris, [
      Uri.parse('http://127.0.0.1:28008/.well-known/portal/owner.json'),
    ]);
  });

  test('discover owner maps configured federation port to local HTTP port',
      () async {
    final requestedUris = <Uri>[];
    final service = WellKnownService(
      localEndpointResolver: LocalEndpointResolver.parse(
        'container.internal:38448=127.0.0.1:38008',
      ),
      httpClient: MockClient((request) async {
        requestedUris.add(request.url);
        return http.Response(
          '{"matrix_user_id":"@owner:container.internal:38448","display_name":"Owner C"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await service.discoverOwner('container.internal:38448');

    expect(result.availability, PortalAvailability.online);
    expect(result.owner?.matrixUserId, '@owner:container.internal:38448');
    expect(requestedUris, [
      Uri.parse('http://127.0.0.1:38008/.well-known/portal/owner.json'),
    ]);
  });
}
