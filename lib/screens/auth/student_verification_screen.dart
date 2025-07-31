import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';

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

  Future<void> _pickImage(Function(File?) onSelect) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        onSelect(File(pickedFile.path));
      });
    }
  }

  Widget _buildPhotoTile(String label, String description, File? image, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(image, width: 70, height: 70, fit: BoxFit.cover),
                  )
                : Icon(Icons.add_a_photo, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 6),
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
      // TODO: Implement upload logic (e.g., Cloudinary, Firebase Storage)
      // Save URLs and verification data in Firestore under student_verification
      await FirebaseFirestore.instance.collection('student_verification').doc(userId).set({
        'faceImage': _faceImage!.path,
        'idImage': _idImage!.path,
        'studentCardImage': _studentCardImage!.path,
        'faceWithStudentCardImage': _faceWithStudentCardImage!.path,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Verification Submitted'),
          content: const Text('Please wait for student verification. This can take up to 15 minutes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('OK'),
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
    final mainColor = AppColors.secondary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Verification'),
        backgroundColor: mainColor,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'To access AsambeStudent rides, you must verify you are a student. Please provide the following four images:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 22),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPhotoTile(
                      'Face',
                      'Take a clear photo of your face.',
                      _faceImage,
                      () => _pickImage((img) => _faceImage = img),
                      mainColor,
                    ),
                    _buildPhotoTile(
                      'ID Card',
                      'Take a photo of your national ID card.',
                      _idImage,
                      () => _pickImage((img) => _idImage = img),
                      mainColor,
                    ),
                    _buildPhotoTile(
                      'Student Card',
                      'Take a photo of your valid student card.',
                      _studentCardImage,
                      () => _pickImage((img) => _studentCardImage = img),
                      mainColor,
                    ),
                    _buildPhotoTile(
                      'Face + Student Card',
                      'face holding your student card.',
                      _faceWithStudentCardImage,
                      () => _pickImage((img) => _faceWithStudentCardImage = img),
                      mainColor,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Submit for Verification'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verification can take up to 15 minutes. You will be notified once approved.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
