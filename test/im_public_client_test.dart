import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_app/data/bi_analytics_service.dart';
import 'package:portal_app/data/im_public_client.dart';

void main() {
  test('listChannels reads IM public channel envelope', () async {
    final client = ImPublicClient(
      baseUri: Uri.parse('https://admin.example.com'),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/im/channel/list');
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['pageSize'], '20');
        expect(request.url.queryParameters['keyword'], '产品');
        return _json({
          'code': 0,
          'data': {
            'list': [
              {
                'ID': 1,
                'channelDomain': 'https://im1.direxio.ai',
                'room_id': '!room:im1.direxio.ai',
                'ownerDomain': 'im1.direxio.ai',
                'intro': 'Release notes',
                'channelDetail': {
                  'channel_id': 'ch_1',
                  'room_id': '!room:im1.direxio.ai',
                  'home_domain': 'im1.direxio.ai',
                  'name': 'Product Updates',
                  'description': 'Release notes',
                  'avatar_url': 'mxc://example.com/avatar',
                  'visibility': 'public',
                  'join_policy': 'open',
                  'comments_enabled': true,
                  'tags': ['技术'],
                  'member_count': 1,
                  'status': 'active',
                },
                'tagId': 1,
                'tag': {'ID': 1, 'name': '技术', 'color': '#67C23A'},
                'status': 1,
                'syncStatus': 1,
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
      keyword: '产品',
    );

    expect(page.total, 1);
    expect(page.items.single.channel.channelId, 'ch_1');
    expect(page.items.single.channel.name, 'Product Updates');
    expect(page.items.single.tag?.name, '技术');
  });

  test('joinChannelDirectory posts documented body', () async {
    final client = ImPublicClient(
      baseUri: Uri.parse('https://admin.example.com'),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/im/channel/join');
        expect(jsonDecode(request.body), {
          'channelDomain': 'https://im1.direxio.ai',
          'room_id': '!room:im1.direxio.ai',
          'tagId': 1,
        });
        return _json({'code': 0, 'data': {}, 'msg': 'success'});
      }),
    );

    await client.joinChannelDirectory(
      channelDomain: 'https://im1.direxio.ai',
      roomId: '!room:im1.direxio.ai',
      tagId: 1,
    );
  });

  test('report endpoints follow IM public contract', () async {
    final seen = <String>[];
    final client = ImPublicClient(
      baseUri: Uri.parse('https://admin.example.com'),
      httpClient: MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
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
          'images': ['uploads/file/im-public/demo.png'],
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
      images: const ['uploads/file/im-public/demo.png'],
    );

    expect(seen, ['GET /im/report/count', 'POST /im/report']);
  });

  test('BI canonical JSON and signature match fixed vector', () {
    const body = {
      'eventType': 'login',
      'deviceNo': 'device-001',
      'reportTime': 1780934400000,
    };
    final canonical = canonicalBiJson(body);

    expect(
      canonical,
      '{"deviceNo":"device-001","eventType":"login","reportTime":1780934400000}',
    );
    expect(
      buildBiSignature(
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
