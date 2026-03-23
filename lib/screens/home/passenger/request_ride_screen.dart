import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gibelbibela/screens/auth/female_verification_screen.dart';
import 'package:gibelbibela/screens/auth/student_verification_screen.dart'; // Added import for StudentVerificationScreen
import 'package:gibelbibela/services/auth_service.dart';
import 'package:gibelbibela/services/pricing_service.dart';
import 'package:gibelbibela/services/ride_service.dart';
import 'package:gibelbibela/widgets/passenger/vehicle_selection.dart';

import '../../../constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/database_service.dart';
import '../../../widgets/common/custom_button.dart';
import '../../../widgets/passenger/route_preview_widget.dart';
import '../../../widgets/passenger/split_fare_widget.dart';
import '../../../services/map_route_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat/chat_screen.dart';
import '../../payments/ride_request_payment.dart';
// Removed: import 'widgets/prediction_list.dart';
// Removed: import 'widgets/ride_finding_overlay.dart';
// Remove imports for RideBookingView, ConfirmationCard, VehicleTypeSheet

class RequestRideScreen extends StatefulWidget {
  final String? initialPickupAddress;
  final String? initialDropoffAddress;
  final List<double>? initialPickupCoordinates;
  final List<double>? initialDropoffCoordinates;
  final String? initialVehicleType;
  final String? initialPaymentType;

