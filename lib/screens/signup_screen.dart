import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';
import 'dart:ui';



class SignupScreen extends StatefulWidget {
  static const routeName = '/signup';

  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final dbRef = FirebaseDatabase.instance.ref("users");

  // Controllers
  final name = TextEditingController();
  final age = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final mobile = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final specialization = TextEditingController();
  final clinicName = TextEditingController();

  String userType = "patient";
  String gender = "";
  String disease = "NA";

  bool showPassword = false;
  bool showConfirmPassword = false;

  File? imageFile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args != null && args is String) {
      userType = args;
    }
  }

  // 📸 Pick image from camera
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);

    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }
//compressed image
  Future<String> convertImageToBase64(File file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: 50, // 🔥 reduce size (0–100)
    );

    if (result == null) return "";

    return base64Encode(result);
  }
  // 🔍 Auto-fill Doctor
  Future<void> checkDoctor(String mob) async {
    final snap = await dbRef.child("doctor/$mob").get();

    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);

      name.text = data["name"] ?? "";
      age.text = data["age"] ?? "";
      email.text = data["email"] ?? "";
      address.text = data["address"] ?? "";
      specialization.text = data["specialization"] ?? "";
      clinicName.text = data["clinicName"] ?? "";
      gender = data["gender"] ?? "";

      // ✅ IMAGE FIX
      if (data["imageBase64"] != null && data["imageBase64"] != "") {
        Uint8List bytes = base64Decode(data["imageBase64"]);

        final file = await _convertBytesToFile(bytes);

        setState(() {
          imageFile = file; // 👈 update UI properly
        });
      }
      setState(() {});
      showMsg("Doctor data loaded");
    }
  }



// 🔍 Auto-fill Patient
  Future<void> checkPatient(String mob) async {
    final snap = await dbRef.child("patient/$mob").get();

    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);

      name.text = data["name"] ?? "";
      age.text = data["age"] ?? "";
      email.text = data["email"] ?? "";
      address.text = data["address"] ?? "";
      // specialization.text = data["specialization"] ?? "";
      // clinicName.text = data["clinicName"] ?? "";
      gender = data["gender"] ?? "";
      disease = data["disease"] ?? "NA";

      // ✅ IMAGE FIX
      if (data["imageBase64"] != null && data["imageBase64"] != "") {
        Uint8List bytes = base64Decode(data["imageBase64"]);

        final file = await _convertBytesToFile(bytes);

        setState(() {
          imageFile = file; // 👈 update UI properly
        });
      }
      setState(() {});
      showMsg("Patient data loaded");
    }
  }

