import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class WorkingHoursManager extends StatefulWidget {
  final Map<String, List<String>> initialHours;
  final Function(Map<String, List<String>>) onHoursUpdated;

  const WorkingHoursManager({
    Key? key,
    required this.initialHours,
    required this.onHoursUpdated,
  }) : super(key: key);

  @override
  State<WorkingHoursManager> createState() => _WorkingHoursManagerState();
}

class _WorkingHoursManagerState extends State<WorkingHoursManager> {
  late Map<String, List<String>> _workingHours;
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _workingHours = Map.from(widget.initialHours);
    _initializeHours();
  }

  void _initializeHours() {
    for (var day in _daysOfWeek) {
      if (!_workingHours.containsKey(day)) {
        _workingHours[day] = ['09:00', '17:00'];
      }
    }
  }

  Future<void> _updateTime(String day, bool isStartTime, TimeOfDay currentTime) async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              hourMinuteShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              dayPeriodShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              dayPeriodColor: MaterialStateColor.resolveWith((states) =>
                  states.contains(MaterialState.selected)
                      ? AppColors.primary
                      : Colors.grey.shade200),
              hourMinuteColor: MaterialStateColor.resolveWith((states) =>
                  states.contains(MaterialState.selected)
                      ? AppColors.primary
                      : Colors.grey.shade200),
            ),
          ),
          child: child!,
        );
      },
    );

    if (newTime != null) {
      setState(() {
        final timeString =
            '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
        if (isStartTime) {
          _workingHours[day]![0] = timeString;
        } else {
          _workingHours[day]![1] = timeString;
        }
      });
      widget.onHoursUpdated(_workingHours);
    }
  }

  TimeOfDay _parseTimeString(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: _daysOfWeek.map((day) {
        final startTime = _parseTimeString(_workingHours[day]![0]);
        final endTime = _parseTimeString(_workingHours[day]![1]);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: AppColors.getIconColor(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      day,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeButton(
                        'Start Time',
                        startTime,
                        () => _updateTime(day, true, startTime),
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeButton(
                        'End Time',
                        endTime,
                        () => _updateTime(day, false, endTime),
                        isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeButton(
    String label,
    TimeOfDay time,
    VoidCallback onPressed,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time.format(context),
                  style: const TextStyle(fontSize: 16),
                ),
                Icon(
                  Icons.access_time,
                  size: 20,
                  color: AppColors.getIconColor(isDark),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}