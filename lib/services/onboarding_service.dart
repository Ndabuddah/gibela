import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing onboarding flow
class OnboardingService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _onboardingVersionKey = 'onboarding_version';
  static const int _currentOnboardingVersion = 2; // Increment when onboarding changes
  
  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_onboardingCompletedKey) ?? false;
      final version = prefs.getInt(_onboardingVersionKey) ?? 0;
      
      // If onboarding version changed, show onboarding again
      if (version < _currentOnboardingVersion) {
        return false;
      }
      
      return completed;
    } catch (e) {
      print('Error checking onboarding status: $e');
      return false;
    }
  }
  
  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
      await prefs.setInt(_onboardingVersionKey, _currentOnboardingVersion);
    } catch (e) {
      print('Error completing onboarding: $e');
    }
  }
  
  /// Reset onboarding (for testing or re-showing)
  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingCompletedKey);
      await prefs.remove(_onboardingVersionKey);
    } catch (e) {
      print('Error resetting onboarding: $e');
    }
  }
  
  /// Check if specific feature tutorial should be shown
  Future<bool> shouldShowFeatureTutorial(String featureKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('tutorial_$featureKey') != true;
    } catch (e) {
      return true; // Show tutorial by default if error
    }
  }
  
  /// Mark feature tutorial as shown
  Future<void> markFeatureTutorialShown(String featureKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial_$featureKey', true);
    } catch (e) {
      print('Error marking tutorial as shown: $e');
    }
  }
}

/// Onboarding step data model
class OnboardingStep {
  final String title;
  final String description;
  final String imageAsset;
  final IconData? icon;
  
  OnboardingStep({
    required this.title,
    required this.description,
    required this.imageAsset,
    this.icon,
  });
}

/// Predefined onboarding steps
class OnboardingSteps {
  static List<OnboardingStep> get passengerSteps => [
    OnboardingStep(
      title: 'Welcome to Gibela',
      description: 'Your reliable ride-sharing partner. Book rides quickly and safely.',
      imageAsset: 'assets/images/onboarding/welcome.png',
      icon: null,
    ),
    OnboardingStep(
      title: 'Book Your Ride',
      description: 'Select your pickup and dropoff locations, choose your vehicle type, and request a ride.',
      imageAsset: 'assets/images/onboarding/book_ride.png',
      icon: null,
    ),
    OnboardingStep(
      title: 'Track Your Driver',
      description: 'See your driver\'s location in real-time and get notified when they arrive.',
      imageAsset: 'assets/images/onboarding/track_driver.png',
      icon: null,
    ),
    OnboardingStep(
      title: 'Safe & Secure',
      description: 'All drivers are verified. Use the panic button if you ever feel unsafe.',
      imageAsset: 'assets/images/onboarding/safety.png',
      icon: null,
    ),
  ];
  
  static List<OnboardingStep> get driverSteps => [
    OnboardingStep(
      title: 'Welcome, Driver!',
      description: 'Start earning with Gibela. Accept rides and grow your income.',
      imageAsset: 'assets/images/onboarding/driver_welcome.png',
      icon: null,
    ),
    OnboardingStep(
      title: 'Accept Rides',
      description: 'Receive ride requests and accept the ones that work for you.',
      imageAsset: 'assets/images/onboarding/accept_rides.png',
      icon: null,
    ),
    OnboardingStep(
      title: 'Track Earnings',
      description: 'Monitor your earnings and ride history in real-time.',
      imageAsset: 'assets/images/onboarding/earnings.png',
      icon: null,
    ),
    OnboardingStep(
      title: 'Stay Online',
      description: 'Go online when you\'re ready to accept rides and offline when you\'re done.',
      imageAsset: 'assets/images/onboarding/online.png',
      icon: null,
    ),
  ];
}


