import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/database_service.dart';
import '../../../services/pricing_service.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import '../../../widgets/passenger/date_time_selection.dart';
import '../../../widgets/passenger/scheduled_confirmation.dart';
import '../../../widgets/passenger/scheduled_location_selection.dart';
import '../../../widgets/passenger/scheduled_trip_header.dart';
import '../../../widgets/passenger/vehicle_selection.dart';
import '../../payments/ride_request_payment.dart';

class ScheduledTripScreen extends StatefulWidget {
  const ScheduledTripScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledTripScreen> createState() => _ScheduledTripScreenState();
}

class _ScheduledTripScreenState extends State<ScheduledTripScreen> with TickerProviderStateMixin {
  // Location variables
  Position? _currentPosition;
  LatLng? _currentLatLng;
  String _pickupAddress = '';
  String _dropoffAddress = '';
  List<double>? _pickupCoordinates;
  List<double>? _dropoffCoordinates;

  // Date and time variables
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Vehicle selection variables
  String _selectedVehicleType = '';
  String? _selectedVehiclePrice;
  bool _showVehicleTypes = false;
  bool _showConfirmation = false;

  // UI state variables
  bool _isLoading = false;
  bool _showLocationSelection = true;
  bool _paymentWasSuccessful = false;
  String _selectedPaymentType = 'Card';
  bool? _below2;
  bool _removeCancellationFee = false; // Add this line
  late final String currentUserId;

