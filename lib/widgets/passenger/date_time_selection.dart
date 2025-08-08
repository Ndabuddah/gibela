import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import 'package:provider/provider.dart';

class DateTimeSelection extends StatelessWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final Function(DateTime) onDateChanged;
  final Function(TimeOfDay) onTimeChanged;

  const DateTimeSelection({
    Key? key,
    required this.selectedDate,
    required this.selectedTime,
    required this.onDateChanged,
    required this.onTimeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When do you need the ride?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimaryColor(isDark),
            ),
          ),
          const SizedBox(height: 16),
          
          // Date Picker
          GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().add(const Duration(hours: 1)),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                onDateChanged(picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getBackgroundColor(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorderColor(isDark)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextSecondaryColor(isDark),
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d, y').format(selectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimaryColor(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.getTextSecondaryColor(isDark),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Time Picker
          GestureDetector(
            onTap: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: selectedTime,
              );
              if (picked != null) {
                onTimeChanged(picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getBackgroundColor(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorderColor(isDark)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextSecondaryColor(isDark),
                          ),
                        ),
                        Text(
                          selectedTime.format(context),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimaryColor(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.getTextSecondaryColor(isDark),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 