import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

class StorageService extends ChangeNotifier {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Upload file to Firebase Storage
  Future<String?> uploadFile(File file, String path) async {
    _setLoading(true);
    try {
      final Reference ref = _storage.ref().child(path);
      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      _setLoading(false);
      return downloadUrl;
    } catch (e) {
      _setLoading(false);
      return null;
    }
  }

  // Upload profile image
  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    return await uploadFile(imageFile, 'profile_images/$userId.jpg');
  }

  // Upload driver document
  Future<String?> uploadDriverDocument(File documentFile, String userId, String documentType) async {
    final String sanitizedType = documentType.replaceAll(' ', '_').toLowerCase();
    return await uploadFile(documentFile, 'driver_documents/$userId/$sanitizedType.jpg');
  }

  // Upload image to Cloudinary
  Future<String?> uploadImageToCloudinary(File imageFile) async {
    _setLoading(true);
    try {
      if (!imageFile.existsSync()) {
        print('File not found: ${imageFile.path}');
        _setLoading(false);
        return null;
      }

      final uri = Uri.parse(AppConstants.cloudinaryUploadUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = AppConstants.cloudinaryUploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = await response.stream.bytesToString();
        final Map<String, dynamic> parsedResponse = Uri.splitQueryString(responseData);

        _setLoading(false);
        return parsedResponse['secure_url'];
      } else {
        _setLoading(false);
        return null;
      }
    } catch (e) {
      _setLoading(false);
      return null;
    }
  }

  // Delete file from Firebase Storage
  Future<bool> deleteFile(String fileUrl) async {
    _setLoading(true);
    try {
      final Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }
}
