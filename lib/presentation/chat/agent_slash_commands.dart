import 'dart:ui';

class AgentSlashCommand {
  const AgentSlashCommand({
    required this.command,
    required this.title,
    required this.description,
  });

  final String command;
  final String title;
  final String description;
}

List<AgentSlashCommand> agentSlashCommandsForLocale(
  Locale locale, {
  String query = '',
  int limit = 8,
}) {
  final commands = _commandsForLanguage(locale.languageCode);
  final normalizedQuery = query.trim().toLowerCase();
  final withoutSlash = normalizedQuery.startsWith('/')
      ? normalizedQuery.substring(1)
      : normalizedQuery;
  final filtered = withoutSlash.isEmpty
      ? commands
      : commands.where((command) {
          final needle = withoutSlash;
          return command.command.toLowerCase().contains(needle) ||
              command.title.toLowerCase().contains(needle) ||
              command.description.toLowerCase().contains(needle);
        });
  return filtered.take(limit).toList(growable: false);
}

String agentSlashCommandPickerLabel(Locale locale) {
  return switch (locale.languageCode) {
    'en' => 'Quick commands',
    'ja' => 'クイックコマンド',
    _ => '快捷命令',
  };
}

List<AgentSlashCommand> _commandsForLanguage(String languageCode) {
  return switch (languageCode) {
    'en' => _englishCommands,
    'ja' => _japaneseCommands,
    _ => _chineseCommands,
  };
}

const _chineseCommands = [
  AgentSlashCommand(command: '/help', title: '帮助', description: '查看可用命令'),
  AgentSlashCommand(
      command: '/new', title: '新会话', description: '开启新的 Agent 会话'),
  AgentSlashCommand(command: '/model', title: '模型', description: '查看或切换模型'),
  AgentSlashCommand(
      command: '/mode', title: '模式', description: '切换 Agent 工作模式'),
  AgentSlashCommand(
    command: '/provider',
    title: '服务商',
    description: '查看或切换模型服务商',
  ),
  AgentSlashCommand(
    command: '/commands',
    title: '自定义命令',
    description: '管理自定义命令',
  ),
  AgentSlashCommand(
    command: '/compress',
    title: '压缩上下文',
    description: '压缩当前会话上下文',
  ),
  AgentSlashCommand(command: '/stop', title: '停止', description: '停止当前执行'),
  AgentSlashCommand(
      command: '/status', title: '状态', description: '查看 Agent 运行状态'),
  AgentSlashCommand(command: '/list', title: '会话列表', description: '查看历史会话'),
  AgentSlashCommand(command: '/current', title: '当前会话', description: '查看当前会话'),
  AgentSlashCommand(command: '/history', title: '历史', description: '查看会话历史'),
  AgentSlashCommand(command: '/cancel', title: '取消', description: '停止并开启新会话'),
  AgentSlashCommand(
      command: '/lang', title: '语言', description: '切换 Agent 回复语言'),
  AgentSlashCommand(command: '/skills', title: '技能', description: '查看可用技能'),
  AgentSlashCommand(command: '/doctor', title: '诊断', description: '运行环境诊断'),
];

const _englishCommands = [
  AgentSlashCommand(
      command: '/help', title: 'Help', description: 'Show commands'),
  AgentSlashCommand(
      command: '/new',
      title: 'New chat',
      description: 'Start a new Agent chat'),
  AgentSlashCommand(
      command: '/model', title: 'Model', description: 'View or switch model'),
  AgentSlashCommand(
      command: '/mode', title: 'Mode', description: 'Switch Agent mode'),
  AgentSlashCommand(
      command: '/provider',
      title: 'Provider',
      description: 'View or switch provider'),
  AgentSlashCommand(
      command: '/commands',
      title: 'Custom commands',
      description: 'Manage custom commands'),
  AgentSlashCommand(
      command: '/compress',
      title: 'Compress',
      description: 'Compress chat context'),
  AgentSlashCommand(
      command: '/stop', title: 'Stop', description: 'Stop the current run'),
  AgentSlashCommand(
      command: '/status', title: 'Status', description: 'Show Agent status'),
  AgentSlashCommand(
      command: '/list',
      title: 'Sessions',
      description: 'List previous sessions'),
  AgentSlashCommand(
      command: '/current',
      title: 'Current',
      description: 'Show current session'),
  AgentSlashCommand(
      command: '/history',
      title: 'History',
      description: 'Show session history'),
  AgentSlashCommand(
      command: '/cancel',
      title: 'Cancel',
      description: 'Stop and start a new session'),
  AgentSlashCommand(
      command: '/lang',
      title: 'Language',
      description: 'Switch Agent language'),
  AgentSlashCommand(
      command: '/skills',
      title: 'Skills',
      description: 'Show available skills'),
  AgentSlashCommand(
      command: '/doctor', title: 'Doctor', description: 'Run diagnostics'),
];

const _japaneseCommands = [
  AgentSlashCommand(
      command: '/help', title: 'ヘルプ', description: '利用できるコマンドを表示'),
  AgentSlashCommand(
      command: '/new', title: '新規会話', description: '新しい Agent 会話を開始'),
  AgentSlashCommand(
      command: '/model', title: 'モデル', description: 'モデルを確認または切り替え'),
  AgentSlashCommand(
      command: '/mode', title: 'モード', description: 'Agent の動作モードを切り替え'),
  AgentSlashCommand(
      command: '/provider', title: 'プロバイダー', description: 'モデル提供元を確認または切り替え'),
  AgentSlashCommand(
      command: '/commands', title: 'カスタムコマンド', description: 'カスタムコマンドを管理'),
  AgentSlashCommand(
      command: '/compress', title: '圧縮', description: '会話コンテキストを圧縮'),
  AgentSlashCommand(command: '/stop', title: '停止', description: '現在の実行を停止'),
  AgentSlashCommand(
      command: '/status', title: '状態', description: 'Agent の状態を表示'),
  AgentSlashCommand(
      command: '/list', title: 'セッション', description: '過去のセッションを表示'),
  AgentSlashCommand(
      command: '/current', title: '現在', description: '現在のセッションを表示'),
  AgentSlashCommand(command: '/history', title: '履歴', description: '会話履歴を表示'),
  AgentSlashCommand(
      command: '/cancel', title: 'キャンセル', description: '停止して新しい会話を開始'),
  AgentSlashCommand(
      command: '/lang', title: '言語', description: 'Agent の応答言語を切り替え'),
  AgentSlashCommand(
      command: '/skills', title: 'スキル', description: '利用可能なスキルを表示'),
  AgentSlashCommand(command: '/doctor', title: '診断', description: '診断を実行'),
];