  const RequestRideScreen({
    Key? key,
    this.initialPickupAddress,
    this.initialDropoffAddress,
    this.initialPickupCoordinates,
    this.initialDropoffCoordinates,
    this.initialVehicleType,
    this.initialPaymentType,
  }) : super(key: key);

  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> with TickerProviderStateMixin {
  bool? _below2; // Must be selected by user
  late final String currentUserId;
  int? _selectedVehicleIndex;
  String? _selectedVehiclePrice;
  String? _selectedVehicleEta;
  String _selectedPaymentType = 'Card';
  int _confirmationStage = 0;
  Map<String, dynamic>? _assignedDriver;
  String? _assignedDriverId;
  String? _currentRequestId;
  StreamSubscription<DocumentSnapshot>? _requestStreamSubscription;
  LatLng? _currentLatLng;
  List<LatLng> _routePoints = [];
  AnimationController? _routeAnimController;
  Animation<double>? _routeAnim;
  Timer? _routeAnimTimer;
  bool _driverAssigned = false;
  bool _paymentWasSuccessful = false;
  Position? _currentPosition;
  List<double>? _pickupCoordinates;
  List<double>? _dropoffCoordinates;
  String _pickupAddress = '';
  String _dropoffAddress = '';
  String _selectedVehicleType = 'Standard';
  bool _isLoading = false;
  bool _showLocationSelection = true;
  bool _showRideBooking = false;
  bool _showVehicleTypes = false;
  bool _showConfirmation = false;
  bool _showRoutePreview = false;
  bool _showSplitFare = false;
  RouteInfo? _selectedRoute;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<String> _pickupPredictions = [];
  List<String> _dropoffPredictions = [];
  int? _selectedPickupPrediction;
  int? _selectedDropoffPrediction;

  // Add vehicleTypes getter
  List<Map<String, dynamic>> get vehicleTypes {
    // Calculate distance for pricing
    final distance = _calculateDistance();

    // Get pricing for all vehicle types
    final allFares = PricingService.calculateAllFares(distanceKm: distance);

    // Helper function to apply discount
    double applyDiscount(double price, int discountPercent) {
      if (discountPercent <= 0) return price;
      final discount = price * (discountPercent / 100);
      return price - discount;
    }

    return [
      {
        'type': 'asambevia',
        'name': 'AsambeVia',
        'originalPrice': allFares['via']?.toStringAsFixed(2) ?? '50',
        'price': allFares['via']?.toStringAsFixed(2) ?? '50',
        'eta': PricingService.getEstimatedTime(distanceKm: distance, vehicleType: 'via'),
        'image': 'assets/images/via.png',
        'maxPeople': '2-3',
        'subtitle': 'Affordable rides',
        'color': AppColors.smallVehicle,
        'available': false,
        'discountPercent': 0,
      },
      {
        'type': 'asambegirl',
        'name': 'AsambeGirl',
        'originalPrice': allFares['girl']?.toStringAsFixed(2) ?? '60',
        'price': applyDiscount(double.parse(allFares['girl']?.toStringAsFixed(2) ?? '60'), 30).toStringAsFixed(2),
        'eta': PricingService.getEstimatedTime(distanceKm: distance, vehicleType: 'girl'),
        'image': 'assets/images/girl.png',
        'maxPeople': 3,
        'subtitle': 'Female drivers only',
        'color': AppColors.sedanVehicle,
        'available': true,
        'discountPercent': 30,
      },
      {
        'type': 'asambe7',
        'name': 'Asambe7',
        'originalPrice': allFares['seven']?.toStringAsFixed(2) ?? '80',
        'price': allFares['seven']?.toStringAsFixed(2) ?? '80',
        'eta': PricingService.getEstimatedTime(distanceKm: distance, vehicleType: 'seven'),
        'image': 'assets/images/7.png',
        'maxPeople': 6,
        'subtitle': 'Large group rides',
        'color': AppColors.largeVehicle,
        'available': true,
        'discountPercent': 0,
      },
      {
        'type': 'asambeluxury',
        'name': 'AsambeLuxury',
        'originalPrice': allFares['luxury']?.toStringAsFixed(2) ?? '120',
        'price': allFares['luxury']?.toStringAsFixed(2) ?? '120',
        'eta': PricingService.getEstimatedTime(distanceKm: distance, vehicleType: 'luxury'),
        'image': 'assets/images/lux.png',
        'maxPeople': 3,
        'subtitle': 'Premium experience',
        'color': AppColors.primaryDark,
        'available': true,
        'discountPercent': 0,
      },
      {
        'type': 'asambestudent',
        'name': 'AsambeStudent',
        'originalPrice': allFares['student']?.toStringAsFixed(2) ?? '45',
        'price': allFares['student']?.toStringAsFixed(2) ?? '45',
        'eta': PricingService.getEstimatedTime(distanceKm: distance, vehicleType: 'student'),
        'image': 'assets/images/student.png',
        'maxPeople': 3,
        'subtitle': 'Student discount rides',
        'color': AppColors.secondary,
        'available': true,
        'discountPercent': 0,
      },
      {
        'type': 'asambeparcel',
        'name': 'AsambeParcel',
        'originalPrice': allFares['parcel']?.toStringAsFixed(2) ?? '35',
        'price': allFares['parcel']?.toStringAsFixed(2) ?? '35',
        'eta': PricingService.getEstimatedTime(distanceKm: distance, vehicleType: 'parcel'),
        'image': 'assets/images/parcel.png',
        'maxPeople': 1,
        'subtitle': 'Package delivery',
        'color': AppColors.success,
        'available': true,
        'discountPercent': 0,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    currentUserId = authService.userModel?.uid ?? FirebaseAuth.instance.currentUser!.uid;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Pre-fill from rebook parameters if provided
    if (widget.initialPickupAddress != null) {
      _pickupAddress = widget.initialPickupAddress!;
      _pickupController.text = widget.initialPickupAddress!;
    }
    if (widget.initialDropoffAddress != null) {
      _dropoffAddress = widget.initialDropoffAddress!;
      _dropoffController.text = widget.initialDropoffAddress!;
    }
    if (widget.initialPickupCoordinates != null) {
      _pickupCoordinates = widget.initialPickupCoordinates;
      _currentLatLng = LatLng(widget.initialPickupCoordinates![0], widget.initialPickupCoordinates![1]);
    }
    if (widget.initialDropoffCoordinates != null) {
      _dropoffCoordinates = widget.initialDropoffCoordinates;
    }
    if (widget.initialVehicleType != null) {
      _selectedVehicleType = widget.initialVehicleType!;
    }
    if (widget.initialPaymentType != null) {
      _selectedPaymentType = widget.initialPaymentType!;
    }
    
    // Only get current location if pickup wasn't pre-filled
    if (widget.initialPickupAddress == null) {
      _getCurrentLocation();
    }
    _animationController.forward();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_currentPosition != null) {
        _pickupCoordinates = [_currentPosition!.latitude, _currentPosition!.longitude];
        _currentLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        await _updateAddressFromCoordinates(_pickupCoordinates!, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)?.translate('error_getting_location') ?? 'Error getting location'}: $e')),
      );
      // Default to Johannesburg if location not available
      _currentLatLng = LatLng(-26.2041, 28.0473);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAddressFromCoordinates(List<double> coordinates, bool isPickup) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinates[0],
        coordinates[1],
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = '${place.street}, ${place.locality}, ${place.administrativeArea}';

        setState(() {
          if (isPickup) {
            _pickupAddress = address;
            _pickupController.text = address;
          } else {
            _dropoffAddress = address;
            _dropoffController.text = address;
          }
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  Future<List<String>> _fetchPredictions(String query) async {
    // Use the provided Mapbox public key
    const mapboxApiKey = 'pk.eyJ1IjoibmRhYmVuaGxlbmdlbWExOTk2IiwiYSI6ImNsdnR0d2x3ZTAyeHIya25ld3k3MnF2aGoifQ.awJhdpzb2bBtfiJRK35pCg';
    final url = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${Uri.encodeComponent(query)}.json?access_token=$mapboxApiKey&autocomplete=true&country=ZA');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final features = data['features'] as List<dynamic>;
      return features.map((f) => f['place_name'] as String).toList();
    }
    return [];
  }

  Future<void> _onPickupTextChanged(String query) async {
    if (query.isNotEmpty) {
      final predictions = await _fetchPredictions(query);
      setState(() {
        _pickupPredictions = predictions;
        _selectedPickupPrediction = null;
      });
    } else {
      setState(() {
        _pickupPredictions = [];
        _selectedPickupPrediction = null;
      });
    }
  }

  Future<void> _onDropoffTextChanged(String query) async {
    if (query.isNotEmpty) {
      final predictions = await _fetchPredictions(query);
      setState(() {
        _dropoffPredictions = predictions;
        _selectedDropoffPrediction = null;
      });
    } else {
      setState(() {
        _dropoffPredictions = [];
        _selectedDropoffPrediction = null;
      });
    }
  }

  void _onPickupPredictionSelected(String prediction) async {
    setState(() {
      _pickupController.text = prediction;
      _pickupPredictions = [];
      _selectedPickupPrediction = null;
    });
    try {
      final locations = await locationFromAddress(prediction);
      if (locations.isNotEmpty) {
        _pickupCoordinates = [locations.first.latitude, locations.first.longitude];
      }
    } catch (e) {
      // Optionally show error
    }
  }

  void _onDropoffPredictionSelected(String prediction) async {
    setState(() {
      _dropoffController.text = prediction;
      _dropoffAddress = prediction; // Ensure dropoff address is set
      _dropoffPredictions = [];
      _selectedDropoffPrediction = null;
    });
    try {
      final locations = await locationFromAddress(prediction);
      if (locations.isNotEmpty) {
        _dropoffCoordinates = [locations.first.latitude, locations.first.longitude];
      }
    } catch (e) {
      // Optionally show error
    }
  }

  void _proceedToVehicleSelection() {
    if (_pickupCoordinates != null && _dropoffCoordinates != null) {
      setState(() {
        _showLocationSelection = false;
        _showVehicleTypes = true;
      });
      _refreshDisabledTypesOnDemand();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('please_select_pickup_dropoff') ?? 'Please select both pickup and dropoff locations')),
      );
    }
  }

