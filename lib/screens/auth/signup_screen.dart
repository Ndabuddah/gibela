// lib/screens/auth/signup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/network_service.dart';
import '../../services/clodinaryservice.dart';
import '../../widgets/common/modern_alert_dialog.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'no_car_application_screen.dart';
import 'owner_application_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _surnameController = TextEditingController();

  final _fullNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  String _selectedRole = 'passenger';
  
  // Profile image
  File? _profileImage;
  final CloudinaryService _cloudinaryService = CloudinaryService(
    cloudName: 'dunfw4ifc', 
    uploadPreset: 'beauti'
  );

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

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _fullNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ModernSnackBar.show(context, message: 'Please agree to the terms and conditions', isError: true);
      return;
    }

    // Check if profile image is selected for passengers
    if (_selectedRole == 'passenger' && _profileImage == null) {
      ModernSnackBar.show(context, message: 'Please select a profile image', isError: true);
      return;
    }

    // Check network connectivity first
    print('🌐 Checking network connectivity...');
    await NetworkService.logNetworkStatus();

    final hasNetwork = await NetworkService.checkNetworkBeforeOperation(context);
    if (!hasNetwork) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🚀 Starting signup process...');
      print('📝 Form data:');
      print('- Full Name: ${_fullNameController.text}');
      print('- Email: ${_emailController.text}');
      print('- Phone: ${_phoneController.text}');
      print('- Role: $_selectedRole');

      final authService = Provider.of<AuthService>(context, listen: false);
      final userCredential = await authService.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (userCredential != null) {
        final user = userCredential.user;
        if (user != null) {
          print('✅ Firebase Auth user created: ${user.uid}');

          // Upload profile image if selected
          String? profileImageUrl;
          if (_profileImage != null) {
            print('📸 Uploading profile image...');
            profileImageUrl = await _cloudinaryService.uploadImage(_profileImage!);
            print('✅ Profile image uploaded: $profileImageUrl');
          }

          // Create user model
          final userModel = UserModel(
            uid: user.uid,
            email: _emailController.text.trim(),
            name: _fullNameController.text.trim(),
            surname: _surnameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            // Enforce driver flags
            isDriver: _selectedRole == 'driver' || _selectedRole == 'driver_no_car' || _selectedRole == 'car_owner',
            // Force isApproved to false for drivers
            isApproved: _selectedRole == 'driver' || _selectedRole == 'driver_no_car' || _selectedRole == 'car_owner' ? false : true,
            // Force driver signup requirement
            requiresDriverSignup: _selectedRole == 'driver' || _selectedRole == 'driver_no_car' || _selectedRole == 'car_owner' ? true : false,
            // Set initial status - removed approvalStatus as it's not a parameter
            // Initialize other fields
            savedAddresses: const [],
            recentRides: const [],
            isOnline: false,
            rating: 5.0,
            missingProfileFields: _selectedRole == 'driver' || _selectedRole == 'driver_no_car' || _selectedRole == 'car_owner' ? const ['Driver Profile'] : const [],
            referrals: 0,
            referralAmount: 0.0,
            lastReferral: null,
            isGirl: false,
            isStudent: false,
            profileImage: profileImageUrl, // Set profile image URL
            photoUrl: null,
            // Add role-specific fields
            userRole: _selectedRole,
            isCarOwner: _selectedRole == 'car_owner',
            isDriverNoCar: _selectedRole == 'driver_no_car',
          );
          print('✅ UserModel created: ${userModel.name}');
          print('🚗 Is Driver: ${userModel.isDriver}');
          print('✓ Is Approved: ${userModel.isApproved}');
          print('📝 Requires Driver Signup: ${userModel.requiresDriverSignup}');
          print('📸 Profile Image: ${userModel.profileImage != null ? 'Set' : 'Not set'}');

          // Save passenger details to Firestore
          print('💾 Saving user to Firestore...');
          await Provider.of<DatabaseService>(context, listen: false).createUser(userModel);
          print('✅ User saved to Firestore');

          if (!mounted) {
            print('⚠️ Widget not mounted, returning');
            return;
          }

          // Navigate based on role - all users go through email verification
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(
                user: user,
                isDriver: _selectedRole == 'driver' || _selectedRole == 'driver_no_car' || _selectedRole == 'car_owner',
              ),
            ),
          );
          print('✅ Navigation completed');
          return;
        } else {
          print('❌ User object is null');
        }
      } else {
        print('❌ UserCredential is null');
      }
    } catch (e) {
      print('💥 Signup error: $e');
      print('💥 Error type: ${e.runtimeType}');
      print('💥 Error stack trace: ${StackTrace.current}');

      if (!mounted) {
        print('⚠️ Widget not mounted during error, returning');
        return;
      }

      String errorMessage = 'Signup failed';
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'An account with this email already exists';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Password is too weak. Please use a stronger password';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Please enter a valid email address';
      } else if (e.toString().contains('network-request-failed') || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        errorMessage = 'Network error. Please check your internet connection and try again';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Please check your Firebase configuration';
      } else {
        errorMessage = 'Signup failed: ${e.toString()}';
      }

      ModernSnackBar.show(context, message: errorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(animation),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getIconColor(isDark)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside
            FocusScope.of(context).unfocus();
          },
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24, // Account for keyboard
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Section
                    Column(
                      children: [
                        Text(
                          'Create Account',
                          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 32, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join RideApp and start your journey',
                          style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Signup Form
                    Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Full Name Field
                          _ModernTextField(
                            controller: _fullNameController,
                            focusNode: _fullNameFocusNode,
                            label: 'Full Name',
                            hint: 'Enter your full name',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                            isDark: isDark,
                          ),

                          const SizedBox(height: 20),
                          // Surname Field
                          _ModernTextField(
                            controller: _surnameController,
                            focusNode: FocusNode(),
                            label: 'Surname',
                            hint: 'Enter your surname',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your surname';
                              }
                              return null;
                            },
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),

                          // Role Selection
                          _RoleSelectionCard(
                            selectedRole: _selectedRole,
                            onRoleChanged: (role) {
                              setState(() {
                                _selectedRole = role;
                                // Clear profile image when switching away from passenger
                                if (role != 'passenger') {
                                  _profileImage = null;
                                }
                              });
                            },
                            isDark: isDark,
                          ),

                          const SizedBox(height: 20),

                          // Profile Image Section (for passengers)
                          if (_selectedRole == 'passenger') ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Profile Image',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.getTextPrimaryColor(isDark),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: _pickProfileImage,
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                                      child: _profileImage == null 
                                        ? Icon(Icons.camera_alt, size: 40, color: Colors.grey[600])
                                        : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to add profile picture',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.getTextSecondaryColor(isDark),
                                    ),
                                  ),
                                  if (_profileImage == null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Profile image is required for passengers',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

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

                          const SizedBox(height: 20),

                          // Phone Field
                          _ModernTextField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            label: 'Phone Number',
                            hint: 'Enter your phone number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              return null;
                            },
                            isDark: isDark,
                          ),

                          const SizedBox(height: 20),

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



                          // Terms and Conditions
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ModernCheckbox(
                                value: _agreeToTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _agreeToTerms = value ?? false;
                                  });
                                },
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 14),
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Terms & Conditions',
                                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                      ),
                                      const TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // Signup Button
                          _ModernButton(text: 'Create Account', onPressed: _isLoading ? null : _signup, isLoading: _isLoading, isDark: isDark),

                          const SizedBox(height: 30),

                          // Login Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Already have an account? ', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 16)),
                              TextButton(
                                onPressed: _goToLogin,
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
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

class _RoleSelectionCard extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final bool isDark;

  const _RoleSelectionCard({required this.selectedRole, required this.onRoleChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I want to join as',
          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        // 2x2 Grid for role options
        Column(
          children: [
            Row(
              children: [
                Flexible(
                  flex: 1,
                  child: _RoleOption(title: 'Passenger', subtitle: 'Book rides', icon: Icons.person, isSelected: selectedRole == 'passenger', onTap: () => onRoleChanged('passenger'), isDark: isDark),
                ),
                const SizedBox(width: 12),
                Flexible(
                  flex: 1,
                  child: _RoleOption(title: 'Driver', subtitle: 'Provide rides', icon: Icons.local_taxi, isSelected: selectedRole == 'driver', onTap: () => onRoleChanged('driver'), isDark: isDark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  flex: 1,
                  child: _RoleOption(title: 'Driver (No Car)', subtitle: 'Find vehicle offers', icon: Icons.directions_car_outlined, isSelected: selectedRole == 'driver_no_car', onTap: () => onRoleChanged('driver_no_car'), isDark: isDark),
                ),
                const SizedBox(width: 12),
                Flexible(
                  flex: 1,
                  child: _RoleOption(title: 'Car Owner', subtitle: 'Offer your vehicle', icon: Icons.car_rental, isSelected: selectedRole == 'car_owner', onTap: () => onRoleChanged('car_owner'), isDark: isDark),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _RoleOption({required this.title, required this.subtitle, required this.icon, required this.isSelected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.getCardColor(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.getBorderColor(isDark), width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.getIconColor(isDark), size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(color: isSelected ? AppColors.primary : AppColors.getTextPrimaryColor(isDark), fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 12)),
          ],
        ),
      ),
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
        // DEBUG: Add a red border to see the tap area
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 0, spreadRadius: 0)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            print('Checkbox tapped!');
            onChanged(!value);
          },
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
