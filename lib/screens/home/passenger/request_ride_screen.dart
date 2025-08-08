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
import 'package:provider/provider.dart';
import 'package:gibelbibela/screens/auth/female_verification_screen.dart';
import 'package:gibelbibela/screens/auth/student_verification_screen.dart'; // Added import for StudentVerificationScreen
import 'package:gibelbibela/services/auth_service.dart';
import 'package:gibelbibela/services/pricing_service.dart';

import '../../../constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/database_service.dart';
import '../../chat/chat_screen.dart';
import '../../payments/ride_request_payment.dart';
// Removed: import 'widgets/prediction_list.dart';
// Removed: import 'widgets/ride_finding_overlay.dart';
// Remove imports for RideBookingView, ConfirmationCard, VehicleTypeSheet

class RequestRideScreen extends StatefulWidget {
  const RequestRideScreen({Key? key}) : super(key: key);

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
  Stream<DocumentSnapshot>? _requestStream;
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
    _getCurrentLocation();
    _animationController.forward();
  }

  @override
  void dispose() {
    _routeAnimController?.dispose();
    _routeAnimTimer?.cancel();
    _animationController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
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
        SnackBar(content: Text('Error getting location: $e')),
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both pickup and dropoff locations')),
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Verify'),
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
            title: const Text('Female Verification Required'),
            content: const Text('You need to verify as a female to use AsambeGirl rides.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Verify'),
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
            title: const Text('Student Verification Required'),
            content: const Text('You need to verify as a student to use AsambeStudent rides.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Verify'),
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
    if (_dropoffAddress.isEmpty || _dropoffCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a dropoff location before requesting a ride.')),
      );
      setState(() {
        _isLoading = false;
        _showConfirmation = false;
        _showLocationSelection = true;
      });
      return;
    }

    setState(() => _isLoading = true);

    final distance = _calculateDistance();
    final pricingInfo = PricingService.getPricingInfo(
      distanceKm: distance,
      vehicleType: _selectedVehicleType,
    );

    final doc = await FirebaseFirestore.instance.collection('requests').add({
      'userId': currentUserId,
      'pickupAddress': _pickupAddress,
      'pickupCoordinates': _pickupCoordinates,
      'dropoffAddress': _dropoffAddress,
      'dropoffCoordinates': _dropoffCoordinates,
      'vehicleType': _selectedVehicleType,
      'distance': distance,
      'estimatedFare': pricingInfo['finalPrice'],
      'basePrice': pricingInfo['basePrice'],
      'isPeak': pricingInfo['isPeak'],
      'isNight': pricingInfo['isNight'],
      'vehiclePrice': _selectedVehiclePrice,
      'paymentType': _selectedPaymentType,
      'paymentStatus': _selectedPaymentType == 'Card' ? 'paid' : 'pending',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'below2': _below2 ?? true,
    });

    _currentRequestId = doc.id;
    _listenForDriverAssignment(doc.id);

    setState(() => _isLoading = false);

    // Start the confirmation stage animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _confirmationStage = 1);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _confirmationStage = 2);
      });
    });
  }

  Future<Map<String, dynamic>?> fetchDriverProfile(String driverId) async {
    final doc = await FirebaseFirestore.instance.collection('drivers').doc(driverId).get();
    return doc.exists ? doc.data() : null;
  }

  void _listenForDriverAssignment(String requestId) {
    _requestStream = FirebaseFirestore.instance.collection('requests').doc(requestId).snapshots();
    _requestStream!.listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final driverId = data['driverId'];
      if (driverId != null && driverId != _assignedDriverId) {
        // New driver assigned, fetch full profile
        final driverProfile = await fetchDriverProfile(driverId);
        setState(() {
          _assignedDriver = driverProfile;
          _assignedDriverId = driverId;
          _confirmationStage = 3;
          _driverAssigned = true;
        });
      }
    });
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
                    color: AppColors.getCardColor(isDark),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 18,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(top: 12, bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Choose Vehicle Type',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimaryColor(isDark),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(children: [
                              for (int index = 0; index < vehicleTypes.length; index++) ...[
                                if (index > 0) const SizedBox(height: 12),
                                Builder(builder: (context) {
                                  final vehicle = vehicleTypes[index];
                                  final selected = selectedIndex == index;

                                  return Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: selected ? vehicle['color'].withOpacity(0.13) : AppColors.getCardColor(isDark),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: selected
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
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(20),
                                                onTap: () async {
                                                  if (vehicle['available'] == false) {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: const Text('Vehicle Unavailable'),
                                                        content: Text('${vehicle['name']} is currently unavailable. Please select a different vehicle type.'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.of(context).pop(),
                                                            child: const Text('OK'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    return;
                                                  }

                                                  // Check for asambegirl
                                                  if (vehicle['type'].toString().toLowerCase() == 'asambegirl') {
                                                    try {
                                                      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();

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
                                                                child: const Text('Cancel'),
                                                              ),
                                                              ElevatedButton(
                                                                onPressed: () => Navigator.of(context).pop(true),
                                                                child: const Text('Verify'),
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
                                                      return;
                                                    }
                                                  }
                                                  // Check for asambestudent
                                                  else if (vehicle['type'].toString().toLowerCase() == 'asambestudent') {
                                                    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
                                                    final isStudent = userDoc.data()?['isStudent'] == true;
                                                    if (!isStudent) {
                                                      if (!mounted) return;
                                                      final shouldVerify = await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          title: const Text('Student Verification Required'),
                                                          content: const Text('You need to verify as a student to use AsambeStudent rides.'),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () => Navigator.of(context).pop(false),
                                                              child: const Text('Cancel'),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () => Navigator.of(context).pop(true),
                                                              child: const Text('Verify'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (shouldVerify == true) {
                                                        if (!mounted) return;
                                                        Navigator.of(context).push(
                                                          MaterialPageRoute(builder: (_) => const StudentVerificationScreen()),
                                                        );
                                                      }
                                                      return;
                                                    }
                                                  }

                                                  setModalState(() {
                                                    selectedIndex = index;
                                                  });
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.all(16),
                                                  child: Row(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Image.asset(
                                                          vehicle['image'],
                                                          width: 60,
                                                          height: 60,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              vehicle['name'],
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 15,
                                                                color: AppColors.getTextPrimaryColor(isDark),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              vehicle['subtitle'],
                                                              style: TextStyle(
                                                                color: AppColors.getTextSecondaryColor(isDark),
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Row(
                                                              children: [
                                                                Icon(Icons.person, size: 14, color: vehicle['color']),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  '${vehicle['maxPeople']}',
                                                                  style: TextStyle(
                                                                    color: vehicle['color'],
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          if ((vehicle['discountPercent'] ?? 0) > 0) ...[
                                                            Text(
                                                              'R${vehicle['originalPrice']}',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w500,
                                                                color: AppColors.getTextSecondaryColor(isDark),
                                                                decoration: TextDecoration.lineThrough,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 2),
                                                          ],
                                                          Text(
                                                            'R${vehicle['price']}',
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.bold,
                                                              color: vehicle['color'],
                                                            ),
                                                          ),
                                                          if (selected)
                                                            Container(
                                                              margin: const EdgeInsets.only(top: 8),
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
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (vehicle['available'] == false || (vehicle['discountPercent'] ?? 0) > 0)
                                            Positioned(
                                              top: -12,
                                              left: 8,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if ((vehicle['discountPercent'] ?? 0) > 0 && vehicle['available'] != false)
                                                    Container(
                                                      margin: const EdgeInsets.only(bottom: 4),
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        borderRadius: BorderRadius.circular(12),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.2),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        '-${vehicle['discountPercent']?.toStringAsFixed(0)}%',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  if (vehicle['available'] == false)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        borderRadius: BorderRadius.circular(12),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.2),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: const Text(
                                                        'Currently Unavailable',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ));
                                }),
                              ],
                            ]),
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          decoration: BoxDecoration(
                            color: AppColors.getCardColor(isDark),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, -1),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: selectedIndex != null
                                ? () {
                                    setState(() {
                                      _selectedVehicleIndex = selectedIndex;
                                      _selectedVehicleType = vehicleTypes[selectedIndex!]['type'];
                                      _selectedVehiclePrice = vehicleTypes[selectedIndex!]['price'];
                                      _selectedVehicleEta = vehicleTypes[selectedIndex!]['eta'];
                                    });
                                    Navigator.of(context).pop();
                                    _showRideBookingSheet();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.getCardColor(isDark),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            child: const Text('Confirm Vehicle'),
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
                gradient: LinearGradient(
                  colors: isDark ? [const Color(0xFF232526), const Color(0xFF414345)] : [const Color(0xFFF8F8F8), const Color(0xFFEDEDED)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.13),
                    blurRadius: 32,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.directions_car, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        _selectedVehicleType ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.getTextPrimaryColor(isDark),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'R${_selectedVehiclePrice ?? ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: isDark ? [const Color(0xFF2C2C2C), const Color(0xFF232526)] : [Colors.white, const Color(0xFFF6F6F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
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
                            Icon(Icons.route, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('Distance:', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontWeight: FontWeight.w500)),
                            const SizedBox(width: 2),
                            Text(_calculateDistance().toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimaryColor(isDark))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(height: 1, color: AppColors.getTextSecondaryColor(isDark)?.withOpacity(0.13)),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.my_location, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_pickupController.text, style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontWeight: FontWeight.w500))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_dropoffController.text, style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Payment type selector
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PaymentTypePill(
                          icon: Icons.credit_card,
                          label: 'Card',
                          selected: _selectedPaymentType == 'Card',
                          isDark: isDark,
                          onTap: () {
                            setModalState(() => _selectedPaymentType = 'Card');
                          },
                        ),
                        const SizedBox(width: 8),
                        _PaymentTypePill(
                          icon: Icons.attach_money,
                          label: 'Cash',
                          selected: _selectedPaymentType == 'Cash',
                          isDark: isDark,
                          onTap: () {
                            setModalState(() => _selectedPaymentType = 'Cash');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Passenger count selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 6),
                        child: Text(
                          'How many passengers?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.getTextPrimaryColor(isDark),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text("Below 2"),
                            selected: _below2 == true,
                            onSelected: (selected) {
                              setModalState(() {
                                _below2 = true;
                              });
                            },
                            selectedColor: AppColors.primary.withOpacity(0.18),
                          ),
                          const SizedBox(width: 16),
                          ChoiceChip(
                            label: const Text("Above 2"),
                            selected: _below2 == false,
                            onSelected: (selected) {
                              setModalState(() {
                                _below2 = false;
                              });
                            },
                            selectedColor: AppColors.primary.withOpacity(0.18),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _below2 == null
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                _handlePaymentChoice();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.getCardColor(isDark),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        child: const Text('Confirm Booking'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
      builder: (context) {
        // Create local variables to track state within the modal
        int localConfirmationStage = _confirmationStage;
        Map<String, dynamic>? localAssignedDriver = _assignedDriver;
        String? localAssignedDriverId = _assignedDriverId;

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Animate through stages
            void startStageAnimation() {
              if (localConfirmationStage == 0) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (Navigator.of(context).canPop()) {
                    setModalState(() {
                      localConfirmationStage = 1;
                      _confirmationStage = 1;
                    });
                  }
                  Future.delayed(const Duration(seconds: 2), () {
                    if (Navigator.of(context).canPop()) {
                      setModalState(() {
                        localConfirmationStage = 2;
                        _confirmationStage = 2;
                      });
                    }
                  });
                });
              }
            }

            if (localConfirmationStage == 0) startStageAnimation();

            final double sheetHeight = MediaQuery.of(context).size.height * 0.57;

            Widget content;
            if (localConfirmationStage == 0) {
              // Ride Confirmed
              content = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green[400],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 14),
                  Text('Ride Confirmed!', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: AppColors.getTextPrimaryColor(isDark), letterSpacing: 0.2)),
                  const SizedBox(height: 6),
                  Text('Your driver will arrive soon', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 22),
                  Icon(Icons.directions_car_filled, color: AppColors.primary, size: 38),
                  const SizedBox(height: 12),
                  Text('Sit back and relax while we process your ride.', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 15)),
                  const SizedBox(height: 8),
                ],
              );
            } else if (localConfirmationStage == 1) {
              // Looking for Driver
              content = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(strokeWidth: 3),
                  const SizedBox(height: 22),
                  Text('Looking for driver...', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text('We are searching for the best driver for you.', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 15)),
                  const SizedBox(height: 32),
                  Icon(Icons.search, color: AppColors.primary, size: 60),
                  const SizedBox(height: 18),
                  Text('Hang tight, this may take a moment.', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 15)),
                  const Spacer(),
                ],
              );
            } else if (localConfirmationStage == 2) {
              // Connecting with Driver
              content = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Icon(Icons.sync, color: AppColors.primary, size: 44),
                  const SizedBox(height: 22),
                  Text('Connecting with driver...', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text('Hang tight while we connect you.', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 15)),
                  const SizedBox(height: 32),
                  Icon(Icons.phone_in_talk, color: AppColors.primary, size: 60),
                  const SizedBox(height: 18),
                  Text('We are making sure your driver is ready.', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 15)),
                  const Spacer(),
                ],
              );
            } else if (localConfirmationStage == 3 && localAssignedDriver != null) {
              final image = localAssignedDriver['profileImage'] ?? '';
              final name = localAssignedDriver['name'] ?? '';
              final car = localAssignedDriver['vehicleModel'] ?? '';
              final plate = localAssignedDriver['licensePlate'] ?? '';
              final rating = (localAssignedDriver['averageRating'] ?? 3).toDouble();

              content = Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: isDark ? [const Color(0xFF232526), const Color(0xFF414345)] : [Colors.white, const Color(0xFFF6F6F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
                              child: image.isEmpty ? Icon(Icons.person, size: 38) : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber[400], size: 16),
                                  const SizedBox(width: 2),
                                  Text(rating.toStringAsFixed(1), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21, color: AppColors.getTextPrimaryColor(isDark))),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.directions_car, color: AppColors.primary, size: 18),
                                  const SizedBox(width: 6),
                                  Text(car, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.getTextSecondaryColor(isDark))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.confirmation_number, color: AppColors.primary, size: 18),
                                  const SizedBox(width: 6),
                                  Text(plate, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.timer, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(localAssignedDriver?['eta'] != null ? '${localAssignedDriver!['eta']} away' : '', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.getCardColor(isDark),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (localAssignedDriverId != null) ...[
                        StreamBuilder<int>(
                          stream: DatabaseService().getUnreadCountForChat(
                            passengerId: FirebaseAuth.instance.currentUser!.uid,
                            driverId: localAssignedDriverId,
                          ),
                          builder: (context, snapshot) {
                            final unread = snapshot.data ?? 0;
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final chatId = await DatabaseService().getOrCreateChat(
                                      localAssignedDriverId,
                                    );
                                    final driverUser = await DatabaseService().getUserById(localAssignedDriverId);
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
                                    DatabaseService().markMessagesAsRead(chatId, currentUserId);
                                  },
                                  icon: Icon(Icons.message, color: AppColors.primary, size: 18),
                                  label: Text('Text', style: TextStyle(color: AppColors.primary)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppColors.primary, width: 2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                if (unread > 0)
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                      ),
                                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                      child: Text(
                                        unread > 9 ? '9+' : unread.toString(),
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Your driver is on the way!', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimaryColor(isDark), fontSize: 16)),
                  const Spacer(),
                ],
              );
            } else {
              // Fallback: always assign content
              content = Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Waiting for driver...', style: TextStyle(fontSize: 18, color: AppColors.primary)),
                  ],
                ),
              );
            }

            return Container(
              height: sheetHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark ? [const Color(0xFF232526), const Color(0xFF414345)] : [const Color(0xFFF8F8F8), const Color(0xFFEDEDED)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.13),
                    blurRadius: 32,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                      child: SizedBox(
                        key: ValueKey(localConfirmationStage),
                        width: double.infinity,
                        child: content,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: localConfirmationStage == 3 ? () => Navigator.of(context).pop() : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.getCardColor(isDark),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        child: Text(localConfirmationStage == 3 ? 'Track Ride' : 'Track Ride', style: const TextStyle(letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.getCardColor(isDark).withOpacity(isDark ? 0.92 : 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 32,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  TextField(
                    controller: _pickupController,
                    enableInteractiveSelection: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Pickup Location',
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextSecondaryColor(isDark)),
                      prefixIcon: const Icon(Icons.my_location, color: Colors.green),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimaryColor(isDark)),
                    onChanged: _onPickupTextChanged,
                  ),
                  if (_pickupPredictions.isNotEmpty)
                    _PredictionList(
                      predictions: _pickupPredictions,
                      selectedIndex: _selectedPickupPrediction,
                      onSelected: (index) => _onPickupPredictionSelected(_pickupPredictions[index]),
                      isDark: isDark,
                    ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _dropoffController,
                    enableInteractiveSelection: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Dropoff Location',
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextSecondaryColor(isDark)),
                      prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Tap on map to select',
                    ),
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimaryColor(isDark)),
                    onChanged: _onDropoffTextChanged,
                  ),
                  if (_dropoffPredictions.isNotEmpty)
                    _PredictionList(
                      predictions: _dropoffPredictions,
                      selectedIndex: _selectedDropoffPrediction,
                      onSelected: (index) => _onDropoffPredictionSelected(_dropoffPredictions[index]),
                      isDark: isDark,
                    ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showVehicleTypeSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.getCardColor(isDark),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      child: const Text('Choose Vehicle'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.getCardColor(isDark).withOpacity(isDark ? 0.92 : 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 32,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Text(
                      'Your Driver',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimaryColor(isDark),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: isDark ? [const Color(0xFF232526), const Color(0xFF414345)] : [Colors.white, const Color(0xFFF6F6F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 38,
                                backgroundImage: NetworkImage(_assignedDriver?['image'] ?? ''),
                              ),
                              if (_assignedDriver?['rating'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber[400], size: 16),
                                      const SizedBox(width: 2),
                                      Text(
                                        double.parse(_assignedDriver!['rating'].toString()).toStringAsFixed(1),
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_assignedDriver?['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21, color: AppColors.getTextPrimaryColor(isDark))),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.directions_car, color: _assignedDriver?['colorHex'] != null ? Color(_assignedDriver!['colorHex']) : AppColors.primary, size: 18),
                                    const SizedBox(width: 6),
                                    Text(_assignedDriver?['car'] ?? '', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.getTextSecondaryColor(isDark))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.confirmation_number, color: AppColors.primary, size: 18),
                                    const SizedBox(width: 6),
                                    Text(_assignedDriver?['plate'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.color_lens, color: _assignedDriver?['colorHex'] != null ? Color(_assignedDriver!['colorHex']) : AppColors.primary, size: 18),
                                    const SizedBox(width: 6),
                                    Text(_assignedDriver?['color'] ?? '', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.getTextSecondaryColor(isDark))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(Icons.timer, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(_assignedDriver?['eta'] != null ? '${_assignedDriver!['eta']} away' : '', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.getCardColor(isDark),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.message, color: AppColors.primary, size: 18),
                          label: Text('Text', style: TextStyle(color: AppColors.primary)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primary, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('Your driver is on the way!', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimaryColor(isDark), fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
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
                  Text('Driver: $driverName', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark))),
                ],
                if (eta.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('ETA: $eta', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark))),
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
