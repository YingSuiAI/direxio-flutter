import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation Text widgets do not use hardcoded Chinese literals', () {
    final root = Directory('lib/presentation');
    final violations = <String>[];

    for (final file in root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final source = _stripComments(file.readAsStringSync());
      for (final call in _findTextCalls(source)) {
        if (call.body.contains('l10n') ||
            call.body.contains('L10n') ||
            call.body.contains('Localizations') ||
            call.body.contains('AppLocalizations')) {
          continue;
        }
        final literals = _stringLiterals(call.body)
            .where((literal) => _hasChinese(literal))
            .toList();
        if (literals.isEmpty) continue;
        violations.add(
          '${file.path}:${_lineNumber(source, call.start)} '
          '${literals.map((literal) => '"$literal"').join(', ')}',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Use AppLocalizations for user-visible Text/TextSpan strings:\n'
          '${violations.join('\n')}',
    );
  });
}

String _stripComments(String source) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (i + 1 < source.length && source[i] == '/' && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      if (i < source.length) buffer.write(source[i++]);
      continue;
    }
    if (i + 1 < source.length && source[i] == '/' && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < source.length &&
          !(source[i] == '*' && source[i + 1] == '/')) {
        if (source[i] == '\n') buffer.write('\n');
        i++;
      }
      i += 2;
      continue;
    }
    buffer.write(source[i++]);
  }
  return buffer.toString();
}

Iterable<_TextCall> _findTextCalls(String source) sync* {
  final pattern = RegExp(r'\b(Text|TextSpan)\s*(?:\.rich)?\s*\(');
  for (final match in pattern.allMatches(source)) {
    final openParen = source.indexOf('(', match.start);
    final end = _matchingParen(source, openParen);
    if (end == -1) continue;
    yield _TextCall(match.start, source.substring(match.start, end + 1));
  }
}

int _matchingParen(String source, int openParen) {
  var depth = 0;
  String? quote;
  var triple = false;
  var escaped = false;
  for (var i = openParen; i < source.length; i++) {
    final char = source[i];
    if (quote != null) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (triple) {
        if (char == quote &&
            i + 2 < source.length &&
            source[i + 1] == quote &&
            source[i + 2] == quote) {
          i += 2;
          quote = null;
          triple = false;
        }
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }

    if (char == "'" || char == '"') {
      quote = char;
      triple = i + 2 < source.length &&
          source[i + 1] == char &&
          source[i + 2] == char;
      if (triple) i += 2;
      continue;
    }
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

Iterable<String> _stringLiterals(String source) sync* {
  String? quote;
  var triple = false;
  var escaped = false;
  var buffer = StringBuffer();
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (quote != null) {
      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (triple) {
        if (char == quote &&
            i + 2 < source.length &&
            source[i + 1] == quote &&
            source[i + 2] == quote) {
          yield buffer.toString();
          buffer = StringBuffer();
          i += 2;
          quote = null;
          triple = false;
        } else {
          buffer.write(char);
        }
      } else if (char == quote) {
        yield buffer.toString();
        buffer = StringBuffer();
        quote = null;
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (char == "'" || char == '"') {
      quote = char;
      triple = i + 2 < source.length &&
          source[i + 1] == char &&
          source[i + 2] == char;
      if (triple) i += 2;
    }
  }
}

bool _hasChinese(String value) => RegExp(r'[\u4e00-\u9fff]').hasMatch(value);

int _lineNumber(String source, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < source.length; i++) {
    if (source.codeUnitAt(i) == 10) line++;
  }
  return line;
}

class _TextCall {
  const _TextCall(this.start, this.body);

  final int start;
  final String body;
}
