import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gibelbibela/services/clodinaryservice.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../services/database_service.dart';
import '../../../widgets/common/custom_button.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../home/passenger/passenger_home_screen.dart';

class PassengerRegistrationScreen extends StatefulWidget {
  const PassengerRegistrationScreen({Key? key}) : super(key: key);

  @override
  _PassengerRegistrationScreenState createState() => _PassengerRegistrationScreenState();
}

class _PassengerRegistrationScreenState extends State<PassengerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _profileImage;
  File? _photo1;
  File? _photo2;
  File? _photo3;

  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _getImage(ImageSource source, Function(File?) onSelect) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        onSelect(File(pickedFile.path));
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _profileImage != null && _photo1 != null && _photo2 != null && _photo3 != null) {
      setState(() => _isLoading = true);

      try {
        final cloudinaryService = Provider.of<CloudinaryService>(context, listen: false);
        final dbService = Provider.of<DatabaseService>(context, listen: false);
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          throw Exception("No authenticated user found.");
        }

        // Upload images
        final profileImageUrl = await cloudinaryService.uploadImage(_profileImage!);
        final photo1Url = await cloudinaryService.uploadImage(_photo1!);
        final photo2Url = await cloudinaryService.uploadImage(_photo2!);
        final photo3Url = await cloudinaryService.uploadImage(_photo3!);

        // Prepare data
        final passengerData = {
          'name': _nameController.text,
          'phoneNumber': _phoneController.text,
          'profileImageUrl': profileImageUrl,
          'additionalPhotos': [photo1Url, photo2Url, photo3Url],
          'isRegistered': true, // Flag to indicate completion
        };

        // Save to Firestore
        await dbService.updateUserProfile(user.uid, passengerData);

        // Navigate to home
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const PassengerHomeScreen(isFirstTime: true)), (route) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save profile: ${e.toString()}')));
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields and add all photos.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile'), backgroundColor: AppColors.primary, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => _getImage(ImageSource.camera, (img) => _profileImage = img),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                    child: _profileImage == null ? const Icon(Icons.camera_alt, size: 50, color: Colors.grey) : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(child: Text('Tap to add a profile picture')),
              const SizedBox(height: 32),
              CustomTextField(controller: _nameController, label: 'Full Name', hintText: 'Enter your name', validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null),
              const SizedBox(height: 16),
              CustomTextField(controller: _phoneController, label: 'Phone Number', hintText: 'Enter your phone number', keyboardType: TextInputType.phone, validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null),
              const SizedBox(height: 32),
              const Text('Add 3 Recent Photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildPhotoPlaceholder((img) => _photo1 = img, _photo1), _buildPhotoPlaceholder((img) => _photo2 = img, _photo2), _buildPhotoPlaceholder((img) => _photo3 = img, _photo3)]),
              const SizedBox(height: 40),
              _isLoading
                  ? Container(
                      height: 56,
                      width: double.infinity,
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                        child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                      ),
                    )
                  : CustomButton(
                      text: 'Continue',
                      onPressed: () {
                        _submit();
                      },
                      isDisabled: false,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder(Function(File?) onSelect, File? image) {
    return GestureDetector(
      onTap: () => _getImage(ImageSource.camera, onSelect),
      child: Container(
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
          image: image != null ? DecorationImage(image: FileImage(image), fit: BoxFit.cover) : null,
        ),
        child: image == null ? const Icon(Icons.camera_enhance, size: 40, color: Colors.grey) : null,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
