import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({required this.onComplete, super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _orbController;
  late AnimationController _shimmerController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimationSequence();
  }

  void _initAnimations() {
    // Logo animation controller
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Text animation controller
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Background orb animation
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Shimmer effect
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Logo animations
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Text animations
    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  void _startAnimationSequence() async {
    // Start logo animation
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();

    // Start text animation after logo
    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();

    // Wait for animations to complete then navigate
    await Future.delayed(const Duration(milliseconds: 1800));
    widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _orbController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF0F4F8);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Animated background orbs
          ..._buildAnimatedOrbs(isDark),

          // Particle effect
          ...List.generate(20, (index) => _buildParticle(index, isDark)),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: _buildLogo(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Animated App Name
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: _buildAppName(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Animated Tagline
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _taglineOpacity.value,
                      child: _buildTagline(isDark),
                    );
                  },
                ),

                const SizedBox(height: 80),

                // Loading indicator
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _taglineOpacity.value,
                      child: _buildLoadingIndicator(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAnimatedOrbs(bool isDark) {
    final orbData = [
      {
        'color': const Color(0xFF007AFF),
        'size': 350.0,
        'x': -150.0,
        'y': -150.0,
        'delay': 0.0,
      },
      {
        'color': const Color(0xFF00D4AA),
        'size': 280.0,
        'x': 200.0,
        'y': 100.0,
        'delay': 0.3,
      },
      {
        'color': const Color(0xFF8B5CF6),
        'size': 220.0,
        'x': -100.0,
        'y': 450.0,
        'delay': 0.6,
      },
      {
        'color': const Color(0xFFFF6B6B),
        'size': 180.0,
        'x': 250.0,
        'y': 600.0,
        'delay': 0.9,
      },
    ];

    return orbData.map((orb) {
      return AnimatedBuilder(
        animation: _orbController,
        builder: (context, child) {
          final delay = orb['delay'] as double;
          final progress = (_orbController.value + delay) % 1.0;
          final offsetX = math.sin(progress * 2 * math.pi) * 30;
          final offsetY = math.cos(progress * 2 * math.pi) * 30;

          return Positioned(
            left: (orb['x'] as double) + offsetX,
            top: (orb['y'] as double) + offsetY,
            child: Container(
              width: orb['size'] as double,
              height: orb['size'] as double,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (orb['color'] as Color).withValues(
                      alpha: isDark ? 0.35 : 0.25,
                    ),
                    (orb['color'] as Color).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildParticle(int index, bool isDark) {
    final random = math.Random(index);
    final startX = random.nextDouble() * 400;
    final startY = random.nextDouble() * 800;
    final size = random.nextDouble() * 4 + 2;
    final delay = random.nextDouble();

    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        final progress = (_orbController.value + delay) % 1.0;
        final y = startY - (progress * 100);
        final opacity = (math.sin(progress * math.pi) * 0.6).clamp(0.0, 0.6);

        return Positioned(
          left: startX,
          top: y,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: opacity),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF007AFF,
                  ).withValues(alpha: opacity * 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: const Color(0xFF00D4AA).withValues(alpha: 0.2),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Image.asset(
          'assets/images/milow_icon.png',
          width: 140,
          height: 140,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAppName() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF007AFF), Color(0xFF00D4AA), Color(0xFF8B5CF6)],
      ).createShader(bounds),
      child: Text(
        'MILOW',
        style: GoogleFonts.inter(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 12,
        ),
      ),
    );
  }

  Widget _buildTagline(bool isDark) {
    return Text(
      'Trucking Made Simple',
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF667085),
        letterSpacing: 3,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return SizedBox(
          width: 180,
          child: Column(
            children: [
              // Glowing line
              Container(
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: (_shimmerController.value * 180) - 40,
                      child: Container(
                        width: 80,
                        height: 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFF007AFF),
                              Color(0xFF00D4AA),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF007AFF,
                              ).withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Pulsing dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final delay = index * 0.15;
                  final progress = ((_shimmerController.value + delay) % 1.0);
                  final scale = 0.5 + (math.sin(progress * math.pi) * 0.5);
                  final opacity = 0.3 + (math.sin(progress * math.pi) * 0.7);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(
                                0xFF007AFF,
                              ).withValues(alpha: opacity),
                              const Color(
                                0xFF00D4AA,
                              ).withValues(alpha: opacity),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF007AFF,
                              ).withValues(alpha: opacity * 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
