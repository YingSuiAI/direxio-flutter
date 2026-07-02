import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/im_public_client.dart';
import 'package:portal_app/data/im_public_tag_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('channel tag cache reuses fresh local tags and refreshes after a day',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesImPublicTagCacheStore(prefs);
    final client = _CountingTagClient([
      const ImPublicTag(
          id: 1, name: 'AI', icon: 'https://cdn.example.com/ai.png'),
    ]);

    final first = await loadCachedImPublicChannelTags(
      client: client,
      store: store,
      now: DateTime.utc(2026, 7, 1, 10),
    );

    expect(first.single.id, 1);
    expect(client.callCount, 1);

    client.tags = [
      const ImPublicTag(
        id: 2,
        name: 'Product',
        icon: 'https://cdn.example.com/product.png',
      ),
    ];
    final fresh = await loadCachedImPublicChannelTags(
      client: client,
      store: store,
      now: DateTime.utc(2026, 7, 2, 9, 59),
    );

    expect(fresh.single.id, 1);
    expect(client.callCount, 1);

    final stale = await loadCachedImPublicChannelTags(
      client: client,
      store: store,
      now: DateTime.utc(2026, 7, 2, 10, 1),
    );

    expect(stale.single.id, 2);
    expect(client.callCount, 2);
  });
}

class _CountingTagClient extends ImPublicClient {
  _CountingTagClient(this.tags)
      : super(
          baseUri: Uri.parse('https://api.example.com'),
          secret: 'bi-secret',
        );

  List<ImPublicTag> tags;
  int callCount = 0;

  @override
  Future<List<ImPublicTag>> listTags({String type = 'channel'}) async {
    callCount += 1;
    return tags;
  }
}
