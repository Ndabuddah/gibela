import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/database_service.dart';
import '../../../widgets/common/modern_drawer.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'driver_application_card.dart';

class CarOwnerHomeScreen extends StatefulWidget {
  final UserModel userModel;

  const CarOwnerHomeScreen({
    super.key,
    required this.userModel,
  });

  @override
  State<CarOwnerHomeScreen> createState() => _CarOwnerHomeScreenState();
}

class _CarOwnerHomeScreenState extends State<CarOwnerHomeScreen> {
  List<Map<String, dynamic>> _driverApplications = [];
  List<Map<String, dynamic>> _myVehicles = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Show alert dialog after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _showFeatureAlert();
      });
    });
  }

  void _showFeatureAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            const Text('Feature Coming Soon'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your details have been successfully added to our database!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'This feature will be fully functional on August 11th, 2024. Until then, you can browse driver applications and prepare for when the service launches.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // Use mock data for now
      final applications = await databaseService.getMockDriverApplications();
      
      // Load owner's vehicles (using mock data for now)
      final vehicles = await databaseService.getMockVehicleOffers();

      setState(() {
        _driverApplications = applications;
        _myVehicles = vehicles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onApplicationAccepted(Map<String, dynamic> application) {
    // TODO: Implement application acceptance logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Application accepted! Contacting ${application['name']}...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _onApplicationRejected(Map<String, dynamic> application) {
    // TODO: Implement application rejection logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Application rejected'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _onViewApplicationDetails(Map<String, dynamic> application) {
    // TODO: Navigate to detailed application view
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${application['name']} - Application Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', application['name']),
              _buildDetailRow('Email', application['email']),
              _buildDetailRow('Phone', application['phoneNumber']),
              _buildDetailRow('ID Number', application['idNumber']),
              _buildDetailRow('Experience', application['drivingExperience']),
              _buildDetailRow('Availability', application['availability']),
              const SizedBox(height: 8),
              Text(
                'Preferred Areas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(application['preferredAreas'] as List<dynamic>)
                  .map((area) => Text('• $area')),
              if ((application['preferences'] as List<dynamic>?)?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  'Preferences:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...(application['preferences'] as List<dynamic>)
                    .map((pref) => Text('• $pref')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value?.toString() ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Car Owner Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getIconColor(isDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: ModernDrawer(user: widget.userModel),
      body: Stack(
        children: [
          // Main content with blur effect
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
            child: Column(
              children: [
                // Tab Bar
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.getCardColor(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.getBorderColor(isDark)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          'Top Drivers',
                          0,
                          Icons.people,
                          isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildTabButton(
                          'My Vehicles',
                          1,
                          Icons.directions_car,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: LoadingIndicator())
                      : _selectedTabIndex == 0
                          ? _buildDriverApplicationsTab(isDark)
                          : _buildMyVehiclesTab(isDark),
                ),
              ],
            ),
          ),
          
          // Overlay with semi-transparent background
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.getIconColor(isDark),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.getTextPrimaryColor(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverApplicationsTab(bool isDark) {
    if (_driverApplications.isEmpty) {
      return _buildEmptyState(
        isDark,
        'No driver applications',
        'Drivers will appear here when they apply for your vehicles',
        Icons.people_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _driverApplications.length,
      itemBuilder: (context, index) {
        final application = _driverApplications[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DriverApplicationCard(
            application: application,
            onAccept: () => _onApplicationAccepted(application),
            onReject: () => _onApplicationRejected(application),
            onViewDetails: () => _onViewApplicationDetails(application),
            isDark: isDark,
          ),
        );
      },
    );
  }

  Widget _buildMyVehiclesTab(bool isDark) {
    if (_myVehicles.isEmpty) {
      return _buildEmptyState(
        isDark,
        'No vehicles registered',
        'Register your first vehicle to start receiving applications',
        Icons.directions_car_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myVehicles.length,
      itemBuilder: (context, index) {
        final vehicle = _myVehicles[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorderColor(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.directions_car,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vehicle['vehicleMake']} ${vehicle['vehicleModel']}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimaryColor(isDark),
                          ),
                        ),
                        Text(
                          '${vehicle['vehicleYear']} • ${vehicle['vehicleType']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextSecondaryColor(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: vehicle['isAvailable'] == true ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      vehicle['isAvailable'] == true ? 'Available' : 'Unavailable',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'R${vehicle['dailyRate']}/day',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${vehicle['totalRentals'] ?? 0} rentals',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondaryColor(isDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: AppColors.getTextSecondaryColor(isDark),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimaryColor(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.getTextSecondaryColor(isDark),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 