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

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

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
            MaterialPageRoute(builder: (_) => const SubmitCasePage()),
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
          final slide = Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

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