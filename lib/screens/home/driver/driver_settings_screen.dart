import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/clodinaryservice.dart';
import '../../../services/referral_service.dart';
import '../../../widgets/common/modern_alert_dialog.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  DriverModel? _driverProfile;
  UserModel? _userProfile;
  bool _isLoading = true;
  bool _isUploadingImage = false;
  String? _profileImageUrl;
  Map<String, dynamic>? _referralStats;

  // Towns management
  List<String> _availableTowns = [];
  List<String> _selectedTowns = [];
  String? _selectedProvince;

  // Province towns mapping
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

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load user profile
      final authService = Provider.of<AuthService>(context, listen: false);
      final userModel = authService.userModel;
      setState(() {
        _userProfile = userModel;
        _profileImageUrl = userModel?.profileImage;
      });

      // Load driver profile
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final driverProfile = await databaseService.getCurrentDriver();
      
      if (driverProfile != null) {
        setState(() {
          _driverProfile = driverProfile;
          _selectedTowns = List.from(driverProfile.towns);
          _selectedProvince = driverProfile.province;
          if (_selectedProvince != null) {
            _availableTowns = _provinceTowns[_selectedProvince] ?? [];
          }
        });
      }

      // Load referral statistics
      final referralStats = await ReferralService.getReferralStats(user.uid);
      setState(() {
        _referralStats = referralStats;
      });
    } catch (e) {
      print('Error loading driver data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    
    if (pickedFile != null) {
      setState(() => _isUploadingImage = true);
      
      try {
        final cloudinaryService = CloudinaryService(
          cloudName: 'dunfw4ifc',
          uploadPreset: 'beauti'
        );
        final uploadedUrl = await cloudinaryService.uploadImage(File(pickedFile.path));
        
        if (uploadedUrl != null) {
          // Update both user and driver profiles
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'profileImage': uploadedUrl});
            
            await FirebaseFirestore.instance
                .collection('drivers')
                .doc(user.uid)
                .update({'profileImage': uploadedUrl});
          }
          
          setState(() {
            _profileImageUrl = uploadedUrl;
            _isUploadingImage = false;
          });
          
          ModernSnackBar.show(context, message: 'Profile picture updated successfully!');
        }
      } catch (e) {
        setState(() => _isUploadingImage = false);
        ModernSnackBar.show(context, message: 'Failed to upload image: $e', isError: true);
      }
    }
  }

  Future<void> _updateTowns() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .update({'towns': _selectedTowns});

      ModernSnackBar.show(context, message: 'Service areas updated successfully!');
    } catch (e) {
      ModernSnackBar.show(context, message: 'Failed to update service areas: $e', isError: true);
    }
  }

  void _copyReferralCode() {
    final referralCode = _referralStats?['referralCode'] ?? _userProfile?.uid ?? '';
    Clipboard.setData(ClipboardData(text: referralCode));
    ModernSnackBar.show(context, message: 'Referral code copied to clipboard!');
  }

  Widget _buildProfileSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimaryColor(Theme.of(context).brightness == Brightness.dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.black.withOpacity(0.1),
                    backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty 
                        ? NetworkImage(_profileImageUrl!) 
                        : null,
                    child: (_profileImageUrl == null || _profileImageUrl!.isEmpty) 
                        ? const Icon(Icons.person, color: AppColors.black, size: 60) 
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingImage ? null : _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8)],
                        ),
                        child: _isUploadingImage 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? 'Tap to change profile picture'
                    : 'Tap to add profile picture',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverDetailsSection() {
    if (_driverProfile == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.drive_eta, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Driver Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimaryColor(Theme.of(context).brightness == Brightness.dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Name', _driverProfile!.name, Icons.person),
            _buildDetailRow('Phone', _driverProfile!.phoneNumber, Icons.phone),
            _buildDetailRow('Email', _driverProfile!.email, Icons.email),
            _buildDetailRow('ID Number', _driverProfile!.idNumber, Icons.badge),
            _buildDetailRow('Province', _driverProfile!.province ?? 'Not set', Icons.location_on),
            _buildDetailRow('Vehicle Model', _driverProfile!.vehicleModel ?? 'Not set', Icons.directions_car),
            _buildDetailRow('Vehicle Color', _driverProfile!.vehicleColor ?? 'Not set', Icons.palette),
            _buildDetailRow('License Plate', _driverProfile!.licensePlate ?? 'Not set', Icons.confirmation_number),
            _buildDetailRow('Total Rides', _driverProfile!.totalRides.toString(), Icons.route),
            _buildDetailRow('Average Rating', _driverProfile!.averageRating.toStringAsFixed(1), Icons.star),
            _buildDetailRow('Total Earnings', 'R${_driverProfile!.totalEarnings}', Icons.attach_money),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimaryColor(Theme.of(context).brightness == Brightness.dark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTownsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_city, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Service Areas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimaryColor(Theme.of(context).brightness == Brightness.dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Province selection
            DropdownButtonFormField<String>(
              value: _selectedProvince,
              decoration: const InputDecoration(
                labelText: 'Province',
                border: OutlineInputBorder(),
              ),
              items: _provinceTowns.keys.map((province) {
                return DropdownMenuItem(value: province, child: Text(province));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProvince = value;
                  _availableTowns = _provinceTowns[value] ?? [];
                  _selectedTowns.clear();
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Towns selection
            if (_availableTowns.isNotEmpty) ...[
              Text(
                'Select towns you want to serve:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimaryColor(Theme.of(context).brightness == Brightness.dark),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTowns.map((town) {
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
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedTowns.isEmpty ? null : _updateTowns,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Update Service Areas',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReferralSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.share, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Referral Program',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimaryColor(Theme.of(context).brightness == Brightness.dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Referral code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Referral Code',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                                             Expanded(
                         child: Text(
                           _referralStats?['referralCode'] ?? _userProfile?.uid ?? 'Loading...',
                           style: TextStyle(
                             fontSize: 18,
                             fontWeight: FontWeight.bold,
                             color: AppColors.primary,
                             fontFamily: 'monospace',
                           ),
                         ),
                       ),
                      IconButton(
                        onPressed: _copyReferralCode,
                        icon: const Icon(Icons.copy, color: AppColors.primary),
                        tooltip: 'Copy referral code',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
                         // Referral stats
             Row(
               children: [
                 Expanded(
                   child: _buildReferralStat(
                     'Total Referrals',
                     '${_referralStats?['referrals'] ?? 0}',
                     Icons.people,
                   ),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: _buildReferralStat(
                     'Earnings',
                     'R${(_referralStats?['referralAmount'] ?? 0.0).toStringAsFixed(2)}',
                     Icons.attach_money,
                   ),
                 ),
               ],
             ),
            
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Share your referral code with friends to earn rewards!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(Theme.of(context).brightness == Brightness.dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimaryColor(Theme.of(context).brightness == Brightness.dark),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Settings'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileSection(),
            const SizedBox(height: 16),
            _buildDriverDetailsSection(),
            const SizedBox(height: 16),
            _buildTownsSection(),
            const SizedBox(height: 16),
            _buildReferralSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
} 