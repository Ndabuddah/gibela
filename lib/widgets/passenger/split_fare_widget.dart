import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../services/split_fare_service.dart';
import '../../services/database_service.dart';
import 'package:provider/provider.dart';

/// Widget for split fare selection and management
class SplitFareWidget extends StatefulWidget {
  final double totalFare;
  final String rideId;
  final Function(Map<String, double>)? onSplitCreated;

  const SplitFareWidget({
    Key? key,
    required this.totalFare,
    required this.rideId,
    this.onSplitCreated,
  }) : super(key: key);

  @override
  State<SplitFareWidget> createState() => _SplitFareWidgetState();
}

class _SplitFareWidgetState extends State<SplitFareWidget> {
  final SplitFareService _splitFareService = SplitFareService();
  final DatabaseService _databaseService = DatabaseService();
  final List<String> _participants = [];
  final Map<String, String> _participantNames = {};
  final Map<String, double> _amounts = {};
  bool _isEvenSplit = true;
  bool _isLoading = false;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Add current user as first participant
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _participants.add(currentUser.uid);
      _loadUserName(currentUser.uid);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName(String userId) async {
    try {
      final user = await _databaseService.getUserById(userId);
      if (user != null) {
        setState(() {
          _participantNames[userId] = user.name;
        });
        _updateAmounts();
      }
    } catch (e) {
      print('Error loading user name: $e');
    }
  }

  Future<void> _addParticipant() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Find user by phone number - search in users collection
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      
      if (usersSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }
      
      final userData = usersSnapshot.docs.first.data();
      final user = await _databaseService.getUserById(usersSnapshot.docs.first.id);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }

      if (_participants.contains(user.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User already added')),
        );
        return;
      }

      setState(() {
        _participants.add(user.uid);
        _participantNames[user.uid] = user.name;
        _phoneController.clear();
      });
      _updateAmounts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateAmounts() {
    if (_isEvenSplit) {
      final splitAmounts = SplitFareService.calculateEvenSplit(
        totalFare: widget.totalFare,
        participantIds: _participants,
      );
      setState(() {
        _amounts.clear();
        _amounts.addAll(splitAmounts);
      });
    }
  }

  void _removeParticipant(String userId) {
    setState(() {
      _participants.remove(userId);
      _participantNames.remove(userId);
      _amounts.remove(userId);
    });
    _updateAmounts();
  }

  Future<void> _createSplitFare() async {
    if (_participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one more participant')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final splitRequestId = await _splitFareService.createSplitFareRequest(
        rideId: widget.rideId,
        initiatorId: currentUser.uid,
        totalFare: widget.totalFare,
        participantIds: _participants,
        amounts: _amounts,
      );

      if (widget.onSplitCreated != null) {
        widget.onSplitCreated!(_amounts);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Split fare request created')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating split fare: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                'Split Fare',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.white : AppColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Add participant
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    hintText: 'Enter phone number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkInputBg : AppColors.lightInputBg,
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _isLoading ? null : _addParticipant,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.black,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Split type toggle
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Even Split'),
                  selected: _isEvenSplit,
                  onSelected: (selected) {
                    setState(() {
                      _isEvenSplit = selected;
                    });
                    _updateAmounts();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Custom'),
                  selected: !_isEvenSplit,
                  onSelected: (selected) {
                    setState(() {
                      _isEvenSplit = !selected;
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Participants list
          if (_participants.isNotEmpty) ...[
            Text(
              'Participants (${_participants.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.white : AppColors.black,
              ),
            ),
            const SizedBox(height: 12),
            ..._participants.map((userId) => _buildParticipantCard(
              userId: userId,
              name: _participantNames[userId] ?? 'Unknown',
              amount: _amounts[userId] ?? 0.0,
              isDark: isDark,
            )),
            const SizedBox(height: 20),
          ],
          
          // Total
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.uberGreyLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.white : AppColors.black,
                  ),
                ),
                Text(
                  'R${widget.totalFare.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading || _participants.length < 2
                  ? null
                  : _createSplitFare,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Create Split Fare',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard({
    required String userId,
    required String name,
    required double amount,
    required bool isDark,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final canRemove = userId != currentUser?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.uberGreyLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(color: AppColors.black),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.white : AppColors.black,
                  ),
                ),
                Text(
                  'R${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              onPressed: () => _removeParticipant(userId),
              icon: const Icon(Icons.close),
              color: AppColors.error,
            ),
        ],
      ),
    );
  }
}

