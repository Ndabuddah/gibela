import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'database_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Register a new user
  Future<UserModel?> registerUser({
    required String email,
    required String password,
    required String name,
    required String surname,
    required String phoneNumber,
    bool isDriver = false,
  }) async {
    _setLoading(true);
    try {
      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;
      if (user != null) {
        // Create user model
        final UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          name: name,
          surname: surname,
          phoneNumber: phoneNumber,
          isDriver: isDriver,
        );

        // Save user to database
        await DatabaseService().createUser(newUser);

        _userModel = newUser;
        _setLoading(false);
        return newUser;
      }
    } catch (e) {
      _setLoading(false);
      rethrow;
    }

    _setLoading(false);
    return null;
  }

  // Login user
  Future<UserModel?> loginUser({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      // Sign in with Firebase Auth
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;
      if (user != null) {
        // Fetch user model from database
        final UserModel? fetchedUser = await DatabaseService().getUserById(user.uid);
        _userModel = fetchedUser;
        _setLoading(false);
        return fetchedUser;
      }
    } catch (e) {
      _setLoading(false);
      rethrow;
    }

    _setLoading(false);
    return null;
  }

  // Sign out user
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _auth.signOut();
      _userModel = null;
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Fetch current user from database
  Future<UserModel?> fetchCurrentUser() async {
    if (currentUser == null) return null;

    _setLoading(true);
    try {
      final UserModel? fetchedUser = await DatabaseService().getUserById(currentUser!.uid);
      _userModel = fetchedUser;
      _setLoading(false);
      return fetchedUser;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Update user profile
  Future<UserModel?> updateUserProfile({
    String? name,
    String? surname,
    String? phoneNumber,
    String? profileImage,
  }) async {
    if (_userModel == null) return null;

    _setLoading(true);
    try {
      final updatedUser = _userModel!.copyWith(
        name: name ?? _userModel!.name,
        surname: surname ?? _userModel!.surname,
        phoneNumber: phoneNumber ?? _userModel!.phoneNumber,
        profileImage: profileImage ?? _userModel!.profileImage,
      );

      await DatabaseService().updateUser(updatedUser);
      _userModel = updatedUser;
      _setLoading(false);
      return updatedUser;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    _setLoading(true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Add missing methods for compatibility
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      // Add a small delay before auth operations
      await Future.delayed(const Duration(milliseconds: 500));
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException:  [31m${e.code} [0m - ${e.message}');
      rethrow;
    } catch (e) {
      print('General auth error: $e');
      rethrow;
    }
  }
}
