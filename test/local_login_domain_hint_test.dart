import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/local_login_domain_hint.dart';

void main() {
  test('suggests portal authority for local three-node Matrix API ports', () {
    expect(
      localLoginDomainHintFor('127.0.0.1:18008')?.recommendedAuthority,
      'host.docker.internal:18448',
    );
    expect(
      localLoginDomainHintFor('http://localhost:28008')?.recommendedAuthority,
      'host.docker.internal:28448',
    );
    expect(
      localLoginDomainHintFor('https://127.0.0.1:38008')?.recommendedAuthority,
      'host.docker.internal:38448',
    );
  });

  test('does not suggest for recommended or production domains', () {
    expect(localLoginDomainHintFor('host.docker.internal:28448'), isNull);
    expect(localLoginDomainHintFor('im.direxio.ai'), isNull);
    expect(localLoginDomainHintFor('127.0.0.1:9999'), isNull);
  });
}
