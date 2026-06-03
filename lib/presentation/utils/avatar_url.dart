import 'package:matrix/matrix.dart';

String? matrixContentHttpUrl(Client client, Uri? uri) {
  if (uri == null) return null;
  final resolved = uri.scheme == 'mxc' ? uri.getDownloadLink(client) : uri;
  final value = resolved.toString();
  return value.isEmpty ? null : value;
}

String? avatarHttpUrl(Client client, String? url) {
  final value = url?.trim() ?? '';
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme.isEmpty) return null;
  if (uri.scheme == 'mxc') {
    return matrixContentHttpUrl(client, uri);
  }
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return value;
  }
  return null;
}

String? profileAvatarHttpUrl(Profile? profile, Client client) {
  return matrixContentHttpUrl(client, profile?.avatarUrl);
}

String? roomAvatarHttpUrl(Room room) {
  return matrixContentHttpUrl(room.client, room.avatar);
}
