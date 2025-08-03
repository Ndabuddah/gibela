import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class ServiceAreaPreferences extends StatefulWidget {
  final Map<String, List<String>> initialPreferences;
  final Function(Map<String, List<String>>) onPreferencesUpdated;

  const ServiceAreaPreferences({
    Key? key,
    required this.initialPreferences,
    required this.onPreferencesUpdated,
  }) : super(key: key);

  @override
  State<ServiceAreaPreferences> createState() => _ServiceAreaPreferencesState();
}

class _ServiceAreaPreferencesState extends State<ServiceAreaPreferences> {
  late Map<String, List<String>> _preferences;
  final TextEditingController _searchController = TextEditingController();
  bool _isAddingArea = false;
  String _selectedMainArea = '';

  @override
  void initState() {
    super.initState();
    _preferences = Map.from(widget.initialPreferences);
  }

  void _addMainArea(String area) {
    if (!_preferences.containsKey(area)) {
      setState(() {
        _preferences[area] = [];
        _selectedMainArea = area;
      });
      widget.onPreferencesUpdated(_preferences);
    }
  }

  void _addSubArea(String mainArea, String subArea) {
    if (!_preferences[mainArea]!.contains(subArea)) {
      setState(() {
        _preferences[mainArea]!.add(subArea);
      });
      widget.onPreferencesUpdated(_preferences);
    }
  }

  void _removeMainArea(String area) {
    setState(() {
      _preferences.remove(area);
      if (_selectedMainArea == area) {
        _selectedMainArea = _preferences.keys.isEmpty ? '' : _preferences.keys.first;
      }
    });
    widget.onPreferencesUpdated(_preferences);
  }

  void _removeSubArea(String mainArea, String subArea) {
    setState(() {
      _preferences[mainArea]!.remove(subArea);
    });
    widget.onPreferencesUpdated(_preferences);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search and Add Bar
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search areas...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (_isAddingArea) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Enter new area name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              _addMainArea(value);
                              setState(() {
                                _isAddingArea = false;
                              });
                              _searchController.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _isAddingArea = false;
                          });
                        },
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isAddingArea = true;
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Area'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Main Areas List
        if (_preferences.isNotEmpty) ...[
          const Text(
            'Your Service Areas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _preferences.length,
              itemBuilder: (context, index) {
                final area = _preferences.keys.elementAt(index);
                final isSelected = area == _selectedMainArea;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(area),
                    onSelected: (selected) {
                      setState(() {
                        _selectedMainArea = selected ? area : '';
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeMainArea(area),
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Sub Areas for Selected Main Area
          if (_selectedMainArea.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Locations in $_selectedMainArea',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => _AddSubAreaDialog(
                        mainArea: _selectedMainArea,
                        onAdd: _addSubArea,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Location'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _preferences[_selectedMainArea]!.map((subArea) {
                return Chip(
                  label: Text(subArea),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeSubArea(_selectedMainArea, subArea),
                );
              }).toList(),
            ),
          ],
        ] else ...[
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.location_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No service areas added yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add areas where you want to provide service',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _AddSubAreaDialog extends StatefulWidget {
  final String mainArea;
  final Function(String, String) onAdd;

  const _AddSubAreaDialog({
    required this.mainArea,
    required this.onAdd,
  });

  @override
  State<_AddSubAreaDialog> createState() => _AddSubAreaDialogState();
}

class _AddSubAreaDialogState extends State<_AddSubAreaDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Location to ${widget.mainArea}'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Enter location name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              widget.onAdd(widget.mainArea, _controller.text);
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}