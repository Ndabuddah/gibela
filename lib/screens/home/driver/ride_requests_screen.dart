import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/ride_request_provider.dart';
import '../../../models/driver_model.dart';
import '../../../services/database_service.dart';
import '../../../widgets/passenger/vehicle_selection.dart';
import '../../../services/ride_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../../../models/ride_model.dart';

class RideRequestsScreen extends StatelessWidget {
  const RideRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DriverModel?>(
      future: DatabaseService().getCurrentDriver(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final driver = snapshot.data!;
        if (!driver.isApproved) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Ride Requests'),
              backgroundColor: AppColors.primary,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 60, color: AppColors.primary),
                    const SizedBox(height: 24),
                    Text(
                      'Your account is pending approval.',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimaryColor(Theme.of(context).brightness == Brightness.dark)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You cannot view or accept ride requests until your account is approved by an admin.',
                      style: TextStyle(fontSize: 16, color: AppColors.getTextSecondaryColor(Theme.of(context).brightness == Brightness.dark)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // If approved, show the ride requests body
        return ChangeNotifierProvider(
          create: (_) => RideRequestProvider(),
          child: const _RideRequestBody(),
        );
      },
    );
  }
}

class _RideRequestBody extends StatelessWidget {
  const _RideRequestBody();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RideRequestProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Show loader bottom sheet if submitting or waiting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.requestStatus == RideRequestStatus.submitting || provider.requestStatus == RideRequestStatus.waiting) {
        if (ModalRoute.of(context)?.isCurrent ?? true) {
          showModalBottomSheet(
            context: context,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Colors.transparent,
            builder: (_) => Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    provider.requestStatus == RideRequestStatus.submitting
                        ? 'Submitting your ride request...'
                        : 'Waiting for a driver to accept your ride...',
                    style: TextStyle(fontSize: 18, color: AppColors.getTextPrimaryColor(isDark)),
                  ),
                ],
              ),
            ),
          );
        }
      }
      // Do not pop the screen when status is idle or other values.
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request a Ride'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pickup field
            _AnimatedAutocompleteField(
              label: 'Pickup Location',
              value: provider.pickupAddress,
              isLoading: provider.isLoadingPickup,
              suggestions: provider.pickupSuggestions,
              onChanged: provider.searchPickup,
              onSuggestionTap: provider.selectPickup,
              icon: Icons.my_location,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            // Dropoff field
            _AnimatedAutocompleteField(
              label: 'Dropoff Location',
              value: provider.dropoffAddress,
              isLoading: provider.isLoadingDropoff,
              suggestions: provider.dropoffSuggestions,
              onChanged: provider.searchDropoff,
              onSuggestionTap: provider.selectDropoff,
              icon: Icons.location_on,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            // Vehicle selection
            VehicleSelection(
              selectedType: provider.vehicleType,
              onChanged: provider.setVehicleType,
              distanceKm: provider.distanceKm,
              // For drivers' own request UI, no gating needed
            ),
            const SizedBox(height: 32),
            // Distance
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: provider.isCalculatingDistance
                  ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : provider.distanceKm != null
                      ? Column(
                          children: [
                            Text(
                              'Distance:',
                              style: TextStyle(
                                color: AppColors.getTextSecondaryColor(isDark),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${provider.distanceKm!.toStringAsFixed(2)} km',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            // Request button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              onPressed: (provider.pickupCoords != null && provider.dropoffCoords != null && provider.distanceKm != null && provider.requestStatus == RideRequestStatus.idle)
                  ? () async {
                      provider.setRequestStatus(RideRequestStatus.submitting);
                      try {
                        // Get current user
                        final authService = AuthService();
                        UserModel? user = authService.userModel;
                        if (user == null) {
                          user = await authService.fetchCurrentUser();
                        }
                        if (user == null) {
                          provider.setRequestStatus(RideRequestStatus.idle);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not get user info.')),
                          );
                          return;
                        }
                        final rideService = RideService();
                        final ride = await rideService.requestRide(
                          passengerId: user.uid,
                          pickupAddress: provider.pickupAddress!,
                          pickupLat: provider.pickupCoords![0],
                          pickupLng: provider.pickupCoords![1],
                          dropoffAddress: provider.dropoffAddress!,
                          dropoffLat: provider.dropoffCoords![0],
                          dropoffLng: provider.dropoffCoords![1],
                          vehicleType: provider.vehicleType,
                          distance: provider.distanceKm!,
                        );
                        if (ride == null) {
                          provider.setRequestStatus(RideRequestStatus.idle);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to submit ride request.')),
                          );
                          return;
                        }
                        provider.setRequestStatus(RideRequestStatus.waiting);
                        // Listen for ride status updates
                        DatabaseService().listenToRideUpdates(ride.id).listen((updatedRide) {
                          switch (updatedRide.status) {
                            case RideStatus.accepted:
                              provider.setRequestStatus(RideRequestStatus.accepted);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ride request accepted!')),
                              );
                              provider.clear();
                              provider.setRequestStatus(RideRequestStatus.idle);
                              break;
                            case RideStatus.cancelled:
                              provider.setRequestStatus(RideRequestStatus.rejected);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ride request was cancelled.')),
                              );
                              provider.clear();
                              provider.setRequestStatus(RideRequestStatus.idle);
                              break;
                            case RideStatus.completed:
                              provider.setRequestStatus(RideRequestStatus.completed);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ride completed!')),
                              );
                              provider.clear();
                              provider.setRequestStatus(RideRequestStatus.idle);
                              break;
                            case RideStatus.driverArrived:
                            case RideStatus.inProgress:
                              // These are intermediate states, no need to clear the form
                              break;
                            default:
                              // Handle other statuses if needed
                              break;
                          }
                        });
                      } catch (e) {
                        provider.setRequestStatus(RideRequestStatus.idle);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    }
                  : null,
              child: const Text(
                'Request Ride',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedAutocompleteField extends StatefulWidget {
  final String label;
  final String? value;
  final bool isLoading;
  final List<Map<String, dynamic>> suggestions;
  final Function(String) onChanged;
  final Function(Map<String, dynamic>) onSuggestionTap;
  final IconData icon;
  final Color color;

  const _AnimatedAutocompleteField({
    required this.label,
    required this.value,
    required this.isLoading,
    required this.suggestions,
    required this.onChanged,
    required this.onSuggestionTap,
    required this.icon,
    required this.color,
  });

  @override
  State<_AnimatedAutocompleteField> createState() => _AnimatedAutocompleteFieldState();
}

class _AnimatedAutocompleteFieldState extends State<_AnimatedAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(covariant _AnimatedAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value ?? '';
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: AppColors.getTextSecondaryColor(isDark),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          enableInteractiveSelection: true,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark)),
          decoration: InputDecoration(
            prefixIcon: Icon(widget.icon, color: widget.color),
            filled: true,
            fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
            hintText: 'Enter address...',
            hintStyle: TextStyle(color: AppColors.getTextSecondaryColor(isDark)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            suffixIcon: widget.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: widget.color),
                    ),
                  )
                : (widget.value != null && widget.value!.isNotEmpty)
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          widget.onChanged('');
                        },
                      )
                    : null,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: widget.suggestions.isNotEmpty
              ? Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final suggestion = widget.suggestions[index];
                      return ListTile(
                        title: Text(
                          suggestion['place_name'],
                          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark)),
                        ),
                        onTap: () => widget.onSuggestionTap(suggestion),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
