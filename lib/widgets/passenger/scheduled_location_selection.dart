import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import 'package:provider/provider.dart';

class ScheduledLocationSelection extends StatefulWidget {
  final String pickupAddress;
  final String dropoffAddress;
  final Function(String) onPickupChanged;
  final Function(String) onDropoffChanged;
  final VoidCallback onContinue;
  final void Function(List<double> coords)? onPickupCoordinatesChanged;
  final void Function(List<double> coords)? onDropoffCoordinatesChanged;

  const ScheduledLocationSelection({
    Key? key,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.onPickupChanged,
    required this.onDropoffChanged,
    required this.onContinue,
    this.onPickupCoordinatesChanged,
    this.onDropoffCoordinatesChanged,
  }) : super(key: key);

  @override
  State<ScheduledLocationSelection> createState() => _ScheduledLocationSelectionState();
}

class _ScheduledLocationSelectionState extends State<ScheduledLocationSelection> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  List<String> _pickupPredictions = [];
  List<String> _dropoffPredictions = [];
  int? _selectedPickupPrediction;
  int? _selectedDropoffPrediction;

  @override
  void initState() {
    super.initState();
    _pickupController.text = widget.pickupAddress;
    _dropoffController.text = widget.dropoffAddress;
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where to?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimaryColor(isDark),
            ),
          ),
          const SizedBox(height: 16),
          
          // Pickup Location
          _buildLocationField(
            controller: _pickupController,
            label: 'Pickup Location',
            hint: 'Enter pickup address',
            icon: Icons.my_location,
            isDark: isDark,
            isPickup: true,
          ),
          
          const SizedBox(height: 16),
          
          // Dropoff Location
          _buildLocationField(
            controller: _dropoffController,
            label: 'Dropoff Location',
            hint: 'Enter destination',
            icon: Icons.location_on,
            isDark: isDark,
            isPickup: false,
          ),
          
          const SizedBox(height: 20),
          
          // Continue Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required bool isPickup,
  }) {
    final predictions = isPickup ? _pickupPredictions : _dropoffPredictions;
    final selectedIndex = isPickup ? _selectedPickupPrediction : _selectedDropoffPrediction;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimaryColor(isDark),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.getBackgroundColor(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.getBorderColor(isDark)),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.getTextHintColor(isDark),
              ),
              prefixIcon: Icon(
                icon,
                color: AppColors.getIconColor(isDark),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: TextStyle(
              color: AppColors.getTextPrimaryColor(isDark),
            ),
            onChanged: isPickup ? _onPickupTextChanged : _onDropoffTextChanged,
          ),
        ),
        if (predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.getCardColor(isDark),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.getBorderColor(isDark)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                final prediction = predictions[index];
                final isSelected = selectedIndex == index;
                
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: Text(
                    prediction,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextPrimaryColor(isDark),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  tileColor: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                  onTap: () {
                    if (isPickup) {
                      _onPickupPredictionSelected(prediction);
                    } else {
                      _onDropoffPredictionSelected(prediction);
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Future<List<String>> _fetchPredictions(String query) async {
    const mapboxApiKey = 'pk.eyJ1IjoibmRhYmVuaGxlbmdlbWExOTk2IiwiYSI6ImNsdnR0d2x3ZTAyeHIya25ld3k3MnF2aGoifQ.awJhdpzb2bBtfiJRK35pCg';
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/'
      '${Uri.encodeComponent(query)}.json?access_token=$mapboxApiKey&autocomplete=true&country=ZA',
    );
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
    widget.onPickupChanged(prediction);
    
    try {
      final locations = await locationFromAddress(prediction);
      if (locations.isNotEmpty) {
        widget.onPickupCoordinatesChanged?.call([locations.first.latitude, locations.first.longitude]);
      }
    } catch (e) {
      // Optionally show error
    }
  }

  void _onDropoffPredictionSelected(String prediction) async {
    setState(() {
      _dropoffController.text = prediction;
      _dropoffPredictions = [];
      _selectedDropoffPrediction = null;
    });
    widget.onDropoffChanged(prediction);
    
    try {
      final locations = await locationFromAddress(prediction);
      if (locations.isNotEmpty) {
        widget.onDropoffCoordinatesChanged?.call([locations.first.latitude, locations.first.longitude]);
      }
    } catch (e) {
      // Optionally show error
    }
  }
} 