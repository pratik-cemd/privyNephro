import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'myprofile.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'myDevicesPage.dart';
import "testHistory.dart";
import 'user_model.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'test_count_screen.dart';

class MyDoctorPage extends StatefulWidget {
  final UserModel user;
  final String? allDoctorsType;
  const MyDoctorPage({
    super.key,
    required this.user,
    this.allDoctorsType,
  });
  static const routeName = '/myDoctor';
  @override
  State<MyDoctorPage> createState() => _MyDoctorPageState();
}
class _MyDoctorPageState extends State<MyDoctorPage> {
  List<Map<String, String>> doctorList = []; // patient -> doctors
  List<Map<String, String>> patientList = []; // doctor -> patients
  List<Map<String, String>> allDoctorList = []; // admin -> all doctors
  List<Map<String, String>> allPatientList = []; // admin -> all patients

  StreamSubscription<DatabaseEvent>? _subscription;

  bool _loading = true;

  String? selectedPatientKey;

  @override
  void initState() {
    super.initState();
    _loadPageLogic();
  }

  void _loadPageLogic() {
    final type = widget.user.type.toLowerCase();
    final allFlag = widget.allDoctorsType?.toLowerCase() ?? "";

    _subscription?.cancel();

    setState(() {
      _loading = true;
    });

    if (type == "doctor") {
      _listenPatients(widget.user.mobile);
    }
    else if (type == "admin") {
      if (allFlag == "aalldoct") {
        _listenAllDoctors();
      } else {
        _listenAllPatients();
      }
    } else {
      _listenDoctorsForPatient(widget.user.mobile);
    }
  }

  void _listenDoctorsForPatient(String patientNumber) {
    final ref = FirebaseDatabase.instance.ref("users/doctor");

    _subscription = ref.onValue.listen((event) {
      doctorList.clear();

      final snapshot = event.snapshot;

      for (var doc in snapshot.children) {
        if (doc.child("patients/$patientNumber").exists) {
          final val = doc.child("patients/$patientNumber").value;
          final isTrue = (val is bool)
              ? val
              : (val?.toString().toLowerCase() == 'true');

          if (isTrue == true) {
            doctorList.add({
              "name": "Dr. ${(doc.child("name").value ?? "").toString().toUpperCase()}",
              "mobile": doc.key ?? "",
              "detailLeft": (doc.child("specialization").value ?? "N/A")
                  .toString()
                  .toUpperCase(),
              "detailRight": (doc.child("clinicName").value ?? "N/A").toString(),
            });
          }
        }
      }

      setState(() {
        _loading = false;
      });
    });
  }