// 🔍 Auto-fill admin
  Future<void> checkAdmin(String mobile) async {
    // Your admin validation logic
      final snap = await dbRef.child("admin/$mobile").get();

      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.value as Map);

        name.text = data["name"] ?? "";
        age.text = data["age"] ?? "";
        email.text = data["email"] ?? "";
        address.text = data["address"] ?? "";
        // specialization.text = data["specialization"] ?? "";
        // clinicName.text = data["clinicName"] ?? "";
        gender = data["gender"] ?? "";


        // ✅ IMAGE FIX
        if (data["imageBase64"] != null && data["imageBase64"] != "") {
          Uint8List bytes = base64Decode(data["imageBase64"]);

          final file = await _convertBytesToFile(bytes);

          setState(() {
            imageFile = file; // 👈 update UI properly
          });
        }
        setState(() {});
        showMsg("Patient data loaded");
      }

    // Example:
    print("Checking admin: $mobile");

    // Navigate or verify admin
  }


  // 💾 Signup
  Future<void> signup() async {
    if (name.text.isEmpty ||
        age.text.isEmpty ||
        email.text.isEmpty ||
        address.text.isEmpty ||
        mobile.text.length != 10) {
      showMsg("Fill all fields correctly");
      return;
    }

    if (password.text.isEmpty) {
      showMsg("Password required");
      return;
    }

    if (password.text != confirmPassword.text) {
      showMsg("Passwords do not match");
      return;
    }

    if (imageFile == null) {
      showMsg("Select profile image");
      return;
    }

    // final bytes = await imageFile!.readAsBytes();
    // final imageBase64 = base64Encode(bytes);

    final imageBase64 = await convertImageToBase64(imageFile!);

    if (imageBase64.isEmpty) {
      showMsg("Image processing failed");
      return;
    }

    final userData = {
      "name": name.text,
      "age": age.text,
      "email": email.text,
      "address": address.text,
      "password": password.text,
      "imageBase64": imageBase64,
      "gender": gender,
      "type": userType,
      // "disease":disease,
      "verified":false,
    };

    if (userType == "doctor") {
      userData["specialization"] = specialization.text;
      userData["clinicName"] = clinicName.text;
      userData["availableTest"] = "0";
    } else if (userType == "patient") {
      userData["disease"] = disease;
    }

    final exist = await dbRef.child("$userType/${mobile.text}").get();

    if (exist.exists) {
      showMsg("User already exists");
      return;
    }

    // await dbRef.child("$userType/${mobile.text}").set(userData);

    await dbRef.child("$userType/${mobile.text}").set(userData).then((_) {
      print("DATA SAVED SUCCESS");
    }).catchError((e) {
      print("ERROR: $e");
    });
    showMsg("Signup successful");
    Navigator.pop(context);
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ✅ Full background
          Positioned.fill(
            child: Image.asset(
              "assets/images/main.png",
              fit: BoxFit.cover,
            ),
          ),

          // ✅ Light overlay (same as login)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ),

          // ✅ Content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const SizedBox(height: 50),
                    // ✅ Profile image
                    Center(
                      child: GestureDetector(
                        onTap: pickImage,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          backgroundImage:
                          imageFile != null ? FileImage(imageFile!) : null,
                          child: imageFile == null
                              ? const Icon(Icons.camera_alt,
                              color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            "Create Account",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // const SizedBox(height: 6),
                          Text(
                            "Register as ${userType.toUpperCase()}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Mobile
                    _label("Mobile Number"),
                    _glassField(
                      child: TextField(
                        controller: mobile,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("Enter mobile"),
                        onEditingComplete: () {
                          // if (mobile.text.length == 10) {
                          //   userType == "doctor"
                          //       ? checkDoctor(mobile.text)
                          //       : checkPatient(mobile.text);
                          // }
                          if (mobile.text.length == 10) {
                            if (userType == "doctor") {
                              checkDoctor(mobile.text);
                            } else if (userType == "patient") {
                              checkPatient(mobile.text);
                            } else if (userType == "admin") {
                              checkAdmin(mobile.text);
                            } else {
                              // fallback (optional)
                              print("Unknown user type");
                            }
                          }

                        },
                      ),
                    ),

                    _label("Name"),
                    _glassField(
                      child: TextField(
                        controller: name,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("Enter name"),
                      ),
                    ),

                    _label("Age"),
                    _glassField(
                      child: TextField(
                        controller: age,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("Enter age"),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _label("Gender"),
                    Wrap(
                      spacing: 10,
                      children: ["Male", "Female","Other"]
                          .map(
                            (e) => ChoiceChip(
                          label: Text(e),
                          selected: gender == e,
                          selectedColor: Colors.white.withOpacity(0.3),
                          backgroundColor: Colors.white.withOpacity(0.1),
                          labelStyle: const TextStyle(color: Colors.black),
                          onSelected: (_) => setState(() => gender = e),
                        ),
                      )
                          .toList(),
                    ),
                    // Patient chips
                    if (userType == "patient")...[
                      _label("Disease"),
                      Wrap(
                        spacing: 8,
                        children: ["DM", "HTN", "PREG", "OTH"]
                            .map((e) => ChoiceChip(
                          label: Text(e),
                          selected: disease == e,
                          onSelected: (_) =>
                              setState(() => disease = e),
                        ))
                            .toList(),
                      ),
                    ],
                    // Doctor fields
                    if (userType == "doctor") ...[
                      _label("Specialization"),
                      _glassField(
                        child: TextField(
                          controller: specialization,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                          _inputDecoration("Enter specialization"),
                        ),
                      ),

                      _label("Clinic Name"),
                      _glassField(
                        child: TextField(
                          controller: clinicName,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                          _inputDecoration("Enter clinic"),
                        ),
                      ),
                    ],

                    _label("Address"),
                    _glassField(
                      child: TextField(
                        controller: address,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("Enter address"),
                      ),
                    ),

                    _label("Email"),
                    _glassField(
                      child: TextField(
                        controller: email,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("Enter email"),
                      ),
                    ),

                    _label("Password"),
                    _glassField(
                      child: TextField(
                        controller: password,
                        obscureText: !showPassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("Enter password")
                            .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white,
                            ),
                            onPressed: () => setState(
                                    () => showPassword = !showPassword),
                          ),
                        ),
                      ),
                    ),

                    _label("Confirm Password"),
                    _glassField(
                      child: TextField(
                        controller: confirmPassword,
                        obscureText: !showConfirmPassword,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                        _inputDecoration("Confirm password")
                            .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              showConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white,
                            ),
                            onPressed: () => setState(() =>
                            showConfirmPassword =
                            !showConfirmPassword),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Button
                    GestureDetector(
                      onTap: signup,
                      child: Container(
                        width: double.infinity,
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassField({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: InputBorder.none,
      counterText: "",
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }
  // // UI
  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     body: Stack(
  //       children: [
  //         Positioned.fill(
  //           child: SizedBox.expand(
  //             child: Stack(
  //               children: [
  //                 Image.asset(
  //                   "assets/images/main.png",
  //                   fit: BoxFit.cover,
  //                 ),
  //
  //                 // 👇 50% dark overlay
  //                 // Container(
  //                 //   color: Colors.black.withOpacity(0.5),
  //                 // ),
  //               ],
  //             ),
  //           ),
  //         ),
  //
  //         // Center(
  //         //   child: Card(
  //         //     margin: const EdgeInsets.all(20),
  //         //     shape: RoundedRectangleBorder(
  //         //         borderRadius: BorderRadius.circular(20)),
  //         //     child: SingleChildScrollView(
  //         //       padding: const EdgeInsets.all(16),
  //         //       child: Column(
  //         //         children: [
  //         //           const Text("Sign Up",
  //         //               style: TextStyle(
  //         //                   fontSize: 20, fontWeight: FontWeight.bold)),
  //         //
  //         //           const SizedBox(height: 10),
  //         //
  //         //           GestureDetector(
  //         //             onTap: pickImage,
  //         //             child: CircleAvatar(
  //         //               radius: 30,
  //         //               backgroundImage:
  //         //               imageFile != null ? FileImage(imageFile!) : null,
  //         //               child: imageFile == null
  //         //                   ? const Icon(Icons.person)
  //         //                   : null,
  //         //             ),
  //         //           ),
  //         //
  //         //           const SizedBox(height: 10),
  //         //
  //         //           textField(mobile, "Mobile", isNumber: true,
  //         //               onBlur: () {
  //         //                 if (mobile.text.length == 10) {
  //         //                   if (userType == "doctor") {
  //         //                     checkDoctor(mobile.text);
  //         //                   } else {
  //         //                     checkPatient(mobile.text);
  //         //                   }
  //         //                 }
  //         //               }),
  //         //
  //         //           textField(name, "Name"),
  //         //           textField(age, "Age", isNumber: true),
  //         //
  //         //           // Gender
  //         //           Row(
  //         //             children: [
  //         //               const Text("Gender"),
  //         //               Radio(
  //         //                   value: "Male",
  //         //                   groupValue: gender,
  //         //                   onChanged: (v) =>
  //         //                       setState(() => gender = v!)),
  //         //               const Text("Male"),
  //         //               Radio(
  //         //                   value: "Female",
  //         //                   groupValue: gender,
  //         //                   onChanged: (v) =>
  //         //                       setState(() => gender = v!)),
  //         //               const Text("Female"),
  //         //             ],
  //         //           ),
  //         //
  //         //           if (userType == "patient")
  //         //             Wrap(
  //         //               spacing: 8,
  //         //               children: ["DM", "HTN", "PREG", "OTH"]
  //         //                   .map((e) => ChoiceChip(
  //         //                 label: Text(e),
  //         //                 selected: disease == e,
  //         //                 onSelected: (_) =>
  //         //                     setState(() => disease = e),
  //         //               ))
  //         //                   .toList(),
  //         //             ),
  //         //
  //         //           if (userType == "doctor") ...[
  //         //             textField(specialization, "Specialization"),
  //         //             textField(clinicName, "Clinic Name"),
  //         //           ],
  //         //
  //         //           textField(address, "Address"),
  //         //           textField(email, "Email"),
  //         //
  //         //           passwordField(password, "Password", showPassword,
  //         //                   () => setState(() => showPassword = !showPassword)),
  //         //
  //         //           passwordField(
  //         //               confirmPassword,
  //         //               "Confirm Password",
  //         //               showConfirmPassword,
  //         //                   () => setState(
  //         //                       () => showConfirmPassword = !showConfirmPassword)),
  //         //
  //         //           const SizedBox(height: 20),
  //         //
  //         //           ElevatedButton(
  //         //             onPressed: signup,
  //         //             child: const Text("SIGN UP"),
  //         //           ),
  //         //         ],
  //         //       ),
  //         //     ),
  //         //   ),
  //         // )
  //         Center(
  //           child: ClipRRect(
  //             borderRadius: BorderRadius.circular(25),
  //             child: BackdropFilter(
  //               filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
  //               child: Container(
  //                 margin: const EdgeInsets.all(25),
  //                 padding: const EdgeInsets.all(16),
  //                 decoration: BoxDecoration(
  //                   borderRadius: BorderRadius.circular(20),
  //                   color: Colors.white.withOpacity(0.15), // 🔥 glass effect
  //                   border: Border.all(
  //                     color: Colors.white.withOpacity(0.3),
  //                   ),
  //                 ),
  //                 child: SingleChildScrollView(
  //                   child: Column(
  //                     children: [
  //                       const Text(
  //                         "Sign Up",
  //                         style: TextStyle(
  //                           fontSize: 22,
  //                           fontWeight: FontWeight.bold,
  //                           color: Colors.white, // 👈 important
  //                         ),
  //                       ),
  //
  //                       const SizedBox(height: 15),
  //
  //                       GestureDetector(
  //                         onTap: pickImage,
  //                         child: CircleAvatar(
  //                           radius: 35,
  //                           backgroundColor: Colors.white.withOpacity(0.3),
  //                           backgroundImage:
  //                           imageFile != null ? FileImage(imageFile!) : null,
  //                           child: imageFile == null
  //                               ? const Icon(Icons.person, color: Colors.white)
  //                               : null,
  //                         ),
  //                       ),
  //
  //                       const SizedBox(height: 15),
  //
  //                       textField(mobile, "Mobile", isNumber: true, onBlur: () {
  //                         if (mobile.text.length == 10) {
  //                           if (userType == "doctor") {
  //                             checkDoctor(mobile.text);
  //                           } else {
  //                             checkPatient(mobile.text);
  //                           }
  //                         }
  //                       }),
  //
  //                       textField(name, "Name"),
  //                       textField(age, "Age", isNumber: true),
  //
  //                       Row(
  //                         children: [
  //                           const Text("Gender", style: TextStyle(color: Colors.white)),
  //                           Radio(
  //                               value: "Male",
  //                               groupValue: gender,
  //                               onChanged: (v) =>
  //                                   setState(() => gender = v!)),
  //                           const Text("Male", style: TextStyle(color: Colors.white)),
  //                           Radio(
  //                               value: "Female",
  //                               groupValue: gender,
  //                               onChanged: (v) =>
  //                                   setState(() => gender = v!)),
  //                           const Text("Female", style: TextStyle(color: Colors.white)),
  //                         ],
  //                       ),
  //
  //                       if (userType == "patient")
  //
  //                         Wrap(
  //                           spacing: 8,
  //                           children: ["DM", "HTN", "PREG", "OTH"]
  //                               .map((e) => ChoiceChip(
  //                             label: Text(e),
  //                             selected: disease == e,
  //                             onSelected: (_) =>
  //                                 setState(() => disease = e),
  //                           ))
  //                               .toList(),
  //                         ),
  //
  //                       if (userType == "doctor") ...[
  //                         textField(specialization, "Specialization"),
  //                         textField(clinicName, "Clinic Name"),
  //                       ],
  //
  //                       textField(address, "Address"),
  //                       textField(email, "Email"),
  //
  //                       passwordField(password, "Password", showPassword,
  //                               () => setState(() => showPassword = !showPassword)),
  //
  //                       passwordField(
  //                           confirmPassword,
  //                           "Confirm Password",
  //                           showConfirmPassword,
  //                               () => setState(() =>
  //                           showConfirmPassword = !showConfirmPassword)),
  //
  //                       const SizedBox(height: 20),
  //
  //                       ElevatedButton(
  //                         style: ElevatedButton.styleFrom(
  //                           backgroundColor: Colors.white.withOpacity(0.3),
  //                           foregroundColor: Colors.white,
  //                           shape: RoundedRectangleBorder(
  //                             borderRadius: BorderRadius.circular(15),
  //                           ),
  //                         ),
  //                         onPressed: signup,
  //                         child: const Text("SIGN UP"),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ),
  //         )
  //       ],
  //     ),
  //   );
  // }

  // Widget textField(TextEditingController c, String hint,
  //     {bool isNumber = false, VoidCallback? onBlur}) {
  //   return Padding(
  //     padding: const EdgeInsets.only(top: 10),
  //     child: Focus(
  //       onFocusChange: (hasFocus) {
  //         if (!hasFocus && onBlur != null) onBlur();
  //       },
  //       child: TextField(
  //         controller: c,
  //         keyboardType:
  //         isNumber ? TextInputType.number : TextInputType.text,
  //         decoration: InputDecoration(
  //             labelText: hint, border: OutlineInputBorder()),
  //       ),
  //     ),
  //   );
  // }
  Widget textField(
      TextEditingController c,
      String hint, {
        bool isNumber = false,
        VoidCallback? onBlur,
      }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus && onBlur != null) onBlur();
        },
        child: TextField(
          controller: c,
          keyboardType:
          isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white),

          cursorColor: Colors.white,

          decoration: InputDecoration(
            labelText: hint,
            labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.9),
            ),

            filled: true,
            fillColor: Colors.white.withOpacity(0.15),

            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.4),
              ),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.white,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
  // Widget passwordField(TextEditingController c, String hint,
  //     bool visible, VoidCallback toggle) {
  //   return Padding(
  //     padding: const EdgeInsets.only(top: 10),
  //     child: TextField(
  //       controller: c,
  //       obscureText: !visible,
  //       decoration: InputDecoration(
  //         labelText: hint,
  //         border: const OutlineInputBorder(),
  //         suffixIcon: IconButton(
  //           icon: Icon(
  //               visible ? Icons.visibility : Icons.visibility_off),
  //           onPressed: toggle,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget passwordField(
      TextEditingController c,
      String hint,
      bool visible,
      VoidCallback toggle,
      ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: c,
        obscureText: !visible,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,

        decoration: InputDecoration(
          labelText: hint,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.9),
          ),

          filled: true,
          fillColor: Colors.white.withOpacity(0.15),

          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.4),
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.white,
              width: 1.5,
            ),
          ),

          suffixIcon: IconButton(
            icon: Icon(
              visible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
            ),
            onPressed: toggle,
          ),
        ),
      ),
    );
  }
  Future<File> _convertBytesToFile(Uint8List bytes) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/temp_img.jpg');
    await file.writeAsBytes(bytes);
    return file;
  }
}