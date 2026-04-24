// import 'dart:convert';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:app/screens/myDevice_BLE.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'myprofile.dart';
// import 'mydoctor.dart';
// // import 'myDevice.dart';
// import 'bleScan.dart';
// import 'myDevicesPage.dart';
// import "testHistory.dart";
// import 'user_model.dart';
//
// class HomeScreen extends StatefulWidget {
//   static const routeName = '/home';
//   final Map<String, dynamic>? savedUserData;
//
//   const HomeScreen({super.key, this.savedUserData});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   // String name = "";
//   // String age = "";
//   // String mobile = "";
//   // String email = "";
//   // String address = "";
//   // String gender = "";
//   // String imageBase64 = "";
//   // String disease = "";
//   // String clinicName = "";
//   // String specialization = "";
//   // String type = "";
//   // String count = "0";
//   late UserModel currentUser;
//
//   bool _loadedPrefs = false;
//   late DatabaseReference testReqRef;
//
//   @override
//   void initState() {
//     super.initState();
//     print("🔍 imageBase64 received: $currentUser.imageBase64");
//
//     if (currentUser.imageBase64.isEmpty) {
//       print("⚠ No image received. Using default photo.");
//     }
//     _loadLocalPrefs();
//   }
//
//   Future<void> _loadLocalPrefs() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     // mobile = prefs.getString("mobile") ?? "";
//     // name = prefs.getString("name") ?? "";
//     // age = prefs.getString("age") ?? "";
//     // email = prefs.getString("email") ?? "";
//     // address = prefs.getString("address") ?? "";
//     // gender = prefs.getString("gender") ?? "";
//     // imageBase64 = prefs.getString("imageBase64") ?? "";
//     // type = prefs.getString("type") ?? "";
//     // count = prefs.getString("count") ?? "0";
//     //
//     // if (type == "doctor") {
//     //   specialization = prefs.getString("specialization") ?? "";
//     //   clinicName = prefs.getString("clinicName") ?? "";
//     //   disease = "NA";
//     // } else {
//     //   disease = prefs.getString("diseaseType") ?? "";
//     //   specialization = "NA";
//     //   clinicName = "NA";
//     // }
//     //
//     // if (widget.savedUserData != null) {
//     //   final u = widget.savedUserData!;
//     //   name = u['name'] ?? name;
//     //   age = u['age'] ?? age;
//     //   mobile = u['mobile'] ?? mobile;
//     //   email = u['email'] ?? email;
//     //   address = u['address'] ?? address;
//     //   gender = u['gender'] ?? gender;
//     //   imageBase64 = u['imageBase64'] ?? imageBase64;
//     //   type = u['type'] ?? type;
//     //   count = u['count'] ?? count;
//     //   specialization = u['specialization'] ?? specialization;
//     //   clinicName = u['clinicName'] ?? clinicName;
//     //   disease = u['diseaseType'] ?? disease;
//     // }
//     String mobile = prefs.getString("mobile") ?? "";
//     String name = prefs.getString("name") ?? "";
//     String age = prefs.getString("age") ?? "";
//     String email = prefs.getString("email") ?? "";
//     String address = prefs.getString("address") ?? "";
//     String gender = prefs.getString("gender") ?? "";
//     String imageBase64 = prefs.getString("imageBase64") ?? "";
//     String type = prefs.getString("type") ?? "";
//     String count = prefs.getString("count") ?? "0";
//
//     String specialization = "";
//     String clinicName = "";
//     String disease = "";
//
//     if (type == "doctor") {
//       specialization = prefs.getString("specialization") ?? "";
//       clinicName = prefs.getString("clinicName") ?? "";
//       disease = "NA";
//     } else {
//       disease = prefs.getString("diseaseType") ?? "";
//       specialization = "NA";
//       clinicName = "NA";
//     }
//
//     currentUser = UserModel(
//       mobile: mobile,
//       name: name,
//       age: age,
//       gender: gender,
//       address: address,
//       disease: disease,
//       type: type,
//       email: email,
//       imageBase64: imageBase64,
//       clinicName: clinicName,
//       specialization: specialization,
//       count: count,
//     );
//
//     setState(() => _loadedPrefs = true);
//     _startAutoCheck();
//   }
//
//   void _startAutoCheck() {
//     if (currentUser.mobile.isEmpty) return;
//     testReqRef = FirebaseDatabase.instance.ref("TestRequests").child(currentUser.mobile);
//
//     testReqRef.onValue.listen((event) {
//       if (event.snapshot.value == null) return;
//
//       final data = Map<String, dynamic>.from(
//           event.snapshot.value as Map<dynamic, dynamic>);
//
//       final status = data["st"] ?? "w";
//       final oldCount = data["OC"] ?? "0";
//       final totalCount = data["TC"] ?? "0";
//       final totalAmount = data["TA"] ?? "0";
//
//       if (status == "a") {
//         _handleAutoApproval(
//             oldCount.toString(), totalCount.toString(), totalAmount.toString());
//       }
//     });
//   }
//
//   Future<void> _handleAutoApproval(String oldCount, String totalCount, String totalAmount) async {
//          final doctorRef = FirebaseDatabase.instance
//         .ref("users/doctor")
//         .child(currentUser.mobile)
//         .child("count");
//
//     await doctorRef.set(totalCount);
//
//     final prefs = await SharedPreferences.getInstance();
//     prefs.setString("count", totalCount);
//     var count = totalCount;
//
//     final historyRef = FirebaseDatabase.instance.ref("ApH").child(currentUser.mobile);
//     final id = DateTime.now().millisecondsSinceEpoch.toString();
//
//     await historyRef.child(id).set({
//       "OC": oldCount,
//       "TC": totalCount,
//       "TA": totalAmount,
//       "st": "a",
//     });
//
//     await testReqRef.remove();
//
//     if (!mounted) return;
//
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text("Remaining Test Count"),
//         content: Text(count),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("OK"))
//         ],
//       ),
//     );
//   }
//
//   ImageProvider<Object> _decodeBase64() {
//     try {
//       if (currentUser.imageBase64.isEmpty) {
//         print("⚠ Base64 string EMPTY. Showing default image.");
//         return const AssetImage("assets/images/default_user.png");
//       }
//
//       print("📥 Attempting to decode Base64...");
//
//       // Cleanup broken base64
//       String cleanBase64 = currentUser.imageBase64
//           .replaceAll("\n", "")
//           .replaceAll("\r", "")
//           .replaceAll(" ", "");
//
//       print("🔧 Cleaned Base64 length: ${cleanBase64.length}");
//
//       final bytes = base64Decode(cleanBase64);
//       print("✅ Decoded successfully. Bytes: ${bytes.length}");
//
//       return MemoryImage(bytes);
//
//     } catch (e) {
//       print("❌ Error decoding Base64: $e");
//       return const AssetImage("assets/images/default_user.png");
//     }
//   }
//
//
//
//   @override
//   Widget build(BuildContext context) {
//     if (!_loadedPrefs) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       body: Stack(
//         children: [
//           Positioned.fill(
//             child: Image.asset("assets/images/main.png", fit: BoxFit.cover),
//           ),
//
//           // ------------ TOP HEADER ------------
//           Positioned(
//             top: 40,
//             left: 20,
//             right: 20,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 // CircleAvatar(
//                 //   radius: 40,
//                 //   backgroundImage: _decodeBase64(),
//                 // ),
//
//                 ClipOval(
//                   child: Image(
//                     image: _decodeBase64(),
//                     width: 80,
//                     height: 80,
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//
//                 Expanded(
//                   child: Column(
//                     children: [
//                       Text(
//                         // type == "doctor" ? "Dr. $name" : name,
//                         currentUser.type == "doctor"
//                             ? "Dr. ${currentUser.name}"
//                             : currentUser.name,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           fontSize: 20,
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Text(
//                         "Mob: ${currentUser.mobile}",
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           fontSize: 14,
//                           color: Colors.white70,
//                         ),
//                       )
//                     ],
//                   ),
//                 ),
//
//                 IconButton(
//                   icon: const Icon(Icons.logout, color: Colors.white),
//                   iconSize: 30,
//                   onPressed: _logout,
//                 )
//               ],
//             ),
//           ),
//
//           // ------------ MENU BUTTONS ------------
//           Padding(
//             padding: const EdgeInsets.only(top: 150),
//             child: Column(
//               children: [
//                 _menuButton("Test History", Icons.history, _onTestHistory),
//                 const SizedBox(height: 12),
//                 _menuButton("My Device   ", Icons.devices, _onMyDevice),
//                 const SizedBox(height: 12),
//                 _menuButton(
//                   // type == "doctor" ? "My Patient  " : "My Doctor   ",
//                   currentUser.type == "admin"
//                       ? "All Doctors"
//                       : currentUser.type == "doctor"
//                       ? "My Patient"
//                       : "My Doctor ",
//
//                   Icons.people,
//                   _onMyDoctor,
//                 ),
//                 const SizedBox(height: 12),
//                 _menuButton("My Profile   ", Icons.person, _onMyProfile),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ------------ GLASS BUTTON ------------
//   Widget _menuButton(String text, IconData icon, VoidCallback onTap) {
//     const double maxWidth = 260;
//
//     return Center(
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: maxWidth),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(18),
//           child: BackdropFilter(
//             filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//             child: InkWell(
//               onTap: onTap,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                     vertical: 14, horizontal: 20),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.20),
//                   borderRadius: BorderRadius.circular(18),
//                   border: Border.all(
//                     color: Colors.white.withOpacity(0.35),
//                   ),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(icon, color: Colors.white),
//                     const SizedBox(width: 12),
//                     Text(
//                       text,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 17,
//                       ),
//                     )
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ------------ MENU ACTIONS ------------
//   void _onTestHistory() {
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text("Open TestHistory")));
//     Navigator.push(
//       context,
//            MaterialPageRoute(builder: (_) => TesthistoryPage(
//                user: currentUser
//            )),
//
//
//     );
//   }
//
//   void _onMyDevice() {
//     print("OPEN MyDevice WITH MOBILE → ${currentUser.mobile} mobile");
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text("Open MyDevice  ${currentUser.mobile}")));
//     Navigator.push(
//       context,
//       // MaterialPageRoute(builder: (_) => BleScan()),
//       // MaterialPageRoute(builder: (_) => MyDevicesPage(userMobile: mobile)),
//       MaterialPageRoute(builder: (_) => MyDevicesPage2(user: currentUser)),
//
//       // MaterialPageRoute(builder: (_) => BLEPage()),
//
//
//     );
//
//   }
//
//   // void _onMyDoctor() {
//   //   Navigator.push(
//   //     context,
//   //     MaterialPageRoute(
//   //       builder: (_) => MyDoctorPage(user: currentUser
//   //       ),
//   //     ),
//   //   );
//   // }
//
//   void _onMyDoctor() {
//     Navigator.push<UserModel>(
//       context,
//       MaterialPageRoute(
//         builder: (_) => MyDoctorPage(
//           user: currentUser,
//         ),
//       ),
//     ).then((updatedUser) {
//       if (updatedUser != null && mounted) {
//         setState(() {
//           currentUser = updatedUser;
//         });
//       }
//     });
//   }
//
//
//
//   void _onMyProfile() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => MyProfileScreen(user: currentUser)),
//     ).then((_) async {
//       await _loadLocalPrefs();   // reload values
//       if (mounted) setState(() {}); // refresh UI
//     });
//   }
//   Future<void> _logout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.clear();
//
//     if (!mounted) return;
//     Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
//   }
// }

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'myprofile.dart';
import 'mydoctor.dart';
import 'myDevicesPage.dart';
import "testHistory.dart";
import 'user_model.dart';
import 'test_count_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  final Map<String, dynamic>? savedUserData;

  const HomeScreen({super.key, this.savedUserData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserModel? currentUser;
  DatabaseReference? testReqRef;

  @override
  void initState() {
    super.initState();
    if (widget.savedUserData != null) {
      _loadFromPassedData(widget.savedUserData!);
    } else {
      _loadLocalPrefs();
    }
  }

  // ---------------- LOAD USER ----------------
  Future<void> _loadLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    String mobile = prefs.getString("mobile") ?? "";
    String name = prefs.getString("name") ?? "";
    String age = prefs.getString("age") ?? "";
    String email = prefs.getString("email") ?? "";
    String address = prefs.getString("address") ?? "";
    String gender = prefs.getString("gender") ?? "";
    String imageBase64 = prefs.getString("imageBase64") ?? "";
    String type = prefs.getString("type") ?? "";
    String count = prefs.getString("count") ?? "0";

    String specialization = "";
    String clinicName = "";
    String disease = "";

    if (type == "doctor") {
      specialization = prefs.getString("specialization") ?? "";
      clinicName = prefs.getString("clinicName") ?? "";
      disease = "NA";
    } else {
      disease = prefs.getString("diseaseType") ?? "";
      specialization = "NA";
      clinicName = "NA";
    }

    currentUser = UserModel(
      mobile: mobile,
      name: name,
      age: age,
      gender: gender,
      address: address,
      disease: disease,
      type: type,
      email: email,
      imageBase64: imageBase64,
      clinicName: clinicName,
      specialization: specialization,
      count: count,
    );

    setState(() {});
    _startAutoCheck();
  }

  // ---------------- AUTO APPROVAL CHECK ----------------
  void _startAutoCheck() {
    if (currentUser == null || currentUser!.mobile.isEmpty) return;

    testReqRef = FirebaseDatabase.instance
        .ref("TestRequests")
        .child(currentUser!.mobile);

    testReqRef!.onValue.listen((event) {
      if (event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(
          event.snapshot.value as Map<dynamic, dynamic>);

      final status = data["st"] ?? "w";
      final oldCount = data["OC"] ?? "0";
      final totalCount = data["TC"] ?? "0";
      final totalAmount = data["TA"] ?? "0";

      if (status == "a") {
        _handleAutoApproval(
            oldCount.toString(), totalCount.toString(), totalAmount.toString());
      }
    });
  }

  Future<void> _handleAutoApproval(
      String oldCount, String totalCount, String totalAmount) async {
    if (currentUser == null) return;

    final doctorRef = FirebaseDatabase.instance
        .ref("users/doctor")
        .child(currentUser!.mobile)
        .child("count");

    await doctorRef.set(totalCount);

    final prefs = await SharedPreferences.getInstance();
    prefs.setString("count", totalCount);

    final historyRef =
    FirebaseDatabase.instance.ref("ApH").child(currentUser!.mobile);

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    await historyRef.child(id).set({
      "OC": oldCount,
      "TC": totalCount,
      "TA": totalAmount,
      "st": "a",
    });

    await testReqRef?.remove();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remaining Test Count"),
        content: Text(totalCount),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"))
        ],
      ),
    );
  }

  // ---------------- IMAGE DECODE ----------------
  ImageProvider _decodeBase64() {
    try {
      if (currentUser == null || currentUser!.imageBase64.isEmpty) {
        return const AssetImage("assets/images/default_user.png");
      }

      String cleanBase64 = currentUser!.imageBase64
          .replaceAll("\n", "")
          .replaceAll("\r", "")
          .replaceAll(" ", "");

      final bytes = base64Decode(cleanBase64);
      return MemoryImage(bytes);
    } catch (_) {
      return const AssetImage("assets/images/default_user.png");
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/main.png", fit: BoxFit.cover),
          ),

          // HEADER
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ClipOval(
                  child: Image(
                    image: _decodeBase64(),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        currentUser!.type == "doctor"
                            ? "Dr. ${currentUser!.name}"
                            : currentUser!.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Mob: ${currentUser!.mobile}",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      )
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                )
              ],
            ),
          ),

          // MENU
          Padding(
            padding: const EdgeInsets.only(top: 150),
            child: Column(
              children: [
                // _menuButton("Test History", Icons.history, _onTestHistory),
                currentUser!.type == "doctor"
                    ? _menuButton("Test Count's", Icons.account_balance_wallet, _onTestCount)
                    : _menuButton("Test History", Icons.history, _onTestHistory),
                const SizedBox(height: 12),
                _menuButton("My Device   ", Icons.devices, _onMyDevice),
                const SizedBox(height: 12),
                _menuButton(
                  currentUser!.type == "admin"
                      ? "All Doctors"
                      : currentUser!.type == "doctor"
                      ? "My Patient  "
                      : "My Doctor   ",
                  Icons.groups,
                  _onMyDoctor,
                ),
                const SizedBox(height: 12),
                _menuButton("My Profile   ", Icons.person, _onMyProfile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButton(String text, IconData icon, VoidCallback onTap) {
    return Center(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 17),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- NAVIGATION ----------------
  void _onTestHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TesthistoryPage(user: currentUser!),
      ),

    ).then((updatedUser) {
      if (updatedUser != null && mounted) {
        setState(() {
          currentUser = updatedUser;
        });
      }
    });
  }

  void _onMyDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyDevicesPage2(user: currentUser!),
      ),
    );
  }

  void _onMyDoctor() {
    Navigator.push<UserModel>(
      context,
      MaterialPageRoute(
        builder: (_) => MyDoctorPage(user: currentUser!),
      ),
    ).then((updatedUser) {
      if (updatedUser != null && mounted) {
        setState(() {
          currentUser = updatedUser;
        });
      }
    });
  }

  void _onMyProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyProfileScreen(user: currentUser!),
      ),
    ).then((_) async {
      await _loadLocalPrefs();
    });
  }

  // void _onTestCount() {
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: const Text("Remaining Test Count"),
  //       content: Text(currentUser!.count),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text("OK"),
  //         )
  //       ],
  //     ),
  //   );
  // }

  void _onTestCount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestCountScreen(user: currentUser!),
      ),
    );
  }
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
  }

  void _loadFromPassedData(Map<String, dynamic> data) {
    currentUser = UserModel(
      mobile: data['mobile'] ?? '',
      name: data['name'] ?? '',
      age: data['age'] ?? '',
      gender: data['gender'] ?? '',
      address: data['address'] ?? '',
      disease: data['disease'] ?? data['diseaseType'] ?? '',
      type: data['type'] ?? '',
      email: data['email'] ?? '',
      imageBase64: data['imageBase64'] ?? '',
      clinicName: data['clinicName'] ?? '',
      specialization: data['specialization'] ?? '',
      count: data['count'] ?? '0',
    );

    setState(() {});
    _startAutoCheck();
  }
}