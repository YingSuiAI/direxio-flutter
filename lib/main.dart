import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web 上禁用浏览器原生右键菜单（翻译/检查等），让我们自己的
  // chat-ctx / msg-ctx 菜单不被遮挡。
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }
  runApp(const ProviderScope(child: PortalApp()));
}

class PortalApp extends ConsumerWidget {
  const PortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Portal IM',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
