// This file contains mock data for ride history to be used for UI visualization.
// It can be removed or replaced with a live data source.

final List<Map<String, dynamic>> mockRideHistory = [
  {
    'status': 2, // Completed
    'fare': 125.50,
    'date': DateTime.now().subtract(const Duration(days: 1, hours: 3)).millisecondsSinceEpoch,
    'pickupAddress': '123 Main St, Springfield',
    'destinationAddress': '456 Oak Ave, Shelbyville',
  },
  {
    'status': 3, // Cancelled
    'fare': 0.0,
    'date': DateTime.now().subtract(const Duration(days: 2, hours: 8)).millisecondsSinceEpoch,
    'pickupAddress': '789 Pine Ln, Capital City',
    'destinationAddress': '101 Maple Dr, Ogdenville',
  },
  {
    'status': 2, // Completed
    'fare': 88.20,
    'date': DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch,
    'pickupAddress': '221B Baker St, London',
    'destinationAddress': '10 Downing St, London',
  },
  {
    'status': 1, // Accepted
    'fare': 92.75,
    'date': DateTime.now().subtract(const Duration(minutes: 30)).millisecondsSinceEpoch,
    'pickupAddress': '31 Spooner St, Quahog',
    'destinationAddress': 'The Drunken Clam, Quahog',
  },
    {
    'status': 2, // Completed
    'fare': 210.00,
    'date': DateTime.now().subtract(const Duration(days: 5)).millisecondsSinceEpoch,
    'pickupAddress': '1600 Pennsylvania Ave, Washington D.C.',
    'destinationAddress': 'Lincoln Memorial, Washington D.C.',
  },
    {
    'status': 2, // Completed
    'fare': 75.60,
    'date': DateTime.now().subtract(const Duration(days: 6)).millisecondsSinceEpoch,
    'pickupAddress': '1, Infinite Loop, Cupertino',
    'destinationAddress': 'Apple Park Visitor Center, Cupertino',
  },
]; 