import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/modern_alert_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.purple,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Drivers'),
            Tab(text: 'Passengers'),
            Tab(text: 'Verifications'),
            Tab(text: 'Delete Requests'),
            Tab(text: 'Pricing'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getCardColor(isDark),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    enableInteractiveSelection: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.getBackgroundColor(isDark),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedFilter,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All')),
                    const DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    const DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    const DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                    const DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    const DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _UsersTab(searchQuery: _searchQuery, filter: _selectedFilter),
                _DriversTab(searchQuery: _searchQuery, filter: _selectedFilter),
                _PassengersTab(searchQuery: _searchQuery, filter: _selectedFilter),
                _VerificationsTab(searchQuery: _searchQuery, filter: _selectedFilter),
                _DeleteRequestsTab(searchQuery: _searchQuery, filter: _selectedFilter),
                _PricingTab(),
                _PaymentsTab(searchQuery: _searchQuery, filter: _selectedFilter),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Users Tab
class _UsersTab extends StatelessWidget {
  final String searchQuery;
  final String filter;

  const _UsersTab({required this.searchQuery, required this.filter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];
        final filteredUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name']?.toString().toLowerCase() ?? '';
          final email = data['email']?.toString().toLowerCase() ?? '';
          final matchesSearch = name.contains(searchQuery.toLowerCase()) || 
                               email.contains(searchQuery.toLowerCase());
          
          if (filter == 'all') return matchesSearch;
          // Add more filtering logic as needed
          return matchesSearch;
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userData = filteredUsers[index].data() as Map<String, dynamic>;
            final userId = filteredUsers[index].id;
            
            return _UserCard(
              userId: userId,
              userData: userData,
            );
          },
        );
      },
    );
  }
}

// Drivers Tab
class _DriversTab extends StatelessWidget {
  final String searchQuery;
  final String filter;

  const _DriversTab({required this.searchQuery, required this.filter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final drivers = snapshot.data?.docs ?? [];
        final filteredDrivers = drivers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name']?.toString().toLowerCase() ?? '';
          final email = data['email']?.toString().toLowerCase() ?? '';
          final matchesSearch = name.contains(searchQuery.toLowerCase()) || 
                               email.contains(searchQuery.toLowerCase());
          
          if (filter == 'all') return matchesSearch;
          if (filter == 'approved') return matchesSearch && (data['isApproved'] == true);
          if (filter == 'pending') return matchesSearch && (data['isApproved'] != true);
          return matchesSearch;
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDrivers.length,
          itemBuilder: (context, index) {
            final driverData = filteredDrivers[index].data() as Map<String, dynamic>;
            final driverId = filteredDrivers[index].id;
            
            return _DriverCard(
              driverId: driverId,
              driverData: driverData,
            );
          },
        );
      },
    );
  }
}

// Passengers Tab
class _PassengersTab extends StatelessWidget {
  final String searchQuery;
  final String filter;

  const _PassengersTab({required this.searchQuery, required this.filter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('isDriver', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final passengers = snapshot.data?.docs ?? [];
        final filteredPassengers = passengers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name']?.toString().toLowerCase() ?? '';
          final email = data['email']?.toString().toLowerCase() ?? '';
          final matchesSearch = name.contains(searchQuery.toLowerCase()) || 
                               email.contains(searchQuery.toLowerCase());
          return matchesSearch;
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredPassengers.length,
          itemBuilder: (context, index) {
            final passengerData = filteredPassengers[index].data() as Map<String, dynamic>;
            final passengerId = filteredPassengers[index].id;
            
            return _PassengerCard(
              passengerId: passengerId,
              passengerData: passengerData,
            );
          },
        );
      },
    );
  }
}

// Verifications Tab
class _VerificationsTab extends StatelessWidget {
  final String searchQuery;
  final String filter;

  const _VerificationsTab({required this.searchQuery, required this.filter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('isGirl', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final verifications = snapshot.data?.docs ?? [];
        final filteredVerifications = verifications.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name']?.toString().toLowerCase() ?? '';
          final email = data['email']?.toString().toLowerCase() ?? '';
          final matchesSearch = name.contains(searchQuery.toLowerCase()) || 
                               email.contains(searchQuery.toLowerCase());
          return matchesSearch;
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredVerifications.length,
          itemBuilder: (context, index) {
            final verificationData = filteredVerifications[index].data() as Map<String, dynamic>;
            final verificationId = filteredVerifications[index].id;
            
            return _VerificationCard(
              verificationId: verificationId,
              verificationData: verificationData,
            );
          },
        );
      },
    );
  }
}

