import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/keyboard_safe_wrapper.dart';
import '../home/driver_no_car/driver_no_car_home_screen.dart';

class NoCarApplicationScreen extends StatefulWidget {
  final User user;
  final UserModel userModel;

  const NoCarApplicationScreen({
    super.key,
    required this.user,
    required this.userModel,
  });

  @override
  State<NoCarApplicationScreen> createState() => _NoCarApplicationScreenState();
}

class _NoCarApplicationScreenState extends State<NoCarApplicationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _experienceController = TextEditingController();
  final _preferredAreasController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _preferencesController = TextEditingController();

  bool _isLoading = false;
  String _selectedExperience = '0-1 years';
  List<String> _selectedPreferences = [];
  List<String> _selectedAreas = [];

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _experienceOptions = [
    '0-1 years',
    '1-3 years',
    '3-5 years',
    '5+ years',
  ];

  final List<String> _preferenceOptions = [
    'Flexible hours',
    'Weekends only',
    'Evening shifts',
    'Morning shifts',
    'Long distance trips',
    'Local trips only',
    'Luxury vehicles',
    'Economy vehicles',
  ];

  final List<String> _areaOptions = [
    'Johannesburg CBD',
    'Sandton',
    'Rosebank',
    'Melville',
    'Parktown',
    'Braamfontein',
    'Newtown',
    'Maboneng',
    'Soweto',
    'Roodepoort',
    'Randburg',
    'Fourways',
    'Midrand',
    'Centurion',
    'Pretoria',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _experienceController.dispose();
    _preferredAreasController.dispose();
    _availabilityController.dispose();
    _preferencesController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one preferred area'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // Create application data
      final applicationData = {
        'userId': widget.user.uid,
        'idNumber': _idNumberController.text.trim(),
        'drivingExperience': _selectedExperience,
        'preferredAreas': _selectedAreas,
        'preferences': _selectedPreferences,
        'availability': _availabilityController.text.trim(),
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'name': widget.userModel.name,
        'email': widget.userModel.email,
        'phoneNumber': widget.userModel.phoneNumber,
      };

      // Save application to specific collection for driver no car users
      await FirebaseFirestore.instance
          .collection('driver_no_car_applications')
          .doc(widget.user.uid)
          .set(applicationData);

      // Update user model with application status
      final updatedUserModel = widget.userModel.copyWith(
        isApproved: false,
        requiresDriverSignup: false,
        userRole: 'driver_no_car',
        isDriverNoCar: true,
      );

      await databaseService.updateUserProfile(widget.user.uid, updatedUserModel.toMap());

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DriverNoCarHomeScreen(userModel: updatedUserModel),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Driver Application'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getIconColor(isDark)),
      ),
      body: KeyboardSafeWrapper(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimaryColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us about yourself to help us find the best vehicle offers for you.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.getTextSecondaryColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ID Number
                    CustomTextField(
                      controller: _idNumberController,
                      label: 'ID Number',
                      hintText: 'Enter your South African ID number',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your ID number';
                        }
                        if (value.trim().length != 13) {
                          return 'ID number must be 13 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Driving Experience
                    Text(
                      'Driving Experience',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimaryColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.getCardColor(isDark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.getBorderColor(isDark)),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedExperience,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: _experienceOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedExperience = newValue!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Preferred Areas
                    Text(
                      'Preferred Service Areas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimaryColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _areaOptions.map((area) {
                        final isSelected = _selectedAreas.contains(area);
                        return FilterChip(
                          label: Text(area),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAreas.add(area);
                              } else {
                                _selectedAreas.remove(area);
                              }
                            });
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Preferences
                    Text(
                      'Work Preferences',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimaryColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _preferenceOptions.map((preference) {
                        final isSelected = _selectedPreferences.contains(preference);
                        return FilterChip(
                          label: Text(preference),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPreferences.add(preference);
                              } else {
                                _selectedPreferences.remove(preference);
                              }
                            });
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Availability
                    CustomTextField(
                      controller: _availabilityController,
                      label: 'Availability',
                      hintText: 'e.g., Weekdays 8 AM - 6 PM, Weekends flexible',
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please describe your availability';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    CustomButton(
                      text: 'Submit Application',
                      onPressed: _isLoading ? null : _submitApplication,
                      isFullWidth: true,
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