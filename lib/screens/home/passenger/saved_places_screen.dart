import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/saved_places_service.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import '../../../widgets/common/empty_state_widget.dart';
import 'request_ride_screen.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({Key? key}) : super(key: key);

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  final SavedPlacesService _savedPlacesService = SavedPlacesService();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Saved Places'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getIconColor(isDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPlaceDialog(context, isDark),
            tooltip: 'Add place',
          ),
        ],
      ),
      body: StreamBuilder<List<SavedPlace>>(
        stream: _savedPlacesService.getSavedPlaces(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading saved places: ${snapshot.error}',
                style: TextStyle(color: AppColors.error),
              ),
            );
          }

          final places = snapshot.data ?? [];

          if (places.isEmpty) {
            return EmptyStateWidget(
              title: 'No Saved Places',
              message: 'Save your favorite locations for quick access when booking rides.',
              icon: Icons.bookmark_border,
              actionText: 'Add Place',
              onAction: () => _showAddPlaceDialog(context, isDark),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              return _buildPlaceCard(place, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceCard(SavedPlace place, bool isDark) {
    IconData icon;
    Color iconColor;

    switch (place.type) {
      case 'home':
        icon = Icons.home;
        iconColor = Colors.blue;
        break;
      case 'work':
        icon = Icons.work;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.location_on;
        iconColor = AppColors.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          place.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimaryColor(isDark),
          ),
        ),
        subtitle: Text(
          place.address,
          style: TextStyle(
            color: AppColors.getTextSecondaryColor(isDark),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.getIconColor(isDark)),
          onSelected: (value) {
            switch (value) {
              case 'use':
                _usePlace(place);
                break;
              case 'edit':
                _showEditPlaceDialog(context, isDark, place);
                break;
              case 'delete':
                _deletePlace(place.id);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'use',
              child: Row(
                children: [
                  Icon(Icons.directions_car, size: 20),
                  SizedBox(width: 8),
                  Text('Use for ride'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _usePlace(place),
      ),
    );
  }

  void _usePlace(SavedPlace place) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RequestRideScreen(
          initialPickupAddress: place.address,
          initialPickupCoordinates: [place.latitude, place.longitude],
        ),
      ),
    );
  }

  Future<void> _deletePlace(String placeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Place'),
        content: const Text('Are you sure you want to delete this saved place?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _savedPlacesService.deleteSavedPlace(placeId);
        if (mounted) {
          ModernSnackBar.show(context, message: 'Place deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          ModernSnackBar.show(
            context,
            message: 'Failed to delete place: $e',
            isError: true,
          );
        }
      }
    }
  }

  void _showAddPlaceDialog(BuildContext context, bool isDark) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    String selectedType = 'favorite';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Saved Place'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name (e.g., Home, Work)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'favorite', child: Text('Favorite')),
                DropdownMenuItem(value: 'home', child: Text('Home')),
                DropdownMenuItem(value: 'work', child: Text('Work')),
              ],
              onChanged: (value) {
                selectedType = value ?? 'favorite';
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || addressController.text.isEmpty) {
                ModernSnackBar.show(
                  context,
                  message: 'Please fill in all fields',
                  isError: true,
                );
                return;
              }

              // Get coordinates from address (simplified - in production use geocoding)
              try {
                final place = SavedPlace(
                  id: '',
                  name: nameController.text,
                  address: addressController.text,
                  latitude: 0.0, // Should be geocoded
                  longitude: 0.0, // Should be geocoded
                  type: selectedType,
                  createdAt: DateTime.now(),
                );

                await _savedPlacesService.addSavedPlace(place);
                if (mounted) {
                  Navigator.of(context).pop();
                  ModernSnackBar.show(context, message: 'Place saved successfully');
                }
              } catch (e) {
                if (mounted) {
                  ModernSnackBar.show(
                    context,
                    message: 'Failed to save place: $e',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditPlaceDialog(BuildContext context, bool isDark, SavedPlace place) {
    final nameController = TextEditingController(text: place.name);
    final addressController = TextEditingController(text: place.address);
    String selectedType = place.type;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Saved Place'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'favorite', child: Text('Favorite')),
                DropdownMenuItem(value: 'home', child: Text('Home')),
                DropdownMenuItem(value: 'work', child: Text('Work')),
              ],
              onChanged: (value) {
                selectedType = value ?? 'favorite';
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || addressController.text.isEmpty) {
                ModernSnackBar.show(
                  context,
                  message: 'Please fill in all fields',
                  isError: true,
                );
                return;
              }

              try {
                final updatedPlace = SavedPlace(
                  id: place.id,
                  name: nameController.text,
                  address: addressController.text,
                  latitude: place.latitude,
                  longitude: place.longitude,
                  placeId: place.placeId,
                  type: selectedType,
                  createdAt: place.createdAt,
                );

                await _savedPlacesService.updateSavedPlace(place.id, updatedPlace);
                if (mounted) {
                  Navigator.of(context).pop();
                  ModernSnackBar.show(context, message: 'Place updated successfully');
                }
              } catch (e) {
                if (mounted) {
                  ModernSnackBar.show(
                    context,
                    message: 'Failed to update place: $e',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}