// Delete Requests Tab
class _DeleteRequestsTab extends StatelessWidget {
  final String searchQuery;
  final String filter;

  const _DeleteRequestsTab({required this.searchQuery, required this.filter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('deleteRequests').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final deleteRequests = snapshot.data?.docs ?? [];
        final filteredRequests = deleteRequests.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final username = data['username']?.toString().toLowerCase() ?? '';
          final email = data['email']?.toString().toLowerCase() ?? '';
          final matchesSearch = username.contains(searchQuery.toLowerCase()) || 
                               email.contains(searchQuery.toLowerCase());
          
          if (filter == 'all') return matchesSearch;
          if (filter == 'pending') return matchesSearch && (data['status'] == 'pending');
          if (filter == 'completed') return matchesSearch && (data['status'] == 'completed');
          return matchesSearch;
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredRequests.length,
          itemBuilder: (context, index) {
            final requestData = filteredRequests[index].data() as Map<String, dynamic>;
            final requestId = filteredRequests[index].id;
            
            return _DeleteRequestCard(
              requestId: requestId,
              requestData: requestData,
            );
          },
        );
      },
    );
  }
}

// Pricing Tab
class _PricingTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pricing Configuration',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimaryColor(Theme.of(context).brightness == Brightness.dark),
            ),
          ),
          const SizedBox(height: 16),
          _PricingConfigCard(),
        ],
      ),
    );
  }
}

// User Card Widget
class _UserCard extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const _UserCard({required this.userId, required this.userData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            userData['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          userData['name']?.toString() ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimaryColor(isDark),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userData['email']?.toString() ?? 'No email'),
            Text('Phone: ${userData['phoneNumber']?.toString() ?? 'No phone'}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditUserDialog(context, userId, userData);
            } else if (value == 'delete') {
              _showDeleteUserDialog(context, userId);
            }
          },
        ),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, String userId, Map<String, dynamic> userData) {
    // Implementation for editing user
  }

  void _showDeleteUserDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('users').doc(userId).delete();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User deleted successfully')),
                );
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting user: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Driver Card Widget
class _DriverCard extends StatelessWidget {
  final String driverId;
  final Map<String, dynamic> driverData;

  const _DriverCard({required this.driverId, required this.driverData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isApproved = driverData['isApproved'] == true;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isApproved ? Colors.green : Colors.orange,
          child: Icon(
            isApproved ? Icons.check : Icons.pending,
            color: Colors.white,
          ),
        ),
        title: Text(
          driverData['name']?.toString() ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimaryColor(isDark),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(driverData['email']?.toString() ?? 'No email'),
            Text('Vehicle: ${driverData['vehicleType']?.toString() ?? 'No vehicle'}'),
            Text('Status: ${isApproved ? 'Approved' : 'Pending'}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Text('View Details'),
            ),
            const PopupMenuItem(
              value: 'approve',
              child: Text('Approve/Reject'),
            ),
            const PopupMenuItem(
              value: 'payout',
              child: Text('Payout'),
            ),
          ],
          onSelected: (value) {
            if (value == 'view') {
              _showDriverDetails(context, driverId, driverData);
            } else if (value == 'approve') {
              _showApprovalDialog(context, driverId, driverData);
            } else if (value == 'payout') {
              _showPayoutDialog(context, driverId, driverData);
            }
          },
        ),
      ),
    );
  }

  void _showDriverDetails(BuildContext context, String driverId, Map<String, dynamic> driverData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _DriverDetailsScreen(driverId: driverId, driverData: driverData),
      ),
    );
  }

  void _showApprovalDialog(BuildContext context, String driverId, Map<String, dynamic> driverData) {
    // Implementation for approval dialog
  }

  void _showPayoutDialog(BuildContext context, String driverId, Map<String, dynamic> driverData) {
    // Implementation for payout dialog
  }
}

// Passenger Card Widget
class _PassengerCard extends StatelessWidget {
  final String passengerId;
  final Map<String, dynamic> passengerData;

