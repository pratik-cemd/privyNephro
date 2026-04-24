import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/myprofile.dart';
import 'screens/mydoctor.dart';
import 'screens/testHistory.dart';
import 'screens/myDevicesPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Privy',
//       debugShowCheckedModeBanner: false,
//       home: const LoginPage(),
//     );
//   }
// }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Privy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      initialRoute: LoginScreen.routeName,
      routes: {
        LoginScreen.routeName: (_) => const LoginScreen(),
        HomeScreen.routeName: (_) => const HomeScreen(),
        SignupScreen.routeName: (_) => const SignupScreen(),
        "/home": (context) => const HomeScreen(),

        // "/myDevice": (context) => const MyDevicesPage2(userMobile: userMobile),
        // "/testHistory": (context) => const TesthistoryPage(userMobile: ),
        // "/myprofile": (context) => const MyProfileScreen(),


      },
    );
  }
}