  void _listenPatients(String doctorNumber) {
    final ref = FirebaseDatabase.instance
        .ref("users/doctor/$doctorNumber/patients");

    _subscription = ref.onValue.listen((event) async {
      patientList.clear();

      if (!event.snapshot.exists) {
        setState(() {
          _loading = false;
        });
        return;
      }

      for (var p in event.snapshot.children) {
        final val = p.value;
        final active = (val is bool)
            ? val
            : (val?.toString().toLowerCase() == 'true');

        final mobile = p.key ?? "";

        if (active == true && mobile.isNotEmpty) {
          final snap = await FirebaseDatabase.instance
              .ref("users/patient/$mobile")
              .get();

          patientList.add({
            "name": (snap.child("name").value ?? "")
                .toString()
                .toUpperCase(),
            "mobile": mobile,
            "detailLeft": (snap.child("disease").value ?? "N/A")
                .toString()
                .toUpperCase(),
            "detailRight":
            "age${snap.child("age").value ?? ""}",
          });
        }
      }

      setState(() {
        _loading = false;
      });
    });
  }
  void _listenAllDoctors() {
    final ref = FirebaseDatabase.instance.ref("users/doctor");

    _subscription = ref.onValue.listen((event) {
      allDoctorList.clear();

      for (var d in event.snapshot.children) {
        allDoctorList.add({
          "name": "Dr. ${(d.child("name").value ?? "").toString().toUpperCase()}",
          "mobile": d.key ?? "",
          "detailLeft": (d.child("specialization").value ?? "N/A")
              .toString()
              .toUpperCase(),
          "detailRight": (d.child("clinicName").value ?? "N/A").toString(),
        });
      }

      setState(() {
        _loading = false;
      });
    });
  }
  void _listenAllPatients() {
    final ref = FirebaseDatabase.instance.ref("users/patient");

    _subscription = ref.onValue.listen((event) {
      allPatientList.clear();

      for (var p in event.snapshot.children) {
        allPatientList.add({
          "name": (p.child("name").value ?? "")
              .toString()
              .toUpperCase(),
          "mobile": p.key ?? "",
          "detailLeft": (p.child("disease").value ?? "N/A")
              .toString()
              .toUpperCase(),
          "detailRight": (p.child("address").value ?? "")
              .toString(),
        });
      }

      setState(() {
        _loading = false;
      });
    });
  }
  // ----------------------------
  // 1) Patient -> Doctors
  // ----------------------------
  // Future<void> _findDoctorsForPatient(String patientNumber) async {
  //   try {
  //     final ref = FirebaseDatabase.instance.ref("users/doctor");
  //     final snapshot = await ref.get();
  //
  //     doctorList.clear();
  //
  //     for (var doc in snapshot.children) {
  //       // check existence and truthiness
  //       if (doc.child("patients/$patientNumber").exists) {
  //         final val = doc.child("patients/$patientNumber").value;
  //         final isTrue = (val is bool) ? val : (val?.toString().toLowerCase() == 'true');
  //         if (isTrue == true) {
  //           final doctorMobile = doc.key?.toString() ?? "";
  //           final name = doc.child("name").value?.toString() ?? "";
  //           final specialization = doc.child("specialization").value?.toString() ?? "N/A";
  //           final clinicName = doc.child("clinicName").value?.toString() ?? "N/A";
  //
  //           doctorList.add({
  //             "name": "Dr. ${name.toUpperCase()}",
  //             "mobile": doctorMobile,
  //             "detailLeft": specialization.toUpperCase(),
  //             "detailRight": clinicName,
  //           });
  //
  //           // original Java breaks after first match — keep same behavior
  //           break;
  //         }
  //       }
  //     }
  //   } catch (e, st) {
  //     // ignore: avoid_print
  //     print("Error in _findDoctorsForPatient: $e\n$st");
  //   } finally {
  //     setState(() {});
  //   }
  // }
  //
  // // ----------------------------
  // // 2) Doctor -> Patients
  // // ----------------------------
  // Future<void> _findPatients(String doctorNumber) async {
  //   try {
  //     final ref = FirebaseDatabase.instance.ref("users/doctor/$doctorNumber/patients");
  //     final snapshot = await ref.get();
  //
  //     patientList.clear();
  //
  //     if (!snapshot.exists) {
  //       // nothing linked
  //       setState(() {});
  //       return;
  //     }
  //
  //     for (var p in snapshot.children) {
  //       final val = p.value;
  //       final active = (val is bool) ? val : (val?.toString().toLowerCase() == 'true');
  //       final mobile = p.key?.toString() ?? "";
  //
  //       if (active == true && mobile.isNotEmpty) {
  //         final snap = await FirebaseDatabase.instance.ref("users/patient/$mobile").get();
  //
  //         final name = snap.child("name").value?.toString() ?? "";
  //         final disease = snap.child("disease").value?.toString() ?? "N/A";
  //         final age = snap.child("age").value?.toString() ?? "";
  //         final address = snap.child("address").value?.toString() ?? "";
  //
  //         // show age on right if present, otherwise truncated address
  //         final right = age.isNotEmpty ? age : (address.length > 20 ? "${address.substring(0, 20)}..." : address);
  //
  //         patientList.add({
  //           "name": name.toUpperCase(),
  //           "mobile": mobile,
  //           "detailLeft": disease.toUpperCase(),
  //           "detailRight": right,
  //         });
  //       }
  //     }
  //   } catch (e, st) {
  //     // ignore: avoid_print
  //     print("Error in _findPatients: $e\n$st");
  //   } finally {
  //     setState(() {});
  //   }
  // }

  // ----------------------------
  // 3) Admin -> All Doctors
  // ----------------------------
  // Future<void> _findAllDoctors() async {
  //   try {
  //     final ref = FirebaseDatabase.instance.ref("users/doctor");
  //     final snapshot = await ref.get();
  //
  //     allDoctorList.clear();
  //
  //     for (var d in snapshot.children) {
  //       final mobile = d.key?.toString() ?? "";
  //       final name = d.child("name").value?.toString() ?? "";
  //       final spec = d.child("specialization").value?.toString() ?? "N/A";
  //       final clinic = d.child("clinicName").value?.toString() ?? "N/A";
  //
  //       allDoctorList.add({
  //         "name": "Dr. ${name.toUpperCase()}",
  //         "mobile": mobile,
  //         "detailLeft": spec.toUpperCase(),
  //         "detailRight": clinic,
  //       });
  //     }
  //   } catch (e, st) {
  //     // ignore: avoid_print
  //     print("Error in _findAllDoctors: $e\n$st");
  //   } finally {
  //     setState(() {});
  //   }
  // }

