import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/driver_profile_service.dart';

class DocumentManagementCard extends StatefulWidget {
  final String documentType;
  final String documentUrl;
  final bool isVerified;
  final DateTime? expiryDate;
  final Function(File) onDocumentUpdated;
  final String driverId;

  const DocumentManagementCard({
    Key? key,
    required this.documentType,
    required this.documentUrl,
    required this.isVerified,
    this.expiryDate,
    required this.onDocumentUpdated,
    required this.driverId,
  }) : super(key: key);

  @override
  State<DocumentManagementCard> createState() => _DocumentManagementCardState();
}

class _DocumentManagementCardState extends State<DocumentManagementCard> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final DriverProfileService _profileService = DriverProfileService();

  Future<void> _pickAndUploadDocument() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _isLoading = true);
        final file = File(image.path);
        await _profileService.updateDocument(widget.driverId, widget.documentType, file);
        widget.onDocumentUpdated(file);
      }
    } catch (e) {
      _showError('Error uploading document: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getDocumentTypeDisplay() {
    return widget.documentType.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Widget _buildExpiryWarning() {
    if (widget.expiryDate == null) return const SizedBox.shrink();

    final daysUntilExpiry = widget.expiryDate!.difference(DateTime.now()).inDays;
    if (daysUntilExpiry <= 30) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: daysUntilExpiry <= 7 ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: daysUntilExpiry <= 7 ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: daysUntilExpiry <= 7 ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              daysUntilExpiry <= 0
                  ? 'Expired'
                  : 'Expires in $daysUntilExpiry days',
              style: TextStyle(
                fontSize: 12,
                color: daysUntilExpiry <= 7 ? Colors.red : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isVerified ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isVerified
                    ? Colors.green.withOpacity(0.1)
                    : AppColors.getCardColor(isDark),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isVerified ? Icons.verified : Icons.pending,
                    color: widget.isVerified ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDocumentTypeDisplay(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isVerified ? 'Verified' : 'Pending Verification',
                          style: TextStyle(
                            color: widget.isVerified ? Colors.green : Colors.orange,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.expiryDate != null)
                    Text(
                      'Expires: ${DateFormat('MMM d, y').format(widget.expiryDate!)}',
                      style: TextStyle(
                        color: AppColors.getTextSecondaryColor(isDark),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            // Document Preview
            if (widget.documentUrl.isNotEmpty)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      widget.documentUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    ),
                    if (_isLoading)
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
              ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExpiryWarning(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickAndUploadDocument,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        widget.documentUrl.isEmpty
                            ? 'Upload Document'
                            : 'Update Document',
                      ),
                    ),
                  ),
                  if (widget.documentUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _isLoading ? null : () {
                          // Implement document preview
                        },
                        icon: const Icon(Icons.remove_red_eye),
                        label: const Text('Preview Document'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}