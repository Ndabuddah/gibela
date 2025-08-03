class UserModel {
  final bool? isGirl;
  final bool? isStudent;
  final String uid;
  final String email;
  final String name;
  final String surname;
  final String? phoneNumber;
  final String? profileImage;
  final bool isDriver;
  final bool isApproved;
  final bool requiresDriverSignup;
  final List<String> savedAddresses;
  final List<String> recentRides;
  final String? photoUrl;
  final bool isOnline;
  final double rating;
  final List<String> missingProfileFields;
  // Referral fields
  final int referrals;
  final double referralAmount;
  final DateTime? lastReferral;

  UserModel({
    required this.uid,
    this.isGirl,
    this.isStudent,
    required this.email,
    required this.name,
    required this.surname,
    this.phoneNumber,
    this.profileImage,
    this.isDriver = false,
    this.isApproved = false,
    this.requiresDriverSignup = false,
    this.savedAddresses = const [],
    this.recentRides = const [],
    this.photoUrl,
    this.isOnline = false,
    this.rating = 5.0,
    this.missingProfileFields = const [],
    this.referrals = 0,
    this.referralAmount = 0.0,
    this.lastReferral,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    final bool? isGirl = data['isGirl'] is bool ? data['isGirl'] : null;
    final bool? isStudent = data['isStudent'] is bool ? data['isStudent'] : null;
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      surname: data['surname'] ?? '',
      phoneNumber: data['phoneNumber'],
      profileImage: data['profileImage'] ?? data['profileImageUrl'], // Support Firestore field 'profileImageUrl'
      isDriver: data['isDriver'] ?? false,
      isApproved: data['isApproved'] ?? false,
      requiresDriverSignup: data['requiresDriverSignup'] ?? false,
      savedAddresses: List<String>.from(data['savedAddresses'] ?? []),
      recentRides: List<String>.from(data['recentRides'] ?? []),
      photoUrl: data['photoUrl'],
      isOnline: data['isOnline'] ?? false,
      rating: (data['rating'] ?? 5.0).toDouble(),
      missingProfileFields: List<String>.from(data['missingProfileFields'] ?? []),
      referrals: data['referrals'] ?? 0,
      referralAmount: (data['referralAmount'] ?? 0.0).toDouble(),
      lastReferral: data['lastReferral'] != null ? DateTime.parse(data['lastReferral']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isGirl': isGirl,
      'isStudent': isStudent,
      'uid': uid,
      'email': email,
      'name': name,
      'surname': surname,
      'phoneNumber': phoneNumber,
      'profileImage': profileImage,
      'isDriver': isDriver,
      'isApproved': isApproved,
      'requiresDriverSignup': requiresDriverSignup,
      'savedAddresses': savedAddresses,
      'recentRides': recentRides,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'rating': rating,
      'missingProfileFields': missingProfileFields,
      'referrals': referrals,
      'referralAmount': referralAmount,
      'lastReferral': lastReferral?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    bool? isGirl,
    bool? isStudent,
    String? email,
    String? name,
    String? surname,
    String? phoneNumber,
    String? profileImage,
    bool? isDriver,
    bool? isApproved,
    bool? requiresDriverSignup,
    List<String>? savedAddresses,
    List<String>? recentRides,
    String? photoUrl,
    bool? isOnline,
    double? rating,
    List<String>? missingProfileFields,
    int? referrals,
    double? referralAmount,
    DateTime? lastReferral,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      isGirl: isGirl ?? this.isGirl,
      isStudent: isStudent ?? this.isStudent,
      email: email ?? this.email,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImage: profileImage ?? this.profileImage,
      isDriver: isDriver ?? this.isDriver,
      isApproved: isApproved ?? this.isApproved,
      requiresDriverSignup: requiresDriverSignup ?? this.requiresDriverSignup,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      recentRides: recentRides ?? this.recentRides,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      rating: rating ?? this.rating,
      missingProfileFields: missingProfileFields ?? this.missingProfileFields,
      referrals: referrals ?? this.referrals,
      referralAmount: referralAmount ?? this.referralAmount,
      lastReferral: lastReferral ?? this.lastReferral,
    );
  }

  String get fullName => (surname.isNotEmpty) ? '$name $surname' : name;
  String? get profileImageUrl => profileImage ?? photoUrl;
  String get role => isDriver ? 'driver' : 'passenger';
}