  const _PassengerCard({required this.passengerId, required this.passengerData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            passengerData['name']?.toString().substring(0, 1).toUpperCase() ?? 'P',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          passengerData['name']?.toString() ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimaryColor(isDark),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(passengerData['email']?.toString() ?? 'No email'),
            Text('Phone: ${passengerData['phoneNumber']?.toString() ?? 'No phone'}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              // Implementation for editing passenger
            } else if (value == 'delete') {
              // Implementation for deleting passenger
            }
          },
        ),
      ),
    );
  }
}

// Verification Card Widget
class _VerificationCard extends StatelessWidget {
  final String verificationId;
  final Map<String, dynamic> verificationData;

  const _VerificationCard({required this.verificationId, required this.verificationData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: const Icon(Icons.verified_user, color: Colors.white),
        ),
        title: Text(
          verificationData['name']?.toString() ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimaryColor(isDark),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(verificationData['email']?.toString() ?? 'No email'),
            Text('Type: ${verificationData['isGirl'] == true ? 'Female' : 'Student'}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'approve',
              child: Text('Approve'),
            ),
            const PopupMenuItem(
              value: 'reject',
              child: Text('Reject'),
            ),
          ],
          onSelected: (value) {
            // Implementation for approval/rejection
          },
        ),
      ),
    );
  }
}

// Delete Request Card Widget
class _DeleteRequestCard extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const _DeleteRequestCard({required this.requestId, required this.requestData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = requestData['status']?.toString() ?? 'pending';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status == 'completed' ? Colors.green : Colors.red,
          child: Icon(
            status == 'completed' ? Icons.check : Icons.delete,
            color: Colors.white,
          ),
        ),
        title: Text(
          requestData['username']?.toString() ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimaryColor(isDark),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(requestData['email']?.toString() ?? 'No email'),
            Text('Reason: ${requestData['reason']?.toString() ?? 'No reason'}'),
            Text('Status: ${status.toUpperCase()}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mark_completed',
              child: Text('Mark Completed'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete Request'),
            ),
          ],
          onSelected: (value) {
            if (value == 'mark_completed') {
              _markRequestCompleted(context, requestId);
            } else if (value == 'delete') {
              _deleteRequest(context, requestId);
            }
          },
        ),
      ),
    );
  }

  void _markRequestCompleted(BuildContext context, String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('deleteRequests')
          .doc(requestId)
          .update({'status': 'completed'});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request marked as completed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _deleteRequest(BuildContext context, String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('deleteRequests')
          .doc(requestId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

// Pricing Config Card Widget
class _PricingConfigCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Base Pricing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Base Fare (R)'),
                      const SizedBox(height: 8),
                      TextField(
                        enableInteractiveSelection: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '25.00',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Per Km Rate (R)'),
                      const SizedBox(height: 8),
                      TextField(
                        enableInteractiveSelection: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '6.50',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Implementation for saving pricing config
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

// Driver Details Screen
class _DriverDetailsScreen extends StatelessWidget {
  final String driverId;
  final Map<String, dynamic> driverData;

  const _DriverDetailsScreen({required this.driverId, required this.driverData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver: ${driverData['name'] ?? 'Unknown'}'),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DriverInfoCard(driverData: driverData),
            const SizedBox(height: 16),
            _DriverDocumentsCard(driverId: driverId),
            const SizedBox(height: 16),
            _DriverPayoutCard(driverId: driverId, driverData: driverData),
          ],
        ),
      ),
    );
  }
}

// Driver Info Card
class _DriverInfoCard extends StatelessWidget {
  final Map<String, dynamic> driverData;

  const _DriverInfoCard({required this.driverData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow('Name', driverData['name']?.toString() ?? 'N/A'),
            _InfoRow('Email', driverData['email']?.toString() ?? 'N/A'),
            _InfoRow('Phone', driverData['phoneNumber']?.toString() ?? 'N/A'),
            _InfoRow('Vehicle Type', driverData['vehicleType']?.toString() ?? 'N/A'),
            _InfoRow('License Plate', driverData['licensePlate']?.toString() ?? 'N/A'),
            _InfoRow('Status', driverData['isApproved'] == true ? 'Approved' : 'Pending'),
          ],
        ),
      ),
    );
  }
}

// Driver Documents Card
class _DriverDocumentsCard extends StatelessWidget {
  final String driverId;

  const _DriverDocumentsCard({required this.driverId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
            ),
            const SizedBox(height: 16),
            // Add document viewing functionality here
            const Text('Document viewing functionality to be implemented'),
          ],
        ),
      ),
    );
  }
}

