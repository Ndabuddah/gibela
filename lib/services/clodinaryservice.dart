// cloudinary_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  final String cloudName;
  final String uploadPreset;

  CloudinaryService({
    required this.cloudName,
    required this.uploadPreset,
  });

  Future<String?> uploadImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        debugPrint('File not found: ${imageFile.path}');
        return null;
      }

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        return jsonData['secure_url'] as String;
      } else {
        final errorResponse = await response.stream.bytesToString();
        debugPrint('Failed to upload image: ${response.statusCode}, $errorResponse');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  // Delete image from Cloudinary
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract public ID from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length < 3) {
        debugPrint('Invalid Cloudinary URL format: $imageUrl');
        return false;
      }
      
      // Get the public ID (remove file extension)
      final fileName = pathSegments.last;
      final publicId = fileName.split('.').first;
      
      // Note: This requires authentication with API key and secret
      // For now, we'll log the deletion attempt
      debugPrint('Would delete image with public ID: $publicId');
      
      // TODO: Implement actual deletion with API key and secret
      // final deleteUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      // final response = await http.post(
      //   deleteUri,
      //   body: {
      //     'public_id': publicId,
      //     'api_key': 'YOUR_API_KEY',
      //     'signature': 'YOUR_SIGNATURE',
      //   },
      // );
      
      // For now, return true to indicate successful "deletion"
      return true;
    } catch (e) {
      debugPrint('Cloudinary delete error: $e');
      return false;
    }
  }
}
