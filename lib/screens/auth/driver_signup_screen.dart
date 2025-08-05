import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:async';

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
import '../../utils/validators.dart';
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
                    // Save progress after purpose selection
                    _saveProgress();
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

  // Towns data for each province
  final Map<String, List<String>> _provinceTowns = {
    'Gauteng': [
      'Johannesburg', 'Pretoria', 'Centurion', 'Sandton', 'Randburg', 'Roodepoort', 
      'Krugersdorp', 'Boksburg', 'Benoni', 'Germiston', 'Alberton', 'Kempton Park',
      'Midrand', 'Fourways', 'Northcliff', 'Rosebank', 'Melville', 'Parktown',
      'Bryanston', 'Woodmead', 'Lonehill', 'Dainfern', 'Kyalami', 'Midrand'
    ],
    'Western Cape': [
      'Cape Town', 'Bellville', 'Durbanville', 'Brackenfell', 'Goodwood', 'Parow',
      'Milnerton', 'Table View', 'Bloubergstrand', 'Melkbosstrand', 'Somerset West',
      'Stellenbosch', 'Paarl', 'Wellington', 'Worcester', 'Malmesbury', 'Vredenburg',
      'Saldanha', 'Langebaan', 'Hermanus', 'Gordons Bay', 'Fish Hoek', 'Hout Bay'
    ],
    'KwaZulu-Natal': [
      'Durban', 'Pietermaritzburg', 'Umhlanga', 'Ballito', 'Westville', 'Berea',
      'Morningside', 'Musgrave', 'Glenwood', 'North Beach', 'South Beach',
      'Newcastle', 'Ladysmith', 'Richards Bay', 'Empangeni', 'Port Shepstone',
      'Margate', 'Scottburgh', 'Amanzimtoti', 'Umkomaas', 'Kingsburgh'
    ],
    'Eastern Cape': [
      'Port Elizabeth', 'East London', 'Mthatha', 'Queenstown', 'Grahamstown',
      'Uitenhage', 'Despatch', 'Jeffreys Bay', 'St Francis Bay', 'Port Alfred',
      'Graaff-Reinet', 'Cradock', 'Aliwal North', 'Butterworth', 'King Williams Town'
    ],
    'Free State': [
      'Bloemfontein', 'Welkom', 'Kroonstad', 'Bethlehem', 'Harrismith', 'Sasolburg',
      'Virginia', 'Odendaalsrus', 'Bothaville', 'Parys', 'Ficksburg', 'Ladybrand'
    ],
    'Limpopo': [
      'Polokwane', 'Tzaneen', 'Phalaborwa', 'Thohoyandou', 'Louis Trichardt',
      'Mokopane', 'Modimolle', 'Bela-Bela', 'Lephalale', 'Musina', 'Giyani'
    ],
    'Mpumalanga': [
      'Nelspruit', 'Witbank', 'Secunda', 'Middelburg', 'Standerton', 'Bethal',
      'Ermelo', 'Barberton', 'White River', 'Hazyview', 'Sabie', 'Lydenburg'
    ],
    'North West': [
      'Rustenburg', 'Potchefstroom', 'Klerksdorp', 'Mahikeng', 'Brits', 'Lichtenburg',
      'Vryburg', 'Zeerust', 'Koster', 'Coligny', 'Sannieshof', 'Ottosdal'
    ],
    'Northern Cape': [
      'Kimberley', 'Upington', 'Springbok', 'De Aar', 'Kuruman', 'Kathu',
      'Postmasburg', 'Daniëlskuil', 'Calvinia', 'Carnarvon', 'Prieska', 'Douglas'
    ]
  };

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

  // Track saved document paths for progress restoration
  Map<String, String> _documentPaths = {};

  // Enhanced loading state management
  bool _isLoading = false;
  String _loadingMessage = '';
  
  void _setLoading(bool loading, {String message = ''}) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
        _loadingMessage = message;
      });
    }
  }

  bool _showThankYou = false;
  
  // Payment verification and rollback tracking
  bool _paymentVerified = false;
  final List<String> _uploadedDocumentUrls = [];
  String? _paymentReference;

  @override
  void initState() {
    super.initState();
    _loadSavedProgress();
    _addTextChangeListeners();
  }

  // Add text change listeners to save progress as user types
  void _addTextChangeListeners() {
    _nameController.addListener(_debouncedSaveProgress);
    _phoneNumberController.addListener(_debouncedSaveProgress);
    _emailController.addListener(_debouncedSaveProgress);
    _idNumberController.addListener(_debouncedSaveProgress);
    _vehicleModelController.addListener(_debouncedSaveProgress);
    _vehicleColorController.addListener(_debouncedSaveProgress);
    _licensePlateController.addListener(_debouncedSaveProgress);
    _referralCodeController.addListener(_debouncedSaveProgress);
  }

  // Load saved progress when screen initializes
  Future<void> _loadSavedProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final databaseService = Provider.of<DatabaseService>(context, listen: false);
        final savedProgress = await databaseService.getDriverSignupProgress(user.uid);
        
        if (savedProgress != null && mounted) {
          setState(() {
            // Restore form data
            _nameController.text = savedProgress['name'] ?? '';
            _phoneNumberController.text = savedProgress['phoneNumber'] ?? '';
            _emailController.text = savedProgress['email'] ?? '';
            _idNumberController.text = savedProgress['idNumber'] ?? '';
            _vehicleModelController.text = savedProgress['vehicleModel'] ?? '';
            _vehicleColorController.text = savedProgress['vehicleColor'] ?? '';
            _licensePlateController.text = savedProgress['licensePlate'] ?? '';
            _referralCodeController.text = savedProgress['referralCode'] ?? '';
            
            // Restore selections
            _selectedProvince = savedProgress['province'];
            _selectedTowns = List<String>.from(savedProgress['towns'] ?? []);
            // Populate towns list if province is restored
            if (_selectedProvince != null) {
              _towns = _provinceTowns[_selectedProvince] ?? [];
            }
            _selectedVehicleType = savedProgress['vehicleType'] ?? 'small';
            _selectedBrand = savedProgress['vehicleBrand'];
            _selectedModel = savedProgress['vehicleModel'];
            _selectedColor = savedProgress['vehicleColor'];
            _selectedPurposes = List<String>.from(savedProgress['purposes'] ?? []);
            
            // Restore document paths (files will need to be re-selected)
            final documentPaths = savedProgress['documentPaths'] as Map<String, dynamic>? ?? {};
            // Note: We can't restore File objects directly, but we can show which documents were uploaded
            _documentPaths = Map<String, String>.from(documentPaths);
            
            // Show user which documents were previously uploaded
            if (_documentPaths.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Found ${_documentPaths.length} previously uploaded documents. Please re-upload them.'),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
          
          print('✅ Driver signup progress restored');
          
          // Check if user has already paid
          await _checkPaymentStatus();
          
          // Check if user has a partial profile and show guidance
          final hasPartial = await _hasPartialProfile();
          if (hasPartial && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('We found some of your previous information. Please complete the remaining fields.'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error loading saved progress: $e');
    }
  }

  // Check if user has already paid and show appropriate UI
  Future<void> _checkPaymentStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final databaseService = Provider.of<DatabaseService>(context, listen: false);
        final hasPaid = await databaseService.verifyDriverPayment(user.uid);
        
        if (hasPaid && mounted) {
          // User has paid, show completion button instead of payment button
          setState(() {
            _paymentVerified = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment verified! You can now complete your profile.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking payment status: $e');
    }
  }

  // Save progress periodically
  Future<void> _saveProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final databaseService = Provider.of<DatabaseService>(context, listen: false);
        
        // Convert documents to paths for storage
        final documentPaths = <String, String>{};
        for (final entry in _documents.entries) {
          if (entry.value != null) {
            documentPaths[entry.key] = entry.value!.path;
          }
        }
        
        final progressData = {
          'name': _nameController.text,
          'phoneNumber': _phoneNumberController.text,
          'email': _emailController.text,
          'idNumber': _idNumberController.text,
          'vehicleModel': _vehicleModelController.text,
          'vehicleColor': _vehicleColorController.text,
          'licensePlate': _licensePlateController.text,
          'referralCode': _referralCodeController.text,
          'province': _selectedProvince,
          'towns': _selectedTowns,
          'vehicleType': _selectedVehicleType,
          'vehicleBrand': _selectedBrand,
          'vehicleModel': _selectedModel,
          'vehicleColor': _selectedColor,
          'purposes': _selectedPurposes,
          'documentPaths': documentPaths,
        };
        
        await databaseService.saveDriverSignupProgress(user.uid, progressData);
      }
    } catch (e) {
      print('Error saving progress: $e');
    }
  }

  // Debounced save progress to avoid too many database calls
  Timer? _saveTimer;
  void _debouncedSaveProgress() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveProgress();
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
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

  Future<void> _pickDocument(String documentType) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _documents[documentType] = File(pickedFile.path);
      });
      // Save progress after document selection (local only, no upload yet)
      _saveProgress();
    }
  }

  // Payment verification method
  Future<bool> _verifyPaymentSuccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user found for payment verification');
        return false;
      }

      // Verify payment with database service
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final paymentVerified = await databaseService.verifyDriverPayment(user.uid);
      
      if (paymentVerified) {
        setState(() {
          _paymentVerified = true;
        });
        print('✅ Payment verified successfully');
        return true;
      } else {
        print('❌ Payment verification failed');
        return false;
      }
    } catch (e) {
      print('Payment verification failed: $e');
      return false;
    }
  }

  // Enhanced rollback method with better error handling
  Future<void> _rollbackUploadedDocuments() async {
    if (_uploadedDocumentUrls.isEmpty) return;
    
    try {
      print('🔄 Rolling back ${_uploadedDocumentUrls.length} uploaded documents...');
      
      for (final url in _uploadedDocumentUrls) {
        try {
          // Extract public ID from Cloudinary URL
          final uri = Uri.parse(url);
          final pathSegments = uri.pathSegments;
          if (pathSegments.length >= 2) {
            final publicId = pathSegments.sublist(1).join('/').replaceAll('.jpg', '').replaceAll('.png', '');
            await cloudinaryService.deleteImage(publicId);
            print('✅ Deleted document: $publicId');
          }
        } catch (e) {
          print('⚠️ Failed to delete document $url: $e');
          // Continue with other deletions even if one fails
        }
      }
      
      _uploadedDocumentUrls.clear();
      print('✅ Document rollback completed');
    } catch (e) {
      print('❌ Error during document rollback: $e');
      // Don't throw here to avoid cascading errors
    }
  }

  // Handle registration failure
  Future<void> _handleRegistrationFailure() async {
    try {
      // Rollback uploaded documents
      await _rollbackUploadedDocuments();
      
      // TODO: Implement payment refund logic
      // This should be handled by your backend
      print('Registration failed - payment refund should be processed');
      
      // Reset payment verification
      setState(() {
        _paymentVerified = false;
        _paymentReference = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed. Payment will be refunded within 24 hours.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error handling registration failure: $e');
    }
  }

  // Update _payR100 to navigate to PaymentScreen and only save after payment
  Future<void> _payR100() async {
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }
    
    // Get email from Firebase Auth user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in with a valid email address.')),
      );
      return;
    }
    final email = user.email!;
    final amount = 100.0;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: amount,
          email: email,
          onPaymentSuccess: () async {
            Navigator.pop(context); // Close PaymentScreen
            
            // Show loading indicator
            if (mounted) {
              _setLoading(true, message: 'Completing profile...');
            }
            
            try {
              // Step 1: Verify payment in database
              if (!await _verifyPaymentSuccess()) {
                if (mounted) {
                  _setLoading(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment verification failed. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              
              // Step 2: Upload documents to Cloudinary (only after payment verification)
              final uploadedDocUrls = await _uploadDocumentsAfterPayment();
              
              // Step 3: Create driver profile with uploaded document URLs
              await _submitDriverProfile(uploadedDocUrls);
              
            } catch (e) {
              // Handle any errors during the process
              if (mounted) {
                _setLoading(false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  // Comprehensive form validation
  String? _validateForm() {
    // Basic form validation
    if (!_formKey.currentState!.validate()) {
      return 'Please fill in all required fields correctly.';
    }
    
    // Check name
    if (_nameController.text.trim().isEmpty) {
      return 'Please enter your full name.';
    }
    
    // Check phone number
    if (_phoneNumberController.text.trim().isEmpty) {
      return 'Please enter your phone number.';
    }
    
    // Check ID number
    if (_idNumberController.text.trim().isEmpty) {
      return 'Please enter your ID number.';
    }
    
    // Check vehicle information
    if (_selectedVehicleType == null || _selectedVehicleType!.isEmpty) {
      return 'Please select a vehicle type.';
    }
    
    if (_selectedBrand == null || _selectedBrand!.isEmpty) {
      return 'Please select a vehicle brand.';
    }
    
    if (_selectedModel == null || _selectedModel!.isEmpty) {
      return 'Please select a vehicle model.';
    }
    
    if (_selectedColor == null || _selectedColor!.isEmpty) {
      return 'Please select a vehicle color.';
    }
    
    if (_licensePlateController.text.trim().isEmpty) {
      return 'Please enter your license plate number.';
    }
    
    // Check location information
    if (_selectedProvince == null || _selectedProvince!.isEmpty) {
      return 'Please select your province.';
    }
    
    if (_selectedTowns.isEmpty) {
      return 'Please select at least one town for service areas.';
    }
    
    // Check vehicle purposes
    if (_selectedPurposes.isEmpty) {
      return 'Please select at least one vehicle purpose.';
    }
    
    // Check documents
    if (!_allDocsUploaded()) {
      return 'Please upload all required documents.';
    }
    
    return null; // No validation errors
  }

  // Pay Later option - skip payment and go to congratulations
  Future<void> _payLater() async {
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }
    
    // Show loading indicator
    if (mounted) {
      _setLoading(true, message: 'Completing profile...');
    }
    
    try {
      // Upload documents to Cloudinary (skip payment check for pay-later users)
      final uploadedDocUrls = await _uploadDocumentsAfterPayment(skipPaymentCheck: true);
      
      // Create driver profile with uploaded document URLs and payLater flag
      await _submitDriverProfilePayLater(uploadedDocUrls);
      
    } catch (e) {
      // Handle any errors during the process
      if (mounted) {
        _setLoading(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Complete profile for users who have already paid
  Future<void> _completeProfileAfterPayment() async {
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }
    
    _setLoading(true);
    
    try {
      // Upload documents and create profile
      final uploadedDocUrls = await _uploadDocumentsAfterPayment();
      await _submitDriverProfile(uploadedDocUrls);
    } catch (e) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _submitDriverProfile([Map<String, String>? preUploadedDocUrls]) async {
    _setLoading(true, message: 'Creating your driver profile...');
    final Map<String, String> docUrls = preUploadedDocUrls ?? {}; // Use pre-uploaded URLs if provided
    String? profileImageUrl;
    
    try {
      // If no pre-uploaded URLs provided, upload documents (for backward compatibility)
      if (preUploadedDocUrls == null) {
        docUrls.addAll(await _uploadDocumentsAfterPayment());
      }
      
      // Get profile image URL
      profileImageUrl = docUrls['Driver Profile Image'];
      
      // Ensure profile image is present
      if (profileImageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a profile image.')),
        );
        _setLoading(false);
        return;
      }

      // Use the current authenticated user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not logged in. Please log in again.')),
        );
        _setLoading(false);
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

      _setLoading(false);

      if (!mounted) return;

      // Clear saved progress after successful submission
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await databaseService.clearDriverSignupProgress(currentUser.uid);
      }

      // Navigate to congratulations screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const CongratulationsScreen(),
        ),
      );
    } catch (e) {
      _setLoading(false);
      
      // Rollback uploaded documents on any error
      await _rollbackUploadedDocuments();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
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
          'referralAmount': FieldValue.increment(50.0), // R50 per referral
          'lastReferral': FieldValue.serverTimestamp(),
        });

        // Add referral record
        await FirebaseFirestore.instance
            .collection('referrals')
            .add({
          'referrerId': referralCode,
          'referredDriverId': newDriverId,
          'amount': 50.0,
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

  void _onProvinceChanged(String? province) {
    if (province != null) {
      setState(() {
        _selectedProvince = province;
        _selectedTowns.clear(); // Clear selected towns for new province
        // Populate towns list for the selected province
        _towns = _provinceTowns[province] ?? [];
      });
      // Save progress after province change
      _saveProgress();
    }
  }

  // Upload documents to Cloudinary after payment verification
  Future<Map<String, String>> _uploadDocumentsAfterPayment({bool skipPaymentCheck = false}) async {
    final Map<String, String> docUrls = {};
    String? profileImageUrl;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User session expired');
      }
      
      // Only verify payment if not skipping payment check (for pay-later users)
      if (!skipPaymentCheck) {
        final paymentVerified = await Provider.of<DatabaseService>(context, listen: false)
            .verifyDriverPayment(user.uid);
        
        if (!paymentVerified) {
          throw Exception('Payment verification failed. Please complete payment first.');
        }
      }
      
      // Show upload progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading documents...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        _setLoading(true, message: 'Uploading documents...');
      }
      
      // Iterate over the documents and upload to Cloudinary
      for (final entry in _documents.entries) {
        final file = entry.value;
        if (file != null) {
          try {
            if (mounted) {
              _setLoading(true, message: 'Uploading ${entry.key}...');
            }
            
            final uploadedUrl = await cloudinaryService.uploadImage(file);
            if (uploadedUrl != null) {
              docUrls[entry.key] = uploadedUrl;
              _uploadedDocumentUrls.add(uploadedUrl); // Track for rollback
              
              if (entry.key == 'Driver Profile Image') {
                profileImageUrl = uploadedUrl;
              }
              
              print('✅ Uploaded ${entry.key}: $uploadedUrl');
            } else {
              print('❌ Failed to upload ${entry.key}');
              throw Exception('Failed to upload ${entry.key}');
            }
          } catch (e) {
            print('❌ Error uploading ${entry.key}: $e');
            // Rollback any previously uploaded documents
            await _rollbackUploadedDocuments();
            throw Exception('Failed to upload ${entry.key}: ${e.toString()}');
          }
        } else {
          print('❌ No file selected for ${entry.key}');
          throw Exception('No file selected for ${entry.key}');
        }
      }
      
      // Ensure profile image is present
      if (profileImageUrl == null) {
        throw Exception('Please upload a profile image');
      }
      
      print('✅ All documents uploaded successfully');
      return docUrls;
      
    } catch (e) {
      print('❌ Error in document upload: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      onChanged: (String? brand) {
                        setState(() {
                          _selectedBrand = brand;
                          _selectedModel = null;
                        });
                        // Save progress after brand selection
                        _saveProgress();
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
                        onChanged: (String? model) {
                          setState(() {
                            _selectedModel = model;
                          });
                          // Save progress after model selection
                          _saveProgress();
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
                      onChanged: (String? color) {
                        setState(() {
                          _selectedColor = color;
                        });
                        // Save progress after color selection
                        _saveProgress();
                      },
                      validator: (value) => value == null ? 'Please select a color' : null,
                    ),
                    const SizedBox(height: 16),

                    // License Plate (Required)
                    CustomTextField(
                      controller: _licensePlateController,
                      label: 'License Plate *',
                      hintText: 'Enter your vehicle license plate',
                      prefixIcon: Icons.confirmation_number,
                      validator: (value) => Validators.validateLicensePlate(value),
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
                      onChanged: _onProvinceChanged,
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
                            // Save progress after town selection
                            _saveProgress();
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
                        color: isDark ? Colors.black12 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.card_giftcard,
                                  color: Colors.white,
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
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : Colors.black87,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Did someone refer you? Enter their code!',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white70 : Colors.black54,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.08) : AppColors.primary.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.1) : AppColors.primary.withOpacity(0.15),
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
                                    'Refer drivers and earn R50 per successful referral!',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isDark ? Colors.white70 : AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
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

                    // Submit buttons
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Pay R100 & Submit',
                            onPressed: _payR100,
                            isFullWidth: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            text: 'Pay Later',
                            onPressed: _payLater,
                            isFullWidth: true,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pay Later Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Pay Later Option', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                SizedBox(height: 4),
                                Text('If you choose "Pay Later", your first week platform fee will be R600 instead of R450.', style: TextStyle(color: Colors.orange, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

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

          if (_isLoading) 
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage.isNotEmpty ? _loadingMessage : 'Processing...',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
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
          // Save progress after vehicle type selection
          _saveProgress();
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

  Future<void> _submitDriverProfilePayLater([Map<String, String>? preUploadedDocUrls]) async {
    _setLoading(true, message: 'Creating your driver profile...');
    final Map<String, String> docUrls = preUploadedDocUrls ?? {}; // Use pre-uploaded URLs if provided
    String? profileImageUrl;
    
    try {
      // If no pre-uploaded URLs provided, upload documents (for backward compatibility)
      if (preUploadedDocUrls == null) {
        docUrls.addAll(await _uploadDocumentsAfterPayment(skipPaymentCheck: true));
      }
      
      // Get profile image URL
      profileImageUrl = docUrls['Driver Profile Image'];
      
      // Ensure profile image is present
      if (profileImageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a profile image.')),
        );
        _setLoading(false);
        return;
      }

      // Use the current authenticated user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not logged in. Please log in again.')),
        );
        _setLoading(false);
        return;
      }

      // Determine driver preferences based on selected purposes
      final isFemale = _selectedPurposes.contains('females');
      final isForStudents = _selectedPurposes.contains('students');
      final isLuxury = _selectedPurposes.contains('luxury');
      final isMax2 = _selectedPurposes.contains('1-2 seater');

      // Create driver model with payLater flag
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
        payLater: true, // Mark as pay later
      );

      // Save driver profile
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      await databaseService.createDriverProfile(driverModel);

      // Handle referral if provided
      final referralCode = _referralCodeController.text.trim();
      if (referralCode != null && referralCode.isNotEmpty) {
        await _handleReferral(referralCode, user.uid);
      }

      _setLoading(false);

      if (!mounted) return;

      // Clear saved progress after successful submission
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await databaseService.clearDriverSignupProgress(currentUser.uid);
      }

      // Navigate to congratulations screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const CongratulationsScreen(),
        ),
      );
    } catch (e) {
      _setLoading(false);
      
      // Rollback uploaded documents on any error
      await _rollbackUploadedDocuments();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Check if user has a partially completed profile
  Future<bool> _hasPartialProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final driver = await databaseService.getCurrentDriver();
      
      if (driver != null) {
        // Check if they have some data but not complete
        final hasBasicInfo = driver.name.isNotEmpty && 
                            driver.phoneNumber.isNotEmpty && 
                            driver.email.isNotEmpty;
        
        final hasVehicleInfo = driver.vehicleType != null && 
                              driver.vehicleModel != null && 
                              driver.licensePlate != null;
        
        final hasDocuments = driver.documents.isNotEmpty;
        
        // Return true if they have some data but not everything
        return hasBasicInfo && (hasVehicleInfo || hasDocuments);
      }
      
      return false;
    } catch (e) {
      print('Error checking partial profile: $e');
      return false;
    }
  }
}
