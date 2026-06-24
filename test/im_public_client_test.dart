import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:portal_app/data/bi_analytics_service.dart';
import 'package:portal_app/data/im_public_config.dart';
import 'package:portal_app/data/im_public_client.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Direxio',
      packageName: 'com.direxio.ai',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  test(
      'listChannels sends signed name query and reads IM public channel envelope',
      () async {
    late http.Request seen;
    final client = ImPublicClient(
      baseUri: Uri.parse('https://admin.example.com'),
      secret: 'bi-secret',
      httpClient: MockClient((request) async {
        seen = request;
        expect(request.method, 'GET');
        expect(request.url.path, '/im/channel/list');
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['pageSize'], '20');
        expect(request.url.queryParameters['name'], '产品');
        expect(request.url.queryParameters.containsKey('keyword'), isFalse);
        expect(request.url.queryParameters.containsKey('status'), isFalse);
        return _json({
          'code': 0,
          'data': {
            'list': [
              {
                'ID': 1,
                'channelDomain': 'https://im1.direxio.ai',
                'channel_id': 'ch_1',
                'room_id': '!room:im1.direxio.ai',
                'name': 'Product Updates',
                'description': 'Release notes',
                'avatar_url': 'mxc://example.com/avatar',
                'join_policy': 'open',
                'channel_type': 'chat',
                'member_count': 1,
                'status': 1,
                'failureCount': 0,
                'reportCount': 0,
                'joinCount': 2,
                'lastJoinTime': '2026-06-16T12:00:00+08:00',
              },
            ],
            'total': 1,
            'page': 2,
            'pageSize': 20,
          },
          'msg': 'success',
        });
      }),
    );

    final page = await client.listChannels(
      page: 2,
      pageSize: 20,
      name: '产品',
    );

    final nonce = seen.headers['X-BI-Nonce'];
    expect(nonce, isNotNull);
    expect(
      seen.headers['X-BI-Signature'],
      buildImPublicSignature(
        secret: 'bi-secret',
        nonce: nonce!,
        canonicalBody: canonicalImPublicJson({
          'desc': 'false',
          'name': '产品',
          'page': '2',
          'pageSize': '20',
          'sortBy': 'createdAt',
        }),
      ),
    );
    expect(page.total, 1);
    expect(page.items.single.channel.channelId, 'ch_1');
    expect(page.items.single.channel.name, 'Product Updates');
    expect(page.items.single.channel.description, 'Release notes');
  });

  test('joinChannelDirectory posts signed documented body', () async {
    late http.Request seen;
    final client = ImPublicClient(
      baseUri: Uri.parse('https://admin.example.com'),
      secret: 'bi-secret',
      httpClient: MockClient((request) async {
        seen = request;
        expect(request.method, 'POST');
        expect(request.url.path, '/im/channel/join');
        expect(jsonDecode(request.body), {
          'channelDomain': 'https://im1.direxio.ai',
          'room_id': '!room:im1.direxio.ai',
        });
        return _json({'code': 0, 'data': {}, 'msg': 'success'});
      }),
    );

    await client.joinChannelDirectory(
      channelDomain: 'https://im1.direxio.ai',
      roomId: '!room:im1.direxio.ai',
    );

    final nonce = seen.headers['X-BI-Nonce'];
    expect(nonce, isNotNull);
    expect(
      seen.headers['X-BI-Signature'],
      buildImPublicSignature(
        secret: 'bi-secret',
        nonce: nonce!,
        canonicalBody: canonicalImPublicJson({
          'channelDomain': 'https://im1.direxio.ai',
          'room_id': '!room:im1.direxio.ai',
        }),
      ),
    );
  });

  test('closeChannelDirectory posts signed documented body', () async {
    late http.Request seen;
    final client = ImPublicClient(
      baseUri: Uri.parse('https://admin.example.com'),
      secret: 'bi-secret',
      httpClient: MockClient((request) async {
        seen = request;
        expect(request.method, 'POST');
        expect(request.url.path, '/im/channel/close');
        expect(jsonDecode(request.body), {
          'room_id': '!room:im1.direxio.ai',
        });
        return _json({'code': 0, 'data': {}, 'msg': 'success'});
      }),
    );

    await client.closeChannelDirectory(roomId: '!room:im1.direxio.ai');

    expect(seen.headers['X-BI-Nonce'], isNotEmpty);
    expect(seen.headers['X-BI-Signature'], isNotEmpty);
  });

  test('report endpoints follow signed IM public contract', () async {
    final seen = <String>[];
    final client = ImPublicClient(
      baseUri: Uri.parse('https://admin.example.com'),
      secret: 'bi-secret',
      httpClient: MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        expect(request.headers['X-BI-Nonce'], isNotEmpty);
        expect(request.headers['X-BI-Signature'], isNotEmpty);
        if (request.url.path == '/im/report/count') {
          expect(request.url.queryParameters['reportedDomain'], 'room');
          expect(request.url.queryParameters['targetType'], '3');
          return _json({
            'code': 0,
            'data': {'count': 3},
            'msg': 'success',
          });
        }
        expect(request.url.path, '/im/report');
        expect(jsonDecode(request.body), {
          'reporterDomain': 'alice',
          'reportedDomain': 'room',
          'targetType': 3,
          'reason': '违规',
        });
        return _json({'code': 0, 'data': {}, 'msg': 'success'});
      }),
    );

    expect(
      await client.getReportCount(reportedDomain: 'room', targetType: 3),
      3,
    );
    await client.submitReport(
      reporterDomain: 'alice',
      reportedDomain: 'room',
      targetType: 3,
      reason: '违规',
    );

    expect(seen, ['GET /im/report/count', 'POST /im/report']);
  });

  test('submitReport sends image bytes as repeated multipart files', () async {
    late http.MultipartRequest seen;
    final client = ImPublicClient(
      baseUri: Uri.parse('https://admin.example.com'),
      secret: 'bi-secret',
      httpClient: _MultipartRecordingClient((request) async {
        seen = request;
        return _streamJson({'code': 0, 'data': {}, 'msg': 'success'});
      }),
    );

    await client.submitReport(
      reporterDomain: 'alice',
      reportedDomain: '!room:im1.direxio.ai',
      targetType: 3,
      reason: '违规',
      files: const [
        ImPublicFilePart(
          filename: 'a.png',
          bytes: [1, 2, 3],
          contentType: 'image/png',
        ),
        ImPublicFilePart(
          filename: 'b.jpg',
          bytes: [4, 5],
          contentType: 'image/jpeg',
        ),
      ],
    );

    expect(seen.url.path, '/im/report');
    expect(seen.fields, {
      'reporterDomain': 'alice',
      'reportedDomain': '!room:im1.direxio.ai',
      'targetType': '3',
      'reason': '违规',
    });
    expect(seen.files.map((file) => file.field).toList(), ['files', 'files']);
    expect(
        seen.files.map((file) => file.filename).toList(), ['a.png', 'b.jpg']);
    expect(seen.headers['X-BI-Nonce'], isNotEmpty);
    expect(
      seen.headers['X-BI-Signature'],
      buildImPublicSignature(
        secret: 'bi-secret',
        nonce: seen.headers['X-BI-Nonce']!,
        canonicalBody: '{}',
      ),
    );
  });

  test('BiAnalyticsService reports launch once and login on every startup',
      () async {
    final events = <BiAnalyticsEvent>[];
    final service = BiAnalyticsService(reporter: (event) async {
      events.add(event);
    });

    await service.reportInstallAndLaunch();
    await service.reportInstallAndLaunch();

    expect(events.map((event) => event.eventType), [
      'launch',
      'login',
      'login',
    ]);
    expect(events.map((event) => event.deviceNo).toSet(), hasLength(1));
    expect(events.every((event) => event.payload.isEmpty), isTrue);
  });

  test('canonical JSON and signature match fixed vector', () {
    const body = {
      'eventType': 'login',
      'deviceNo': 'device-001',
      'reportTime': 1780934400000,
    };
    final canonical = canonicalImPublicJson(body);

    expect(
      canonical,
      '{"deviceNo":"device-001","eventType":"login","reportTime":1780934400000}',
    );
    expect(
      buildImPublicSignature(
        secret: 'bi-secret',
        nonce: 'nonce-001',
        canonicalBody: canonical,
      ),
      'da4bdf612502b1aaf00fe0dae27b31d7',
    );
  });

  test('HttpBiAnalyticsReporter posts signed canonical body', () async {
    late http.Request seen;
    final reporter = HttpBiAnalyticsReporter(
      baseUri: Uri.parse('https://admin.example.com'),
      secret: 'bi-secret',
      httpClient: MockClient((request) async {
        seen = request;
        return _json({'code': 0, 'data': {}, 'msg': 'success'});
      }),
    );

    await reporter(const BiAnalyticsEvent(
      eventType: 'login',
      deviceNo: 'device-001',
      phoneModel: '',
      reportTime: 1780934400000,
      payload: {},
    ));

    expect(seen.method, 'POST');
    expect(seen.url.path, '/bi/events/report');
    expect(seen.headers['X-BI-Nonce'], isNotEmpty);
    expect(seen.headers['X-BI-Signature'], isNotEmpty);
    expect(
      seen.body,
      '{"deviceNo":"device-001","eventType":"login","reportTime":1780934400000}',
    );
  });
}

http.Response _json(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

http.StreamedResponse _streamJson(Map<String, Object?> body) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class _MultipartRecordingClient extends http.BaseClient {
  _MultipartRecordingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.MultipartRequest request)
      handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is! http.MultipartRequest) {
      throw StateError('expected MultipartRequest, got ${request.runtimeType}');
    }
    return handler(request);
  }
}
