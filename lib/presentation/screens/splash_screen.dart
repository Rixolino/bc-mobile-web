import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to HomeScreen after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              theme.primaryColor.withOpacity(0.15),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bus icon with gradient
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFF43AA8B)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                child: const Icon(
                  Icons.directions_bus,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Logo BC.T
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFF43AA8B)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                    child: Text(
                      'BC',
                      style: GoogleFonts.syne(
                        fontSize: 15  ,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '.',
                    style: GoogleFonts.syne(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF3b82f6),
                    ),
                  ),
                  Text(
                    'TRANSPORTER',
                    style: GoogleFonts.syne(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: theme.textColor,
                      shadows: [BoxShadow(color: theme.textColor.withOpacity(0.15), blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}