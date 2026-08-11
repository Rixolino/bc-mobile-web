import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../../core/design_system.dart';
import 'home_screen.dart';

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

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
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
    final screenWidth = MediaQuery.of(context).size.width;

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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: _scaleAnim.value,
                    child: Container(
                      width: 100,
                      height: 100,
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
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
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
                            'Tuo viaggio, in tempo reale',
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
                  const SizedBox(height: 48),
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
          );
        },
      ),
    );
  }
}
