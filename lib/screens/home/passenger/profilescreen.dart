// lib/screens/messages/profile_screen.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gibelbibela/models/user_model.dart';
import 'package:gibelbibela/screens/auth/login_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/clodinaryservice.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import '../../../widgets/common/referral_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _fullNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isEditing = false;
  UserModel? _currentUser;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    _slideController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userModel = authService.userModel;
    if (userModel != null) {
      setState(() {
        _currentUser = userModel;
        _fullNameController.text = userModel.fullName;
        _emailController.text = userModel.email;
        _phoneController.text = userModel.phoneNumber ?? '';
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.updateUserProfile(name: _fullNameController.text.trim(), phoneNumber: _phoneController.text.trim());

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });

        ModernSnackBar.show(context, message: 'Profile updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ModernSnackBar.show(context, message: 'Failed to update profile: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ModernAlertDialog(title: 'Logout', message: 'Are you sure you want to logout?', confirmText: 'Logout', cancelText: 'Cancel', icon: Icons.logout, isDestructive: true),
    );

    if (confirmed == true) {
      print('Logout confirmed. Attempting to sign out...');
      final authService = Provider.of<AuthService>(context, listen: false);
      try {
        await authService.signOut();
        print('Sign out successful. Navigating to login screen...');
      } catch (e) {
        print(
          'Sign out error: '
                  '\n' +
              e.toString(),
        );
        // Optionally show a snackbar or dialog
      } finally {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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
        title: Text(
          'Profile',
          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.getIconColor(isDark)),
              onPressed: _toggleEditMode,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Header
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _ProfileHeader(user: _currentUser, isDark: isDark),
                ),
              ),

              const SizedBox(height: 30),

              // Profile Form
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Full Name Field
                        _ProfileField(
                          controller: _fullNameController,
                          focusNode: _fullNameFocusNode,
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          isEnabled: _isEditing,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                          isDark: isDark,
                        ),

                        const SizedBox(height: 20),

                        // Email Field
                        _ProfileField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          isEnabled: false, // Email cannot be edited
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                          isDark: isDark,
                        ),

                        const SizedBox(height: 20),

                        // Phone Field
                        _ProfileField(
                          controller: _phoneController,
                          focusNode: _phoneFocusNode,
                          label: 'Phone Number',
                          icon: Icons.phone_outlined,
                          isEnabled: _isEditing,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            return null;
                          },
                          isDark: isDark,
                        ),

                        const SizedBox(height: 30),

                        // Action Buttons
                        if (_isEditing) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _ModernButton(
                                  text: 'Cancel',
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                      _loadUserData(); // Reset to original values
                                    });
                                  },
                                  isOutlined: true,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _ModernButton(text: 'Save', onPressed: _isLoading ? null : _saveProfile, isLoading: _isLoading, isDark: isDark),
                              ),
                            ],
                          ),
                        ] else ...[
                          _ModernButton(text: 'Edit Profile', onPressed: _toggleEditMode, isDark: isDark),
                        ],

                        const SizedBox(height: 30),

                        // Settings Section
                        _SettingsSection(onLogout: _logout, isDark: isDark),
                      ],
                    ),
                  ),
                ),
              ),
              if (_currentUser?.role == 'driver') ...[const SizedBox(height: 30), _DriverDetailsCard(user: _currentUser)],

              // Referral Card for all users
              const SizedBox(height: 30),
              ReferralCard(userId: _currentUser?.uid ?? '', referrals: _currentUser?.referrals ?? 0, referralAmount: _currentUser?.referralAmount ?? 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatefulWidget {
  final UserModel? user;
  final bool isDark;

  const _ProfileHeader({required this.user, required this.isDark});

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  String? _profileImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _profileImageUrl = widget.user?.profileImageUrl;
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      final cloudinaryService = CloudinaryService(cloudName: 'dunfw4ifc', uploadPreset: 'beauti');
      final uploadedUrl = await cloudinaryService.uploadImage(File(pickedFile.path));
      if (uploadedUrl != null) {
        setState(() => _profileImageUrl = uploadedUrl);
        // Update user profile image in Firestore
        final user = widget.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'profileImage': uploadedUrl});
        }
      }
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.user?.role == 'driver';
    final rating = (widget.user?.rating ?? 3).toDouble();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.black.withOpacity(0.1),
                backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty ? NetworkImage(_profileImageUrl!) : null,
                child: (_profileImageUrl == null || _profileImageUrl!.isEmpty) ? Icon(Icons.person, color: AppColors.black, size: 50) : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploading ? null : _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8)],
                    ),
                    child: _isUploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // User Name
          Text(
            widget.user?.fullName ?? 'User',
            style: const TextStyle(color: AppColors.black, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // User Role
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: AppColors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(
              isDriver ? 'Driver' : 'Passenger',
              style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          if (isDriver) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(5, (i) => Icon(Icons.star, color: i < rating.round() ? Colors.amber : Colors.grey[300], size: 22)),
                const SizedBox(width: 8),
                Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final bool isEnabled;
  final String? Function(String?)? validator;
  final bool isDark;

  const _ProfileField({required this.controller, required this.focusNode, required this.label, required this.icon, required this.isEnabled, this.validator, required this.isDark});

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
            border: Border.all(color: focusNode.hasFocus ? AppColors.primary : AppColors.getBorderColor(isDark), width: focusNode.hasFocus ? 2 : 1),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            enabled: isEnabled,
            validator: validator,
            enableInteractiveSelection: true,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 16),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: focusNode.hasFocus ? AppColors.primary : AppColors.getIconColor(isDark), size: 24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            onTap: () {
              // Ensure proper focus handling
              if (!focusNode.hasFocus) {
                focusNode.requestFocus();
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isDark;

  const _ModernButton({required this.text, this.onPressed, this.isLoading = false, this.isOutlined = false, required this.isDark});

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
                gradient: widget.isOutlined ? null : (widget.onPressed != null && !widget.isLoading ? AppColors.primaryGradient : null),
                color: widget.isOutlined ? Colors.transparent : (widget.onPressed == null || widget.isLoading ? AppColors.getDividerColor(widget.isDark) : null),
                borderRadius: BorderRadius.circular(16),
                border: widget.isOutlined ? Border.all(color: AppColors.primary, width: 2) : null,
                boxShadow: widget.isOutlined ? null : (widget.onPressed != null && !widget.isLoading ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))] : null),
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
                            style: TextStyle(color: widget.isOutlined ? AppColors.primary : AppColors.black, fontSize: 18, fontWeight: FontWeight.bold),
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

class _SettingsSection extends StatelessWidget {
  final VoidCallback onLogout;
  final bool isDark;

  const _SettingsSection({required this.onLogout, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _SettingsItem(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage notification preferences',
          onTap: () {
            // TODO: Implement notifications settings
            ModernSnackBar.show(context, message: 'Notifications settings coming soon!');
          },
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _SettingsItem(
          icon: Icons.security_outlined,
          title: 'Privacy & Security',
          subtitle: 'Manage your privacy settings',
          onTap: () {
            // TODO: Implement privacy settings
            ModernSnackBar.show(context, message: 'Privacy settings coming soon!');
          },
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _SettingsItem(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Get help and contact support',
          onTap: () {
            // TODO: Implement help and support
            ModernSnackBar.show(context, message: 'Help & support coming soon!');
          },
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _SettingsItem(icon: Icons.logout, title: 'Logout', subtitle: 'Sign out of your account', onTap: onLogout, isDestructive: true, isDark: isDark),
      ],
    );
  }
}

class _SettingsItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isDark;

  const _SettingsItem({required this.icon, required this.title, required this.subtitle, required this.onTap, this.isDestructive = false, required this.isDark});

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(widget.isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorderColor(widget.isDark), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: widget.isDestructive ? AppColors.error.withOpacity(0.1) : AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(widget.icon, color: widget.isDestructive ? AppColors.error : AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(color: widget.isDestructive ? AppColors.error : AppColors.getTextPrimaryColor(widget.isDark), fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(widget.subtitle, style: TextStyle(color: AppColors.getTextSecondaryColor(widget.isDark), fontSize: 14)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: AppColors.getIconColor(widget.isDark), size: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DriverDetailsCard extends StatefulWidget {
  final UserModel? user;
  const _DriverDetailsCard({required this.user});

  @override
  State<_DriverDetailsCard> createState() => _DriverDetailsCardState();
}

class _DriverDetailsCardState extends State<_DriverDetailsCard> {
  Map<String, dynamic>? driverProfile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDriverProfile();
  }

  Future<void> _fetchDriverProfile() async {
    if (widget.user == null) return;
    final doc = await FirebaseFirestore.instance.collection('drivers').doc(widget.user!.uid).get();
    setState(() {
      driverProfile = doc.data();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Driver Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            _detailRow('Phone', widget.user?.phoneNumber ?? 'Not set', Icons.phone),
            const SizedBox(height: 10),
            _detailRow('Province', driverProfile?['province'] ?? 'Not set', Icons.location_on),
            const SizedBox(height: 10),
            _detailRow('Car Model', driverProfile?['vehicleModel'] ?? 'Not set', Icons.directions_car),
            const SizedBox(height: 10),
            _detailRow('Number Plate', driverProfile?['licensePlate'] ?? 'Not set', Icons.confirmation_number),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w400)),
        ),
      ],
    );
  }
}