// Driver Payout Card
class _DriverPayoutCard extends StatelessWidget {
  final String driverId;
  final Map<String, dynamic> driverData;

  const _DriverPayoutCard({required this.driverId, required this.driverData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payout Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow('Total Earnings', 'R${driverData['totalEarnings']?.toString() ?? '0.00'}'),
            _InfoRow('Total Rides', driverData['totalRides']?.toString() ?? '0'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Implementation for marking as paid
                    },
                    child: const Text('Mark as Paid'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Implementation for viewing payout history
                    },
                    child: const Text('View History'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Info Row Widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.getTextSecondaryColor(isDark),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimaryColor(isDark),
            ),
          ),
        ],
      ),
    );
  }
} 

// Payments Tab
class _PaymentsTab extends StatelessWidget {
  final String searchQuery;
  final String filter;

  const _PaymentsTab({required this.searchQuery, required this.filter});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('isDriver', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];
        
        // Filter users based on search query and payment status
        final filteredUsers = users.where((user) {
          final userData = user.data() as Map<String, dynamic>;
          final name = userData['name']?.toString().toLowerCase() ?? '';
          final email = userData['email']?.toString().toLowerCase() ?? '';
          final phone = userData['phoneNumber']?.toString().toLowerCase() ?? '';
          final searchLower = searchQuery.toLowerCase();
          
          // Check if user matches search query
          final matchesSearch = searchQuery.isEmpty || 
              name.contains(searchLower) || 
              email.contains(searchLower) || 
              phone.contains(searchLower);
          
          // Check payment status based on filter
          bool matchesFilter = true;
          if (filter == 'paid') {
            matchesFilter = userData['paymentCompleted'] == true;
          } else if (filter == 'unpaid') {
            matchesFilter = userData['paymentCompleted'] != true;
          }
          
          return matchesSearch && matchesFilter;
        }).toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payment, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No drivers found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            final userData = user.data() as Map<String, dynamic>;
            final userId = user.id;
            
            return _PaymentCard(
              userId: userId,
              userData: userData,
              searchQuery: searchQuery,
            );
          },
        );
      },
    );
  }
}

// Payment Card Widget
class _PaymentCard extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;
  final String searchQuery;

  const _PaymentCard({
    required this.userId,
    required this.userData,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPaid = userData['paymentCompleted'] == true;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    (userData['name']?.toString().substring(0, 1).toUpperCase() ?? 'D'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userData['name']?.toString() ?? 'Unknown Driver',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimaryColor(isDark),
                        ),
                      ),
                      Text(
                        userData['email']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                      Text(
                        userData['phoneNumber']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPaid ? 'PAID' : 'UNPAID',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPaid ? null : () => _markAsPaid(context, userId),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark as Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPaid ? Colors.grey : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewPaymentDetails(context, userId),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsPaid(BuildContext context, String userId) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Payment'),
          content: const Text('Are you sure you want to mark this driver\'s payment as completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Update user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'paymentCompleted': true,
        'paymentDate': FieldValue.serverTimestamp(),
        'paymentMethod': 'manual_admin',
      });

      // Add payment record to driver_payments collection
      await FirebaseFirestore.instance
          .collection('driver_payments')
          .add({
        'userId': userId,
        'amount': 150.00, // Default driver registration fee
        'paymentMethod': 'manual_admin',
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
        'adminId': AuthService().currentUser?.uid,
        'notes': 'Payment marked as completed by admin',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment marked as completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewPaymentDetails(BuildContext context, String userId) async {
    try {
      final paymentDocs = await FirebaseFirestore.instance
          .collection('driver_payments')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Payment History'),
            content: SizedBox(
              width: double.maxFinite,
              child: paymentDocs.docs.isEmpty
                  ? const Text('No payment records found.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: paymentDocs.docs.length,
                      itemBuilder: (context, index) {
                        final payment = paymentDocs.docs[index].data();
                        return ListTile(
                          title: Text('R${payment['amount']?.toString() ?? '0.00'}'),
                          subtitle: Text(payment['paymentMethod']?.toString() ?? ''),
                          trailing: Text(
                            payment['timestamp'] != null
                                ? DateTime.fromMillisecondsSinceEpoch(
                                    payment['timestamp'].millisecondsSinceEpoch,
                                  ).toString().substring(0, 16)
                                : 'Unknown',
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 