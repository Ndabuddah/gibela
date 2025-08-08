import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/database_service.dart';
import '../../../widgets/common/modern_drawer.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'vehicle_offer_card.dart';

class DriverNoCarHomeScreen extends StatefulWidget {
  final UserModel userModel;

  const DriverNoCarHomeScreen({
    super.key,
    required this.userModel,
  });

  @override
  State<DriverNoCarHomeScreen> createState() => _DriverNoCarHomeScreenState();
}

class _DriverNoCarHomeScreenState extends State<DriverNoCarHomeScreen> {
  List<Map<String, dynamic>> _vehicleOffers = [];
  List<Map<String, dynamic>> _allOffers = []; // Keep all offers for filtering
  bool _isLoading = true;
  String _selectedArea = 'All Areas';

  final List<String> _areaOptions = [
    'All Areas',
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
    _loadVehicleOffers();
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
              'This feature will be fully functional on August 11th, 2024. Until then, you can browse available vehicles and prepare for when the service launches.',
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

  Future<void> _loadVehicleOffers() async {
    setState(() => _isLoading = true);
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // Use mock data for now
      final offers = await databaseService.getMockVehicleOffers();
      
      setState(() {
        _allOffers = offers;
        _filterOffers();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vehicle offers: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _filterOffers() {
    if (_selectedArea == 'All Areas') {
      _vehicleOffers = List.from(_allOffers);
    } else {
      _vehicleOffers = _allOffers.where((offer) {
        final serviceAreas = List<String>.from(offer['serviceAreas'] ?? []);
        return serviceAreas.contains(_selectedArea);
      }).toList();
    }
  }

  void _onAreaChanged(String? newArea) {
    if (newArea != null) {
      setState(() => _selectedArea = newArea);
      _filterOffers();
    }
  }

  void _onOfferAccepted(Map<String, dynamic> offer) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            const Text('Accept Offer'),
          ],
        ),
        content: Text(
          'Are you sure you want to accept this vehicle offer from ${offer['ownerName']}?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _processOfferAcceptance(offer);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _processOfferAcceptance(Map<String, dynamic> offer) {
    // Remove the offer from the list
    setState(() {
      _allOffers.removeWhere((o) => o['id'] == offer['id']);
      _filterOffers();
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Offer accepted! Contacting ${offer['ownerName']}...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View Details',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Navigate to offer details or chat screen
          },
        ),
      ),
    );
  }

  void _onOfferRejected(Map<String, dynamic> offer) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('Reject Offer'),
          ],
        ),
        content: Text(
          'Are you sure you want to reject this vehicle offer? This action cannot be undone.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _processOfferRejection(offer);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _processOfferRejection(Map<String, dynamic> offer) {
    // Remove the offer from the list
    setState(() {
      _allOffers.removeWhere((o) => o['id'] == offer['id']);
      _filterOffers();
    });

    // Show rejection message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.cancel, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Offer rejected successfully',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Implement undo functionality
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Undo functionality coming soon!'),
                backgroundColor: Colors.blue,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
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
        title: Row(
          children: [
            Icon(Icons.directions_car_filled, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Vehicle Offers'),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getIconColor(isDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVehicleOffers,
            tooltip: 'Refresh offers',
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
                // Area Filter with improved design
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.getCardColor(isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getBorderColor(isDark), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Filter by Area',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimaryColor(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.getBackgroundColor(isDark),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.getBorderColor(isDark)),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedArea,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            prefixIcon: Icon(Icons.filter_list),
                            suffixIcon: Icon(Icons.keyboard_arrow_down),
                          ),
                          items: _areaOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: _onAreaChanged,
                          style: TextStyle(
                            color: AppColors.getTextPrimaryColor(isDark),
                            fontSize: 16,
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down),
                          isExpanded: true,
                          dropdownColor: AppColors.getBackgroundColor(isDark),
                          menuMaxHeight: 300,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_vehicleOffers.length} offers available',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: LoadingIndicator())
                      : _vehicleOffers.isEmpty
                          ? _buildEmptyState(isDark)
                          : _buildOffersList(isDark),
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(isDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.getBorderColor(isDark)),
              ),
              child: Icon(
                Icons.directions_car_outlined,
                size: 80,
                color: AppColors.getTextSecondaryColor(isDark),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No vehicle offers available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedArea == 'All Areas'
                  ? 'Check back later for new offers in your area'
                  : 'No offers available in $_selectedArea. Try selecting a different area.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.getTextSecondaryColor(isDark),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadVehicleOffers,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_selectedArea != 'All Areas') ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _onAreaChanged('All Areas'),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Filter'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _vehicleOffers.length,
      itemBuilder: (context, index) {
        final offer = _vehicleOffers[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: VehicleOfferCard(
            offer: offer,
            onAccept: () => _onOfferAccepted(offer),
            onReject: () => _onOfferRejected(offer),
            isDark: isDark,
          ),
        );
      },
    );
  }
} 