  // ----------------------------
  // 4) Admin -> All Patients
  // ----------------------------
  Future<void> _findAllPatients() async {
    try {
      final ref = FirebaseDatabase.instance.ref("users/patient");
      final snapshot = await ref.get();

      allPatientList.clear();

      for (var p in snapshot.children) {
        final mobile = p.key?.toString() ?? "";
        final name = p.child("name").value?.toString() ?? "";
        final disease = p.child("disease").value?.toString() ?? "N/A";
        final address = p.child("address").value?.toString() ?? "";

        final trimmed = address.length > 20 ? "${address.substring(0, 20)}..." : address;

        allPatientList.add({
          "name": name.toUpperCase(),
          "mobile": mobile,
          "detailLeft": disease.toUpperCase(),
          "detailRight": trimmed,
        });
      }
    } catch (e, st) {
      // ignore: avoid_print
      print("Error in _findAllPatients: $e\n$st");
    } finally {
      setState(() {});
    }
  }

  // ----------------------------
  // choose which list to show
  // ----------------------------
  List<Map<String, String>> currentList() {
    final type = widget.user.type.toLowerCase();
    final allFlag = widget.allDoctorsType?.toLowerCase() ?? "";

    if (type == "doctor") return patientList;
    if (type == "admin" && allFlag == "aalldoct") return allDoctorList;
    if (type == "admin" && allFlag == "aallpst") return allPatientList;
    return doctorList;
  }

  // ----------------------------
  // dynamic details for second row
  // ----------------------------
  String _leftDetail(Map<String, String> item) {
    return item["detailLeft"] ?? item["spec"] ?? "";
  }

