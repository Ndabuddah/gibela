import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/clodinaryservice.dart';

class FemaleVerificationScreen extends StatefulWidget {
  const FemaleVerificationScreen({Key? key}) : super(key: key);

  @override
  State<FemaleVerificationScreen> createState() => _FemaleVerificationScreenState();
}

class _FemaleVerificationScreenState extends State<FemaleVerificationScreen> {
  File? _faceImage1;
  File? _faceImage2;
  File? _idImage;
  File? _faceWithIdSideImage;
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

  Widget _buildPhotoTile(String label, File? image, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: image == null
            ? Center(child: Text(label, textAlign: TextAlign.center))
            : ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(image, fit: BoxFit.cover, width: 110, height: 110),
              ),
      ),
    );
  }

  Future<String?> _uploadToCloudinary(File file, String folder) async {
    final cloudinaryService = Provider.of<CloudinaryService>(context, listen: false);
    // Optionally, you can add folder logic in your CloudinaryService if needed
    return await cloudinaryService.uploadImage(file);
  }

  void _submitVerification() async {
    if (_faceImage1 == null || _faceImage2 == null || _idImage == null || _faceWithIdSideImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide all four required images.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Not logged in');
      final faceUrl1 = await _uploadToCloudinary(_faceImage1!, 'woman_verification/$userId');
      final faceUrl2 = await _uploadToCloudinary(_faceImage2!, 'woman_verification/$userId');
      final idUrl = await _uploadToCloudinary(_idImage!, 'woman_verification/$userId');
      final faceWithIdSideUrl = await _uploadToCloudinary(_faceWithIdSideImage!, 'woman_verification/$userId');
      if (faceUrl1 == null || faceUrl2 == null || idUrl == null || faceWithIdSideUrl == null) {
        throw Exception('Failed to upload images.');
      }
      await FirebaseFirestore.instance.collection('womanVerification').doc(userId).set({
        'uid': userId,
        'faceUrl1': faceUrl1,
        'faceUrl2': faceUrl2,
        'idUrl': idUrl,
        'faceWithIdSideUrl': faceWithIdSideUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Verification Submitted'),
          content: const Text('Please wait for verification. This can take up to 15 minutes.'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Female Verification'),
        backgroundColor: Colors.pinkAccent,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'To access AsambeGirl rides, you must verify you are female. Please provide the following four images:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPhotoTile('Face (1)', _faceImage1, () => _pickImage((img) => _faceImage1 = img)),
                    _buildPhotoTile('Face (2)', _faceImage2, () => _pickImage((img) => _faceImage2 = img)),
                    _buildPhotoTile('ID Card', _idImage, () => _pickImage((img) => _idImage = img)),
                    _buildPhotoTile('Face + ID Card side-by-side', _faceWithIdSideImage, () => _pickImage((img) => _faceWithIdSideImage = img)),
                  ],
                ),
                const SizedBox(height: 36),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
