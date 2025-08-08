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
import '../home/car_owner/car_owner_home_screen.dart';

class OwnerApplicationScreen extends StatefulWidget {
  final User user;
  final UserModel userModel;

  const OwnerApplicationScreen({
    super.key,
    required this.user,
    required this.userModel,
  });

  @override
  State<OwnerApplicationScreen> createState() => _OwnerApplicationScreenState();
}

class _OwnerApplicationScreenState extends State<OwnerApplicationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _vehicleConditionController = TextEditingController();
  final _dailyRateController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  String _selectedVehicleType = 'Sedan';
  String _selectedTransmission = 'Automatic';
  String _selectedFuelType = 'Petrol';
  List<String> _selectedFeatures = [];
  List<String> _selectedServiceAreas = [];

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _vehicleTypes = [
    'Sedan',
    'SUV',
    'Hatchback',
    'Coupe',
    'Convertible',
    'Van',
    'Truck',
  ];

  final List<String> _transmissionTypes = [
    'Automatic',
    'Manual',
  ];

  final List<String> _fuelTypes = [
    'Petrol',
    'Diesel',
    'Hybrid',
    'Electric',
  ];

  final List<String> _featureOptions = [
    'Air Conditioning',
    'Bluetooth',
    'GPS Navigation',
    'Backup Camera',
    'Leather Seats',
    'Sunroof',
    'Alloy Wheels',
    'Tinted Windows',
    'Child Safety Seats',
    'WiFi Hotspot',
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
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _licensePlateController.dispose();
    _vehicleConditionController.dispose();
    _dailyRateController.dispose();
    _descriptionController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedServiceAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service area'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // Create vehicle offer data
      final vehicleData = {
        'ownerId': widget.user.uid,
        'ownerName': widget.userModel.name,
        'ownerEmail': widget.userModel.email,
        'ownerPhone': widget.userModel.phoneNumber,
        'vehicleMake': _vehicleMakeController.text.trim(),
        'vehicleModel': _vehicleModelController.text.trim(),
        'vehicleYear': _vehicleYearController.text.trim(),
        'licensePlate': _licensePlateController.text.trim(),
        'vehicleType': _selectedVehicleType,
        'transmission': _selectedTransmission,
        'fuelType': _selectedFuelType,
        'vehicleCondition': _vehicleConditionController.text.trim(),
        'dailyRate': double.parse(_dailyRateController.text.trim()),
        'description': _descriptionController.text.trim(),
        'features': _selectedFeatures,
        'serviceAreas': _selectedServiceAreas,
        'status': 'active',
        'isAvailable': true,
        'createdAt': DateTime.now().toIso8601String(),
        'rating': 0.0,
        'totalRentals': 0,
      };

      // Save vehicle offer to specific collection for car owners
      await FirebaseFirestore.instance
          .collection('car_owner_applications')
          .doc(widget.user.uid)
          .set(vehicleData);

      // Update user model with owner status
      final updatedUserModel = widget.userModel.copyWith(
        isApproved: false, // Set to false for now since feature is not fully functional
        requiresDriverSignup: false,
        userRole: 'car_owner',
        isCarOwner: true,
      );

      await databaseService.updateUserProfile(widget.user.uid, updatedUserModel.toMap());

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CarOwnerHomeScreen(userModel: updatedUserModel),
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
        title: const Text('Vehicle Registration'),
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
                      'Register Your Vehicle',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimaryColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'List your vehicle and start earning from qualified drivers.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.getTextSecondaryColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Vehicle Make
                    CustomTextField(
                      controller: _vehicleMakeController,
                      label: 'Vehicle Make',
                      hintText: 'e.g., Toyota, BMW, Mercedes',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter vehicle make';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Vehicle Model
                    CustomTextField(
                      controller: _vehicleModelController,
                      label: 'Vehicle Model',
                      hintText: 'e.g., Corolla, X3, C-Class',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter vehicle model';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Vehicle Year
                    CustomTextField(
                      controller: _vehicleYearController,
                      label: 'Year',
                      hintText: 'e.g., 2020',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter vehicle year';
                        }
                        final year = int.tryParse(value.trim());
                        if (year == null || year < 1990 || year > DateTime.now().year + 1) {
                          return 'Please enter a valid year';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // License Plate
                    CustomTextField(
                      controller: _licensePlateController,
                      label: 'License Plate',
                      hintText: 'e.g., CA 123-456',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter license plate';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Vehicle Type
                    Text(
                      'Vehicle Type',
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
                        value: _selectedVehicleType,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: _vehicleTypes.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedVehicleType = newValue!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Transmission
                    Text(
                      'Transmission',
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
                        value: _selectedTransmission,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: _transmissionTypes.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedTransmission = newValue!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Fuel Type
                    Text(
                      'Fuel Type',
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
                        value: _selectedFuelType,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: _fuelTypes.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedFuelType = newValue!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Vehicle Condition
                    CustomTextField(
                      controller: _vehicleConditionController,
                      label: 'Vehicle Condition',
                      hintText: 'e.g., Excellent condition, well maintained',
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please describe vehicle condition';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Daily Rate
                    CustomTextField(
                      controller: _dailyRateController,
                      label: 'Daily Rate (R)',
                      hintText: 'e.g., 500',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter daily rate';
                        }
                        final rate = double.tryParse(value.trim());
                        if (rate == null || rate <= 0) {
                          return 'Please enter a valid rate';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Features
                    Text(
                      'Vehicle Features',
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
                      children: _featureOptions.map((feature) {
                        final isSelected = _selectedFeatures.contains(feature);
                        return FilterChip(
                          label: Text(feature),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFeatures.add(feature);
                              } else {
                                _selectedFeatures.remove(feature);
                              }
                            });
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Service areas
                    Text(
                      'Service Areas',
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
                        final isSelected = _selectedServiceAreas.contains(area);
                        return FilterChip(
                          label: Text(area),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedServiceAreas.add(area);
                              } else {
                                _selectedServiceAreas.remove(area);
                              }
                            });
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Description
                    CustomTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hintText: 'Tell drivers about your vehicle and any special requirements...',
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please provide a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    CustomButton(
                      text: 'Register Vehicle',
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