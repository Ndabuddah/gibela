enum DriverStatus { offline, online, onRide }

class DriverModel {
  final String userId;
  final String idNumber;
  final String name;
  final String phoneNumber;
  final String email;
  final String? province;
  final List<String> towns;
  final Map<String, String> documents;
  final String? vehicleType;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? licensePlate;
  final DriverStatus status;
  final double averageRating;
  final int totalRides;
  final int totalEarnings;
  final bool isApproved;
  final String? profileImage;
  final bool? isFemale;
  final bool? isForStudents;
  final bool? isLuxury;
  final bool? isMax2;
  final List<String> vehiclePurposes;

  DriverModel({
    required this.userId,
    required this.idNumber,
    required this.name,
    required this.phoneNumber,
    required this.email,
    this.province,
    this.towns = const [],
    required this.documents,
    this.vehicleType,
    this.vehicleModel,
    this.vehicleColor,
    this.licensePlate,
    this.status = DriverStatus.offline,
    this.averageRating = 0.0,
    this.totalRides = 0,
    this.totalEarnings = 0,
    this.isApproved = false,
    this.profileImage,
    this.isFemale,
    this.isForStudents,
    this.isLuxury,
    this.isMax2,
    this.vehiclePurposes = const [],
  });

  factory DriverModel.fromMap(Map<String, dynamic> data) {
    return DriverModel(
      userId: data['userId'] ?? '',
      idNumber: data['idNumber'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'] ?? '',
      province: data['province'],
      towns: List<String>.from(data['towns'] ?? []),
      documents: Map<String, String>.from(data['documents'] ?? {}),
      vehicleType: data['vehicleType'],
      vehicleModel: data['vehicleModel'],
      vehicleColor: data['vehicleColor'],
      licensePlate: data['licensePlate'],
      status: DriverStatus.values.asMap().containsKey(data['status'])
          ? DriverStatus.values[data['status']]
          : DriverStatus.offline,
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      totalRides: data['totalRides'] ?? 0,
      totalEarnings: data['totalEarnings'] ?? 0,
      isApproved: data['isApproved'] ?? false,
      profileImage: data['profileImage'],
      isFemale: data['IsFemale'],
      isForStudents: data['IsForStudents'],
      isLuxury: data['isLuxury'],
      isMax2: data['isMax2'] ?? false,
      vehiclePurposes: List<String>.from(data['vehiclePurposes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'vehiclePurposes': vehiclePurposes,
      'idNumber': idNumber,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'province': province,
      'towns': towns,
      'documents': documents,
      'vehicleType': vehicleType,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'licensePlate': licensePlate,
      'status': status.index,
      'averageRating': averageRating,
      'totalRides': totalRides,
      'totalEarnings': totalEarnings,
      'isApproved': isApproved,
      'profileImage': profileImage,
      'IsFemale': isFemale,
      'IsForStudents': isForStudents,
      'isLuxury': isLuxury,
      'isMax2': isMax2,
    };
  }

  DriverModel copyWith({
    String? userId,
    String? idNumber,
    String? name,
    String? phoneNumber,
    String? email,
    String? province,
    List<String>? towns,
    Map<String, String>? documents,
    String? vehicleType,
    String? vehicleModel,
    String? vehicleColor,
    String? licensePlate,
    DriverStatus? status,
    double? averageRating,
    int? totalRides,
    int? totalEarnings,
    bool? isApproved,
    String? profileImage,
    bool? isFemale,
    bool? isForStudents,
    bool? isLuxury,
    bool? isMax2,
    List<String>? vehiclePurposes,
  }) {
    return DriverModel(
      userId: userId ?? this.userId,
      idNumber: idNumber ?? this.idNumber,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      province: province ?? this.province,
      towns: towns ?? this.towns,
      documents: documents ?? this.documents,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      licensePlate: licensePlate ?? this.licensePlate,
      status: status ?? this.status,
      averageRating: averageRating ?? this.averageRating,
      totalRides: totalRides ?? this.totalRides,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      isApproved: isApproved ?? this.isApproved,
      profileImage: profileImage ?? this.profileImage,
            isFemale: isFemale ?? this.isFemale,
      isForStudents: isForStudents ?? this.isForStudents,
      isLuxury: isLuxury ?? this.isLuxury,
      isMax2: isMax2 ?? this.isMax2,
      vehiclePurposes: vehiclePurposes ?? this.vehiclePurposes,
    );
  }
}
