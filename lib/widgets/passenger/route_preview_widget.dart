import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../services/map_route_service.dart';
import 'package:provider/provider.dart';

/// Widget for displaying route preview with traffic information
class RoutePreviewWidget extends StatefulWidget {
  final gmaps.LatLng pickup;
  final gmaps.LatLng dropoff;
  final Function(RouteInfo)? onRouteSelected;

  const RoutePreviewWidget({
    Key? key,
    required this.pickup,
    required this.dropoff,
    this.onRouteSelected,
  }) : super(key: key);

  @override
  State<RoutePreviewWidget> createState() => _RoutePreviewWidgetState();
}

class _RoutePreviewWidgetState extends State<RoutePreviewWidget> {
  final MapRouteService _routeService = MapRouteService();
  List<RouteInfo> _routes = [];
  RouteInfo? _selectedRoute;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final routes = await _routeService.getRouteOptions(
        origin: widget.pickup,
        destination: widget.dropoff,
      );

      setState(() {
        _routes = routes;
        _selectedRoute = routes.isNotEmpty ? routes.first : null;
        _isLoading = false;
      });

      if (_selectedRoute != null && widget.onRouteSelected != null) {
        widget.onRouteSelected!(_selectedRoute!);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load routes: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                'Route Preview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.white : AppColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadRoutes,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_routes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'No routes available',
                style: TextStyle(
                  color: isDark ? AppColors.white : AppColors.black,
                ),
              ),
            )
          else ...[
            // Route options
            ..._routes.asMap().entries.map((entry) {
              final index = entry.key;
              final route = entry.value;
              final isSelected = _selectedRoute == route;

              return _buildRouteOption(
                route: route,
                index: index,
                isSelected: isSelected,
                isDark: isDark,
              );
            }),

            const SizedBox(height: 16),

            // Selected route details
            if (_selectedRoute != null) _buildRouteDetails(_selectedRoute!, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteOption({
    required RouteInfo route,
    required int index,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRoute = route;
        });
        if (widget.onRouteSelected != null) {
          widget.onRouteSelected!(route);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : (isDark ? AppColors.darkSurface : AppColors.uberGreyLight),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Route number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.uberGrey,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isSelected ? AppColors.black : AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Route info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: _getTrafficColor(route.trafficLevel),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        route.formattedDurationInTraffic,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.white : AppColors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.straighten,
                        size: 16,
                        color: isDark ? AppColors.uberGrey : AppColors.uberGreyDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        route.formattedDistance,
                        style: TextStyle(
                          color: isDark ? AppColors.uberGrey : AppColors.uberGreyDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    route.trafficLevel.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getTrafficColor(route.trafficLevel),
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteDetails(RouteInfo route, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.uberGreyLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.white : AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.location_on,
            label: 'From',
            value: route.startAddress,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            icon: Icons.location_on,
            label: 'To',
            value: route.endAddress,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            icon: Icons.straighten,
            label: 'Distance',
            value: route.formattedDistance,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            icon: Icons.access_time,
            label: 'Duration',
            value: route.formattedDurationInTraffic,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            icon: Icons.traffic,
            label: 'Traffic',
            value: route.trafficLevel.label,
            isDark: isDark,
            valueColor: _getTrafficColor(route.trafficLevel),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: isDark ? AppColors.uberGrey : AppColors.uberGreyDark,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? (isDark ? AppColors.white : AppColors.black),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getTrafficColor(TrafficLevel level) {
    switch (level) {
      case TrafficLevel.light:
        return const Color(0xFF4CAF50); // Green
      case TrafficLevel.normal:
        return const Color(0xFF2196F3); // Blue
      case TrafficLevel.moderate:
        return const Color(0xFFFF9800); // Orange
      case TrafficLevel.heavy:
        return const Color(0xFFF44336); // Red
    }
  }
}