  String _rightDetail(Map<String, String> item) {
    return item["detailRight"] ?? item["clinic"] ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = widget.user.type == "doctor";

    final historyTitle = isDoctor ? "Test Count’s" : "Test History";
    final historyIcon = isDoctor ? Icons.account_balance_wallet : Icons.history;

    void showUserDetails() {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("User Details"),
          content: Text(
            "Name: ${widget.user.name}\n"
                "Mobile: ${widget.user.mobile}\n"
                "Type: ${widget.user.type}",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    }

    final type = widget.user.type.toLowerCase();
    final allFlag = widget.allDoctorsType?.toLowerCase() ?? "";
// -------- Cleaner Page Title Logic --------
    final pageTitle = type == "doctor"
        ? "My Patients"
        : type == "admin"
        ? (allFlag == "aalldoct" ? "All Doctors" : "All Patients")
        : "My Doctors";

    final list = currentList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.menu, color: Colors.white),
          offset: const Offset(0, 40), // adjust this value

          onSelected: (value) {
            if (value == "home") {
              Navigator.pushNamed(context, "/home");
            }
            // else if (value == "history") {
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(
            //       builder: (_) => TesthistoryPage(
            //         user:widget.user,
            //       ),
            //     ),
            //   );
            // }
            else if (value == "history") {
              if (widget.user.type == "doctor") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TestCountScreen(user: widget.user),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TesthistoryPage(user: widget.user),
                  ),
                );
              }
            }
            else if (value == "device") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyDevicesPage2(
                      user: widget.user
                  ),
                ),
              );
            }
            else if (value == "profile") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyProfileScreen(user: widget.user),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: "home",
              child: Row(
                children: [
                  Icon(Icons.home, color: Colors.black),
                  SizedBox(width: 8),
                  Text("Home", style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
            // PopupMenuItem(
            //   value: "history",
            //   child: Row(
            //     children: [
            //       Icon(Icons.history, color: Colors.black),
            //       SizedBox(width: 8),
            //       Text("Test History", style: TextStyle(color: Colors.black)),
            //     ],
            //   ),
            // ),
            PopupMenuItem(
              value: "history",
              child: Row(
                children: [
                  Icon(historyIcon, color: Colors.black),
                  const SizedBox(width: 8),
                   Text(historyTitle,
                      style: const TextStyle(color: Colors.black)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: "device",
              child: Row(
                children: [
                  Icon(Icons.devices, color: Colors.black),
                  SizedBox(width: 8),
                  Text("My Device", style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: "profile",
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.black),
                  SizedBox(width: 8),
                  Text("My Profile", style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
          ],
        ),
        title: Text(
          pageTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info, color: Colors.white),
            // onPressed: _showUserDetails,
            onPressed:() {
              if (type == "doctor") {
                _showPatientSelection();
            } else {
              showUserDetails();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/main.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                ? Center(
              child: Text(
                type == "doctor"
                    ? "No patients found"
                    : type == "admin"
                    ? (allFlag == "aalldoct"
                    ? "No doctors found"
                    : "No patients found")
                    : "No doctors found",
                style: const TextStyle(
                    color: Colors.white70, fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, index) {
                final item = list[index];
                return InkWell(
                    onTap: type == "doctor"
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TesthistoryPage(
                            user: widget.user,
                            patientMobile: item["mobile"], // pass patient mobile
                          ),
                        ),
                      );
                    }
                        : null,
                    onLongPress: type == "doctor"
                        ? () {
                      _showPatientDetailsDialog(item["mobile"]!);
                    }
                        : null,
                    child: Card(
                  margin:const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                item["name"] ?? "",
                                style: const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow:
                                TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: Text(
                                item["mobile"] ?? "",
                                textAlign:
                                TextAlign.end,
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow:
                                TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                _leftDetail(item),
                                overflow:
                                TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: Text(
                                _rightDetail(item),
                                textAlign:
                                TextAlign.end,
                                overflow:
                                TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () {
          if (type == "doctor") {
            // showSearchPatientDialog(context, widget.mobile);
            showSearchPatientDialog(context, widget.user.mobile).then((value) {
              if (value == true) {
                setState(() {
                  _loading = true;
                });
                _loadPageLogic();
              }
            });

          } else if (type == "admin") {
            if (allFlag == "aalldoct") {
              findAllDoctors();
            } else if (allFlag == "aallpst") {
              _findAllPatients();
            }
          } else {
            // showSearchDoctorDialog(context, widget.mobile);
            showSearchDoctorDialog(context, widget.user.mobile).then((value) {
              if (value == true) {
                setState(() {
                  _loading = true;
                });
                _loadPageLogic();
              }
            });
          }
        },
      ),
    );
  }
   //Search Patient Dialog
  Future<bool?> showSearchPatientDialog(BuildContext context, String mobileNumber)  async {
    final TextEditingController mobileController = TextEditingController();
    Map<String, dynamic>? patientData;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Patient by Mobile"),
          content: StatefulBuilder(
            builder: (BuildContext context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: "Enter patient mobile",
                        counterText: "",
                      ),
                    ),
                    SizedBox(height: 10),

                    if (patientData != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Name: ${patientData!['name']}"),
                          Text("Disease: ${patientData!['disease']}"),
                          Text("Gender: ${patientData!['gender']}"),
                          Text("Email: ${patientData!['email']}"),
                          Text("Address: ${patientData!['address']}"),
                        ],
                      ),

                    SizedBox(height: 15),

                    ElevatedButton(
                      onPressed: () async {
                        final mobile = mobileController.text.trim();
                        if (mobile.isEmpty) return;

                        final ref = FirebaseDatabase.instance
                            .ref("users/patient/$mobile");

                        final snapshot = await ref.get();

                        if (snapshot.exists) {
                          setState(() {
                            patientData =
                            Map<String, dynamic>.from(snapshot.value as Map);
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Patient not found")),
                          );
                        }
                      },
                      child: Text("Search"),
                    ),

                    if (patientData != null)
                      ElevatedButton(
                        onPressed: () async {
                          await FirebaseDatabase.instance
                              .ref("users/doctor/$mobileNumber/patients/${mobileController.text}")
                              .set(true);
                          // Navigator.pop(context);
                          Navigator.pop(context, true);
                        },
                        child: Text("Add Patient"),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
  //Find All Doctors
  Future<void> findAllDoctors() async {
    final ref = FirebaseDatabase.instance.ref("users/doctor");
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      print("No doctors found");
      return;
    }

    final doctors = snapshot.children.map((doc) {
      return {
        "mobile": doc.key,
        "name": doc.child("name").value,
        "specialization": doc.child("specialization").value,
        "clinicName": doc.child("clinicName").value,
        "address": doc.child("address").value,
      };
    }).toList();

    // setState(() {
    //   doctorList = doctors;
    // });
  }

  Future<bool?> showSearchDoctorDialog(BuildContext context, String patientMobile) async {
    final TextEditingController controller = TextEditingController();
    Map<String, dynamic>? doctorData;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Search Doctor"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: "Enter Doctor Mobile",
                        counterText: "",
                      ),
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: () async {
                        final mobile = controller.text.trim();
                        if (mobile.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Enter valid 10 digit mobile number"),
                            ),
                          );
                          return;
                        }

                        // if (mobile.isEmpty) return;

                        final ref = FirebaseDatabase.instance
                            .ref("users/doctor/$mobile");

                        final snapshot = await ref.get();

                        if (snapshot.exists) {
                          setStateDialog(() {
                            doctorData = Map<String, dynamic>.from(
                                snapshot.value as Map);
                          });
                        } else {
                          doctorData = null;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Doctor not found")),
                          );
                        }
                      },
                      child: const Text("Search"),
                    ),

                    const SizedBox(height: 12),

                    if (doctorData != null) ...[
                      Text("Name: ${doctorData!['name']}"),
                      Text("Specialization: ${doctorData!['specialization']}"),
                      Text("Clinic: ${doctorData!['clinicName']}"),
                      Text("Email: ${doctorData!['email']}"),
                      Text("Address: ${doctorData!['address']}"),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: () async {
                          final doctorMobile = controller.text.trim();

                          await FirebaseDatabase.instance
                              .ref("users/doctor/$doctorMobile/patients/$patientMobile")
                              .set(true);

                          Navigator.pop(context,true);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Doctor added successfully")),
                          );
                        },
                        child: const Text("Add Doctor"),
                      ),
                    ],

                    if (doctorData == null)
                      ElevatedButton(
                        onPressed: () {
                          final mobile = controller.text.trim();

                          if (mobile.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Enter valid 10 digit mobile number"),
                              ),
                            );
                            return;
                          }

                          // Navigator.pop(context);
                          Navigator.pop(context, true);
                          Navigator.pushNamed(
                            context,
                            "/signup",
                            arguments: {
                              "userType": "doctor",
                              "mobile": controller.text.trim(),
                            },
                          );
                        },
                        child: const Text("Create Doctor Profile"),
                      )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _showPatientSelection() {
    if (patientList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No patients available")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const Text(
                "Select Patient",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              ListView.builder(
                shrinkWrap: true,
                itemCount: patientList.length,
                itemBuilder: (context, index) {

                  final patient = patientList[index];
                  final mobile = patient["mobile"];

                  return FutureBuilder<DataSnapshot>(
                    future: FirebaseDatabase.instance
                        .ref("users/patient/$mobile")
                        .get(),
                    builder: (context, snapshot) {

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const SizedBox();
                      }

                      final data = Map<String, dynamic>.from(
                          snapshot.data!.value as Map);

                      final name = data["name"] ?? "";
                      final imageBase64 =
                          data["imageBase64"]?.toString() ?? "";

                      Widget avatar;

                      try {
                        if (imageBase64.isNotEmpty) {

                          String cleaned = imageBase64.trim();

                          if (cleaned.contains(',')) {
                            cleaned = cleaned.split(',').last;
                          }

                          cleaned = cleaned
                              .replaceAll('\n', '')
                              .replaceAll('\r', '')
                              .replaceAll(' ', '');

                          final bytes = base64Decode(cleaned);

                          avatar = CircleAvatar(
                            radius: 22,
                            backgroundImage: MemoryImage(bytes),
                          );
                        } else {
                          avatar = const CircleAvatar(
                            radius: 22,
                            child: Icon(Icons.person),
                          );
                        }
                      } catch (e) {
                        avatar = const CircleAvatar(
                          radius: 22,
                          child: Icon(Icons.person),
                        );
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(context);
                          _checkActiveDevicesAndProceed(mobile);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(12),
                            color: Colors.grey.shade100,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [

                              avatar,
                              const SizedBox(width: 15),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [

                                    Text(
                                      name,
                                      style:
                                      const TextStyle(
                                        fontWeight:
                                        FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      mobile!,
                                      style: TextStyle(
                                        color:
                                        Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkActiveDevicesAndProceed(String patientMobile) async {
    final snap = await FirebaseDatabase.instance
        .ref("Devices/$patientMobile")
        .get();

    if (!snap.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No devices found")),
      );
      return;
    }

    List<Map<String, dynamic>> activeDevices = [];

    for (var device in snap.children) {

      final raw = device.value;
      if (raw == null || raw is! Map) continue;

      final data = Map<String, dynamic>.from(raw);

      final status = data["st"]?.toString().toLowerCase();

      if (status == "active") {
        activeDevices.add({
          "deviceId": device.key ?? "",
          "testCount": int.tryParse(
            data["testCount"]?.toString() ?? "0",
          ) ?? 0,
        });
      }
    }

    if (activeDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No active device found")),
      );
      return;
    }

    if (activeDevices.length == 1) {
      final device = activeDevices.first;

      _showAddDeviceTestDialog(
        patientMobile,
        device["deviceId"],
        device["testCount"],
      );
    } else {
      _showDeviceSelectionDialog(
        patientMobile,
        activeDevices,
      );
    }
  }

  void _showDeviceSelectionDialog(String patientMobile,List<Map<String, dynamic>> devices) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // Top Handle
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const Text(
                "Select Active Device",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(context);
                      _showAddDeviceTestDialog(
                        patientMobile,
                        device["deviceId"],
                        device["testCount"],
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade100,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        children: [

                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.devices,
                              color: Colors.blue,
                            ),
                          ),

                          const SizedBox(width: 15),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                Text(
                                  device["deviceId"],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  "Current Test: ${device["testCount"]}",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
  // void _showAddDeviceTestDialog(String patientMobile,String deviceId,int currentTest) async {
  //
  //   final doctorSnap = await FirebaseDatabase.instance
  //       .ref("users/doctor/${widget.user.mobile}/availableTest")
  //       .get();
  //
  //   int doctorAvailable =
  //       int.tryParse(doctorSnap.value?.toString() ?? "0") ?? 0;
  //
  //   final TextEditingController controller =
  //   TextEditingController(text: "0");
  //
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: Text("Device: $deviceId"),
  //
  //       content: StatefulBuilder(
  //         builder: (context, setStateDialog) {
  //
  //           int addCount =
  //               int.tryParse(controller.text) ?? 0;
  //
  //           void updateValue(int value) {
  //             if (value < 0) value = 0;
  //             if (value > doctorAvailable) value = doctorAvailable;
  //
  //             controller.text = value.toString();
  //             controller.selection = TextSelection.fromPosition(
  //               TextPosition(offset: controller.text.length),
  //             );
  //             setStateDialog(() {});
  //           }
  //
  //           return Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //
  //               Text("Current Test: $currentTest"),
  //               const SizedBox(height: 5),
  //               Text("Doctor Available: $doctorAvailable"),
  //               const SizedBox(height: 20),
  //
  //               const Text("Add Test:"),
  //
  //               Row(
  //                 children: [
  //
  //                   IconButton(
  //                     icon: const Icon(Icons.remove),
  //                     onPressed: () {
  //                       updateValue(addCount - 1);
  //                     },
  //                   ),
  //
  //                   Expanded(
  //                     child: TextField(
  //                       controller: controller,
  //                       keyboardType: TextInputType.number,
  //                       textAlign: TextAlign.center,
  //                       decoration: const InputDecoration(
  //                         border: OutlineInputBorder(),
  //                         isDense: true,
  //                       ),
  //                       onChanged: (value) {
  //                         int entered =
  //                             int.tryParse(value) ?? 0;
  //                         updateValue(entered);
  //                       },
  //                     ),
  //                   ),
  //
  //                   IconButton(
  //                     icon: const Icon(Icons.add),
  //                     onPressed: () {
  //                       updateValue(addCount + 1);
  //                     },
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           );
  //         },
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () async {
  //
  //             int addCount =
  //                 int.tryParse(controller.text) ?? 0;
  //
  //             if (addCount <= 0) {
  //               Navigator.pop(context);
  //               return;
  //             }
  //
  //             if (addCount > doctorAvailable) {
  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 const SnackBar(
  //                     content: Text("Not enough available tests")),
  //               );
  //               return;
  //             }
  //
  //             // Update device test count
  //             await FirebaseDatabase.instance
  //                 .ref("Devices/$patientMobile/$deviceId")
  //                 .update({
  //               "testCount": currentTest + addCount,
  //             });
  //
  //             // Deduct from doctor
  //             await FirebaseDatabase.instance
  //                 .ref("users/doctor/${widget.user.mobile}")
  //                 .update({
  //               "availableTest": doctorAvailable - addCount,
  //             });
  //
  //             Navigator.pop(context);
  //           },
  //           child: const Text("OK"),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _showAddDeviceTestDialog(String patientMobile,String deviceId,int currentTest) async {

    final doctorSnap = await FirebaseDatabase.instance
        .ref("users/doctor/${widget.user.mobile}/availableTest")
        .get();

    int doctorAvailable =
        int.tryParse(doctorSnap.value?.toString() ?? "0") ?? 0;



    final TextEditingController controller =
    TextEditingController(text: "0");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Recharge Device",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Device ID: $deviceId",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            int addCount = int.tryParse(controller.text) ?? 0;

            void updateValue(int value) {
              if (value < 0) value = 0;
              if (value > doctorAvailable) value = doctorAvailable;

              controller.text = value.toString();
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
              setStateDialog(() {});
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 📊 Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow("Patient Current Test", "$currentTest"),
                      const SizedBox(height: 6),
                      _infoRow("Doctor Available Test", "$doctorAvailable"),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Add Test",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                // ➖ ➕ Counter
                Row(
                  children: [
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                      ),
                      icon: const Icon(Icons.remove),
                      onPressed: () => updateValue(addCount - 1),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (value) {
                          int entered = int.tryParse(value) ?? 0;
                          updateValue(entered);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                      ),
                      icon: const Icon(Icons.add),
                      onPressed: () => updateValue(addCount + 1),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            // onPressed: () async {
            //   // keep your existing OK logic here
            //
            // },
            onPressed: () async {

              int addCount = int.tryParse(controller.text) ?? 0;

              if (addCount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter valid test count")),
                );
                return;
              }

              if (addCount > doctorAvailable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Not enough available tests")),
                );
                return;
              }

              int newPatientTotal = currentTest + addCount;
              int newDoctorAvailable = doctorAvailable - addCount;

              // 🔹 Open Summary Dialog
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    "Recharge Summary",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      _summaryRow("Device ID", deviceId),
                      const SizedBox(height: 8),

                      _summaryRow("Recharge Test", addCount.toString()),

                      const Divider(height: 24),

                      _summaryRow("Patient Old Test", currentTest.toString()),
                      _summaryRow("Patient New Test", newPatientTotal.toString()),

                      const SizedBox(height: 12),

                      _summaryRow("Doctor Old Available", doctorAvailable.toString()),
                      _summaryRow("Doctor New Available", newDoctorAvailable.toString()),
                    ],
                  ),
                  actions: [

                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // close summary only
                      },
                      child: const Text("Back"),
                    ),

                    ElevatedButton(
                      // onPressed: () async {
                      //
                      //   // 🔹 Update Patient Device
                      //   await FirebaseDatabase.instance
                      //       .ref("Devices/$patientMobile/$deviceId")
                      //       .update({
                      //     "testCount": newPatientTotal,
                      //   });
                      //
                      //   // 🔹 Update Doctor Available
                      //   await FirebaseDatabase.instance
                      //       .ref("users/doctor/${widget.user.mobile}")
                      //       .update({
                      //     "availableTest": newDoctorAvailable,
                      //   });
                      //
                      //   // 🔹 Save Recharge Log
                      //   // String key =
                      //   // DateTime.now().millisecondsSinceEpoch.toString();
                      //     // 🔹 Save Recharge Log
                      //   String dateTimeKey =DateFormat("dd-MM-yy_hh:mm a").format(DateTime.now());
                      //   await FirebaseDatabase.instance
                      //       .ref("Recharge/patient/$patientMobile/$dateTimeKey")
                      //       .set({
                      //     "p_id": deviceId,
                      //     "d_mob": widget.user.mobile,
                      //     "add": addCount,
                      //     "p_OldTest": currentTest,
                      //     "p_NewTest": newPatientTotal,
                      //     "d_Old": doctorAvailable,
                      //     "d_New": newDoctorAvailable,
                      //     "p_mob": patientMobile,   // ✅ Added patient number
                      //   });
                      //
                      //   Navigator.pop(context); // close summary dialog
                      //   Navigator.pop(context); // close main dialog
                      //
                      //   ScaffoldMessenger.of(context).showSnackBar(
                      //     const SnackBar(content: Text("Recharge Successful")),
                      //   );
                      // },

                      onPressed: () async {

                        // 🔹 Show Loading Dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const AlertDialog(
                            content: Row(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 20),
                                Text("Updating..."),
                              ],
                            ),
                          ),
                        );

                        try {

                          // 🔹 Update Patient Device
                          await FirebaseDatabase.instance
                              .ref("Devices/$patientMobile/$deviceId")
                              .update({
                            "testCount": newPatientTotal,
                          });

                          // 🔹 Update Doctor
                          await FirebaseDatabase.instance
                              .ref("users/doctor/${widget.user.mobile}")
                              .update({
                            "availableTest": newDoctorAvailable,
                          });

                          // 🔹 Save Recharge Log
                          String dateTimeKey =DateFormat("dd-MM-yy_hh:mm a").format(DateTime.now());
                          await FirebaseDatabase.instance
                              .ref("Recharge/patient/$patientMobile/$dateTimeKey")
                              .set({
                            "p_id": deviceId,
                            "d_mob": widget.user.mobile,
                            "p_mob": patientMobile,
                            "add": addCount,
                            "p_Old": currentTest,
                            "p_New": newPatientTotal,
                            "d_Old": doctorAvailable,
                            "d_New": newDoctorAvailable,
                          });

                          // 🔹 Close Loading
                          Navigator.pop(context);

                          // 🔹 Close Summary
                          Navigator.pop(context);

                          // 🔹 Close Main Dialog
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Test Added Successfully"),
                            ),
                          );

                        } catch (e) {

                          Navigator.pop(context); // close loading

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Something went wrong"),
                            ),
                          );
                        }
                      },

                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );

    // showDialog(
    //   context: context,
    //   builder: (_) => AlertDialog(
    //     title: Text("Device: $deviceId"),
    //     content: StatefulBuilder(
    //       builder: (context, setStateDialog) {
    //
    //         int addCount = int.tryParse(controller.text) ?? 0;
    //
    //         void updateValue(int value) {
    //           if (value < 0) value = 0;
    //           if (value > doctorAvailable) value = doctorAvailable;
    //
    //           controller.text = value.toString();
    //           controller.selection = TextSelection.fromPosition(
    //             TextPosition(offset: controller.text.length),
    //           );
    //           setStateDialog(() {});
    //         }
    //
    //         return Column(
    //           mainAxisSize: MainAxisSize.min,
    //           crossAxisAlignment: CrossAxisAlignment.start,
    //           children: [
    //
    //             Text("Current Patient Test: $currentTest"),
    //             const SizedBox(height: 5),
    //             Text("Doctor Available Test: $doctorAvailable"),
    //             const SizedBox(height: 20),
    //
    //             const Text("Add Test:"),
    //
    //             Row(
    //               children: [
    //                 IconButton(
    //                   icon: const Icon(Icons.remove),
    //                   onPressed: () {
    //                     updateValue(addCount - 1);
    //                   },
    //                 ),
    //                 Expanded(
    //                   child: TextField(
    //                     controller: controller,
    //                     keyboardType: TextInputType.number,
    //                     textAlign: TextAlign.center,
    //                     decoration: const InputDecoration(
    //                       border: OutlineInputBorder(),
    //                       isDense: true,
    //                     ),
    //                     onChanged: (value) {
    //                       int entered =
    //                           int.tryParse(value) ?? 0;
    //                       updateValue(entered);
    //                     },
    //                   ),
    //                 ),
    //                 IconButton(
    //                   icon: const Icon(Icons.add),
    //                   onPressed: () {
    //                     updateValue(addCount + 1);
    //                   },
    //                 ),
    //               ],
    //             ),
    //           ],
    //         );
    //       },
    //     ),
    //     actions: [
    //       TextButton(
    //         onPressed: () async {
    //
    //           int addCount =
    //               int.tryParse(controller.text) ?? 0;
    //
    //           if (addCount <= 0) {
    //             Navigator.pop(context);
    //             return;
    //           }
    //
    //           if (addCount > doctorAvailable) {
    //             ScaffoldMessenger.of(context).showSnackBar(
    //               const SnackBar(
    //                   content: Text("Not enough available tests")),
    //             );
    //             return;
    //           }
    //
    //           int newPatientTotal = currentTest + addCount;
    //           int newDoctorAvailable = doctorAvailable - addCount;
    //
    //           // 🔹 Confirmation Dialog
    //           showDialog(
    //             context: context,
    //             builder: (_) => AlertDialog(
    //               title: const Text("Confirm Update"),
    //               content: Column(
    //                 mainAxisSize: MainAxisSize.min,
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   Text("Recharge Test: $addCount"),
    //                   const SizedBox(height: 10),
    //                   Text("Patient Old Test: $currentTest"),
    //                   Text("Patient New Test: $newPatientTotal"),
    //                   const SizedBox(height: 10),
    //                   Text("Doctor Old Available: $doctorAvailable"),
    //                   Text("Doctor New Available: $newDoctorAvailable"),
    //                 ],
    //               ),
    //               actions: [
    //
    //                 TextButton(
    //                   onPressed: () {
    //                     Navigator.pop(context); // close confirm
    //                   },
    //                   child: const Text("Cancel"),
    //                 ),
    //
    //                 ElevatedButton(
    //                   onPressed: () async {
    //
    //                     // 🔹 Update Device
    //                     await FirebaseDatabase.instance
    //                         .ref("Devices/$patientMobile/$deviceId")
    //                         .update({
    //                       "testCount": newPatientTotal,
    //                     });
    //
    //                     // 🔹 Update Doctor
    //                     await FirebaseDatabase.instance
    //                         .ref("users/doctor/${widget.user.mobile}")
    //                         .update({
    //                       "availableTest": newDoctorAvailable,
    //                     });
    //
    //                     // 🔹 Save Recharge Log
    //                     String dateTimeKey =
    //                     DateFormat("dd-MM-yy_hh:mm a")
    //                         .format(DateTime.now());
    //
    //                     await FirebaseDatabase.instance
    //                         .ref("Recharge/patient/$patientMobile/$dateTimeKey")
    //                         .set({
    //
    //                       "id": deviceId,
    //                       "add": addCount,
    //                       "d_name": widget.user.mobile,
    //                       "p_OldTest": currentTest,
    //                       "p_NewTest": newPatientTotal,
    //                       "d_Old": doctorAvailable,
    //                       "d_New": newDoctorAvailable,
    //                       });
    //
    //                     Navigator.pop(context); // close confirm
    //                     Navigator.pop(context); // close first dialog
    //                   },
    //                   child: const Text("Confirm"),
    //                 ),
    //               ],
    //             ),
    //           );
    //         },
    //         child: const Text("OK"),
    //       ),
    //     ],
    //   ),
    // );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  Future<void> _showPatientDetailsDialog(String mobile) async {
    final snap = await FirebaseDatabase.instance
        .ref("users/patient/$mobile")
        .get();

    if (!snap.exists) return;

    final data = Map<String, dynamic>.from(snap.value as Map);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Patient Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Name: ${data["name"] ?? ""}"),
              Text("Mobile: $mobile"),
              Text("Disease: ${data["disease"] ?? ""}"),
              Text("Age: ${data["age"] ?? ""}"),
              Text("Gender: ${data["gender"] ?? ""}"),
              Text("Email: ${data["email"] ?? ""}"),
              Text("Address: ${data["address"] ?? ""}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
  Widget _summaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

}
