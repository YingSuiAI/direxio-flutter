import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/call/voice_call_display_name.dart';

void main() {
  test('uses product contact name instead of Matrix owner fallback', () {
    expect(
      voiceCallPeerDisplayName(
        peerMxid: '@owner:p2p-liyanan.com',
        contactDisplayName: 'Yanan',
        contactDomain: 'p2p-liyanan.com',
        routeDisplayName: 'owner',
        statePeerName: 'owner',
        roomDisplayName: 'owner',
      ),
      'Yanan',
    );
  });

  test('falls back to domain instead of showing owner', () {
    expect(
      voiceCallPeerDisplayName(
        peerMxid: '@owner:p2p-liyanan.com',
        routeDisplayName: 'owner',
        statePeerName: 'owner',
        roomDisplayName: 'owner',
      ),
      'p2p-liyanan.com',
    );
  });
}
