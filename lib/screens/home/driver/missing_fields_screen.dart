import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/provinces.dart';
import '../../../models/user_model.dart';
import '../../../services/database_service.dart';
import '../../../services/clodinaryservice.dart';
import '../../../widgets/common/custom_button.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/driver/document_upload.dart';
import 'driver_home_screen.dart';

class MissingFieldsScreen extends StatefulWidget {
  final List<String> missingFields;
  final UserModel user;

  const MissingFieldsScreen({
    Key? key,
    required this.missingFields,
    required this.user,
  }) : super(key: key);

  @override
  State<MissingFieldsScreen> createState() => _MissingFieldsScreenState();
}

class _MissingFieldsScreenState extends State<MissingFieldsScreen> {
  final CloudinaryService _cloudinaryService = CloudinaryService(
    cloudName: 'dunfw4ifc', 
    uploadPreset: 'beauti'
  );
  
  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();
  
  // Form state
  String? _selectedProvince;
  List<String> _selectedTowns = [];
  String? _selectedVehicleType;
  String? _selectedColor;
  
  // Document uploads
  final Map<String, File?> _documents = {
    'ID Document': null,
    'Professional Driving Permit': null,
    'Roadworthy Certificate': null,
    'Vehicle Image': null,
    'Driver Profile Image': null,
    'Driver Image Next to Vehicle': null,
    'Bank Statement': null,
    'Profile Image': null, // For passengers
  };
  
  // Loading state
  bool _isLoading = false;
  String _loadingMessage = '';
  
  // Towns list
  List<String> _towns = [];
  
  @override
  void initState() {
    super.initState();
    _checkDriverStatus();
    _loadExistingData();
  }