  void _selectVehicleType(String vehicleType) async {
    if (vehicleType == 'asambegirl') {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();

        // Check if isGirl exists and is true, otherwise show verification
        if (!userDoc.exists || !userDoc.data()!.containsKey('isGirl') || userDoc.data()!['isGirl'] != true) {
          if (!mounted) return;
          final shouldVerify = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Female Verification Required'),
              content: const Text('You need to verify as a female to use AsambeGirl rides.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(AppLocalizations.of(context)?.translate('verify') ?? 'Verify'),
                ),
              ],
            ),
          );
          if (shouldVerify == true) {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FemaleVerificationScreen()),
            );
          }
          return;
        }
      } catch (e) {
        print('Error checking female verification: $e');
        // If there's an error, default to requiring verification
        if (!mounted) return;
        final shouldVerify = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)?.translate('female_verification_required') ?? 'Female Verification Required'),
            content: Text(AppLocalizations.of(context)?.translate('female_verification_message') ?? 'You need to verify as a female to use AsambeGirl rides.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(AppLocalizations.of(context)?.translate('verify') ?? 'Verify'),
              ),
            ],
          ),
        );
        if (shouldVerify == true) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FemaleVerificationScreen()),
          );
        }
        return;
      }
    } else if (vehicleType == 'asambestudent') {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final isStudent = userDoc.data()?['isStudent'] == true;
      if (!isStudent) {
        if (!mounted) return;
        final shouldVerify = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)?.translate('student_verification_required') ?? 'Student Verification Required'),
            content: Text(AppLocalizations.of(context)?.translate('student_verification_message') ?? 'You need to verify as a student to use AsambeStudent rides.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(AppLocalizations.of(context)?.translate('verify') ?? 'Verify'),
              ),
            ],
          ),
        );
        if (shouldVerify == true) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StudentVerificationScreen()),
          );
        }
        return;
      }
    }

    // Calculate distance and get pricing info
    final distance = _calculateDistance();
    final pricingInfo = PricingService.getPricingInfo(
      distanceKm: distance,
      vehicleType: vehicleType,
    );

    setState(() {
      _selectedVehicleType = vehicleType;
      _selectedVehiclePrice = pricingInfo['finalPrice'].toString();
      _selectedVehicleEta = pricingInfo['estimatedTime'];
      _showVehicleTypes = false;
      _showConfirmation = true;
    });

    // Show confirmation sheet
    _showConfirmationSheet();
  }

  // Build vehicle selection using unified widget gating
  Widget _buildVehicleSelection() {
    return VehicleSelection(
      selectedType: _selectedVehicleType,
      onChanged: _selectVehicleType,
      distanceKm: _calculateDistance(),
      requestTime: DateTime.now(),
      disabledTypes: _disabledTypesOnDemand,
      onDisabledTap: _handleDisabledTapOnDemand,
    );
  }

  Set<String> _disabledTypesOnDemand = {};
  Future<void> _refreshDisabledTypesOnDemand() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final isGirl = userDoc.data()?['isGirl'] == true;
      final isStudent = userDoc.data()?['isStudent'] == true;
      final disabled = <String>{};
      if (!isGirl) disabled.add('asambegirl');
      if (!isStudent) disabled.add('asambestudent');
      setState(() {
        _disabledTypesOnDemand = disabled;
      });
    } catch (_) {}
  }

  Future<void> _handleDisabledTapOnDemand(String type) async {
    if (type == 'asambegirl') {
      final shouldVerify = await showDialog<bool>(
        context: context,
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(localizations?.translate('female_verification_required') ?? 'Female Verification Required'),
            content: Text(localizations?.translate('female_verification_message') ?? 'You need to verify as a female to use AsambeGirl rides.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(localizations?.translate('cancel') ?? 'Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: Text(localizations?.translate('verify') ?? 'Verify')),
            ],
          );
        },
      );
      if (shouldVerify == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FemaleVerificationScreen()),
        );
      }
    } else if (type == 'asambestudent') {
      final shouldVerify = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)?.translate('student_verification_required') ?? 'Student Verification Required'),
          content: Text(AppLocalizations.of(context)?.translate('student_verification_message') ?? 'You need to verify as a student to use AsambeStudent rides.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context)?.translate('verify') ?? 'Verify')),
          ],
        ),
      );
      if (shouldVerify == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StudentVerificationScreen()),
        );
      }
    }
  }

  void _confirmBooking() {
    setState(() {
      _showRideBooking = false;
      _showConfirmation = true;
    });
  }

  Future<void> _handlePaymentChoice() async {
    _paymentWasSuccessful = false;
    if (_selectedPaymentType == 'Card') {
      setState(() {
        _showConfirmation = false;
      });
      // Navigate to payment screen for card payments
      final paymentResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => RidePaymentScreen(
            amount: double.parse(_selectedVehiclePrice ?? '0'),
            email: FirebaseAuth.instance.currentUser?.email ?? '',
            onPaymentSuccess: () {
              Navigator.pop(context, true);
            },
          ),
        ),
      );
      if (paymentResult == true) {
        _paymentWasSuccessful = true;
        _startDriverSearch();
      }
    } else {
      // For cash payments, proceed directly
      _paymentWasSuccessful = true;
      _startDriverSearch();
    }
  }

  void _startDriverSearch() {
    setState(() {
      _showConfirmation = true;
      _confirmationStage = 0;
      _driverAssigned = false;
    });
    // Only create the ride request if payment type is not card, or if called after payment success
    if (_selectedPaymentType != 'Card' || _paymentWasSuccessful) {
      _createRideRequest();
    }
  }

  Future<void> _createRideRequest() async {
    if (_dropoffAddress.isEmpty || _dropoffCoordinates == null || _pickupCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('please_select_dropoff') ?? 'Please select a dropoff location before requesting a ride.')),
      );
      setState(() {
        _isLoading = false;
        _showConfirmation = false;
        _showLocationSelection = true;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final rideService = Provider.of<RideService>(context, listen: false);
      final distance = _calculateDistance();
      
      // Determine passenger count and special ride types
      final passengerCount = (_below2 ?? true) ? 1 : 2;
      final isAsambeGirl = _selectedVehicleType.toLowerCase().contains('girl');
      final isAsambeStudent = _selectedVehicleType.toLowerCase().contains('student');
      final isAsambeLuxury = _selectedVehicleType.toLowerCase().contains('luxury');
      
      // Use RideService to create ride request (prevents duplicates)
      final createdRide = await rideService.requestRide(
        passengerId: currentUserId,
        pickupAddress: _pickupAddress,
        pickupLat: _pickupCoordinates![0],
        pickupLng: _pickupCoordinates![1],
        dropoffAddress: _dropoffAddress,
        dropoffLat: _dropoffCoordinates![0],
        dropoffLng: _dropoffCoordinates![1],
        vehicleType: _selectedVehicleType,
        distance: distance,
        passengerCount: passengerCount,
        isAsambeGirl: isAsambeGirl,
        isAsambeStudent: isAsambeStudent,
        isAsambeLuxury: isAsambeLuxury,
      );

      // Update payment info separately (RideService doesn't handle payment)
      if (createdRide != null) {
        await FirebaseFirestore.instance.collection('requests').doc(createdRide.id).update({
          'vehiclePrice': _selectedVehiclePrice,
          'paymentType': _selectedPaymentType,
          'paymentStatus': _selectedPaymentType == 'Card' ? 'paid' : 'pending',
          'below2': _below2 ?? true,
        });
        
        _currentRequestId = createdRide.id;
        _listenForDriverAssignment(createdRide.id);
      }

      setState(() => _isLoading = false);

      // Start the confirmation stage animation
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _confirmationStage = 1);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _confirmationStage = 2);
        });
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showConfirmation = false;
      });
      
      String errorMessage = 'Failed to create ride request';
      if (e.toString().contains('already have an active')) {
        errorMessage = 'You already have an active ride request. Please cancel it first.';
      } else if (e.toString().isNotEmpty) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> fetchDriverProfile(String driverId) async {
    final doc = await FirebaseFirestore.instance.collection('drivers').doc(driverId).get();
    return doc.exists ? doc.data() : null;
  }

  Timer? _timeoutTimer;
  
  void _listenForDriverAssignment(String requestId) {
    _requestStreamSubscription?.cancel();
    _timeoutTimer?.cancel();
    
    _requestStreamSubscription = FirebaseFirestore.instance.collection('requests').doc(requestId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String?;
      final driverId = data['driverId'];
      
      // Check if request was cancelled or timed out
      if (status == 'cancelled') {
        final reason = data['cancellationReason'] as String? ?? 'Request cancelled';
        if (mounted) {
          setState(() {
            _isLoading = false;
            _showConfirmation = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reason),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        _timeoutTimer?.cancel();
        return;
      }
      
      if (driverId != null && driverId != _assignedDriverId) {
        // New driver assigned, fetch full profile
        final driverProfile = await fetchDriverProfile(driverId);
        if (mounted) {
          setState(() {
            _assignedDriver = driverProfile;
            _assignedDriverId = driverId;
            _confirmationStage = 3;
            _driverAssigned = true;
          });
        }
        _timeoutTimer?.cancel();
      }
    });
    
    // Start timeout monitoring (15 minutes)
    _timeoutTimer = Timer(const Duration(minutes: 15), () {
      if (mounted && !_driverAssigned) {
        setState(() {
          _isLoading = false;
          _showConfirmation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('ride_request_timeout') ?? 'Your ride request timed out. No driver was available. Please try again.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }
  
  @override
  void dispose() {
    _routeAnimController?.dispose();
    _routeAnimTimer?.cancel();
    _animationController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _requestStreamSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _showDriverDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDriverDetailsView(),
    );
  }

  Future<void> _fetchRouteAndAnimate() async {
    if (_pickupCoordinates == null || _dropoffCoordinates == null) {
      print('DEBUG: Missing pickup or dropoff coordinates');
      return;
    }
    print('DEBUG: Fetching route from $_pickupCoordinates to $_dropoffCoordinates');
    final start = _pickupCoordinates!;
    final end = _dropoffCoordinates!;
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${start[1]},${start[0]};${end[1]},${end[0]}?overview=full&geometries=geojson',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      setState(() {
        _routePoints = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
      });
      print('DEBUG: Route fetched with ${_routePoints.length} points');
      _startRouteAnimation();
    } else {
      print('DEBUG: Failed to fetch route, status: ${response.statusCode}');
    }
  }

  void _startRouteAnimation() {
    _routeAnimController?.dispose();
    _routeAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200 + (_routePoints.length * 8)),
    );
    _routeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _routeAnimController!,
      curve: Curves.easeInOut,
    ));
    _routeAnimController!.addListener(() {
      setState(() {});
    });
    _routeAnimController!.forward();
  }

  double _calculateDistance() {
    if (_pickupCoordinates == null || _dropoffCoordinates == null) {
      return 1.0; // Default 1km if coordinates not available
    }

    const double R = 6371; // Radius of the earth in km
    final double lat1 = _pickupCoordinates![0];
    final double lon1 = _pickupCoordinates![1];
    final double lat2 = _dropoffCoordinates![0];
    final double lon2 = _dropoffCoordinates![1];

    final double dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final double dLon = (lon2 - lon1) * 3.141592653589793 / 180;
    final double a = 0.5 - (cos(dLat) / 2) + cos(lat1 * 3.141592653589793 / 180) * cos(lat2 * 3.141592653589793 / 180) * (1 - cos(dLon)) / 2;
    final double distance = R * 2 * asin(sqrt(a));
    return distance;
  }

  void _showVehicleTypeSheet() async {
    if (!mounted) return;
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    int? selectedIndex = _selectedVehicleIndex;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : AppColors.uberGrey,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Your Ride',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.getTextPrimaryColor(isDark),
                                letterSpacing: -0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                AppLocalizations.of(context)?.translate('best_price') ?? 'Best Price',
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: vehicleTypes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final vehicle = vehicleTypes[index];
                            final isSelected = selectedIndex == index;
                            final color = vehicle['color'] as Color;

                            return GestureDetector(
                              onTap: () async {
                                if (vehicle['available'] == false) return;
                                setModalState(() {
                                  selectedIndex = index;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? color.withOpacity(0.08) 
                                      : (isDark ? Colors.white.withOpacity(0.03) : AppColors.white),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? color : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.15),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    )
                                  ] : [],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Image.asset(vehicle['image'], fit: BoxFit.contain),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vehicle['name'],
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.getTextPrimaryColor(isDark),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            vehicle['subtitle'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.getTextSecondaryColor(isDark),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.person_outline_rounded, size: 14, color: isSelected ? color : Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('${vehicle['maxPeople']}', style: TextStyle(color: isSelected ? color : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Builder(
                                                builder: (context) {
                                                  final localizations = AppLocalizations.of(context);
                                                  return Text('3 ${localizations?.translate('min') ?? 'min'}', style: const TextStyle(color: Colors.grey, fontSize: 12));
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'R${vehicle['price']}',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: isSelected ? color : AppColors.getTextPrimaryColor(isDark),
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        if (isSelected) 
                                          Container(
                                            margin: const EdgeInsets.only(top: 8),
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                            child: const Icon(Icons.check, color: Colors.white, size: 12),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: CustomButton(
                          text: selectedIndex != null ? 'Choose ${vehicleTypes[selectedIndex!]['name']}' : 'Select a Vehicle',
                          onPressed: selectedIndex == null ? null : () {
                            setState(() {
                              _selectedVehicleIndex = selectedIndex;
                              _selectedVehicleType = vehicleTypes[selectedIndex!]['name'];
                              _selectedVehiclePrice = vehicleTypes[selectedIndex!]['price'];
                            });
                            Navigator.of(context).pop();
                            _showRideBookingSheet();
                          },
                          isFullWidth: true,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showRideBookingSheet() async {
    if (!mounted) return;
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Vehicle & Price Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.directions_car_filled, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedVehicleType ?? 'Standard',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: AppColors.getTextPrimaryColor(isDark),
                                ),
                              ),
                              Text(
                                'Recommended',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.getTextSecondaryColor(isDark),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        'R${_selectedVehiclePrice ?? '0.00'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Route Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Distance & Route info
                        Row(
                          children: [
                            Icon(Icons.timeline, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Total Distance: ',
                              style: TextStyle(
                                color: AppColors.getTextSecondaryColor(isDark),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${_calculateDistance().toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextPrimaryColor(isDark),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Path representation
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 4)],
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 30,
                                  color: isDark ? Colors.white10 : Colors.black12,
                                ),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 4)],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickupController.text,
                                    style: TextStyle(
                                      color: AppColors.getTextPrimaryColor(isDark),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 22),
                                  Text(
                                    _dropoffController.text,
                                    style: TextStyle(
                                      color: AppColors.getTextPrimaryColor(isDark),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Route Preview Section
                  if (_pickupCoordinates != null && _dropoffCoordinates != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Route Preview',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimaryColor(isDark),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              _showRoutePreview = !_showRoutePreview;
                            });
                          },
                          icon: Icon(
                            _showRoutePreview ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                          ),
                          label: Text(_showRoutePreview ? 'Hide' : 'Show'),
                        ),
                      ],
                    ),
                    if (_showRoutePreview) ...[
                      const SizedBox(height: 12),
                      RoutePreviewWidget(
                        pickup: gmaps.LatLng(_pickupCoordinates![0], _pickupCoordinates![1]),
                        dropoff: gmaps.LatLng(_dropoffCoordinates![0], _dropoffCoordinates![1]),
                        onRouteSelected: (route) {
                          setModalState(() {
                            _selectedRoute = route;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                  
                  // Split Fare Option
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Split Fare',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimaryColor(isDark),
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _showSplitFare,
                        onChanged: (value) {
                          setModalState(() {
                            _showSplitFare = value;
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  if (_showSplitFare) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.uberGreyLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _currentRequestId == null
                            ? 'Split fare will be available after booking'
                            : 'Split fare feature - Add participants after booking',
                        style: TextStyle(
                          color: isDark ? AppColors.white : AppColors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Payment Section
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimaryColor(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentOptionCard(
                          icon: Icons.credit_card,
                          label: 'Card',
                          isSelected: _selectedPaymentType == 'Card',
                          isDark: isDark,
                          onTap: () => setModalState(() => _selectedPaymentType = 'Card'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PaymentOptionCard(
                          icon: Icons.payments_outlined,
                          label: 'Cash',
                          isSelected: _selectedPaymentType == 'Cash',
                          isDark: isDark,
                          onTap: () => setModalState(() => _selectedPaymentType = 'Cash'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Passengers Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Number of Passengers',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimaryColor(isDark),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _PassengerChip(
                              label: "1-2",
                              isSelected: _below2 == true,
                              onTap: () => setModalState(() => _below2 = true),
                              isDark: isDark,
                            ),
                            _PassengerChip(
                              label: "3+",
                              isSelected: _below2 == false,
                              onTap: () => setModalState(() => _below2 = false),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Confirmation Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _below2 == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _handlePaymentChoice();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Confirm Booking',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _below2 == null ? AppColors.getTextHintColor(isDark) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showConfirmationSheet() async {
    if (!mounted) return;
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      isDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void startStageAnimation() {
              if (_confirmationStage == 0) {
                Future.delayed(const Duration(seconds: 3), () {
                  if (Navigator.of(context).canPop()) {
                    setModalState(() {
                      _confirmationStage = 1;
                    });
                  }
                  Future.delayed(const Duration(seconds: 3), () {
                    if (Navigator.of(context).canPop()) {
                      setModalState(() {
                        _confirmationStage = 2;
                      });
                    }
                  });
                });
              }
            }

            if (_confirmationStage == 0) startStageAnimation();

            return Container(
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_confirmationStage == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: AppColors.success, size: 64),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Request Received',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.getTextPrimaryColor(isDark),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Searching for the best driver nearby...',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.getTextSecondaryColor(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (_confirmationStage == 1) ...[
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary.withOpacity(0.3)),
                          ),
                        ),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 44),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Finding Your Ride',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.getTextPrimaryColor(isDark),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connecting with nearby drivers...',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.getTextSecondaryColor(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else if (_confirmationStage == 2) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 64),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Securing Your Driver',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.getTextPrimaryColor(isDark),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Almost there! Securing your trip.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.getTextSecondaryColor(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  CustomButton(
                    text: 'Cancel Request',
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _showConfirmation = false;
                        _showLocationSelection = true;
                        _isLoading = false;
                      });
                    },
                    isOutlined: true,
                    color: AppColors.error,
                    isFullWidth: true,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      resizeToAvoidBottomInset: true, // Ensure proper keyboard handling
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_currentLatLng != null && !_showConfirmation)
            FlutterMap(
              options: MapOptions(
                center: _currentLatLng,
                zoom: 14.5,
                interactiveFlags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.rideapp.mobile',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 48,
                      height: 48,
                      point: _currentLatLng!,
                      builder: (ctx) => const Icon(Icons.directions_car, color: Colors.blueAccent, size: 40),
                    ),
                  ],
                ),
              ],
            )
          else if (_currentLatLng == null && !_showConfirmation)
            const Center(child: CircularProgressIndicator()),
          if (_showLocationSelection) _buildLocationSelectionView(),
          if (_showConfirmation && !_driverAssigned)
            _RideFindingOverlay(
              status: 'Looking for driver...',
              driverName: '',
              eta: '',
              onCancel: () {
                setState(() {
                  _showConfirmation = false;
                  _showLocationSelection = true;
                  _isLoading = false;
                });
              },
              isDark: isDark,
            ),
          if (_showConfirmation && _driverAssigned) _buildDriverDetailsView(),
          if (_isLoading && !_showConfirmation) _buildAnimatedLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLocationSelectionView() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : AppColors.uberGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _buildLocationField(
                      controller: _pickupController,
                      label: 'Pickup',
                      icon: Icons.my_location_rounded,
                      iconColor: AppColors.success,
                      onChanged: _onPickupTextChanged,
                      isDark: isDark,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                    ),
                    _buildLocationField(
                      controller: _dropoffController,
                      label: 'Where to?',
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.error,
                      onChanged: _onDropoffTextChanged,
                      isDark: isDark,
                      hint: 'Search destination',
                    ),
                  ],
                ),
              ),
              if (_pickupPredictions.isNotEmpty)
                _PredictionList(
                  predictions: _pickupPredictions,
                  selectedIndex: _selectedPickupPrediction,
                  onSelected: (index) => _onPickupPredictionSelected(_pickupPredictions[index]),
                  isDark: isDark,
                ),
              if (_dropoffPredictions.isNotEmpty)
                _PredictionList(
                  predictions: _dropoffPredictions,
                  selectedIndex: _selectedDropoffPrediction,
                  onSelected: (index) => _onDropoffPredictionSelected(_dropoffPredictions[index]),
                  isDark: isDark,
                ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Confirm Locations',
                onPressed: _showVehicleTypeSheet,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Function(String) onChanged,
    required bool isDark,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.getTextSecondaryColor(isDark),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintText: hint,
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: TextStyle(
        color: AppColors.getTextPrimaryColor(isDark),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAnimatedLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 15),
                Text(
                  'Loading...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverDetailsView() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final driverName = _assignedDriver?['name'] ?? 'Driver';
    final vehicleModel = _assignedDriver?['car'] ?? 'Vehicle';
    final licensePlate = _assignedDriver?['plate'] ?? '';
    final driverImage = _assignedDriver?['image'] ?? '';
    final rating = _assignedDriver?['rating'] != null 
        ? double.parse(_assignedDriver!['rating'].toString()).toStringAsFixed(1)
        : '5.0';
    final eta = _assignedDriver?['eta'] ?? '3 min';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 25,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : AppColors.uberGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: AppColors.uberGrey,
                          backgroundImage: driverImage.isNotEmpty ? NetworkImage(driverImage) : null,
                          child: driverImage.isEmpty ? const Icon(Icons.person, size: 35, color: Colors.grey) : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.uberBlack,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: AppColors.primary, size: 12),
                              const SizedBox(width: 2),
                              Text(rating, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.getTextPrimaryColor(isDark),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '$vehicleModel • $licensePlate',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextSecondaryColor(isDark),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(eta.split(' ')[0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                        Text(AppLocalizations.of(context)?.translate('min') ?? 'min', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Message',
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed: () async {
                        if (_assignedDriverId != null) {
                          final chatId = await DatabaseService().getOrCreateChat(
                            _assignedDriverId!,
                          );
                          final driverUser = await DatabaseService().getUserById(_assignedDriverId!);
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatId,
                                receiver: driverUser as UserModel,
                                currentUserId: currentUserId,
                              ),
                            ),
                          );
                        }
                      },
                      isOutlined: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Call',
                      icon: Icons.phone_enabled_rounded,
                      onPressed: () async {
                        final phone = _assignedDriver?['phone'] ?? _assignedDriver?['phoneNumber'];
                        if (phone != null) {
                          final Uri url = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        }
                      },
                      isSecondary: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showConfirmation = false;
                      _showLocationSelection = true;
                      _isLoading = false;
                    });
                  },
                  child: Text(
                    'Cancel Ride',
                    style: TextStyle(
                      color: AppColors.error.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

// Helper widgets (outside the class)
class _PredictionList extends StatelessWidget {
  final List<String> predictions;
  final int? selectedIndex;
  final void Function(int) onSelected;
  final bool isDark;

  const _PredictionList({
    required this.predictions,
    required this.selectedIndex,
    required this.onSelected,
    required this.isDark,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.getCardColor(isDark),
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: predictions.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.primary.withOpacity(0.1)),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return ListTile(
            title: Text(
              predictions[index],
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.getTextPrimaryColor(isDark),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            tileColor: selected ? AppColors.primary.withOpacity(0.08) : null,
            onTap: () => onSelected(index),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          );
        },
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PaymentOptionCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withOpacity(0.1) 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon, 
              color: isSelected ? AppColors.primary : AppColors.getTextSecondaryColor(isDark),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.getTextSecondaryColor(isDark),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassengerChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _PassengerChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.getTextSecondaryColor(isDark),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _PaymentTypePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _PaymentTypePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: selected ? (isDark ? AppColors.primary.withOpacity(0.18) : AppColors.primary.withOpacity(0.13)) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : (isDark ? Colors.white24 : Colors.black12),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.getTextSecondaryColor(isDark), size: 20),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? AppColors.primary : AppColors.getTextSecondaryColor(isDark),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleTypeCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _VehicleTypeCard({
    required this.vehicle,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? vehicle['color'].withOpacity(0.13) : AppColors.getCardColor(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? vehicle['color']
                  : isDark
                      ? Colors.white24
                      : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: vehicle['color'].withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      vehicle['image'],
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: vehicle['color'],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: vehicle['color'].withOpacity(0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                vehicle['name'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.getTextPrimaryColor(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'R${vehicle['price']}',
                style: TextStyle(
                  color: vehicle['color'],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                vehicle['eta'],
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideFindingOverlay extends StatelessWidget {
  final String status;
  final String driverName;
  final String eta;
  final VoidCallback onCancel;
  final bool isDark;

  const _RideFindingOverlay({
    required this.status,
    required this.driverName,
    required this.eta,
    required this.onCancel,
    required this.isDark,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          color: AppColors.getCardColor(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(status, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimaryColor(isDark))),
                if (driverName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${AppLocalizations.of(context)?.translate('driver') ?? 'Driver'}: $driverName', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark))),
                ],
                if (eta.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${AppLocalizations.of(context)?.translate('eta') ?? 'ETA'}: $eta', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark))),
                ],
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
