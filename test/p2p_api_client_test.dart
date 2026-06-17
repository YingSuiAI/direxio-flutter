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
      baseUri: Uri.parse('http://localhost:8888'),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/im/channel/list');
        expect(request.url.queryParameters['page'], '1');
        expect(request.url.queryParameters['pageSize'], '20');
        expect(request.url.queryParameters['status'], '1');
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

  test('listPublicTags parses enabled tag response wrapper', () async {
    final client = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/im/tag/public/list');
        return _apiResponse({
          'list': [
            {
              'ID': 1,
              'name': '技术',
              'color': '#67C23A',
              'status': 1,
              'sort': 2,
            },
          ],
        });
      }),
    );

    final tags = await client.listPublicTags();

    expect(tags.single.id, 1);
    expect(tags.single.name, '技术');
    expect(tags.single.color, '#67C23A');
    expect(tags.single.sort, 2);
  });

  test('listChannelPage parses pagination and public channel fields', () async {
    final client = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/im/channel/list');
        expect(request.url.queryParameters['status'], '2');
        expect(request.url.queryParameters['ownerDomain'], 'owner');
        expect(request.url.queryParameters['desc'], 'false');
        return _apiResponse({
          'list': [
            {
              'ID': 1,
              'channelDomain': 'channel.example.com',
              'room_id': '!room:owner.example.com',
              'ownerDomain': 'owner.example.com',
              'intro': '频道简介',
              'channelDetail': {
                'channel_id': 'ch_public',
                'room_id': '!room:owner.example.com',
                'home_domain': 'owner.example.com',
                'name': '产品公告',
                'description': '只发布重要产品更新',
                'avatar_url': 'mxc://example.com/avatar',
                'visibility': 'public',
                'join_policy': 'open',
                'comments_enabled': true,
                'tags': ['技术', '美术'],
                'member_count': 1,
                'status': 'active',
              },
              'tag': {'ID': 1, 'name': '技术', 'color': '#67C23A'},
              'status': 1,
              'reportCount': 0,
              'joinCount': 2,
              'lastJoinTime': '2026-06-16T12:00:00+08:00',
            },
          ],
          'total': 1,
          'page': 1,
          'pageSize': 10,
        });
      }),
    );

    final page = await client.listChannelPage(
      status: 2,
      ownerDomain: 'owner',
    );

    expect(page.total, 1);
    expect(page.page, 1);
    expect(page.pageSize, 10);
    expect(page.channels.single.channelId, 'ch_public');
    expect(page.channels.single.roomId, '!room:owner.example.com');
    expect(page.channels.single.homeDomain, 'owner.example.com');
    expect(page.channels.single.name, '产品公告');
    expect(page.channels.single.description, '只发布重要产品更新');
    expect(page.channels.single.avatarUrl, 'mxc://example.com/avatar');
    expect(page.channels.single.memberCount, 1);
    expect(page.channels.single.tags, ['技术', '美术']);
  });

  test('joinChannel posts public channel domain and room id', () async {
    final client = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/im/channel/join');
        expect(jsonDecode(request.body), {
          'channelDomain': 'channel.example.com',
          'room_id': '!room:owner.example.com',
          'tagId': 1,
        });
        return _apiResponse({});
      }),
    );

    await client.joinChannel(
      channelDomain: ' channel.example.com ',
      roomId: ' !room:owner.example.com ',
      tagId: 1,
    );
  });

  test('getReportCount calls public report count endpoint', () async {
    final client = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/im/report/count');
        expect(
            request.url.queryParameters['reportedDomain'], 'bad.example.com');
        expect(request.url.queryParameters['targetType'], '3');
        return _apiResponse({'count': 3});
      }),
    );

    final count = await client.getReportCount(
      reportedDomain: ' bad.example.com ',
      targetType: 3,
    );

    expect(count, 3);
  });

  test('submitReport sends JSON body', () async {
    final client = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/im/report');
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {
          'reporterDomain': 'alice.example.com',
          'reportedDomain': 'bad-user.example.com',
          'targetType': 1,
          'reason': '违规内容',
          'images': ['uploads/file/im-public/20260616/demo.png'],
        });
        return _apiResponse({'ID': 7});
      }),
    );

    final result = await client.submitReport(
      reporterDomain: ' alice.example.com ',
      reportedDomain: ' bad-user.example.com ',
      reason: ' 违规内容 ',
      images: const ['uploads/file/im-public/20260616/demo.png'],
    );

    expect(result['ID'], 7);
  });

  test('submitReportMultipart sends fields, image urls, and files', () async {
    final client = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
      httpClient: _InspectingClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/im/report');
        expect(request, isA<http.MultipartRequest>());
        final multipart = request as http.MultipartRequest;
        expect(multipart.fields['reporterDomain'], 'alice.example.com');
        expect(multipart.fields['reportedDomain'], 'bad-user.example.com');
        expect(multipart.fields['targetType'], '2');
        expect(multipart.fields['reason'], '违规内容');
        expect(
          jsonDecode(multipart.fields['images']!),
          ['uploads/file/im-public/20260616/a.png', 'uploads/b.png'],
        );
        expect(multipart.files.single.field, 'files');
        expect(multipart.files.single.filename, 'evidence.jpg');
        return _streamedApiResponse({'ID': 8});
      }),
    );

    final result = await client.submitReportMultipart(
      reporterDomain: 'alice.example.com',
      reportedDomain: 'bad-user.example.com',
      targetType: 2,
      reason: '违规内容',
      images: const [
        'uploads/file/im-public/20260616/a.png',
        'uploads/b.png',
      ],
      files: const [
        ImPublicImageUploadPart(bytes: [1, 2, 3], fileName: 'evidence.jpg'),
      ],
    );

    expect(result['ID'], 8);
  });

  test('uploadImage sends multipart file and parses file metadata', () async {
    late http.BaseRequest seen;
    final client = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
      httpClient: _InspectingClient((request) async {
        seen = request;
        expect(request.method, 'POST');
        expect(request.url.path, '/im/image/upload');
        expect(request, isA<http.MultipartRequest>());
        final multipart = request as http.MultipartRequest;
        expect(multipart.files.single.field, 'file');
        expect(multipart.files.single.filename, 'avatar.png');
        return _streamedApiResponse({
          'file': {
            'url': 'uploads/file/im-public/20260616/avatar.png',
            'fileName': 'avatar.png',
            'size': 3,
          },
        });
      }),
    );

    final file = await client.uploadImage(
      bytes: const [1, 2, 3],
      fileName: 'avatar.png',
    );

    expect(seen, isA<http.MultipartRequest>());
    expect(file.url, 'uploads/file/im-public/20260616/avatar.png');
    expect(file.fileName, 'avatar.png');
    expect(file.size, 3);
  });

  test('business code errors throw P2pApiException', () async {
    final client = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode({'code': 1001, 'msg': 'bad request', 'data': {}}),
          200,
        );
      }),
    );

    await expectLater(
      client.listPublicTags(),
      throwsA(isA<P2pApiException>().having(
        (error) => error.message,
        'message',
        'bad request',
      )),
    );
  });

  test('reportBiEvent sends nonce and MD5 signature over raw body', () async {
    const secret = 'secret';
    late http.Request seen;
    final client = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
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
    expect(
      seen.body,
      '{"deviceNo":"device-1","eventType":"launch","payload":{"appVersion":"1.0.0"},"phoneModel":"phone 16","reportTime":123}',
    );
  });

  test('canonicalJson matches documented BI signature vector', () {
    const secret = 'bi-secret';
    const nonce = 'nonce-001';
    final body = canonicalJson({
      'eventType': 'login',
      'deviceNo': 'device-001',
      'reportTime': 1780934400000,
    });
    final signature = md5.convert(
      utf8.encode('$secret\n$nonce\n$body'),
    );

    expect(
      body,
      '{"deviceNo":"device-001","eventType":"login","reportTime":1780934400000}',
    );
    expect(signature.toString(), 'da4bdf612502b1aaf00fe0dae27b31d7');
  });

  test('canonicalJson recursively sorts object keys and preserves arrays', () {
    final body = canonicalJson({
      'z': 1,
      'a': {
        'b': true,
        'a': [
          {'y': 2, 'x': 1},
        ],
      },
    });

    expect(body, '{"a":{"a":[{"x":1,"y":2}],"b":true},"z":1}');
  });

  test('disabled BI analytics does not send network requests', () async {
    final client = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
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

http.Response _apiResponse(Map<String, dynamic> data) {
  return http.Response.bytes(
    utf8.encode(jsonEncode({
      'code': 0,
      'data': data,
      'msg': 'success',
    })),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

http.StreamedResponse _streamedApiResponse(Map<String, dynamic> data) {
  final bytes = utf8.encode(jsonEncode({
    'code': 0,
    'data': data,
    'msg': 'success',
  }));
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class _InspectingClient extends http.BaseClient {
  _InspectingClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}
