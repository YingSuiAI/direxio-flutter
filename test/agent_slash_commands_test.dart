import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/agent_slash_commands.dart';

void main() {
  test('agent slash commands use Chinese labels by default', () {
    final commands = agentSlashCommandsForLocale(
      const Locale('zh'),
      query: '/',
    );

    expect(commands.first.command, '/help');
    expect(commands.first.title, '帮助');
    expect(agentSlashCommandPickerLabel(const Locale('zh')), '快捷命令');
  });

  test('agent slash commands support English labels', () {
    final commands = agentSlashCommandsForLocale(
      const Locale('en'),
      query: '/',
    );

    expect(commands.first.command, '/help');
    expect(commands.first.title, 'Help');
    expect(agentSlashCommandPickerLabel(const Locale('en')), 'Quick commands');
  });

  test('agent slash commands support Japanese labels', () {
    final commands = agentSlashCommandsForLocale(
      const Locale('ja'),
      query: '/',
    );

    expect(commands.first.command, '/help');
    expect(commands.first.title, 'ヘルプ');
    expect(agentSlashCommandPickerLabel(const Locale('ja')), 'クイックコマンド');
  });

  test('agent slash commands filter by command prefix and title', () {
    final byCommand = agentSlashCommandsForLocale(
      const Locale('en'),
      query: '/mo',
    );
    final byTitle = agentSlashCommandsForLocale(
      const Locale('zh'),
      query: '语言',
    );

    expect(byCommand.map((command) => command.command), [
      '/model',
      '/mode',
    ]);
    expect(byTitle.single.command, '/lang');
  });
}
