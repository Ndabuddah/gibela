import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart' show AppColors;
import '../../constants/app_constants.dart';
import '../../constants/provinces.dart';
import '../../models/driver_model.dart';
import '../../screens/payments/payment_screen.dart';
import '../../services/clodinaryservice.dart' show CloudinaryService;
import '../../services/database_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/driver/document_upload.dart';
import 'congratulations_screen.dart';

class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({Key? key}) : super(key: key);

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  final List<String> _vehiclePurposes = [
    '1-2 seater',
    '1-4 seater',
    '7 seater',
    'students',
    'luxury',
    'packages',
    'females',
  ];
  final Map<String, String> _purposeInfo = {
    '1-2 seater': 'These are small vehicles that can only take 1 or 2 passengers.',
    '1-4 seater': 'Standard vehicles that can take up to 4 passengers.',
    '7 seater': 'Larger vehicles that can take up to 7 passengers.',
    'students': 'Only students can select this. You will only be matched with student passengers.',
    'luxury': 'High-end vehicles for premium rides.',
    'packages': 'Anyone can select this. For delivering packages.',
    'females': 'Only female drivers can select this. This is for female-only rides.',
  };
  List<String> _selectedPurposes = [];

  Widget _buildPurposeOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userIsFemale = _genderIsFemale(); // You may need to implement a gender field if not present
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _vehiclePurposes.map((purpose) {
        final isFemaleOnly = purpose == 'females';
        final isStudentOnly = purpose == 'students';
        final isDisabled = isFemaleOnly && !userIsFemale;
        return Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(purpose, style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showPurposeInfoDialog(context, purpose),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.11),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            selected: _selectedPurposes.contains(purpose),
            selectedColor: AppColors.primary.withOpacity(0.18),
            backgroundColor: isDark ? Colors.black12 : Colors.white,
            checkmarkColor: AppColors.primary,
            onSelected: isDisabled
                ? null
                : (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPurposes.add(purpose);
                      } else {
                        _selectedPurposes.remove(purpose);
                      }
                    });
                  },
          ),
        );
      }).toList(),
    );
  }

  void _showPurposeInfoDialog(BuildContext context, String purpose) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(purpose, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(_purposeInfo[purpose] ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _genderIsFemale() {
    // TODO: Replace with real gender check if available (e.g. from user profile or registration field)
    // For now, always allow
    return true;
  }
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers for new fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehicleColorController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();

  final cloudinaryService = CloudinaryService(cloudName: 'dunfw4ifc', uploadPreset: 'beauti' // Replace with your upload preset
      );

  String _selectedVehicleType = 'small';
  String? _selectedProvince;
  List<String> _towns = [];
  List<String> _selectedTowns = [];

  // 1. Add lists for car brands, models, and colors
  final List<String> carBrands = ['Toyota', 'Volkswagen', 'BMW', 'Mercedes', 'Ford', 'Nissan', 'Hyundai', 'Kia', 'Mazda', 'Other'];
  final Map<String, List<String>> carModels = {
    'Toyota': ['Corolla', 'Hilux', 'Fortuner', 'Yaris', 'Quantum', 'Other'],
    'Volkswagen': ['Polo', 'Golf', 'Tiguan', 'Amarok', 'Caddy', 'Other'],
    'BMW': ['1 Series', '3 Series', '5 Series', 'X1', 'X3', 'Other'],
    'Mercedes': ['A-Class', 'C-Class', 'E-Class', 'GLA', 'Vito', 'Other'],
    'Ford': ['Fiesta', 'Ranger', 'EcoSport', 'Focus', 'Other'],
    'Nissan': ['NP200', 'Almera', 'Navara', 'Qashqai', 'Other'],
    'Hyundai': ['i10', 'i20', 'Tucson', 'H-1', 'Other'],
    'Kia': ['Picanto', 'Rio', 'Sportage', 'Sorento', 'Other'],
    'Mazda': ['Mazda2', 'Mazda3', 'CX-5', 'BT-50', 'Other'],
    'Other': ['Other'],
  };
  final List<String> carColors = ['White', 'Black', 'Silver', 'Blue', 'Red', 'Grey', 'Green', 'Yellow', 'Brown', 'Other'];
  String? _selectedBrand;
  String? _selectedModel;
  String? _selectedColor;

  final Map<String, File?> _documents = {
    'ID Document': null,
    'Professional Driving Permit': null,
    'Roadworthy Certificate': null,
    'Vehicle Image': null,
    'Driver Profile Image': null,
    'Driver Image Next to Vehicle': null,
    'Bank Statement': null,
  };

  bool _isLoading = false;
  bool _showThankYou = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _idNumberController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    _licensePlateController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(String documentType, {bool isCamera = false}) async {
    final picker = ImagePicker();
    final pickedFile = isCamera ? await picker.pickImage(source: ImageSource.camera, imageQuality: 80) : await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _documents[documentType] = File(pickedFile.path);
      });
    }
  }

  // Update _payR100 to navigate to PaymentScreen and only save after payment
  Future<void> _payR100() async {
    if (!_formKey.currentState!.validate() || _selectedTowns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields and select at least one town.')),
      );
      return;
    }
    if (!_allDocsUploaded()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required documents.')),
      );
      return;
    }
    final email = _emailController.text;
    final amount = 100.0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: amount,
          email: email,
          onPaymentSuccess: () async {
            Navigator.pop(context); // Close PaymentScreen
            await _submitDriverProfile();
            // Optionally show congratulations screen here
          },
        ),
      ),
    );
  }

  Future<void> _submitDriverProfile() async {
    setState(() => _isLoading = true);
    final Map<String, String> docUrls = {}; // Ensure this is a Map<String, String>
    String? profileImageUrl;
    try {
      // Iterate over the documents and upload to Cloudinary
      for (final entry in _documents.entries) {
        final file = entry.value; // This is your file (image or document)
        if (file != null) {
          final uploadedUrl = await cloudinaryService.uploadImage(file);
          if (uploadedUrl != null) {
            docUrls[entry.key] = uploadedUrl; // Store as String, not List<Map>
            if (entry.key == 'Driver Profile Image') {
              profileImageUrl = uploadedUrl;
            }
          } else {
            print('Failed to upload ${entry.key}');
          }
        } else {
          print('No file selected for ${entry.key}');
        }
      }

      // Ensure profile image is present
      if (profileImageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a profile image.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Use the current authenticated user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not logged in. Please log in again.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Determine driver preferences based on selected purposes
      final isFemale = _selectedPurposes.contains('females');
      final isForStudents = _selectedPurposes.contains('students');
      final isLuxury = _selectedPurposes.contains('luxury');
      final isMax2 = _selectedPurposes.contains('1-2 seater');

      // Create driver model
      final driverModel = DriverModel(
        userId: user.uid,
        idNumber: _idNumberController.text.trim(),
        name: _nameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        email: _emailController.text.trim(),
        province: _selectedProvince,
        towns: _selectedTowns,
        documents: docUrls,
        vehicleType: _selectedVehicleType,
        vehicleModel: _selectedModel,
        vehicleColor: _selectedColor,
        licensePlate: _licensePlateController.text.trim(),
        isFemale: isFemale,
        isForStudents: isForStudents,
        isLuxury: isLuxury,
        isMax2: isMax2,
        vehiclePurposes: _selectedPurposes,
      );

      // Save driver profile
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      await databaseService.createDriverProfile(driverModel);

      // Handle referral if provided
      final referralCode = _referralCodeController.text.trim();
      if (referralCode.isNotEmpty) {
        await _handleReferral(referralCode, user.uid);
      }

      setState(() => _isLoading = false);

      if (!mounted) return;

      // Navigate to congratulations screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const CongratulationsScreen(),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  // Handle referral processing
  Future<void> _handleReferral(String referralCode, String newDriverId) async {
    try {
      // Check if the referral code exists (it should be a user's UID)
      final referrerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(referralCode)
          .get();

      if (referrerDoc.exists) {
        // Update referrer's referral stats
        await FirebaseFirestore.instance
            .collection('users')
            .doc(referralCode)
            .update({
          'referrals': FieldValue.increment(1),
          'referralAmount': FieldValue.increment(15.0), // R15 per referral
          'lastReferral': FieldValue.serverTimestamp(),
        });

        // Add referral record
        await FirebaseFirestore.instance
            .collection('referrals')
            .add({
          'referrerId': referralCode,
          'referredDriverId': newDriverId,
          'amount': 15.0,
          'status': 'pending', // Will be 'completed' when driver is approved
          'createdAt': FieldValue.serverTimestamp(),
        });

        print('Referral processed successfully for referrer: $referralCode');
      } else {
        print('Referral code not found: $referralCode');
      }
    } catch (e) {
      print('Error processing referral: $e');
      // Don't throw error to avoid blocking driver registration
    }
  }

  void _onProvinceSelected(String? province) {
    setState(() {
      _selectedProvince = province;
      _towns = provinceTowns[province] ?? [];
      _selectedTowns.clear(); // Clear selected towns for new province
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Ensure proper keyboard handling
      appBar: AppBar(
        title: const Text('Driver Registration'),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16, // Account for keyboard
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Complete your driver profile',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    const Text('Please provide the required information to register as a driver', style: TextStyle(color: AppColors.textLight)),
                    const SizedBox(height: 24),

                    // Name (non-editable if already provided)
                    AbsorbPointer(
                      absorbing: _nameController.text.isNotEmpty,
                      child: CustomTextField(
                        controller: _nameController,
                        label: 'Name',
                        hintText: _nameController.text.isNotEmpty ? _nameController.text : 'Enter your name',
                        prefixIcon: Icons.person,
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
                        readOnly: _nameController.text.isNotEmpty,
                      ),
                    ),

                    // Profile Image (show preview, not editable if already provided)
                    if (_documents['Driver Profile Image'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Profile Image', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_documents['Driver Profile Image']!, height: 80, width: 80, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 16),
                        ],
                      )
                    else
                      DocumentUpload(
                        title: 'Driver Profile Image',
                        file: _documents['Driver Profile Image'],
                        onTap: () => _pickDocument('Driver Profile Image'),
                      ),

                    // Phone Number (num keyboard)
                    CustomTextField(
                      controller: _phoneNumberController,
                      label: 'Phone Number',
                      hintText: 'Enter your phone number',
                      prefixIcon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null,
                    ),

                    // Email (non-editable if already provided)
                    AbsorbPointer(
                      absorbing: _emailController.text.isNotEmpty,
                      child: CustomTextField(
                        controller: _emailController,
                        label: 'Email',
                        hintText: _emailController.text.isNotEmpty ? _emailController.text : 'Enter your email',
                        prefixIcon: Icons.email,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your email';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Please enter a valid email';
                          return null;
                        },
                        readOnly: _emailController.text.isNotEmpty,
                      ),
                    ),

                    // ID Number (num keyboard)
                    CustomTextField(
                      controller: _idNumberController,
                      label: 'ID Number',
                      hintText: 'Enter your ID number',
                      prefixIcon: Icons.badge,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your ID number';
                        if (value.length != 13) return 'ID number must be 13 digits';
                        return null;
                      },
                    ),

                    // Vehicle Brand Dropdown
                    const Text('Vehicle Brand', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedBrand,
                      hint: const Text('Select brand'),
                      items: carBrands.map((brand) => DropdownMenuItem(value: brand, child: Text(brand))).toList(),
                      onChanged: (brand) {
                        setState(() {
                          _selectedBrand = brand;
                          _selectedModel = null;
                        });
                      },
                      validator: (value) => value == null ? 'Please select a brand' : null,
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Model Dropdown (depends on brand)
                    if (_selectedBrand != null)
                      DropdownButtonFormField<String>(
                        value: _selectedModel,
                        hint: const Text('Select model'),
                        items: carModels[_selectedBrand]!.map((model) => DropdownMenuItem(value: model, child: Text(model))).toList(),
                        onChanged: (model) {
                          setState(() {
                            _selectedModel = model;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a model' : null,
                      ),
                    const SizedBox(height: 16),

                    // Vehicle Color Dropdown
                    const Text('Vehicle Color', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedColor,
                      hint: const Text('Select color'),
                      items: carColors.map((color) => DropdownMenuItem(value: color, child: Text(color))).toList(),
                      onChanged: (color) {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      validator: (value) => value == null ? 'Please select a color' : null,
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Purpose Selection
                    const SizedBox(height: 24),
                    const Text('Choose what you would like to do', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    _buildPurposeOptions(context),
                    const SizedBox(height: 24),
                    // Province Dropdown
                    const Text('Select Province', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _selectedProvince,
                      hint: const Text('Choose a province'),
                      onChanged: _onProvinceSelected,
                      items: provinceTowns.keys.map((String province) {
                        return DropdownMenuItem<String>(
                          value: province,
                          child: Text(province),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Town Selection
                    const Text('Select Towns', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0,
                      children: _towns.map((town) {
                        return ChoiceChip(
                          label: Text(town),
                          selected: _selectedTowns.contains(town),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTowns.add(town);
                              } else {
                                _selectedTowns.remove(town);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Document Uploads
                    const Text('Required Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    const Text('Please upload clear photos of the following documents', style: TextStyle(color: AppColors.textLight)),
                    const SizedBox(height: 16),

                    // Document upload widgets
                    ...AppConstants.requiredDriverDocuments.map((doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DocumentUpload(
                            title: doc,
                            file: _documents[doc],
                            onTap: () => _pickDocument(doc),
                          ),
                        )),
                    DocumentUpload(
                      title: 'Bank Statement',
                      file: _documents['Bank Statement'],
                      onTap: () => _pickDocument('Bank Statement'),
                    ),
                    const SizedBox(height: 18),
                    const SizedBox(height: 24),

                    // Referral Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            AppColors.primary.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.card_giftcard,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Referral Bonus',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      'Did someone refer you? Enter their code!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _referralCodeController,
                            label: 'Referral Code (Optional)',
                            hintText: 'Enter referral code here',
                            prefixIcon: Icons.person_add,
                            validator: (value) => null, // Optional field
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.monetization_on,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Refer drivers and earn R15 per successful referral!',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    CustomButton(
                      text: 'Pay R100 & Submit Application',
                      onPressed: _payR100,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 30),

                    // Note about approval
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Application Review', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                SizedBox(height: 4),
                                Text('Your application will be reviewed within 48 hours. You\'ll be notified once approved.', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isLoading) const LoadingIndicator(),
        ],
      ),
    ));
  }

  Widget _buildVehicleTypeOption(String type, String label) {
    final isSelected = _selectedVehicleType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedVehicleType = type;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _allDocsUploaded() => _documents.values.every((file) => file != null);
}
