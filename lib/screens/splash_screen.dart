import 'package:flutter/material.dart';
import 'home_page.dart';

/// Pantalla de splash que muestra el logo y navega a la pantalla principal tras 2 segundos
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF111111), Colors.black],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF00FF41),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 180,
                          height: 180,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Precio Gas Alert',
                      style: TextStyle(
                        fontFamily: 'VT323',
                        color: Color(0xFFFFC300),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Cargando...',
                      style: TextStyle(
                        fontFamily: 'VT323',
                        color: Color(0xFF00FF41),
                        fontSize: 18,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
