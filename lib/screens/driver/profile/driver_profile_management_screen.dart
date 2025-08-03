import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../services/driver_profile_service.dart';
import '../../../widgets/common/custom_button.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import '../../../widgets/driver/document_upload.dart';

class DriverProfileManagementScreen extends StatefulWidget {
  const DriverProfileManagementScreen({Key? key}) : super(key: key);

  @override
  State<DriverProfileManagementScreen> createState() => _DriverProfileManagementScreenState();
}

class _DriverProfileManagementScreenState extends State<DriverProfileManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DriverProfileService _profileService = DriverProfileService();
  bool _isLoading = false;
  late DriverModel _driver;
  final ImagePicker _picker = ImagePicker();

  // Working hours
  final Map<String, List<TimeOfDay>> _workingHours = {};
  final List<String> _daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    setState(() => _isLoading = true);
    try {
      // Load driver data
      // Initialize working hours
      for (var day in _daysOfWeek) {
        _workingHours[day] = [
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 17, minute: 0)
        ];
      }
    } catch (e) {
      _showError('Error loading profile data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfilePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _isLoading = true);
        await _profileService.updateProfilePhoto(_driver.userId, File(image.path));
        _showSuccess('Profile photo updated successfully');
      }
    } catch (e) {
      _showError('Error updating profile photo');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateWorkingHours(String day, bool isStartTime, TimeOfDay newTime) async {
    try {
      setState(() {
        if (isStartTime) {
          _workingHours[day]![0] = newTime;
        } else {
          _workingHours[day]![1] = newTime;
        }
      });

      // Convert working hours to the format expected by the service
      final Map<String, List<String>> formattedHours = {};
      _workingHours.forEach((day, times) {
        formattedHours[day] = [
          '${times[0].hour}:${times[0].minute.toString().padLeft(2, '0')}',
          '${times[1].hour}:${times[1].minute.toString().padLeft(2, '0')}'
        ];
      });

      await _profileService.updateWorkingHours(_driver.userId, formattedHours);
      _showSuccess('Working hours updated successfully');
    } catch (e) {
      _showError('Error updating working hours');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: LoadingIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Basic Info'),
            Tab(text: 'Documents'),
            Tab(text: 'Vehicle'),
            Tab(text: 'Schedule'),
            Tab(text: 'Preferences'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicInfoTab(),
          _buildDocumentsTab(),
          _buildVehicleTab(),
          _buildScheduleTab(),
          _buildPreferencesTab(),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Completion Card
          _buildProfileCompletionCard(),
          const SizedBox(height: 24),

          // Profile Photo Section
          _buildProfilePhotoSection(),
          const SizedBox(height: 24),

          // Basic Information Form
          _buildBasicInfoForm(),
        ],
      ),
    );
  }

  Widget _buildProfileCompletionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Completion',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _driver.profileCompletionPercentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${_driver.profileCompletionPercentage.toStringAsFixed(1)}% Complete',
              style: TextStyle(
                color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: _driver.profileImage != null
                    ? NetworkImage(_driver.profileImage!)
                    : null,
                child: _driver.profileImage == null
                    ? const Icon(Icons.person, size: 60)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    onPressed: _updateProfilePhoto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Profile Photo',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Basic Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _driver.name,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            // Handle name change
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _driver.phoneNumber,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            // Handle phone number change
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _driver.email,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            // Handle email change
          },
        ),
      ],
    );
  }

  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDocumentSection(
            'Driver\'s License',
            'Upload your valid driver\'s license',
            _driver.documents['license'] ?? '',
            () => _uploadDocument('license'),
          ),
          _buildDocumentSection(
            'Vehicle Registration',
            'Upload your vehicle registration document',
            _driver.documents['registration'] ?? '',
            () => _uploadDocument('registration'),
          ),
          _buildDocumentSection(
            'Insurance',
            'Upload your vehicle insurance document',
            _driver.documents['insurance'] ?? '',
            () => _uploadDocument('insurance'),
          ),
          _buildDocumentSection(
            'Professional Permit',
            'Upload your professional driving permit',
            _driver.documents['permit'] ?? '',
            () => _uploadDocument('permit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(String title, String description, String documentUrl, VoidCallback onUpload) {
    final bool isDocumentUploaded = documentUrl.isNotEmpty;
    final bool isVerified = _driver.documentVerificationStatus[title] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                if (isDocumentUploaded)
                  Icon(
                    isVerified ? Icons.verified : Icons.pending,
                    color: isVerified ? Colors.green : Colors.orange,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark),
              ),
            ),
            const SizedBox(height: 16),
            if (isDocumentUploaded) ...[
              Image.network(
                documentUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${isVerified ? 'Verified' : 'Pending Verification'}',
                style: TextStyle(
                  color: isVerified ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 16),
            CustomButton(
              text: isDocumentUploaded ? 'Update Document' : 'Upload Document',
              onPressed: onUpload,
              icon: Icons.upload_file,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDocument(String documentType) async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        setState(() => _isLoading = true);
        await _profileService.updateDocument(_driver.userId, documentType, File(file.path));
        _showSuccess('Document uploaded successfully');
      }
    } catch (e) {
      _showError('Error uploading document');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildVehicleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildVehicleInfoForm(),
          const SizedBox(height: 24),
          _buildVehiclePhotosSection(),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoForm() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: _driver.vehicleType,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _driver.vehicleModel,
              decoration: const InputDecoration(
                labelText: 'Vehicle Model',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _driver.vehicleColor,
              decoration: const InputDecoration(
                labelText: 'Vehicle Color',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _driver.licensePlate,
              decoration: const InputDecoration(
                labelText: 'License Plate',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclePhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Photos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildPhotoUploadCard('Front View'),
            _buildPhotoUploadCard('Back View'),
            _buildPhotoUploadCard('Side View'),
            _buildPhotoUploadCard('Interior'),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoUploadCard(String title) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Handle photo upload
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo,
              size: 32,
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Working Hours',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ..._daysOfWeek.map((day) => _buildDayScheduleCard(day)).toList(),
        ],
      ),
    );
  }

  Widget _buildDayScheduleCard(String day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              day,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimePickerButton(
                    'Start Time',
                    _workingHours[day]![0],
                    (newTime) => _updateWorkingHours(day, true, newTime),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimePickerButton(
                    'End Time',
                    _workingHours[day]![1],
                    (newTime) => _updateWorkingHours(day, false, newTime),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerButton(String label, TimeOfDay time, Function(TimeOfDay) onTimeSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final TimeOfDay? newTime = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (newTime != null) {
              onTimeSelected(newTime);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time.format(context)),
                const Icon(Icons.access_time),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Driver Preferences',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildPreferenceSection(),
        ],
      ),
    );
  }

  Widget _buildPreferenceSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSwitchPreference(
              'Female Passengers Only',
              _driver.isFemale ?? false,
              (value) {
                // Handle preference change
              },
            ),
            _buildSwitchPreference(
              'Student Rides',
              _driver.isForStudents ?? false,
              (value) {
                // Handle preference change
              },
            ),
            _buildSwitchPreference(
              'Luxury Service',
              _driver.isLuxury ?? false,
              (value) {
                // Handle preference change
              },
            ),
            _buildSwitchPreference(
              'Maximum 2 Passengers',
              _driver.isMax2 ?? false,
              (value) {
                // Handle preference change
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Service Areas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAreaChip('City Center', true),
                _buildAreaChip('Suburbs', false),
                _buildAreaChip('Airport', true),
                _buildAreaChip('Shopping Centers', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchPreference(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildAreaChip(String area, bool isSelected) {
    return FilterChip(
      selected: isSelected,
      label: Text(area),
      onSelected: (bool selected) {
        // Handle area selection
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}