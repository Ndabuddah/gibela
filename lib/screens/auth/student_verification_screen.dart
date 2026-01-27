// lib/screens/auth/student_verification_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../services/clodinaryservice.dart';
import '../../widgets/common/custom_button.dart';

class StudentVerificationScreen extends StatefulWidget {
  const StudentVerificationScreen({Key? key}) : super(key: key);

  @override
  State<StudentVerificationScreen> createState() => _StudentVerificationScreenState();
}

class _StudentVerificationScreenState extends State<StudentVerificationScreen> {
  File? _faceImage;
  File? _idImage;
  File? _studentCardImage;
  File? _faceWithStudentCardImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final cloudinaryService = CloudinaryService(
    cloudName: 'dunfw4ifc',
    uploadPreset: 'beauti',
  );

  Future<void> _pickImage(Function(File?) onSelect) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        onSelect(File(pickedFile.path));
      });
    }
  }

  Widget _buildPhotoTile(String label, String description, File? image, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: image != null ? color.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: image != null ? color : Colors.black.withOpacity(0.05),
            width: image != null ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(image, width: 80, height: 80, fit: BoxFit.cover),
              )
            else
              Icon(Icons.add_a_photo_rounded, color: color.withOpacity(0.5), size: 40),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _submitVerification() async {
    if (_faceImage == null || _idImage == null || _studentCardImage == null || _faceWithStudentCardImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide all four required images.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Not logged in');

      // Upload to Cloudinary
      final faceUrl = await cloudinaryService.uploadImage(_faceImage!);
      final idUrl = await cloudinaryService.uploadImage(_idImage!);
      final studentCardUrl = await cloudinaryService.uploadImage(_studentCardImage!);
      final faceWithIdUrl = await cloudinaryService.uploadImage(_faceWithStudentCardImage!);

      if (faceUrl == null || idUrl == null || studentCardUrl == null || faceWithIdUrl == null) {
        throw Exception('Failed to upload one or more images');
      }

      await FirebaseFirestore.instance.collection('student_verification').doc(userId).set({
        'faceImageUrl': faceUrl,
        'idImageUrl': idUrl,
        'studentCardImageUrl': studentCardUrl,
        'faceWithStudentCardImageUrl': faceWithIdUrl,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Verification Submitted'),
          content: const Text('Our team will verify your student status within 15 minutes. You\'ll receive a notification once it\'s done.'),
          actions: [
            CustomButton(
              text: 'OK', 
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              isFullWidth: true,
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mainColor = AppColors.primary;
    
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Student Verification', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Verify your student status to unlock AsambeStudent rides.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPhotoTile(
                      'Face',
                      'Clear photo of your face',
                      _faceImage,
                      () => _pickImage((img) => _faceImage = img),
                      mainColor,
                    ),
                    _buildPhotoTile(
                      'ID Card',
                      'Your national ID card',
                      _idImage,
                      () => _pickImage((img) => _idImage = img),
                      mainColor,
                    ),
                    _buildPhotoTile(
                      'Student Card',
                      'Valid student card',
                      _studentCardImage,
                      () => _pickImage((img) => _studentCardImage = img),
                      mainColor,
                    ),
                    _buildPhotoTile(
                      'Verification',
                      'Face + Student Card',
                      _faceWithStudentCardImage,
                      () => _pickImage((img) => _faceWithStudentCardImage = img),
                      mainColor,
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                CustomButton(
                  text: 'Submit for Verification',
                  onPressed: _isLoading ? null : _submitVerification,
                  isFullWidth: true,
                ),
                const SizedBox(height: 24),
                const Text(
                  'By submitting, you agree to our verification process.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
