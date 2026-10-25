import 'package:flutter/material.dart';

import '../core/widgets/gb_bottom_nav.dart';
import '../features/about/presentation/about_page.dart';
import '../features/chat/presentation/chat_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/info/presentation/info_page.dart';
import '../features/submit_case/presentation/submit_case_page.dart';
import '../features/track/presentation/track_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const String routeName = '/main';

  static const int chatTab = 3;

  static final ValueNotifier<int?> _tabRequest = ValueNotifier<int?>(null);

  /// Closes any pages opened on top of the shell and switches to [index].
  static void openTab(BuildContext context, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _tabRequest.value = index;
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    MainShell._tabRequest.addListener(_handleTabRequest);
  }

  @override
  void dispose() {
    MainShell._tabRequest.removeListener(_handleTabRequest);
    super.dispose();
  }

  void _handleTabRequest() {
    final index = MainShell._tabRequest.value;
    if (index == null) return;
    MainShell._tabRequest.value = null;
    _onTabSelected(index);
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        onSubmitTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubmitCasePage(
                onSubmitted: (message) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: const Color(0xFF168548),
                    ),
                  );
                },
              ),
            ),
          );
        },
        onTrackTap: () => _onTabSelected(1),
        onInfoTap: () => _onTabSelected(2),
      ),
      const TrackPage(),
      const InfoPage(),
      const ChatPage(),
      const AboutPage(),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide =
              Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: GbBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
