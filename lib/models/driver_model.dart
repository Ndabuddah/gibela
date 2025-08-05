enum DriverStatus { offline, online, onRide }

enum PaymentModel { weekly, percentage }

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
  final bool payLater;
  final PaymentModel paymentModel;
  final bool isPaid;
  final DateTime? lastPaymentModelChange;
  
  // New fields for enhanced profile management
  final Map<String, bool> documentVerificationStatus;
  final Map<String, DateTime> documentExpiryDates;
  final Map<String, dynamic> vehicleInformation;
  final Map<String, List<String>> serviceAreaPreferences;
  final Map<String, List<String>> workingHours;
  final Map<String, dynamic> driverPreferences;
  final double profileCompletionPercentage;

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
    this.payLater = false,
    this.paymentModel = PaymentModel.weekly,
    this.isPaid = false,
    this.lastPaymentModelChange,
    this.documentVerificationStatus = const {},
    this.documentExpiryDates = const {},
    this.vehicleInformation = const {},
    this.serviceAreaPreferences = const {},
    this.workingHours = const {},
    this.driverPreferences = const {},
    this.profileCompletionPercentage = 0.0,
  });

  factory DriverModel.fromMap(Map<String, dynamic> data) {
    // Convert document verification status
    final verificationStatus = (data['documentVerificationStatus'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as bool),
        ) ?? {};

    // Convert document expiry dates
    final expiryDates = (data['documentExpiryDates'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, DateTime.parse(value as String)),
        ) ?? {};

    // Convert service area preferences
    final areaPrefs = (data['serviceAreaPreferences'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as List).cast<String>()),
        ) ?? {};

    // Convert working hours
    final hours = (data['workingHours'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as List).cast<String>()),
        ) ?? {};
    return DriverModel(
      userId: data['userId'] ?? '',
      idNumber: data['idNumber'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'] ?? '',
      province: data['province'],
      towns: (data['towns'] as List<dynamic>?)?.cast<String>() ?? [],
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
      vehiclePurposes: (data['vehiclePurposes'] as List<dynamic>?)?.cast<String>() ?? [],
      payLater: data['payLater'] ?? false,
      paymentModel: PaymentModel.values.asMap().containsKey(data['paymentModel'])
          ? PaymentModel.values[data['paymentModel']]
          : PaymentModel.weekly,
      isPaid: data['isPaid'] ?? false,
      lastPaymentModelChange: data['lastPaymentModelChange'] != null ? DateTime.parse(data['lastPaymentModelChange'] as String) : null,
      documentVerificationStatus: verificationStatus,
      documentExpiryDates: expiryDates,
      vehicleInformation: data['vehicleInformation'] as Map<String, dynamic>? ?? {},
      serviceAreaPreferences: areaPrefs,
      workingHours: hours,
      driverPreferences: data['driverPreferences'] as Map<String, dynamic>? ?? {},
      profileCompletionPercentage: (data['profileCompletionPercentage'] ?? 0.0).toDouble(),
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
      'payLater': payLater,
      'paymentModel': paymentModel.index,
      'isPaid': isPaid,
      'lastPaymentModelChange': lastPaymentModelChange?.toIso8601String(),
      'documentVerificationStatus': documentVerificationStatus,
      'documentExpiryDates': documentExpiryDates.map((key, value) => MapEntry(key, value.toIso8601String())),
      'vehicleInformation': vehicleInformation,
      'serviceAreaPreferences': serviceAreaPreferences,
      'workingHours': workingHours,
      'driverPreferences': driverPreferences,
      'profileCompletionPercentage': profileCompletionPercentage,
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
    bool? payLater,
    PaymentModel? paymentModel,
    bool? isPaid,
    DateTime? lastPaymentModelChange,
    Map<String, bool>? documentVerificationStatus,
    Map<String, DateTime>? documentExpiryDates,
    Map<String, dynamic>? vehicleInformation,
    Map<String, List<String>>? serviceAreaPreferences,
    Map<String, List<String>>? workingHours,
    Map<String, dynamic>? driverPreferences,
    double? profileCompletionPercentage,
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
      payLater: payLater ?? this.payLater,
      paymentModel: paymentModel ?? this.paymentModel,
      isPaid: isPaid ?? this.isPaid,
      lastPaymentModelChange: lastPaymentModelChange ?? this.lastPaymentModelChange,
      documentVerificationStatus: documentVerificationStatus ?? this.documentVerificationStatus,
      documentExpiryDates: documentExpiryDates ?? this.documentExpiryDates,
      vehicleInformation: vehicleInformation ?? this.vehicleInformation,
      serviceAreaPreferences: serviceAreaPreferences ?? this.serviceAreaPreferences,
      workingHours: workingHours ?? this.workingHours,
      driverPreferences: driverPreferences ?? this.driverPreferences,
      profileCompletionPercentage: profileCompletionPercentage ?? this.profileCompletionPercentage,
    );
  }
}
