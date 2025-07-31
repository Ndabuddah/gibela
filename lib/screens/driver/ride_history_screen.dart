import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({Key? key}) : super(key: key);

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  List<Map<String, dynamic>> _rideHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRideHistory();
  }

  Future<void> _fetchRideHistory() async {
    // Ensure the widget is still mounted before proceeding
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final user = authService.userModel;

    if (user != null) {
      final history = await dbService.getAcceptedRides(user.uid);
      if (mounted) {
      setState(() {
          _rideHistory = history;
          _isLoading = false;
      });
      }
    } else {
      if (mounted) {
      setState(() {
          _isLoading = false;
          _rideHistory = []; // Ensure history is empty if no user
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF181A20) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Ride History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF181A20) : Colors.white,
        elevation: 4,
        shadowColor: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rideHistory.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  itemCount: _rideHistory.length,
                  itemBuilder: (context, index) {
                    final ride = _rideHistory[index];
                    return _buildRideHistoryCard(ride, isDark);
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'No Ride History',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your past rides will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideHistoryCard(Map<String, dynamic> ride, bool isDark) {
    final status = ride['status'];
    final fare = ride['fare'] as double? ?? 0.0;
        final date = ride['date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(ride['date'])
            : null;
    final pickup = ride['pickupAddress'] as String? ?? 'Unknown Pickup';
    final destination = ride['destinationAddress'] as String? ?? 'Unknown Destination';

    final isCompleted = status == 2;
    final isCancelled = status == 3;

    final color = isCompleted
                        ? Colors.green
                        : isCancelled
                            ? Colors.red
            : AppColors.primary;

    final icon = isCompleted
        ? Icons.check_circle_outline_rounded
        : isCancelled
            ? Icons.cancel_outlined
            : Icons.timelapse_rounded;

    return Card(
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      shadowColor: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
      color: isDark ? const Color(0xFF232526) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  avatar: Icon(icon, color: color, size: 18),
                  label: Text(
                    isCompleted
                        ? 'Completed'
                        : isCancelled
                            ? 'Cancelled'
                            : 'Accepted',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  backgroundColor: color.withOpacity(0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Text(
                  'R${fare.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (date != null)
              Text(
                DateFormat('MMM d, yyyy â¢ h:mm a').format(date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            const SizedBox(height: 16),
            _buildAddressRow(Icons.trip_origin_rounded, pickup, isDark),
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Container(
                height: 20,
                width: 1,
                color: isDark ? Colors.white12 : Colors.grey[300],
              ),
            ),
            _buildAddressRow(Icons.location_on_rounded, destination, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String address, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: isDark ? Colors.white38 : AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            address,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.grey[800],
            ),
          ),
          ),
      ],
    );
  }
} 