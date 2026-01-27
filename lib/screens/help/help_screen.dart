import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../widgets/common/modern_alert_dialog.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Beautiful Gradient Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.support_agent, color: Colors.white, size: 48),
                  SizedBox(height: 18),
                  Text('Help & Support', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 8),
                  Text('We’re here to help you 24/7. Browse FAQs or contact us below.', style: TextStyle(fontSize: 16, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // FAQ Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Frequently Asked Questions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                  _faqCard(Icons.chat_bubble_outline, 'How do I contact support?', 'You can contact us via WhatsApp, email, or phone using the buttons below.'),
                  _faqCard(Icons.attach_money, 'How are driver earnings calculated?', 'Drivers earn the full fare minus a weekly platform fee.'),
                  _faqCard(Icons.delete_forever, 'How do I delete my account?', 'Go to Settings > Delete Account.'),
                  _faqCard(Icons.payments, 'When are payouts made?', 'Weekly payouts are made every Sunday.'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Contact Support Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.support_agent, color: AppColors.primary, size: 28),
                          SizedBox(width: 12),
                          Text('Contact Support', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 32,
                        runSpacing: 18,
                        children: [
                          _iconSupportButton(
                            icon: Icons.chat,
                            color: Colors.green,
                            label: 'WhatsApp',
                            onTap: () async {
                              const whatsappUrl = 'https://wa.me/27687455976';
                              if (await canLaunch(whatsappUrl)) {
                                await launch(whatsappUrl);
                              } else {
                                _showError(context, 'Could not open WhatsApp.');
                              }
                            },
                          ),
                          _iconSupportButton(
                            icon: Icons.email,
                            color: Colors.blue,
                            label: 'Email',
                            onTap: () async {
                              final emailUri = Uri(
                                scheme: 'mailto',
                                path: 'asamberyde@gmail.com',
                                query: 'subject=Support Request',
                              );
                              if (await canLaunch(emailUri.toString())) {
                                await launch(emailUri.toString());
                              } else {
                                _showError(context, 'Could not open email.');
                              }
                            },
                          ),

                        ],
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _showSupportTicketDialog(context),
                          icon: const Icon(Icons.support_agent),
                          label: const Text('Submit a Support Ticket'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static Widget _faqCard(IconData icon, String question, String answer) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(answer, style: const TextStyle(fontSize: 15, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _iconSupportButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 15)),
      ],
    );
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSupportTicketDialog(BuildContext context) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String selectedCategory = 'general';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Support Ticket'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(value: 'technical', child: Text('Technical Issue')),
                  DropdownMenuItem(value: 'payment', child: Text('Payment Issue')),
                  DropdownMenuItem(value: 'safety', child: Text('Safety Concern')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  selectedCategory = value ?? 'general';
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (subjectController.text.isEmpty || messageController.text.isEmpty) {
                ModernSnackBar.show(
                  context,
                  message: 'Please fill in all fields',
                  isError: true,
                );
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection('support_tickets').add({
                    'userId': user.uid,
                    'category': selectedCategory,
                    'subject': subjectController.text,
                    'message': messageController.text,
                    'status': 'open',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ModernSnackBar.show(
                      context,
                      message: 'Support ticket submitted successfully! We\'ll get back to you soon.',
                      isSuccess: true,
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ModernSnackBar.show(
                    context,
                    message: 'Failed to submit ticket: $e',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
} 