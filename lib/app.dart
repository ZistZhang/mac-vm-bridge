import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'controllers/app_controller.dart';
import 'core/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/jobs_screen.dart';
import 'screens/settings_screen.dart';

class MinerUFlowApp extends StatelessWidget {
  const MinerUFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MinerU Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  StreamSubscription<List<SharedMediaFile>>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      _shareSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
        _importShared,
        onError: (_) {},
      );
      ReceiveSharingIntent.instance.getInitialMedia().then((items) async {
        await _importShared(items);
        await ReceiveSharingIntent.instance.reset();
      });
    }
  }

  Future<void> _importShared(List<SharedMediaFile> items) async {
    final paths = items.map((item) => item.path).where((path) => path.isNotEmpty).toList();
    if (paths.isNotEmpty && mounted) {
      await context.read<AppController>().importPaths(paths);
    }
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 860;
    final screens = const [HomeScreen(), JobsScreen(), SettingsScreen()];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final message = controller.message;
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        controller.clearMessage();
      }
    });

    final body = IndexedStack(
      index: controller.navigationIndex,
      children: screens,
    );

    if (desktop) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: controller.navigationIndex,
                onDestinationSelected: controller.setNavigationIndex,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 24),
                  child: _BrandMark(compact: width < 1050),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.add_to_drive_outlined),
                    selectedIcon: Icon(Icons.add_to_drive),
                    label: Text('转换'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: Text('任务'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.tune_outlined),
                    selectedIcon: Icon(Icons.tune),
                    label: Text('设置'),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MinerU Flow'),
        centerTitle: false,
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.navigationIndex,
        onDestinationSelected: controller.setNavigationIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_to_drive_outlined), label: '转换'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: '任务'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), label: '设置'),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)]),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(Icons.description_rounded, color: Colors.white),
    );
    if (compact) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        const Text('MinerU Flow', style: TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