  // Check if driver is already approved and redirect if necessary
  Future<void> _checkDriverStatus() async {
    try {
      if (widget.user.isDriver && widget.user.isApproved) {
        // Driver is already approved, redirect to home screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const DriverHomeScreen(),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking driver status: $e');
    }
  }
  
  void _setLoading(bool loading, {String message = ''}) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
        _loadingMessage = message;
      });
    }
  }
  
  Future<void> _loadExistingData() async {
    try {
      // Load existing driver data
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.user.uid)
          .get();
      
      if (driverDoc.exists) {
        final driverData = driverDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _nameController.text = driverData['name'] ?? '';
          _phoneNumberController.text = driverData['phoneNumber'] ?? '';
          _idNumberController.text = driverData['idNumber'] ?? '';
          _vehicleModelController.text = driverData['vehicleModel'] ?? '';
          _licensePlateController.text = driverData['licensePlate'] ?? '';
          _selectedProvince = driverData['province'];
          _selectedTowns = List<String>.from(driverData['towns'] ?? []);
          _selectedVehicleType = driverData['vehicleType'];
          _selectedColor = driverData['vehicleColor'];
          
          // Populate towns if province is set
          if (_selectedProvince != null) {
            _towns = provinceTowns[_selectedProvince] ?? [];
          }
        });
      }
    } catch (e) {
      print('Error loading existing data: $e');
    }
  }
  
  Future<void> _pickDocument(String documentType) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      setState(() {
        _documents[documentType] = File(pickedFile.path);
      });
    }
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
        _documents['Profile Image'] = File(pickedFile.path);
      });
    }
  }
  
  void _onProvinceChanged(String? province) {
    if (province != null) {
      setState(() {
        _selectedProvince = province;
        _selectedTowns.clear();
        _towns = provinceTowns[province] ?? [];
      });
    }
  }
  
  bool _isFieldMissing(String fieldName) {
    return widget.missingFields.contains(fieldName);
  }
  
  bool _isDocumentMissing(String documentType) {
    return widget.missingFields.contains(documentType);
  }
  
  Future<void> _saveMissingFields() async {
    if (!_validateForm()) return;
    
    _setLoading(true, message: 'Saving your information...');
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      // Upload documents if any are missing
      final Map<String, String> documentUrls = {};
      
      for (final entry in _documents.entries) {
        if (entry.value != null && _isDocumentMissing(entry.key)) {
          _setLoading(true, message: 'Uploading ${entry.key}...');
          
          final uploadedUrl = await _cloudinaryService.uploadImage(entry.value!);
          if (uploadedUrl != null) {
            documentUrls[entry.key] = uploadedUrl;
          } else {
            throw Exception('Failed to upload ${entry.key}');
          }
        }
      }
      
      // Update driver document
      final driverUpdates = <String, dynamic>{};
      
      if (_isFieldMissing('Full Name') && _nameController.text.isNotEmpty) {
        driverUpdates['name'] = _nameController.text;
      }
      
      if (_isFieldMissing('Phone Number') && _phoneNumberController.text.isNotEmpty) {
        driverUpdates['phoneNumber'] = _phoneNumberController.text;
      }
      
      if (_isFieldMissing('ID Number') && _idNumberController.text.isNotEmpty) {
        driverUpdates['idNumber'] = _idNumberController.text;
      }
      
      if (_isFieldMissing('Vehicle Model') && _vehicleModelController.text.isNotEmpty) {
        driverUpdates['vehicleModel'] = _vehicleModelController.text;
      }
      
      if (_isFieldMissing('License Plate') && _licensePlateController.text.isNotEmpty) {
        driverUpdates['licensePlate'] = _licensePlateController.text;
      }
      
      if (_selectedProvince != null) {
        driverUpdates['province'] = _selectedProvince;
      }
      
      if (_selectedTowns.isNotEmpty) {
        driverUpdates['towns'] = _selectedTowns;
      }
      
      if (_selectedVehicleType != null) {
        driverUpdates['vehicleType'] = _selectedVehicleType;
      }
      
      if (_selectedColor != null) {
        driverUpdates['vehicleColor'] = _selectedColor;
      }
      
      if (documentUrls.isNotEmpty) {
        driverUpdates['documents'] = documentUrls;
      }
      
      // Update driver document
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .update(driverUpdates);
      
      // Update user document
      final userUpdates = <String, dynamic>{};
      
      if (_nameController.text.isNotEmpty) {
        userUpdates['name'] = _nameController.text;
      }
      
      if (_phoneNumberController.text.isNotEmpty) {
        userUpdates['phoneNumber'] = _phoneNumberController.text;
      }
      
      // Set profile image if uploaded
      if (documentUrls.containsKey('Driver Profile Image')) {
        userUpdates['profileImage'] = documentUrls['Driver Profile Image'];
      } else if (documentUrls.containsKey('Profile Image')) {
        userUpdates['profileImage'] = documentUrls['Profile Image'];
      }
      
      // Recalculate missing fields
      final newMissingFields = _calculateMissingFields(driverUpdates, documentUrls);
      userUpdates['missingProfileFields'] = newMissingFields;
      
      // Update user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(userUpdates);
      
      _setLoading(false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop(true); // Return true to indicate success
      }
      
    } catch (e) {
      _setLoading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  List<String> _calculateMissingFields(Map<String, dynamic> driverUpdates, Map<String, String> documentUrls) {
    final missingFields = <String>[];
    
    // Check required fields
    final name = driverUpdates['name'] ?? _nameController.text;
    if (name.isEmpty) missingFields.add('Full Name');
    
    final phoneNumber = driverUpdates['phoneNumber'] ?? _phoneNumberController.text;
    if (phoneNumber.isEmpty) missingFields.add('Phone Number');
    
    final idNumber = driverUpdates['idNumber'] ?? _idNumberController.text;
    if (idNumber.isEmpty) missingFields.add('ID Number');
    
    final vehicleModel = driverUpdates['vehicleModel'] ?? _vehicleModelController.text;
    if (vehicleModel.isEmpty) missingFields.add('Vehicle Model');
    
    final licensePlate = driverUpdates['licensePlate'] ?? _licensePlateController.text;
    if (licensePlate.isEmpty) missingFields.add('License Plate');
    
    // Check documents
    final hasDocuments = documentUrls.isNotEmpty || 
        (widget.user.missingProfileFields.contains('Required Documents') == false);
    if (!hasDocuments) missingFields.add('Required Documents');
    
    return missingFields;
  }
  
  bool _validateForm() {
    final errors = <String>[];
    
    if (_isFieldMissing('Full Name') && _nameController.text.isEmpty) {
      errors.add('Full Name is required');
    }
    
    if (_isFieldMissing('Phone Number') && _phoneNumberController.text.isEmpty) {
      errors.add('Phone Number is required');
    }
    
    if (_isFieldMissing('ID Number') && _idNumberController.text.isEmpty) {
      errors.add('ID Number is required');
    }
    
    if (_isFieldMissing('Vehicle Model') && _vehicleModelController.text.isEmpty) {
      errors.add('Vehicle Model is required');
    }
    
    if (_isFieldMissing('License Plate') && _licensePlateController.text.isEmpty) {
      errors.add('License Plate is required');
    }
    
    // Check if any required documents are missing
    for (final entry in _documents.entries) {
      if (_isDocumentMissing(entry.key) && entry.value == null) {
        errors.add('${entry.key} is required');
      }
    }
    
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix the following errors:\n${errors.join('\n')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return false;
    }
    
    return true;
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Missing Fields'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? LoadingIndicator(message: _loadingMessage)
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Missing Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please complete the following missing fields to get approved:',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.missingFields.map((field) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.close, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              field,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Personal Information Section
                if (_isFieldMissing('Full Name') || _isFieldMissing('Phone Number') || _isFieldMissing('ID Number'))
                  _buildSection(
                    'Personal Information',
                    Icons.person,
                    [
                      if (_isFieldMissing('Full Name'))
                        CustomTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hintText: 'Enter your full name',
                        ),
                      if (_isFieldMissing('Phone Number'))
                        CustomTextField(
                          controller: _phoneNumberController,
                          label: 'Phone Number',
                          hintText: 'Enter your phone number',
                          keyboardType: TextInputType.phone,
                        ),
                      if (_isFieldMissing('ID Number'))
                        CustomTextField(
                          controller: _idNumberController,
                          label: 'ID Number',
                          hintText: 'Enter your ID number',
                        ),
                    ],
                  ),
                
                // Vehicle Information Section
                if (_isFieldMissing('Vehicle Model') || _isFieldMissing('License Plate'))
                  _buildSection(
                    'Vehicle Information',
                    Icons.directions_car,
                    [
                      if (_isFieldMissing('Vehicle Model'))
                        CustomTextField(
                          controller: _vehicleModelController,
                          label: 'Vehicle Model',
                          hintText: 'Enter your vehicle model',
                        ),
                      if (_isFieldMissing('License Plate'))
                        CustomTextField(
                          controller: _licensePlateController,
                          label: 'License Plate',
                          hintText: 'Enter your license plate number',
                        ),
                    ],
                  ),
                
                // Location Information Section
                if (_selectedProvince == null || _selectedTowns.isEmpty)
                  _buildSection(
                    'Service Areas',
                    Icons.location_on,
                    [
                      DropdownButtonFormField<String>(
                        value: _selectedProvince,
                        decoration: InputDecoration(
                          labelText: 'Province',
                          prefixIcon: Icon(Icons.location_on, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: provinceTowns.keys.map((province) {
                          return DropdownMenuItem(
                            value: province,
                            child: Text(province),
                          );
                        }).toList(),
                        onChanged: _onProvinceChanged,
                      ),
                      if (_towns.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Select Service Areas:',
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
                          children: _towns.map((town) {
                            final isSelected = _selectedTowns.contains(town);
                            return FilterChip(
                              label: Text(town),
                              selected: isSelected,
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
                      ],
                    ],
                  ),
                
                // Profile Image Section (for passengers)
                if (_isDocumentMissing('Profile Image'))
                  _buildSection(
                    'Profile Image',
                    Icons.person,
                    [
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _documents['Profile Image'] != null 
                                  ? FileImage(_documents['Profile Image']!) 
                                  : null,
                                child: _documents['Profile Image'] == null 
                                  ? Icon(Icons.camera_alt, size: 40, color: Colors.grey[600])
                                  : null,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap to add profile picture',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.getTextSecondaryColor(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                // Documents Section
                if (widget.missingFields.any((field) => _documents.keys.contains(field) && field != 'Profile Image'))
                  _buildSection(
                    'Required Documents',
                    Icons.upload_file,
                    _documents.entries
                        .where((entry) => _isDocumentMissing(entry.key) && entry.key != 'Profile Image')
                        .map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DocumentUpload(
                            title: entry.key,
                            file: entry.value,
                            onTap: () => _pickDocument(entry.key),
                          ),
                        ))
                        .toList(),
                  ),
                
                const SizedBox(height: 30),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Save Missing Fields',
                    onPressed: _saveMissingFields,
                    icon: Icons.save,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
    );
  }
  
  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
        const SizedBox(height: 30),
      ],
    );
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    _idNumberController.dispose();
    _vehicleModelController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }
}
