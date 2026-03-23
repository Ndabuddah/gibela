import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../models/ride_model.dart';
import '../../services/database_service.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/skeleton_loader.dart';
import '../../l10n/app_localizations.dart';
import '../home/passenger/request_ride_screen.dart';

class ComprehensiveRideHistoryScreen extends StatefulWidget {
  final bool isDriver;

  const ComprehensiveRideHistoryScreen({
    Key? key,
    this.isDriver = false,
  }) : super(key: key);

  @override
  State<ComprehensiveRideHistoryScreen> createState() => _ComprehensiveRideHistoryScreenState();
}

class _ComprehensiveRideHistoryScreenState extends State<ComprehensiveRideHistoryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, completed, cancelled, in_progress
  String _selectedSort = 'recent'; // recent, oldest, fare_high, fare_low
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRides = [];
  List<Map<String, dynamic>> _filteredRides = [];

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      List<Map<String, dynamic>> rides = [];

      if (widget.isDriver) {
        // Load driver rides
        final driverHistory = await _databaseService.getAcceptedRides(user.uid);
        rides = driverHistory;
      } else {
        // Load passenger rides
        final passengerHistory = await _databaseService.getPassengerRideHistory(user.uid);
        rides = passengerHistory;
      }

      setState(() {
        _allRides = rides;
        _filteredRides = rides;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading rides: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allRides);

    // Apply status filter
    if (_selectedFilter != 'all') {
      filtered = filtered.where((ride) {
        final status = ride['status'];
        switch (_selectedFilter) {
          case 'completed':
            return status == RideStatus.completed.index;
          case 'cancelled':
            return status == RideStatus.cancelled.index;
          case 'in_progress':
            return status == RideStatus.inProgress.index ||
                   status == RideStatus.accepted.index;
          default:
            return true;
        }
      }).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((ride) {
        final pickup = (ride['pickupAddress'] ?? '').toLowerCase();
        final dropoff = (ride['dropoffAddress'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return pickup.contains(query) || dropoff.contains(query);
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      switch (_selectedSort) {
        case 'oldest':
          final dateA = _getRideDate(a);
          final dateB = _getRideDate(b);
          return dateA.compareTo(dateB);
        case 'fare_high':
          final fareA = (a['actualFare'] ?? a['estimatedFare'] ?? 0.0) as double;
          final fareB = (b['actualFare'] ?? b['estimatedFare'] ?? 0.0) as double;
          return fareB.compareTo(fareA);
        case 'fare_low':
          final fareA = (a['actualFare'] ?? a['estimatedFare'] ?? 0.0) as double;
          final fareB = (b['actualFare'] ?? b['estimatedFare'] ?? 0.0) as double;
          return fareA.compareTo(fareB);
        case 'recent':
        default:
          final dateA = _getRideDate(a);
          final dateB = _getRideDate(b);
          return dateB.compareTo(dateA);
      }
    });

    setState(() => _filteredRides = filtered);
  }

  DateTime _getRideDate(Map<String, dynamic> ride) {
    if (ride['dropoffTime'] != null) {
      final timestamp = ride['dropoffTime'];
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }
    if (ride['requestTime'] != null) {
      final timestamp = ride['requestTime'];
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('ride_history') ?? 'Ride History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getIconColor(isDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRides,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(isDark),
          Expanded(
            child: _isLoading
                ? const SkeletonRideList(itemCount: 5)
                : _filteredRides.isEmpty
                    ? EmptyStateWidget(
                        title: 'No Rides Found',
                        message: _searchQuery.isNotEmpty || _selectedFilter != 'all'
                            ? 'Try adjusting your search or filters'
                            : 'Your ride history will appear here',
                        icon: Icons.history,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRides.length,
                        itemBuilder: (context, index) {
                          return _buildRideCard(_filteredRides[index], isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.getBackgroundColor(isDark),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search trips...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _applyFilters();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilters();
              },
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All Trips', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('completed', 'Completed', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('cancelled', 'Cancelled', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? AppColors.uberWhite : AppColors.uberBlack) 
              : (isDark ? AppColors.darkCard : AppColors.uberGrey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
                ? (isDark ? AppColors.uberBlack : AppColors.uberWhite) 
                : (isDark ? Colors.white70 : Colors.black54),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, bool isDark) {
    final status = ride['status'] as int? ?? 0;
    final fare = (ride['actualFare'] ?? ride['estimatedFare'] ?? 0.0) as double;
    final date = _getRideDate(ride);
    final pickup = ride['pickupAddress'] ?? 'Unknown Pickup';
    final dropoff = ride['dropoffAddress'] ?? 'Unknown Destination';
    final vehicleType = ride['vehicleType'] ?? 'Standard';

    final isCompleted = status == RideStatus.completed.index;
    final isCancelled = status == RideStatus.cancelled.index;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.uberGreyLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: isCompleted ? () => _rebookRide(ride) : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM d, yyyy • h:mm a').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vehicleType,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimaryColor(isDark),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'R${fare.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.getTextPrimaryColor(isDark),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                      ),
                      Container(
                        width: 1.5,
                        height: 20,
                        color: isDark ? Colors.white10 : AppColors.uberGreyLight,
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pickup,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.getTextPrimaryColor(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          dropoff,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.getTextPrimaryColor(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success.withOpacity(0.1)
                          : isCancelled
                              ? AppColors.error.withOpacity(0.1)
                              : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCompleted
                          ? 'Completed'
                          : isCancelled
                              ? 'Cancelled'
                              : 'In Progress',
                      style: TextStyle(
                        color: isCompleted
                            ? AppColors.success
                            : isCancelled
                                ? AppColors.error
                                : AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (isCompleted)
                    Text(
                      'Tap to rebook',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _rebookRide(Map<String, dynamic> ride) {
    final pickupAddress = ride['pickupAddress'] as String?;
    final dropoffAddress = ride['dropoffAddress'] as String?;
    final pickupCoordinates = ride['pickupCoordinates'] as List<dynamic>?;
    final dropoffCoordinates = ride['dropoffCoordinates'] as List<dynamic>?;
    final vehicleType = ride['vehicleType'] as String?;

    if (pickupAddress == null || dropoffAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('cannot_rebook') ?? 'Cannot rebook: Missing location information')),
      );
      return;
    }

    List<double>? pickupCoords;
    List<double>? dropoffCoords;

    if (pickupCoordinates != null) {
      pickupCoords = pickupCoordinates.map((e) => (e as num).toDouble()).toList();
    }
    if (dropoffCoordinates != null) {
      dropoffCoords = dropoffCoordinates.map((e) => (e as num).toDouble()).toList();
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RequestRideScreen(
          initialPickupAddress: pickupAddress,
          initialDropoffAddress: dropoffAddress,
          initialPickupCoordinates: pickupCoords,
          initialDropoffCoordinates: dropoffCoords,
          initialVehicleType: vehicleType,
        ),
      ),
    );
  }
}

