import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_app/data/bi_analytics_service.dart';
import 'package:portal_app/data/p2p_api_client.dart';

void main() {
  test('listChannels calls configured P2P channel endpoint', () async {
    final client = P2pApiClient(
      baseUri: Uri.parse('http://192.168.1.104:8888'),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/im/channel/list');
        expect(request.url.queryParameters['page'], '1');
        expect(request.url.queryParameters['pageSize'], '20');
        expect(request.url.queryParameters['keyword'], 'channel');
        expect(request.url.queryParameters['sortBy'], 'createdAt');
        expect(request.url.queryParameters['desc'], 'true');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'data': {
              'list': [
                {
                  'channelDomain': 'channel.example.com',
                  'ownerDomain': 'owner.example.com',
                  'name': '产品公告',
                  'description': '只发布重要产品更新',
                  'createdAt': '2026-06-01T12:00:00Z',
                },
              ],
            },
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final channels =
        await client.listChannels(keyword: 'channel', pageSize: 20);

    expect(channels.single.channelId, 'channel.example.com');
    expect(channels.single.homeDomain, 'owner.example.com');
    expect(channels.single.name, '产品公告');
  });

  test('reportBiEvent sends nonce and MD5 signature over raw body', () async {
    const secret = 'secret';
    late http.Request seen;
    final client = P2pApiClient(
      baseUri: Uri.parse('http://192.168.1.104:8888'),
      biSecret: secret,
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      }),
    );

    await client.reportBiEvent(
      deviceNo: 'device-1',
      eventType: 'launch',
      phoneModel: 'phone 16',
      reportTime: 123,
      payload: const {'appVersion': '1.0.0'},
    );

    expect(seen.method, 'POST');
    expect(seen.url.path, '/bi/events/report');
    final nonce = seen.headers['X-BI-Nonce'];
    expect(nonce, isNotEmpty);
    final expected = md5.convert(
      utf8.encode('$secret\n$nonce\n${seen.body}'),
    );
    expect(seen.headers['X-BI-Signature'], expected.toString());
    expect(jsonDecode(seen.body), {
      'deviceNo': 'device-1',
      'eventType': 'launch',
      'payload': {'appVersion': '1.0.0'},
      'phoneModel': 'phone 16',
      'reportTime': 123,
    });
  });

  test('disabled BI analytics does not send network requests', () async {
    final client = P2pApiClient(
      baseUri: Uri.parse('http://192.168.1.104:8888'),
      httpClient: MockClient((_) async {
        fail('BI should not send requests when disabled');
      }),
    );
    final analytics = BiAnalyticsService(apiClient: client, enabled: false);

    await analytics.reportLogin(
      homeserver: 'https://im.jkmf.top',
      userId: '@owner:im.jkmf.top',
    );
  });
}
