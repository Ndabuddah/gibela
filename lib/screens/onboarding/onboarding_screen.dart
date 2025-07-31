import 'dart:ui'; // Added for ImageFilter

import 'package:flutter/material.dart';
import 'package:gibelbibela/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import 'onboarding_content.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLastPage = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<OnboardingContent> _onboardingData = [
    OnboardingContent(title: 'Welcome to RideApp', description: 'Your trusted partner for safe and convenient rides across South Africa.', icon: Icons.local_taxi, color: AppColors.primary, imagePath: 'assets/images/onboarding1.png'),
    OnboardingContent(title: 'Quick & Easy', description: 'Book your ride in seconds with our intuitive interface and real-time tracking.', icon: Icons.speed, color: AppColors.secondary, imagePath: 'assets/images/onboarding2.png'),
    OnboardingContent(title: 'Safe & Secure', description: 'All our drivers are verified and your rides are fully insured for your peace of mind.', icon: Icons.security, color: AppColors.success, imagePath: 'assets/images/onboarding3.png'),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _updateLastPageStatus();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _slideController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  void _updateLastPageStatus() {
    setState(() {
      _isLastPage = _currentPage == _onboardingData.length - 1;
    });
  }

  void _nextPage() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.animateToPage(_currentPage + 1, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(_currentPage - 1, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  Future<void> _completeOnboarding() async {
    // Save onboarding completion status
    // In a real app, you'd save this to SharedPreferences

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final content = _onboardingData[_currentPage];

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      body: Stack(
        children: [
          // Invisible PageView for swiping (must be at the bottom of the stack)
          PageView.builder(
            controller: _pageController,
            itemCount: _onboardingData.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _updateLastPageStatus();
              });
            },
            itemBuilder: (context, index) => const SizedBox.shrink(),
          ),
          // Background image with blur and overlay
          if (content.imagePath != null)
            Positioned.fill(
              child: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: Image.asset(content.imagePath!, key: ValueKey(content.imagePath), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  ),
                  Positioned.fill(child: Container(color: Colors.black.withOpacity(0.45))),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
          // Fixed bottom sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -8))],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeInBack,
                    transitionBuilder: (child, animation) {
                      final safeAnimation = animation.drive(Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: Curves.linear)));
                      return FadeTransition(
                        opacity: safeAnimation,
                        child: ScaleTransition(
                          scale: safeAnimation.drive(Tween<double>(begin: 0.95, end: 1.0).chain(CurveTween(curve: const ClampedEaseOutBackCurve()))),
                          child: child,
                        ),
                      );
                    },
                    child: _OnboardingSheetContent(key: ValueKey(_currentPage), content: content, currentPage: _currentPage, pageCount: _onboardingData.length, isLastPage: _isLastPage, onNext: _nextPage, onBack: _previousPage, onSkip: _completeOnboarding),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// New widget for the animated content inside the bottom sheet
class _OnboardingSheetContent extends StatelessWidget {
  final OnboardingContent content;
  final int currentPage;
  final int pageCount;
  final bool isLastPage;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _OnboardingSheetContent({Key? key, required this.content, required this.currentPage, required this.pageCount, required this.isLastPage, required this.onNext, required this.onBack, required this.onSkip}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(content.icon, color: content.color, size: 48),
        const SizedBox(height: 24),
        Text(
          content.title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          content.description,
          style: const TextStyle(fontSize: 17, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pageCount,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: currentPage == i ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(color: currentPage == i ? content.color : Colors.grey[300], borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (currentPage > 0) IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), color: Colors.grey[700], onPressed: onBack) else const SizedBox(width: 48),
            ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: content.color,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: Text(isLastPage ? 'Get Started' : 'Next', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (!isLastPage) TextButton(onPressed: onSkip, child: const Text('Skip')) else const SizedBox(width: 48),
          ],
        ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingContent content;
  final bool isDark;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  const _OnboardingPage({required this.content, required this.isDark, required this.fadeAnimation, required this.slideAnimation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with animation
          FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [content.color, content.color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [BoxShadow(color: content.color.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)],
                ),
                child: Icon(content.icon, color: AppColors.black, size: 80),
              ),
            ),
          ),

          const SizedBox(height: 60),

          // Title
          FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: Text(
                content.title,
                style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Description
          FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: Text(
                content.description,
                style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final bool isActive;
  final bool isDark;

  const _PageIndicator({required this.isActive, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(color: isActive ? AppColors.primary : AppColors.getDividerColor(isDark), borderRadius: BorderRadius.circular(4)),
    );
  }
}

class _ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isDark;
  final bool isPrimary;

  const _ModernButton({required this.text, required this.onPressed, required this.isDark, this.isPrimary = false});

  @override
  State<_ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<_ModernButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: widget.isPrimary ? AppColors.primaryGradient : null,
                color: widget.isPrimary ? null : AppColors.getCardColor(widget.isDark),
                borderRadius: BorderRadius.circular(16),
                border: widget.isPrimary ? null : Border.all(color: AppColors.getBorderColor(widget.isDark), width: 2),
                boxShadow: widget.isPrimary ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Text(
                      widget.text,
                      style: TextStyle(color: widget.isPrimary ? AppColors.black : AppColors.getTextPrimaryColor(widget.isDark), fontSize: 18, fontWeight: FontWeight.bold),
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

class _AnimatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final bool isDark;

  const _AnimatedButton({required this.onPressed, required this.icon, required this.isDark});

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.getCardColor(widget.isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorderColor(widget.isDark), width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(widget.icon, color: AppColors.getIconColor(widget.isDark), size: 24),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ClampedEaseOutBackCurve extends Curve {
  const ClampedEaseOutBackCurve();
  @override
  double transform(double t) => Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
}
