import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gibelbibela/providers/theme_provider.dart';
import 'package:gibelbibela/services/auth_service.dart';
import 'package:gibelbibela/services/clodinaryservice.dart';
import 'package:gibelbibela/services/database_service.dart';
import 'package:gibelbibela/services/location_service.dart';
import 'package:gibelbibela/services/notification_service.dart';
import 'package:gibelbibela/services/ride_service.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set preferred orientations and status bar style
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => RideService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        Provider(
          create: (_) => CloudinaryService(
            cloudName: 'dunfw4ifc',
            uploadPreset: 'beauti', // Replace with your upload preset
          ),
        ), // Add this line
      ],
      child: const MyApp(),
    ),
  );
}
