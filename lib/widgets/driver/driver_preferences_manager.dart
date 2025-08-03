import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class DriverPreferencesManager extends StatefulWidget {
  final Map<String, dynamic> initialPreferences;
  final Function(Map<String, dynamic>) onPreferencesUpdated;

  const DriverPreferencesManager({
    Key? key,
    required this.initialPreferences,
    required this.onPreferencesUpdated,
  }) : super(key: key);

  @override
  State<DriverPreferencesManager> createState() => _DriverPreferencesManagerState();
}

class _DriverPreferencesManagerState extends State<DriverPreferencesManager> {
  late Map<String, dynamic> _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = Map.from(widget.initialPreferences);
    _initializeDefaultPreferences();
  }

  void _initializeDefaultPreferences() {
    final defaultPreferences = {
      'rideTypes': {
        'standard': true,
        'premium': false,
        'express': false,
      },
      'passengerPreferences': {
        'femaleOnly': false,
        'studentsOnly': false,
        'maxPassengers2': false,
      },
      'schedulePreferences': {
        'acceptAdvanceBookings': true,
        'acceptInstantRides': true,
        'minimumNoticeTime': 15, // minutes
      },
      'paymentPreferences': {
        'acceptCash': true,
        'acceptCard': true,
        'acceptWallet': true,
      },
      'communicationPreferences': {
        'inAppMessages': true,
        'smsNotifications': true,
        'emailNotifications': false,
        'pushNotifications': true,
      },
    };

    defaultPreferences.forEach((key, value) {
      if (!_preferences.containsKey(key)) {
        _preferences[key] = value;
      }
    });
  }

  void _updatePreference(String category, String key, dynamic value) {
    setState(() {
      _preferences[category][key] = value;
    });
    widget.onPreferencesUpdated(_preferences);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildPreferenceSection(
          'Ride Types',
          Icons.directions_car,
          _buildRideTypesContent(),
          isDark,
        ),
        _buildPreferenceSection(
          'Passenger Preferences',
          Icons.people,
          _buildPassengerPreferencesContent(),
          isDark,
        ),
        _buildPreferenceSection(
          'Schedule Preferences',
          Icons.schedule,
          _buildSchedulePreferencesContent(),
          isDark,
        ),
        _buildPreferenceSection(
          'Payment Preferences',
          Icons.payment,
          _buildPaymentPreferencesContent(),
          isDark,
        ),
        _buildPreferenceSection(
          'Communication Preferences',
          Icons.notifications,
          _buildCommunicationPreferencesContent(),
          isDark,
        ),
      ],
    );
  }

  Widget _buildPreferenceSection(
    String title,
    IconData icon,
    Widget content,
    bool isDark,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: [content],
        ),
      ),
    );
  }

  Widget _buildRideTypesContent() {
    return Column(
      children: [
        _buildSwitchPreference(
          'Standard Rides',
          'Accept regular ride requests',
          _preferences['rideTypes']['standard'],
          (value) => _updatePreference('rideTypes', 'standard', value),
        ),
        _buildSwitchPreference(
          'Premium Rides',
          'Accept premium/luxury ride requests',
          _preferences['rideTypes']['premium'],
          (value) => _updatePreference('rideTypes', 'premium', value),
        ),
        _buildSwitchPreference(
          'Express Rides',
          'Accept express/urgent ride requests',
          _preferences['rideTypes']['express'],
          (value) => _updatePreference('rideTypes', 'express', value),
        ),
      ],
    );
  }

  Widget _buildPassengerPreferencesContent() {
    return Column(
      children: [
        _buildSwitchPreference(
          'Female Passengers Only',
          'Only accept ride requests from female passengers',
          _preferences['passengerPreferences']['femaleOnly'],
          (value) => _updatePreference('passengerPreferences', 'femaleOnly', value),
        ),
        _buildSwitchPreference(
          'Students Only',
          'Only accept ride requests from students',
          _preferences['passengerPreferences']['studentsOnly'],
          (value) => _updatePreference('passengerPreferences', 'studentsOnly', value),
        ),
        _buildSwitchPreference(
          'Maximum 2 Passengers',
          'Limit rides to maximum 2 passengers',
          _preferences['passengerPreferences']['maxPassengers2'],
          (value) => _updatePreference('passengerPreferences', 'maxPassengers2', value),
        ),
      ],
    );
  }

  Widget _buildSchedulePreferencesContent() {
    return Column(
      children: [
        _buildSwitchPreference(
          'Accept Advance Bookings',
          'Allow passengers to book rides in advance',
          _preferences['schedulePreferences']['acceptAdvanceBookings'],
          (value) => _updatePreference('schedulePreferences', 'acceptAdvanceBookings', value),
        ),
        _buildSwitchPreference(
          'Accept Instant Rides',
          'Accept immediate ride requests',
          _preferences['schedulePreferences']['acceptInstantRides'],
          (value) => _updatePreference('schedulePreferences', 'acceptInstantRides', value),
        ),
        const SizedBox(height: 16),
        _buildSliderPreference(
          'Minimum Notice Time',
          'Minimum time required before ride starts',
          _preferences['schedulePreferences']['minimumNoticeTime'].toDouble(),
          5,
          60,
          (value) => _updatePreference('schedulePreferences', 'minimumNoticeTime', value.round()),
        ),
      ],
    );
  }

  Widget _buildPaymentPreferencesContent() {
    return Column(
      children: [
        _buildSwitchPreference(
          'Accept Cash',
          'Accept cash payments from passengers',
          _preferences['paymentPreferences']['acceptCash'],
          (value) => _updatePreference('paymentPreferences', 'acceptCash', value),
        ),
        _buildSwitchPreference(
          'Accept Card',
          'Accept card payments from passengers',
          _preferences['paymentPreferences']['acceptCard'],
          (value) => _updatePreference('paymentPreferences', 'acceptCard', value),
        ),
        _buildSwitchPreference(
          'Accept Wallet',
          'Accept in-app wallet payments',
          _preferences['paymentPreferences']['acceptWallet'],
          (value) => _updatePreference('paymentPreferences', 'acceptWallet', value),
        ),
      ],
    );
  }

  Widget _buildCommunicationPreferencesContent() {
    return Column(
      children: [
        _buildSwitchPreference(
          'In-App Messages',
          'Receive messages through the app',
          _preferences['communicationPreferences']['inAppMessages'],
          (value) => _updatePreference('communicationPreferences', 'inAppMessages', value),
        ),
        _buildSwitchPreference(
          'SMS Notifications',
          'Receive SMS notifications',
          _preferences['communicationPreferences']['smsNotifications'],
          (value) => _updatePreference('communicationPreferences', 'smsNotifications', value),
        ),
        _buildSwitchPreference(
          'Email Notifications',
          'Receive email notifications',
          _preferences['communicationPreferences']['emailNotifications'],
          (value) => _updatePreference('communicationPreferences', 'emailNotifications', value),
        ),
        _buildSwitchPreference(
          'Push Notifications',
          'Receive push notifications',
          _preferences['communicationPreferences']['pushNotifications'],
          (value) => _updatePreference('communicationPreferences', 'pushNotifications', value),
        ),
      ],
    );
  }

  Widget _buildSwitchPreference(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSliderPreference(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: ((max - min) / 5).round(),
                label: '${value.round()} minutes',
                onChanged: onChanged,
                activeColor: AppColors.primary,
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                '${value.round()}m',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}