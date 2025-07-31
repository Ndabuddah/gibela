// lib/widgets/driver_info_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_colors.dart';
import '../../models/driver_model.dart';
import '../../models/user_model.dart';
import '../common/loading_indicator.dart';
import '../common/modern_alert_dialog.dart';
import '../../screens/home/passenger/track_driver_screen.dart';

class DriverInfoCard extends StatelessWidget {
  final UserModel driver;
  final DriverModel driverDetails;
  final VoidCallback onCallPressed;
  final VoidCallback onMessagePressed;
  final String rideId;

  const DriverInfoCard({
    Key? key,
    required this.driver,
    required this.driverDetails,
    required this.onCallPressed,
    required this.onMessagePressed,
    required this.rideId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Driver header
          Row(
            children: [
              UserAvatar(
                userModel: driver, 
                size: 60,
                onTap: () => _showDriverProfileDialog(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimaryColor(isDark),
                      ),
                    ),
                    Text(
                      'Your Driver',
                      style: TextStyle(
                        color: AppColors.getTextSecondaryColor(isDark),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      driverDetails.averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Vehicle info
          Row(
            children: [
              _buildInfoColumn(
                title: 'Vehicle',
                value: driverDetails.vehicleModel ?? 'Unknown',
                icon: Icons.directions_car,
                isDark: isDark,
              ),
              _buildInfoColumn(
                title: 'Color',
                value: driverDetails.vehicleColor ?? 'Unknown',
                icon: Icons.color_lens,
                isDark: isDark,
              ),
              _buildInfoColumn(
                title: 'Plate',
                value: driverDetails.licensePlate ?? 'Unknown',
                icon: Icons.confirmation_number,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  color: Colors.green,
                  onPressed: onCallPressed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.message,
                  label: 'Message',
                  color: AppColors.primary,
                  onPressed: onMessagePressed,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Track Driver button
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              icon: Icons.location_on,
              label: 'Track Driver',
              color: Colors.orange,
              onPressed: () => _navigateToTrackDriver(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DriverProfileDialog(
        driver: driver,
        driverDetails: driverDetails,
      ),
    );
  }

  void _navigateToTrackDriver(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TrackDriverScreen(
          rideId: rideId,
          driverId: driver.uid,
          driverName: driver.name,
          driverDetails: driverDetails,
        ),
      ),
    );
  }

  Widget _buildInfoColumn({
    required String title,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimaryColor(isDark),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextSecondaryColor(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class DriverProfileDialog extends StatefulWidget {
  final UserModel driver;
  final DriverModel driverDetails;

  const DriverProfileDialog({
    Key? key,
    required this.driver,
    required this.driverDetails,
  }) : super(key: key);

  @override
  State<DriverProfileDialog> createState() => _DriverProfileDialogState();
}

class _DriverProfileDialogState extends State<DriverProfileDialog> {
  List<Map<String, dynamic>> reviews = [];
  bool isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('passenger_ratings')
          .where('driverId', isEqualTo: widget.driver.uid)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      setState(() {
        reviews = reviewsSnapshot.docs
            .map((doc) => doc.data())
            .toList();
        isLoadingReviews = false;
      });
    } catch (e) {
      setState(() {
        isLoadingReviews = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.getBackgroundColor(isDark),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Driver Profile Image
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 3),
              ),
              child: ClipOval(
                child: widget.driver.photoUrl != null && widget.driver.photoUrl!.isNotEmpty
                    ? Image.network(
                        widget.driver.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(),
                      )
                    : _buildInitialsAvatar(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Driver Name
            Text(
              widget.driver.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Rating and Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${widget.driverDetails.averageRating.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimaryColor(isDark),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.directions_car, color: AppColors.primary, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${widget.driverDetails.totalRides} trips',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Vehicle Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.directions_car, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.driverDetails.vehicleModel ?? 'Unknown Vehicle',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.getTextPrimaryColor(isDark),
                          ),
                        ),
                        Text(
                          '${widget.driverDetails.vehicleColor ?? 'Unknown'} • ${widget.driverDetails.licensePlate ?? 'No Plate'}',
                          style: TextStyle(
                            color: AppColors.getTextSecondaryColor(isDark),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Reviews Section
            Text(
              'Recent Reviews',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
            ),
            
            const SizedBox(height: 12),
            
            if (isLoadingReviews)
              Center(child: CircularProgressIndicator())
            else if (reviews.isEmpty)
              Text(
                'No reviews yet',
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(isDark),
                  fontSize: 14,
                ),
              )
            else
              Container(
                height: 120,
                child: ListView.builder(
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.getCardColor(isDark),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${review['rating']?.toString() ?? '0'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getTextPrimaryColor(isDark),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                review['timestamp'] != null
                                    ? _formatDate(review['timestamp'])
                                    : '',
                                style: TextStyle(
                                  color: AppColors.getTextSecondaryColor(isDark),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (review['comment'] != null && review['comment'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                review['comment'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.getTextPrimaryColor(isDark),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    String initials = '';
    if (widget.driver.name.isNotEmpty) {
      final nameParts = widget.driver.name.split(' ');
      if (nameParts.length > 1) {
        initials = nameParts.first[0] + nameParts.last[0];
      } else {
        initials = nameParts.first[0];
      }
      initials = initials.toUpperCase();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return '';
  }
}
