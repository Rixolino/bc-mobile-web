import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../../core/design_system.dart';
import '../../core/services/runtime_localizations.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeOut)),
    );
    _slideAnim = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic)),
    );

    _controller.forward();

    _route();
  }

  /// Se l'app è stata aperta da un link condiviso (/share/?id=...),
  /// salta l'intro e vai subito alla home (che aprirà il dettaglio viaggio).
  Future<void> _route() async {
    bool skipIntro = false;
    try {
      final uri = await AppLinks()
          .getInitialLink()
          .timeout(const Duration(seconds: 2));
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'betacloud-transporter.is-cool.dev' &&
          uri.path.startsWith('/share') &&
          (uri.queryParameters['id'] ?? '').isNotEmpty) {
        skipIntro = true;
      }
    } catch (_) {}
    if (!mounted) return;

    bool hasSeenOnboarding = false;
    int startScreen = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      startScreen = (prefs.getInt('ui_start_screen') ?? 0).clamp(0, 4);
    } catch (_) {}
    if (!mounted) return;

    if (skipIntro) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => hasSeenOnboarding ? HomeScreen(initialMode: startScreen) : const OnboardingScreen()),
      );
      return;
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => hasSeenOnboarding ? HomeScreen(initialMode: startScreen) : const OnboardingScreen(),
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isLandscape = media.orientation == Orientation.landscape;

    // In landscape l'altezza è ridotta: logo/spaziature compatti + scroll
    // per evitare bottom overflow; contenuti centrati con larghezza massima.
    final logoSize = isLandscape ? 72.0 : 100.0;
    final logoIconSize = isLandscape ? 36.0 : 50.0;
    final gap1 = isLandscape ? 16.0 : 32.0;
    final gap2 = isLandscape ? 16.0 : 48.0;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  theme.primaryColor.withOpacity(theme.isDark ? 0.08 : 0.05),
                  theme.backgroundColor,
                  theme.surfaceColor.withOpacity(0.5),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: isLandscape ? 12 : 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: _scaleAnim.value,
                    child: Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        gradient: AppGradients.brandGradient,
                        borderRadius: BorderRadius.circular(AppTokens.radius2Xl),
                        boxShadow: [
                          BoxShadow(
                            color: AppTokens.brandOrange.withOpacity(0.3),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_bus_rounded,
                        size: logoIconSize,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: gap1),
                  Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnim.value),
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => AppGradients.brandGradient.createShader(bounds),
                            child: Text(
                              'BC.TRANSPORTER',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Syne', 
                                fontSize: screenWidth < 375 ? 15 : 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            RuntimeLocalizations.t(context, 'splash_tagline',
                                fallback: 'Tuo viaggio, in tempo reale'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: gap2),
                  Opacity(
                    opacity: _fadeAnim.value,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                      ),
                    ),
                  ),
                ],
              ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
