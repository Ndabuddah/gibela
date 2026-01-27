# Gibela Ride App

A comprehensive ride-sharing application built with Flutter, connecting passengers with drivers for safe and convenient transportation services.

## Features

### For Passengers
- **Ride Booking**: Request rides with multiple vehicle types (Standard, Via, Girl, Student, Luxury, Parcel)
- **Scheduled Rides**: Book rides in advance with reminders
- **Real-time Tracking**: Track your driver's location in real-time
- **In-app Chat**: Communicate with drivers directly
- **Payment Options**: Secure card payments or cash payments
- **Ride History**: View and manage your past rides
- **Rating System**: Rate and review drivers after rides
- **Emergency Features**: Panic button for safety

### For Drivers
- **Ride Requests**: Accept and manage ride requests
- **Earnings Tracking**: Monitor your earnings and ride history
- **Schedule Management**: Manage your availability and scheduled bookings
- **Profile Management**: Complete driver profile with documents and vehicle information
- **Service Area Preferences**: Set preferred service areas and working hours

## Tech Stack

- **Framework**: Flutter 3.8.1+
- **Backend**: Firebase (Firestore, Auth, Storage, Messaging)
- **Maps**: Google Maps Flutter, Mapbox
- **State Management**: Provider
- **Payment**: Paystack
- **Image Storage**: Cloudinary
- **Location Services**: Geolocator, Geocoding

## Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Firebase project with:
  - Authentication enabled
  - Firestore database
  - Cloud Storage
  - Cloud Messaging (FCM)
- Google Maps API key
- Paystack API keys (for payment processing)
- Cloudinary account (for image storage)

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd gibela
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Configuration

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication (Email/Password)
3. Create Firestore database
4. Enable Cloud Storage
5. Set up Cloud Messaging (FCM)
6. Download configuration files:
   - `google-services.json` for Android (place in `android/app/`)
   - `GoogleService-Info.plist` for iOS (place in `ios/Runner/`)

### 4. Environment Configuration

Create a `.env` file or use Flutter's `--dart-define` for:
- `PAYSTACK_SECRET_KEY`: Your Paystack secret key
- Google Maps API key (configure in platform-specific files)

### 5. Platform-Specific Setup

#### Android
1. Add Google Maps API key to `android/app/src/main/AndroidManifest.xml`
2. Ensure minimum SDK version is 21 or higher

#### iOS
1. Add Google Maps API key to `ios/Runner/AppDelegate.swift`
2. Update `Info.plist` with location permissions

### 6. Run the App

```bash
# For development
flutter run

# For release build
flutter build apk  # Android
flutter build ios  # iOS
```

## Project Structure

```
lib/
├── app.dart                 # Main app widget
├── main.dart               # App entry point
├── constants/              # App constants (colors, styles, etc.)
├── models/                 # Data models
├── screens/                 # UI screens
│   ├── auth/              # Authentication screens
│   ├── home/              # Main app screens
│   │   ├── passenger/    # Passenger-specific screens
│   │   ├── driver/       # Driver-specific screens
│   │   └── car_owner/    # Car owner screens
│   ├── payments/         # Payment screens
│   ├── settings/          # Settings screens
│   └── ...
├── services/              # Business logic services
│   ├── auth_service.dart
│   ├── database_service.dart
│   ├── location_service.dart
│   └── ...
├── widgets/               # Reusable widgets
│   ├── common/           # Common widgets
│   ├── passenger/        # Passenger-specific widgets
│   └── driver/           # Driver-specific widgets
├── providers/            # State management providers
└── utils/                # Utility functions
```

## Architecture

The app follows a clean architecture pattern:

- **Presentation Layer**: Screens and Widgets (UI)
- **Business Logic Layer**: Services and Providers (State Management)
- **Data Layer**: Models and Firebase Integration

### State Management
- Uses Provider pattern for state management
- Services extend `ChangeNotifier` for reactive updates

### Key Services
- `AuthService`: Handles authentication
- `DatabaseService`: Firestore operations
- `LocationService`: Location and geocoding
- `RideService`: Ride booking and management
- `NotificationService`: Push notifications
- `PricingService`: Fare calculation

## Firebase Collections

- `users`: User profiles
- `drivers`: Driver profiles and documents
- `rides`: Completed rides
- `requests`: Active ride requests
- `scheduled_bookings`: Scheduled rides
- `chats`: Chat conversations
- `notifications`: User notifications

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow Flutter/Dart style guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Write tests for critical functionality

## Security Notes

- Never commit API keys or secrets to the repository
- Use environment variables or secure storage for sensitive data
- Implement proper authentication and authorization
- Validate all user inputs
- Use HTTPS for all network requests

## License

This project is proprietary and confidential. All rights reserved.

## Support

For support, email support@gibela.com or use the in-app support feature.

## Version

Current Version: 9.0.0+9
