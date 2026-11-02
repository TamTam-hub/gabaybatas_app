import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../core/storage/session_store.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import 'main_shell.dart';

class GabayBatasApp extends StatelessWidget {
  const GabayBatasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GabayBatas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        RegisterPage.routeName: (_) => const RegisterPage(),
        MainShell.routeName: (_) => const MainShell(),
      },
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final Future<String?> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _resolveStartup();
  }

  Future<String?> _resolveStartup() async {
    // Read the session while the splash animation plays its intro.
    final token = SessionStore.getToken();
    await Future<void>.delayed(const Duration(milliseconds: 3000));
    return token;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupLoadingPage();
        }

        final token = snapshot.data;
        if (token != null && token.isNotEmpty) {
          return const MainShell();
        }
        return const LoginPage();
      },
    );
  }
}

class _StartupLoadingPage extends StatefulWidget {
  const _StartupLoadingPage();

  @override
  State<_StartupLoadingPage> createState() => _StartupLoadingPageState();
}

class _StartupLoadingPageState extends State<_StartupLoadingPage>
    with SingleTickerProviderStateMixin {
  // splash_logo.json: intro runs to frame 96 of 156, then 96–156 loops gently.
  static const double _loopStart = 96 / 156;

  late final AnimationController _logo = AnimationController(vsync: this);

  @override
  void dispose() {
    _logo.dispose();
    super.dispose();
  }

  void _startLogo(LottieComposition composition) {
    _logo.duration = composition.duration;
    if (MediaQuery.of(context).disableAnimations) {
      _logo.value = _loopStart;
      return;
    }
    _logo.animateTo(_loopStart).then((_) {
      if (mounted) _logo.repeat(min: _loopStart, max: 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FF), Color(0xFFE5EDFC)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -30,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F5BC4).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -60,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A4CA3).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The animation is twice the tile's size so its rings
                      // can spread; the tile itself stays 104 px.
                      SizedBox(
                        width: 104,
                        height: 104,
                        child: OverflowBox(
                          maxWidth: 208,
                          maxHeight: 208,
                          child: Lottie.asset(
                            'assets/animations/splash_logo.json',
                            controller: _logo,
                            width: 208,
                            height: 208,
                            onLoaded: _startLogo,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'GabayBatas',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF173F8A),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Legal help at your fingertips',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5F7396),
                          letterSpacing: 0.15,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(
                            minHeight: 6,
                            backgroundColor: Color(0xFFD8E4FA),
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F5BC4)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
