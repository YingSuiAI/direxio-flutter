import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group call mesh signaling uses room events for single-device MVP', () {
    final callSession = File(
      'vendor/matrix/lib/src/voip/call_session.dart',
    ).readAsStringSync();
    final groupCallSession = File(
      'vendor/matrix/lib/src/voip/group_call_session.dart',
    ).readAsStringSync();
    final voip =
        File('vendor/matrix/lib/src/voip/voip.dart').readAsStringSync();

    expect(
      callSession,
      contains(
          'P2P IM MVP: use room events for federated group-call signaling'),
    );
    expect(callSession,
        contains('const bool p2pForceGroupCallRoomEvents = true;'));
    expect(
      callSession,
      contains(
          'isGroupCall && remoteDeviceId != null && !p2pForceGroupCallRoomEvents'),
    );
    expect(
      voip,
      contains("event.content.tryGet<String>('device_id') ??"),
    );
    expect(
      voip,
      contains("content.tryGet<String>('conf_id') != null"),
    );
    expect(
      voip,
      contains('remoteUserId == client.userID'),
    );
    expect(
      callSession,
      contains('_remoteCandidates.toList(growable: false)'),
    );
    expect(
      groupCallSession,
      contains('oldPcopy.contains(rp)'),
    );
    final localParticipantGate = groupCallSession.indexOf('if (rp.isLocal)');
    final remoteEnteredGate =
        groupCallSession.indexOf('if (state != GroupCallState.entered)');
    final remoteParticipantAddAfterEnteredGate =
        groupCallSession.indexOf('newP.add(rp);', remoteEnteredGate);
    expect(localParticipantGate, greaterThanOrEqualTo(0));
    expect(remoteEnteredGate, greaterThan(localParticipantGate));
    expect(
      remoteParticipantAddAfterEnteredGate,
      greaterThan(remoteEnteredGate),
      reason:
          'Remote participants must not enter _participants before the call is entered; otherwise mesh setup is skipped later.',
    );
    expect(
      groupCallSession,
      contains('membershipToSetup.key'),
    );
    expect(
      groupCallSession,
      contains('state != GroupCallState.ended &&'),
    );
  });
}
