import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/update/update_prompt.dart';
import '../core/update/update_service.dart';
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

  static const int trackTab = 1;
  static const int chatTab = 3;
  static const int profileTab = 4;

  static final ValueNotifier<int?> _tabRequest = ValueNotifier<int?>(null);

  /// The tab on screen. Tabs stay alive between visits; a tab that shows
  /// changing data (Track, Profile) listens to this to refresh when opened.
  static final ValueNotifier<int> shownTab = ValueNotifier<int>(0);

  /// Closes any pages opened on top of the shell and switches to [index].
  static void openTab(BuildContext context, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _tabRequest.value = index;
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;

  /// Tabs are built the first time they are opened, then kept.
  final List<bool> _built = <bool>[true, false, false, false, false];

  /// Fades the newly shown tab in (only that tab is drawn, never two at once).
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final Animation<double> _fadeCurve = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOutCubic,
  );

  /// The update check runs once per app start, not on every return to the shell.
  static bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    MainShell._tabRequest.addListener(_handleTabRequest);
    if (kReleaseMode && !_updateChecked) {
      _updateChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
    }
  }

  Future<void> _checkForUpdate() async {
    final update = await const UpdateService().checkForUpdate();
    if (update == null || !mounted) return;
    await showUpdatePrompt(context, update);
  }

  @override
  void dispose() {
    MainShell._tabRequest.removeListener(_handleTabRequest);
    _fade.dispose();
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
      _built[index] = true;
    });
    MainShell.shownTab.value = index;
    _fade.forward(from: 0);
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

    final direction = _currentIndex >= _previousIndex ? 1.0 : -1.0;
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeCurve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.03 * direction, 0),
            end: Offset.zero,
          ).animate(_fadeCurve),
          child: IndexedStack(
            index: _currentIndex,
            children: [
              for (var i = 0; i < pages.length; i++)
                // Hidden tabs keep their state but pause their animations.
                TickerMode(
                  enabled: i == _currentIndex,
                  child: _built[i]
                      ? RepaintBoundary(child: pages[i])
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: GbBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
