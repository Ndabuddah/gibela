import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gibelbibela/screens/auth/email_verification_screen.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/common/modern_alert_dialog.dart';
import '../home/driver/driver_home_screen.dart';
import '../home/passenger/passenger_home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    _slideController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userCredential = await authService.signInWithEmailAndPassword(_emailController.text.trim(), _passwordController.text);
      // Fetch UserModel from DB
      UserModel? userModel;
      if (userCredential != null) {
        userModel = await DatabaseService().getUserById(userCredential.user?.uid ?? '');
      }

      if (!mounted) return;

      final firebaseUser = userCredential?.user;
      if (firebaseUser == null) {
        _showErrorDialog('Login Failed', 'No user found. Please try again.');
        return;
      }

      await firebaseUser.reload(); // Ensure latest emailVerified
      final refreshedUser = authService.currentUser ?? firebaseUser;

      if (userModel == null) {
        _showErrorDialog('Account Not Found', 'Account data not found. Please complete registration.');
        return;
      }

      if (!refreshedUser.emailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(user: refreshedUser, isDriver: userModel?.role == 'driver'),
          ),
        );
        return;
      }

      if (userModel.role == 'driver') {
        final dbService = Provider.of<DatabaseService>(context, listen: false);
        await dbService.setUserOnlineStatus(userModel.uid, true);
        await dbService.setDriverOnlineStatus(userModel.uid, true);
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const DriverHomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else if (userModel.role == 'passenger') {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => PassengerHomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        _showErrorDialog('Unknown Role', 'Unknown user role. Please contact support.');
      }
    } catch (e) {
      if (!mounted) return;
      _handleAuthError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleAuthError(dynamic error) {
    String title = 'Login Failed';
    String message = 'An unexpected error occurred. Please try again.';

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          title = 'Account Not Found';
          message = 'No account found with this email address. Please check your email or create a new account.';
          break;
        case 'wrong-password':
          title = 'Incorrect Password';
          message = 'The password you entered is incorrect. Please try again.';
          break;
        case 'invalid-email':
          title = 'Invalid Email';
          message = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          title = 'Account Disabled';
          message = 'This account has been disabled. Please contact support.';
          break;
        case 'too-many-requests':
          title = 'Too Many Attempts';
          message = 'Too many failed login attempts. Please try again later.';
          break;
        case 'network-request-failed':
          title = 'Network Error';
          message = 'Please check your internet connection and try again.';
          break;
        default:
          title = 'Authentication Error';
          message = 'Unable to sign in. Please check your credentials and try again.';
      }
    } else if (error.toString().contains('network')) {
      title = 'Connection Error';
      message = 'Please check your internet connection and try again.';
    }

    _showErrorDialog(title, message);
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _goToSignup() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SignupScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      resizeToAvoidBottomInset: true, // Ensure proper keyboard handling
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside
            FocusScope.of(context).unfocus();
          },
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8, // Account for keyboard
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    // Logo and Welcome Section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            // Logo
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.18), blurRadius: 10, spreadRadius: 2)],
                              ),
                              child: const Icon(Icons.local_taxi, color: AppColors.black, size: 32),
                            ),
                            const SizedBox(height: 12),
                            // Welcome Text
                            Text(
                              'Welcome Back!',
                              style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 22, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sign in to continue your journey',
                              style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Login Form
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Email Field
                              _ModernTextField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                label: 'Email',
                                hint: 'Enter your email',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                                isDark: isDark,
                              ),
                              const SizedBox(height: 12),
                              // Password Field
                              _ModernTextField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                label: 'Password',
                                hint: 'Enter your password',
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.getIconColor(isDark)),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                                isDark: isDark,
                              ),
                              const SizedBox(height: 8),
                              // Remember Me & Forgot Password
                              Row(
                                children: [
                                  Row(
                                    children: [
                                      _ModernCheckbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberMe = value ?? false;
                                          });
                                        },
                                        isDark: isDark,
                                      ),
                                      const SizedBox(width: 6),
                                      Text('Remember me', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 12)),
                                    ],
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () async {
                                      final emailController = TextEditingController(text: _emailController.text);
                                      try {
                                        final result = await showDialog<String>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Reset Password'),
                                            content: TextField(
                                              controller: emailController,
                                              keyboardType: TextInputType.emailAddress,
                                              decoration: const InputDecoration(labelText: 'Enter your email'),
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                                              ElevatedButton(onPressed: () => Navigator.of(context).pop(emailController.text.trim()), child: const Text('Send Reset Link')),
                                            ],
                                          ),
                                        );
                                        if (result != null && result.isNotEmpty) {
                                          try {
                                            await Provider.of<AuthService>(context, listen: false).resetPassword(result);
                                            ModernSnackBar.show(context, message: 'Password reset email sent! Check your inbox.');
                                          } catch (e) {
                                            ModernSnackBar.show(context, message: 'Failed to send reset email: ${e.toString()}', isError: true);
                                          }
                                        }
                                      } finally {
                                        emailController.dispose();
                                      }
                                    },
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              // Login Button
                              _ModernButton(text: 'Sign In', onPressed: _isLoading ? null : _login, isLoading: _isLoading, isDark: isDark),
                              const SizedBox(height: 16),
                              // Divider
                              Row(
                                children: [
                                  Expanded(child: Divider(color: AppColors.getDividerColor(isDark), thickness: 1)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(color: AppColors.getTextHintColor(isDark), fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: AppColors.getDividerColor(isDark), thickness: 1)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Sign Up Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Don't have an account? ", style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 13)),
                                  TextButton(
                                    onPressed: _goToSignup,
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(), // Add spacer to push content to top when keyboard is open
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool isDark;

  const _ModernTextField({required this.controller, required this.focusNode, required this.label, required this.hint, required this.icon, this.obscureText = false, this.keyboardType, this.suffixIcon, this.validator, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.getInputBgColor(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorderColor(isDark), width: 1),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.getTextHintColor(isDark), fontSize: 16),
              prefixIcon: Icon(icon, color: AppColors.getIconColor(isDark), size: 24),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModernCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool isDark;

  const _ModernCheckbox({required this.value, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: value ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: value ? AppColors.primary : AppColors.getBorderColor(isDark), width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(4),
          child: value ? const Icon(Icons.check, color: AppColors.black, size: 16) : null,
        ),
      ),
    );
  }
}

class _ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDark;

  const _ModernButton({required this.text, this.onPressed, this.isLoading = false, required this.isDark});

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
              height: 56,
              decoration: BoxDecoration(
                gradient: widget.onPressed != null && !widget.isLoading ? AppColors.primaryGradient : null,
                color: widget.onPressed == null || widget.isLoading ? AppColors.getDividerColor(widget.isDark) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: widget.onPressed != null && !widget.isLoading ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: widget.isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2))
                        : Text(
                            widget.text,
                            style: const TextStyle(color: AppColors.black, fontSize: 18, fontWeight: FontWeight.bold),
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
