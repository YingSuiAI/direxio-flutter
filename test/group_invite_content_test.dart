import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/groups/group_invite_content.dart';

void main() {
  test('parses v1 group invite content', () {
    final invite = GroupInviteContent.tryParse(
      const {
        'msgtype': 'p2p.group.invite.v1',
        'group_room_id': '!group:p2p-im.com',
        'group_name': '产品测试群',
        'inviter_mxid': '@alice:p2p-liyanan.com',
        'inviter_display_name': 'Alice',
      },
      eventId: r'$invite',
      directRoomId: '!dm:p2p-im.com',
    );

    expect(invite, isNotNull);
    expect(invite!.groupRoomId, '!group:p2p-im.com');
    expect(invite.groupName, '产品测试群');
    expect(invite.inviterMxid, '@alice:p2p-liyanan.com');
    expect(invite.inviteEventId, r'$invite');
    expect(invite.directRoomId, '!dm:p2p-im.com');
  });

  test('accepts legacy group invite msgtype', () {
    final invite = GroupInviteContent.tryParse(
      const {
        'msgtype': 'p2p.group.invite',
        'group_room_id': '!group:p2p-im.com',
        'group_name': '旧版群邀请',
      },
    );

    expect(invite?.groupName, '旧版群邀请');
  });

  test('does not parse ordinary text message', () {
    final invite = GroupInviteContent.tryParse(
      const {'msgtype': 'm.text', 'body': 'hello'},
    );

    expect(invite, isNull);
  });
}
