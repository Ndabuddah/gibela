import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> with SingleTickerProviderStateMixin {
  double dailyEarnings = 0.0;
  double weeklyEarnings = 0.0;
  double monthlyEarnings = 0.0;
  double cardEarnings = 0.0;
  int dailyRides = 0;
  int weeklyRides = 0;
  int monthlyRides = 0;
  List<Map<String, dynamic>> rideHistory = [];
  bool isLoading = true;
  late AnimationController _controller;
  late Animation<double> _earningsAnim;
  StreamSubscription? _earningsSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _earningsAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
    _fetchEarnings();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _earningsSubscription?.cancel();
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startRealTimeUpdates() {
    // Refresh earnings every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _fetchEarnings();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _fetchEarnings() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final user = authService.userModel;
    if (user != null) {
      try {
        final today = await dbService.getTodaysEarningsAndRides(user.uid);
        final week = await dbService.getEarningsAndRidesForPeriod(user.uid, period: 'week');
        final month = await dbService.getEarningsAndRidesForPeriod(user.uid, period: 'month');
        final history = await dbService.getAcceptedRides(user.uid);

        if (mounted) {
          setState(() {
            dailyEarnings = (today['earnings'] ?? 0.0) as double;
            dailyRides = (today['rides'] ?? 0) as int;
            weeklyEarnings = (week['earnings'] ?? 0.0) as double;
            weeklyRides = (week['rides'] ?? 0) as int;
            monthlyEarnings = (month['earnings'] ?? 0.0) as double;
            monthlyRides = (month['rides'] ?? 0) as int;
            cardEarnings = (today['cardEarnings'] ?? 0.0) as double;
            rideHistory = history;
            isLoading = false;
          });
          _controller.forward(from: 0);
        }
      } catch (e) {
        print('Error fetching earnings: $e');
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Fixed money due calculation - show -R450 instead of calculation
    final moneyDue = -450.0;
    final totalRides = rideHistory.length;
    final completedRides = rideHistory.where((r) => r['status'] == 2).length;
    final cancelledRides = rideHistory.where((r) => r['status'] == 3).length;
    final avgFare = completedRides > 0 ? rideHistory.where((r) => r['status'] == 2).map((r) => r['fare'] as double).reduce((a, b) => a + b) / completedRides : 0.0;
    final completionRate = totalRides > 0 ? (completedRides / totalRides * 100).toStringAsFixed(1) : '0.0';
    final cancellationRate = totalRides > 0 ? (cancelledRides / totalRides * 100).toStringAsFixed(1) : '0.0';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Layered background with gradients and abstract shapes
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFe0e7ff), Color(0xFFf8fafc)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -80,
                  left: -60,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6A82FB).withOpacity(0.18), Color(0xFF4F8FFF).withOpacity(0.10)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  right: -40,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF4F8FFF).withOpacity(0.10), Color(0xFF6A82FB).withOpacity(0.18)],
                        begin: Alignment.bottomRight,
                        end: Alignment.topLeft,
                      ),
                    ),
                  ),
                ),
                // Main content
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 48),
                          // Hero Card Section
                          Stack(
                            children: [
                              Center(
                                child: GlassCard(
                                  child: Container(
                                    width: MediaQuery.of(context).size.width * 0.88,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(32),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF4F8FFF), Color(0xFF6A82FB)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.13),
                                          blurRadius: 32,
                                          offset: const Offset(0, 16),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // Card chip
                                        Positioned(
                                          top: 28,
                                          left: 32,
                                          child: Container(
                                            width: 38,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              gradient: LinearGradient(
                                                colors: [Colors.white.withOpacity(0.7), Colors.white.withOpacity(0.3)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Main earnings
                                        Center(
                                          child: AnimatedBuilder(
                                            animation: _earningsAnim,
                                            builder: (context, child) {
                                              final value = (dailyEarnings * _earningsAnim.value).toStringAsFixed(2);
                                              return FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'R$value',
                                                  style: const TextStyle(
                                                    fontSize: 44,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    letterSpacing: 1.2,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black26,
                                                        blurRadius: 8,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        // Daily rides
                                        Positioned(
                                          left: 32,
                                          bottom: 32,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.directions_car, color: Colors.white, size: 20),
                                              const SizedBox(width: 6),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text('$dailyRides rides', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Today label
                                        Positioned(
                                          right: 32,
                                          bottom: 32,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('Today', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16, fontWeight: FontWeight.w400)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Floating back button has been moved to be stationary
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Horizontally scrollable stat cards
                          SizedBox(
                            height: 160,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                _statGlassCard('Total Rides', totalRides.toString(), Icons.directions_car, Colors.blueAccent),
                                _statGlassCard('Completed', completedRides.toString(), Icons.check_circle, Colors.green),
                                _statGlassCard('Cancelled', cancelledRides.toString(), Icons.cancel, Colors.redAccent),
                                _statGlassCard('Avg Fare', 'R${avgFare.toStringAsFixed(2)}', Icons.monetization_on, Colors.deepPurple),
                                _statGlassCard('Completion', '$completionRate%', Icons.done_all, Colors.green[800]!),
                                _statGlassCard('Cancel Rate', '$cancellationRate%', Icons.cancel_schedule_send, Colors.red[800]!),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Scroll indicator
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('scroll for more', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward_ios, color: Colors.grey[500], size: 13),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Earnings breakdown
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                Expanded(child: _breakdownCard('This Week', weeklyEarnings, weeklyRides, Icons.calendar_view_week, Colors.indigo)),
                                const SizedBox(width: 18),
                                Expanded(child: _breakdownCard('This Month', monthlyEarnings, monthlyRides, Icons.calendar_month, Colors.deepPurple)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Money Due Card
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: _breakdownCard('Money Due', moneyDue, 0, Icons.payments, Colors.green),
                          ),
                          const SizedBox(height: 36),
                          // Ride History Timeline
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Ride History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[900], letterSpacing: 0.2)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    // Ride History List
                    rideHistory.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history, size: 70, color: Colors.blue.withOpacity(0.18)),
                                  const SizedBox(height: 18),
                                  Text('No rides yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                                  const SizedBox(height: 8),
                                  Text('Your accepted rides will appear here.', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final ride = rideHistory[index];
                                final status = ride['status'];
                                final isCompleted = status == 2;
                                final isCancelled = status == 3;
                                final fare = isCancelled ? 0.0 : (ride['fare'] as double? ?? 0.0);
                                final date = ride['date'] != null
                                    ? DateTime.fromMillisecondsSinceEpoch(ride['date'])
                                    : null;
                                return _rideTimelineCard(
                                  fare: fare,
                                  date: date,
                                  status: status,
                                  isCompleted: isCompleted,
                                  isCancelled: isCancelled,
                                );
                              },
                              childCount: rideHistory.length,
                            ),
                          ),
                  ],
                ),
                // Stationary floating back button
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 12.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF4F8FFF), size: 22),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statGlassCard(String label, String value, IconData icon, Color color) {
    // Use AppColors for accent colors
    final accent = label == 'Total Rides'
        ? AppColors.primary
        : label == 'Completed'
            ? Colors.green
            : label == 'Cancelled'
                ? Colors.red
                : label == 'Avg Fare'
                    ? AppColors.primaryDark
                    : label == 'Completion'
                        ? Colors.green[800]!
                        : label == 'Cancel Rate'
                            ? Colors.red[800]!
                            : AppColors.primaryLight;
    return Container(
      width: 150,
      height: 240, // Further increased height
      margin: const EdgeInsets.only(right: 18),
      child: GlassCard(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18), // Slightly more padding
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [accent.withOpacity(0.13), Colors.white.withOpacity(0.10)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22), // Reduced icon size
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: accent)), // Reduced font size
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)), // Slightly reduced
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdownCard(String label, double amount, int rides, IconData icon, Color color) {
    // Use AppColors for accent colors
    final accent = label == 'This Week'
        ? AppColors.primary
        : label == 'This Month'
            ? AppColors.primaryDark
            : label == 'Money Due'
                ? Colors.green
                : AppColors.primaryLight;
    return GlassCard(
      child: Container(
        height: 160, // Further increased height
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22), // Slightly more padding
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.13), Colors.white.withOpacity(0.10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 22), // Reduced icon size
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accent)), // Reduced font size
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('R${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), // Reduced font size
            ),
            if (rides > 0) ...[
              const SizedBox(height: 6),
              Text('$rides rides', style: TextStyle(fontSize: 13, color: Colors.black54)), // Slightly reduced
            ],
          ],
        ),
      ),
    );
  }

  Widget _rideTimelineCard({required double fare, required DateTime? date, required int status, required bool isCompleted, required bool isCancelled}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GlassCard(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isCompleted
                ? Colors.green.withOpacity(0.12)
                : isCancelled
                    ? Colors.red.withOpacity(0.12)
                    : Colors.blue.withOpacity(0.12),
            child: Icon(
              isCompleted
                  ? Icons.check_circle
                  : isCancelled
                      ? Icons.cancel
                      : Icons.directions_car,
              color: isCompleted
                  ? Colors.green
                  : isCancelled
                      ? Colors.red
                      : Colors.blue,
            ),
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('R ${fare.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          subtitle: Text(
            date != null ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : 'No date',
          ),
          trailing: Chip(
            label: Text(
              isCompleted
                  ? 'Completed'
                  : isCancelled
                      ? 'Cancelled'
                      : 'Accepted',
              style: TextStyle(
                color: isCompleted
                    ? Colors.green[800]
                    : isCancelled
                        ? Colors.red[800]
                        : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: isCompleted
                ? Colors.green.withOpacity(0.12)
                : isCancelled
                    ? Colors.red.withOpacity(0.12)
                    : Colors.blue.withOpacity(0.12),
          ),
        ),
      ),
    );
  }
}

// GlassCard widget for glassmorphism effect
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.13), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
