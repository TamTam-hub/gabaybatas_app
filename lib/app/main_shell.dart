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
  int _previousIndex = 0;

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
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  /// Fade-through: the old tab fades out quickly, then the new one fades in
  /// with a short slide toward the side of the tab that was tapped.
  Widget _tabTransition(Widget child, Animation<double> animation) {
    final direction = _currentIndex >= _previousIndex ? 1.0 : -1.0;
    final incoming = child.key == ValueKey<int>(_currentIndex);

    if (incoming) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.04 * direction, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    }

    // Outgoing: the animation runs 1 → 0, so this fades out in the first 30%.
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.7, 1, curve: Curves.easeIn),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(-0.02 * direction, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
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
        duration: const Duration(milliseconds: 340),
        transitionBuilder: _tabTransition,
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: RepaintBoundary(child: pages[_currentIndex]),
        ),
      ),
      bottomNavigationBar: GbBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