  // Controllers
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<String> _pickupPredictions = [];
  List<String> _dropoffPredictions = [];
  int? _selectedPickupPrediction;
  int? _selectedDropoffPrediction;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getCurrentLocation();
    _initializeUser();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _animationController.forward();
  }

  Future<void> _initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Schedule Trip'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getIconColor(isDark)),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const ScheduledTripHeader(),

              const SizedBox(height: 20),

              // Date and Time Selection
              DateTimeSelection(selectedDate: _selectedDate, selectedTime: _selectedTime, onDateChanged: (date) => setState(() => _selectedDate = date), onTimeChanged: (time) => setState(() => _selectedTime = time)),

              const SizedBox(height: 20),

              // Location Selection
              if (_showLocationSelection)
                ScheduledLocationSelection(pickupAddress: _pickupAddress, dropoffAddress: _dropoffAddress, onPickupChanged: (address) => setState(() => _pickupAddress = address), onDropoffChanged: (address) => setState(() => _dropoffAddress = address), onContinue: _proceedToVehicleSelection),

              // Vehicle Selection
              if (_showVehicleTypes)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.getCardColor(isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getBorderColor(isDark)),
                  ),
                  child: VehicleSelection(selectedType: _selectedVehicleType, onChanged: _selectVehicleType, distanceKm: _calculateDistance()),
                ),

              // Confirmation
              if (_showConfirmation)
                ScheduledConfirmation(
                  selectedDate: _selectedDate,
                  selectedTime: _selectedTime,
                  pickupAddress: _pickupAddress,
                  dropoffAddress: _dropoffAddress,
                  selectedVehicleType: _selectedVehicleType,
                  selectedVehiclePrice: _selectedVehiclePrice ?? '0',
                  isLoading: _isLoading,
                  onConfirm: _handlePaymentChoice,
                  distanceKm: _calculateDistance(),
                  onCancellationFeeChanged: _onCancellationFeeChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);

      // Check if location permission is already granted
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          ModernSnackBar.show(context, message: 'Location permission denied. Please enable location access.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        ModernSnackBar.show(context, message: 'Location permission permanently denied. Please enable it in your device settings.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      _currentPosition = position;
      _currentLatLng = LatLng(position.latitude, position.longitude);

      await _updateAddressFromCoordinates(_currentLatLng!);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ModernSnackBar.show(context, message: 'Error getting location: $e');
    }
  }

  Future<void> _updateAddressFromCoordinates(LatLng coordinates) async {
    try {
      final placemarks = await placemarkFromCoordinates(coordinates.latitude, coordinates.longitude);

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}';

        setState(() {
          _pickupAddress = address;
          _pickupController.text = address;
          _pickupCoordinates = [coordinates.latitude, coordinates.longitude];
        });
      }
    } catch (e) {
      ModernSnackBar.show(context, message: 'Error getting address: $e');
    }
  }

  void _proceedToVehicleSelection() {
    if (_pickupAddress.isNotEmpty && _dropoffAddress.isNotEmpty) {
      setState(() {
        _showLocationSelection = false;
        _showVehicleTypes = true;
      });
    } else {
      ModernSnackBar.show(context, message: 'Please select both pickup and dropoff locations');
    }
  }

  void _selectVehicleType(String vehicleType) async {
    // Calculate distance and get pricing info using the same logic as ride request screen
    final distance = _calculateDistance();
    final scheduledDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    
    // Use the same pricing logic as ride request screen - calculate all fares and get the specific one
    final allFares = PricingService.calculateAllFares(
      distanceKm: distance,
      requestTime: scheduledDateTime,
    );
    
    // Get the specific vehicle fare
    final vehicleFare = allFares[vehicleType.toLowerCase()] ?? 50.0;
    
    // Apply discount for specific vehicles (same as ride request screen)
    double finalPrice = vehicleFare;
    if (vehicleType == 'asambegirl') {
      finalPrice = vehicleFare * 0.7; // 30% discount
    }

    setState(() {
      _selectedVehicleType = vehicleType;
      _selectedVehiclePrice = finalPrice.toString();
      _showVehicleTypes = false;
      _showConfirmation = true;
    });
  }

  void _onCancellationFeeChanged(bool removeCancellationFee) {
    setState(() {
      _removeCancellationFee = removeCancellationFee;
    });
  }

  Future<void> _handlePaymentChoice() async {
    // Validate minimum 2 hours requirement
    final now = DateTime.now();
    final scheduledDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    final timeDifference = scheduledDateTime.difference(now);
    
    if (timeDifference.inHours < 2) {
      ModernSnackBar.show(context, message: 'Scheduled trips must be at least 2 hours from now');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Calculate distance and pricing using the same logic as ride request screen
      final distance = _calculateDistance();
      final scheduledDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
      
      // Use the same pricing logic as ride request screen
      final allFares = PricingService.calculateAllFares(
        distanceKm: distance,
        requestTime: scheduledDateTime,
      );
      
      // Get the specific vehicle fare
      final vehicleFare = allFares[_selectedVehicleType.toLowerCase()] ?? 50.0;
      
      // Apply discount for specific vehicles (same as ride request screen)
      double calculatedPrice = vehicleFare;
      if (_selectedVehicleType == 'asambegirl') {
        calculatedPrice = vehicleFare * 0.7; // 30% discount
      }
      
      final cancellationFee = _removeCancellationFee ? 0.0 : calculatedPrice * 0.15;
      final totalAmount = calculatedPrice + cancellationFee;
      
      // Navigate to payment screen for card payments
      final paymentResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => RidePaymentScreen(
            amount: totalAmount,
            email: FirebaseAuth.instance.currentUser?.email ?? '',
            onPaymentSuccess: () {
              Navigator.pop(context, true);
            },
          ),
        ),
      );

      if (paymentResult == true) {
        _paymentWasSuccessful = true;
        await _createScheduledBooking();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ModernSnackBar.show(context, message: 'Payment failed: $e');
    }
  }

  Future<void> _createScheduledBooking() async {
    if (_pickupAddress.isEmpty || _dropoffAddress.isEmpty) {
      ModernSnackBar.show(context, message: 'Please select pickup and dropoff locations');
      return;
    }

    if (_pickupCoordinates == null || _dropoffCoordinates == null) {
      ModernSnackBar.show(context, message: 'Please select valid pickup and dropoff locations');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Calculate distance and pricing using the same logic as ride request screen
      final distance = _calculateDistance();
      final scheduledDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
      
      // Use the same pricing logic as ride request screen
      final allFares = PricingService.calculateAllFares(
        distanceKm: distance,
        requestTime: scheduledDateTime,
      );
      
      // Get the specific vehicle fare
      final vehicleFare = allFares[_selectedVehicleType.toLowerCase()] ?? 50.0;
      
      // Apply discount for specific vehicles (same as ride request screen)
      double calculatedPrice = vehicleFare;
      if (_selectedVehicleType == 'asambegirl') {
        calculatedPrice = vehicleFare * 0.7; // 30% discount
      }
      
      final cancellationFee = _removeCancellationFee ? 0.0 : calculatedPrice * 0.15;
      final totalAmount = calculatedPrice + cancellationFee;

      // Prepare request data
      final requestData = {
        'userId': currentUserId,
        'pickupAddress': _pickupAddress,
        'pickupCoordinates': _pickupCoordinates,
        'dropoffAddress': _dropoffAddress,
        'dropoffCoordinates': _dropoffCoordinates,
        'vehicleType': _selectedVehicleType,
        'distance': distance,
        'estimatedFare': calculatedPrice,
        'basePrice': calculatedPrice,
        'cancellationFee': cancellationFee,
        'totalAmount': totalAmount,
        'removeCancellationFee': _removeCancellationFee,
        'paymentType': _selectedPaymentType,
        'paymentStatus': 'paid', // Since it's card payment only
        'status': 'scheduled', // Changed from 'pending' to 'scheduled'
        'scheduledDateTime': Timestamp.fromDate(scheduledDateTime),
        'createdAt': FieldValue.serverTimestamp(),
        'below2': _below2 ?? true,
        'passengerCount': _below2 == true ? 1 : 2,
        'bookingTime': FieldValue.serverTimestamp(), // For cancellation policy
      };

      // Save to scheduled requests collection
      final databaseService = DatabaseService();
      await databaseService.createScheduledRequest(requestData);

      setState(() => _isLoading = false);

      // Show success message
      ModernSnackBar.show(context, message: 'Scheduled trip booked successfully!');

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ModernSnackBar.show(context, message: 'Error creating scheduled booking: $e');
    }
  }

  double _calculateDistance() {
    if (_pickupCoordinates == null || _dropoffCoordinates == null) return 0.0;

    const double earthRadius = 6371; // Earth's radius in kilometers

    final double lat1 = _pickupCoordinates![0];
    final double lng1 = _pickupCoordinates![1];
    final double lat2 = _dropoffCoordinates![0];
    final double lng2 = _dropoffCoordinates![1];

    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLng = (lng2 - lng1) * (pi / 180);

    final double a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
}
