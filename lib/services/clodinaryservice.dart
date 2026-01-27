// cloudinary_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  final String cloudName;
  final String uploadPreset;
  final String? apiKey;
  final String? apiSecret;

  CloudinaryService({
    required this.cloudName,
    required this.uploadPreset,
    this.apiKey,
    this.apiSecret,
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
      
      // Extract public ID from Cloudinary URL
      // Format: https://res.cloudinary.com/{cloudName}/image/upload/{version}/{publicId}.{format}
      String publicId;
      if (pathSegments.contains('upload')) {
        final uploadIndex = pathSegments.indexOf('upload');
        if (uploadIndex < pathSegments.length - 1) {
          // Skip version if present (it's usually a number or v{number})
          var idIndex = uploadIndex + 1;
          if (idIndex < pathSegments.length && 
              (pathSegments[idIndex].startsWith('v') || 
               RegExp(r'^\d+$').hasMatch(pathSegments[idIndex]))) {
            idIndex++;
          }
          
          if (idIndex < pathSegments.length) {
            // Get the public ID and remove file extension
            final fileName = pathSegments[idIndex];
            publicId = fileName.split('.').first;
          } else {
            debugPrint('Could not extract public ID from URL: $imageUrl');
            return false;
          }
        } else {
          debugPrint('Invalid Cloudinary URL structure: $imageUrl');
          return false;
        }
      } else {
        debugPrint('URL does not contain upload path: $imageUrl');
        return false;
      }
      
      // If API key and secret are not provided, return false
      if (apiKey == null || apiSecret == null) {
        debugPrint('Cloudinary API key and secret are required for deletion');
        return false;
      }
      
      // Generate timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Create signature
      final signatureString = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(signatureString)).toString();
      
      // Make deletion request
      final deleteUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      final response = await http.post(
        deleteUri,
        body: {
          'public_id': publicId,
          'api_key': apiKey!,
          'timestamp': timestamp.toString(),
          'signature': signature,
        },
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['result'] == 'ok') {
          debugPrint('Successfully deleted image: $publicId');
          return true;
        } else {
          debugPrint('Deletion failed: ${responseData['result']}');
          return false;
        }
      } else {
        final errorResponse = response.body;
        debugPrint('Failed to delete image: ${response.statusCode}, $errorResponse');
        return false;
      }
    } catch (e) {
      debugPrint('Cloudinary delete error: $e');
      return false;
    }
  }
}
