// lib/models/vehicle_model.dart
enum VehicleType { small, sedan, large }

class VehicleModel {
  final String id;
  final String name;
  final VehicleType type;
  final String? imageUrl;
  final double priceMultiplier;
  final int capacity;
  final int estimatedMinutes;

  VehicleModel({
    required this.id,
    required this.name,
    required this.type,
    this.imageUrl,
    required this.priceMultiplier,
    required this.capacity,
    required this.estimatedMinutes,
  });

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    return VehicleModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: _typeFromString(map['type'] ?? 'sedan'),
      imageUrl: map['imageUrl'],
      priceMultiplier: (map['priceMultiplier'] ?? 1.0).toDouble(),
      capacity: map['capacity'] ?? 4,
      estimatedMinutes: map['estimatedMinutes'] ?? 5,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': _stringFromType(type),
      'imageUrl': imageUrl,
      'priceMultiplier': priceMultiplier,
      'capacity': capacity,
      'estimatedMinutes': estimatedMinutes,
    };
  }

  static VehicleType _typeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'small':
        return VehicleType.small;
      case 'large':
        return VehicleType.large;
      case 'sedan':
      default:
        return VehicleType.sedan;
    }
  }

  static String _stringFromType(VehicleType type) {
    switch (type) {
      case VehicleType.small:
        return 'small';
      case VehicleType.large:
        return 'large';
      case VehicleType.sedan:
        return 'sedan';
    }
  }

  // Get vehicle icon based on type
  String get icon {
    switch (type) {
      case VehicleType.small:
        return '🚗';
      case VehicleType.sedan:
        return '🚙';
      case VehicleType.large:
        return '🚐';
    }
  }

  // Get predefined vehicle types
  static List<VehicleModel> getVehicleTypes() {
    return [
      VehicleModel(
        id: 'small',
        name: 'Small',
        type: VehicleType.small,
        priceMultiplier: 1.0,
        capacity: 2,
        estimatedMinutes: 5,
      ),
      VehicleModel(
        id: 'sedan',
        name: 'Sedan',
        type: VehicleType.sedan,
        priceMultiplier: 1.5,
        capacity: 3,
        estimatedMinutes: 7,
      ),
      VehicleModel(
        id: 'large',
        name: 'Large',
        type: VehicleType.large,
        priceMultiplier: 1.6,
        capacity: 5,
        estimatedMinutes: 10,
      ),
    ];
  }
}
