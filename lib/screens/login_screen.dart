import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_service.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileCtl = TextEditingController();
  final _pwdCtl = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.getBool('isLoggedIn') ?? false;

    if (!logged) return;

    final mobile = prefs.getString('mobile') ?? '';
    if (mobile.isEmpty) return;

    final userMap = {
      'name': prefs.getString('name'),
      'age': prefs.getString('age'),
      'email': prefs.getString('email'),
      'address': prefs.getString('address'),
      'gender': prefs.getString('gender'),
      'imageBase64': prefs.getString('imageBase64'),
      'type': prefs.getString('type'),
      'count': prefs.getString('count'),
      'specialization': prefs.getString('specialization'),
      'clinicName': prefs.getString('clinicName'),
      'diseaseType': prefs.getString('diseaseType'),
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            savedUserData: {'mobile': mobile, ...userMap},
          ),
        ),
      );
    });
  }

  Future<void> _onLogin() async {
    final mobile = _mobileCtl.text.trim();
    final password = _pwdCtl.text.trim();

    if (mobile.length != 10) {
      _showError("Enter valid 10-digit mobile number");
      return;
    }
    if (password.isEmpty) {
      _showError("Password required");
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await _firebaseService.login(mobile, password);
      final node = result['node'] as String;
      final user = result['user'] as Map<String, String?>;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('mobile', mobile);
      await prefs.setString('password', password);

      await prefs.setString('name', user['name'] ?? '');
      await prefs.setString('age', user['age'] ?? '');
      await prefs.setString('email', user['email'] ?? '');
      await prefs.setString('address', user['address'] ?? '');
      await prefs.setString('gender', user['gender'] ?? '');
      await prefs.setString('imageBase64', user['imageBase64'] ?? '');
      await prefs.setString('type', node);
      await prefs.setString('count', user['count'] ?? '');

      if (node == 'doctor') {
        await prefs.setString('specialization', user['specialization'] ?? '');
        await prefs.setString('clinicName', user['clinicName'] ?? '');
      } else {
        await prefs.setString('diseaseType', user['disease'] ?? '');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            savedUserData: {'mobile': mobile, 'type': node, ...user},
          ),
        ),
      );
    } catch (e) {
      _showError(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isHolding = false;

  void _showSignUpDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                /// 🔐 Hidden Admin Trigger (3 sec hold)
                GestureDetector(
                  onLongPressStart: (_) async {
                    _isHolding = true;

                    await Future.delayed(const Duration(seconds: 2));

                    if (_isHolding) {
                      Navigator.pop(ctx);
                      _showAdminCodeDialog(); // extra protection
                    }
                  },
                  onLongPressEnd: (_) {
                    _isHolding = false;
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Choose Signup Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// 👇 Options
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.pushNamed(
                              context,
                              SignupScreen.routeName,
                              arguments: 'doctor',
                            );
                          },
                          child: _signupBox(
                            'Doctor',
                            Icons.medical_services,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.pushNamed(
                              context,
                              SignupScreen.routeName,
                              arguments: 'patient',
                            );
                          },
                          child: _signupBox(
                            'Patient',
                            Icons.person,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void _showSignUpDialog2() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Choose Signup Type',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, SignupScreen.routeName,
                              arguments: 'doctor');
                        },
                        child: _signupBox('Doctor', Icons.medical_services),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, SignupScreen.routeName,
                              arguments: 'patient');
                        },
                        child: _signupBox('Patient', Icons.person),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
  //
  // Widget _signupBox(String label) {
  //   return Container(
  //     padding: const EdgeInsets.all(14),
  //     alignment: Alignment.center,
  //     decoration: BoxDecoration(
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: Colors.grey.shade300),
  //     ),
  //     child: Text(label),
  //   );
  // }
  Widget _signupBox2(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signupBox(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  void _showForgotPasswordDialog() {
    final mobileCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final newPwdCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _dialogField(mobileCtl, 'Mobile (10 digits)', TextInputType.phone),
                _dialogField(emailCtl, 'Email', TextInputType.emailAddress),
                _dialogField(newPwdCtl, 'New Password', TextInputType.text,
                    obscure: true),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final m = mobileCtl.text.trim();
                final e = emailCtl.text.trim();
                final np = newPwdCtl.text.trim();

                if (m.length != 10) {
                  _showError('Enter valid 10-digit mobile');
                  return;
                }
                if (!e.contains('@')) {
                  _showError('Enter valid email');
                  return;
                }
                if (np.isEmpty) {
                  _showError('Enter new password');
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _loading = true);

                try {
                  await _firebaseService.resetPassword(m, e, np);
                  _showError('Password reset successfully');
                } catch (err) {
                  _showError(err.toString());
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: const Text('Reset'),
            )
          ],
        );
      },
    );
  }

  Widget _dialogField(TextEditingController c, String label,
      TextInputType type, {bool obscure = false}) {
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/login.png", fit: BoxFit.cover),
          ),

          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),

          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome Back",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Login to your account",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 36),

                    const Text("Mobile Number",
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 6),

                    _glassField(
                      child: TextField(
                        controller: _mobileCtl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        maxLength: 10,
                        decoration: InputDecoration(
                          counterText: "",
                          hintText: "Enter mobile number",
                          border: InputBorder.none,
                          hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.5)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text("Password",
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 6),

                    _glassField(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pwdCtl,
                              obscureText: !_showPassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Enter password",
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white,
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _showForgotPasswordDialog,
                        child: Text(
                          "Forgot password?",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: _loading ? null : _onLogin,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: _loading
                            ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ))
                            : const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _showSignUpDialog,
                          child: const Text(
                            "Sign up",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _glassField({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  void _showAdminCodeDialog() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Enter Admin Code"),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: "Secret Code",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text == "1811") {
                  Navigator.pop(ctx);

                  Navigator.pushNamed(
                    context,
                    SignupScreen.routeName,
                    arguments: 'admin',
                  );
                } else {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid Code")),
                  );
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
}
