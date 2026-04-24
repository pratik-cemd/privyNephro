import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'user_model.dart';
import 'package:intl/intl.dart';
import 'myprofile.dart';
import 'myDevicesPage.dart';
import 'mydoctor.dart';

import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import 'package:share_plus/share_plus.dart';

class TestCountScreen extends StatefulWidget {
  final UserModel user;

  const TestCountScreen({super.key, required this.user});

  @override
  State<TestCountScreen> createState() => _TestCountScreenState();
}

class _TestCountScreenState extends State<TestCountScreen> {

  int currentCount = 0;
  int pricePerTest = 0;
  int enteredTests = 0;
  int totalAmount = 0;

  final TextEditingController testController = TextEditingController();

  late DatabaseReference doctorRef;
  late DatabaseReference rechargeRef;
  late DatabaseReference rechargeRefTemp;
  StreamSubscription? _rechargeSubscription;

  @override
  void initState() {
    super.initState();

    doctorRef =
        FirebaseDatabase.instance.ref("users/doctor/${widget.user.mobile}");

    rechargeRef =
        FirebaseDatabase.instance.ref("Recharge/Doctor/${widget.user.mobile}");

    rechargeRefTemp =
        FirebaseDatabase.instance.ref("Rechargetemp/Doctor/${widget.user.mobile}");

    _listenDoctorData();
    _listenForApprovedRecharges();
  }

  // 🔷 Listen Doctor Profile
  void _listenDoctorData() {
    doctorRef.onValue.listen((event) {

      if (event.snapshot.value == null) return;

      final data =
      Map<String, dynamic>.from(event.snapshot.value as Map);

      setState(() {
        currentCount =
            int.tryParse(data["availableTest"]?.toString() ?? "0") ?? 0;

        pricePerTest =
            int.tryParse(data["amount"]?.toString() ?? "0") ?? 0;
      });
    });
  }

  // 🔷 Auto Add Tests After Approval
  // void _listenForApprovedRecharges2() {
  //
  //   rechargeRefTemp.onChildChanged.listen((event) async {
  //
  //     final data =
  //     Map<String, dynamic>.from(event.snapshot.value as Map);
  //
  //     if (data["status"] == "approved") {
  //
  //       int approvedTests =
  //           int.tryParse(data["tests"]?.toString() ?? "0") ?? 0;
  //
  //       // 🔹 Add tests safely using transaction
  //       await doctorRef.runTransaction((mutableData) {
  //
  //         if (mutableData == null) {
  //           return Transaction.abort();
  //         }
  //
  //         final map =
  //         Map<String, dynamic>.from(mutableData as Map);
  //
  //         int existing =
  //             int.tryParse(map["availableTest"]?.toString() ?? "0") ?? 0;
  //
  //         map["availableTest"] = existing + approvedTests;
  //
  //         return Transaction.success(map);
  //       });
  //
  //       // 🔹 Change status to credited (prevent duplicate addition)
  //       // await event.snapshot.ref.update({
  //       //   "status": "credited"
  //       // });
  //
  //       String formattedDate =
  //       DateFormat('dd-MM-yy_hh:mm a').format(DateTime.now());
  //
  //       await rechargeRef.child(data["Dt"]).set({
  //         "tests": enteredTests,
  //         "totalAmount": totalAmount,
  //         "status": data["status"],
  //         "Dt":formattedDate,
  //       });
  //
  //     }
  //   });
  // }


  void _listenForApprovedRecharges() {

    _rechargeSubscription =
        rechargeRefTemp.onChildChanged.listen((event) async {

          if (event.snapshot.value == null) return;

          final data =
          Map<String, dynamic>.from(event.snapshot.value as Map);

          if (data["st"] != "approved") return;

          int approvedTests =
              int.tryParse(data["tests"]?.toString() ?? "0") ?? 0;

          // 🔹 Add tests
          await doctorRef.runTransaction((mutableData) {

            if (mutableData == null) {
              return Transaction.abort();
            }

            final map =
            Map<String, dynamic>.from(mutableData as Map);

            int existing =
                int.tryParse(map["availableTest"]?.toString() ?? "0") ?? 0;

            map["availableTest"] = existing + approvedTests;

            return Transaction.success(map);
          });

          String formattedDate =
          DateFormat('dd-MM-yy_hh:mm a').format(DateTime.now());

          // 🔹 Move to main rechargeRef using SAME KEY
          await rechargeRef.child(event.snapshot.key!).set({
            "tests": data["tests"],
            "pay": data["totalAmount"],
            "st": "credited",
            "Dt": formattedDate,
            "payment": "online",
          });

          // 🔹 Remove from temp
          await event.snapshot.ref.remove();

          // 🔹 Cancel listener if you want to stop completely
          await _rechargeSubscription?.cancel();
        });
  }

  // 🔷 Send Recharge Request
  // Future<void> _requestRecharge() async {
  //
  //   if (enteredTests <= 0) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Enter valid test count")),
  //     );
  //     return;
  //   }
  //
  //   final id = DateTime.now().millisecondsSinceEpoch.toString();
  //   final formattedDate =
  //       DateFormat("dd/MM/yy hh:mm a").format(id as DateTime);
  //
  //   await rechargeRef.child(formattedDate).set({
  //     "tests": enteredTests,
  //     "pricePerTest": pricePerTest,
  //     "totalAmount": totalAmount,
  //     "status": "pending",
  //     "timestamp": formattedDate,
  //   });
  //
  //   testController.clear();
  //
  //   setState(() {
  //     enteredTests = 0;
  //     totalAmount = 0;
  //   });
  //
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text("Recharge request sent")),
  //   );
  // }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff6D8EBE),
      body: SafeArea(
        child: Column(
          children: [

            // 🔷 TOP BAR (Same as MyProfile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  // Popup Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    offset: const Offset(0, 40),
                    onSelected: (value) {

                      if (value == "home") {
                        Navigator.pushNamed(context, "/home");
                      }
                      else if (value == "patient") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyDoctorPage(
                              user: widget.user,
                            ),
                          ),
                        );
                      } else if (value == "device") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyDevicesPage2(
                              user: widget.user,
                            ),
                          ),
                        );
                      } else if (value == "profile") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyProfileScreen(
                              user: widget.user,
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: "home",
                        child: Row(
                          children: [
                            Icon(Icons.home, color: Colors.black),
                            SizedBox(width: 8),
                            Text("Home", style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),

                      PopupMenuItem(
                        value: "device",
                        child: Row(
                          children: [
                            Icon(Icons.devices, color: Colors.black),
                            SizedBox(width: 8),
                            Text("My Device", style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "patient",
                        child: Row(
                          children: [
                            Icon(Icons.people, color: Colors.black),
                            SizedBox(width: 8),
                            Text("My Patient", style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
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

                  const Text(
                    "Test Count",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),

                  // const SizedBox(width: 40), // spacing balance
                  IconButton(
                    icon: const Icon(Icons.insert_drive_file_outlined,
                        color: Colors.white, size: 28),
                    onPressed: () {
                      _showRechargeHistoryByDoctor();
                    },
                  ),
                ],
              ),
            ),

            // 🔷 MAIN WHITE CONTAINER
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xffF9FEFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Container(
                      //   width: double.infinity,
                      //   padding: const EdgeInsets.all(20),
                      //   decoration: BoxDecoration(
                      //     color: const Color(0xFF1A2B55), // solid background
                      //     borderRadius: BorderRadius.circular(16),
                      //     boxShadow: [
                      //       BoxShadow(
                      //         color: Colors.black.withOpacity(0.2),
                      //         blurRadius: 8,
                      //         offset: const Offset(0, 4),
                      //       ),
                      //     ],
                      //   ),
                    // 🔹 CLICKABLE AVAILABLE TEST CARD
                    Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openRechargeDialog,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2B55),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Available Tests",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentCount.toString(),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Price per Test: ₹$pricePerTest",
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),

                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Recharge History",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.download,
                              color: Colors.blue,
                            ),
                            // onPressed: _downloadAndSharePDF(_generatePDF),
                            onPressed: () => _downloadAndSharePDF(_generatePDF),
                            tooltip: "Download History",
                          ),
                        ],
                      ),
                      // const Text(
                      //   "Recharge History",
                      //   style: TextStyle(
                      //     fontSize: 18,
                      //     fontWeight: FontWeight.bold,
                      //   ),
                      // ),
                      //
                      // // 🔹 Download Button
                      // IconButton(
                      //   icon: const Icon(Icons.download, color: Colors.blue),
                      //   onPressed: _downloadAndSharePDF,
                      // ),
                      const SizedBox(height: 10),

                      _buildRechargeHistory(), // your existing history builder
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildRechargeHistory() {
  //   return StreamBuilder<DatabaseEvent>(
  //     stream: rechargeRef.onValue,
  //     builder: (context, snapshot) {
  //
  //       if (!snapshot.hasData ||
  //           snapshot.data!.snapshot.value == null) {
  //         return const Padding(
  //           padding: EdgeInsets.all(20),
  //           child: Text("No recharge history"),
  //         );
  //       }
  //
  //       final rawData = snapshot.data!.snapshot.value;
  //
  //       if (rawData is! Map) {
  //         return const Text("Invalid data format");
  //       }
  //
  //       final Map<dynamic, dynamic> data = rawData;
  //
  //       final List<Map<String, dynamic>> historyList = [];
  //
  //       data.forEach((key, value) {
  //         if (value is Map) {
  //           historyList.add(Map<String, dynamic>.from(value));
  //         }
  //       });
  //
  //       if (historyList.isEmpty) {
  //         return const Text("No recharge history");
  //       }
  //
  //       historyList.sort((a, b) {
  //         final t1 = int.tryParse(a["Dt"]?.toString() ?? "0") ?? 0;
  //         final t2 = int.tryParse(b["Dt"]?.toString() ?? "0") ?? 0;
  //         return t2.compareTo(t1);
  //       });
  //
  //       return ListView.builder(
  //         shrinkWrap: true,
  //         physics: const NeverScrollableScrollPhysics(),
  //         itemCount: historyList.length,
  //         itemBuilder: (context, index) {
  //
  //           final item = historyList[index];
  //
  //           Color statusColor = Colors.orange;
  //
  //           if (item["status"] == "approved") {
  //             statusColor = Colors.blue;
  //           } else if (item["status"] == "credited") {
  //             statusColor = Colors.green;
  //           } else if (item["status"] == "rejected") {
  //             statusColor = Colors.red;
  //           }
  //           String formattedDate = item["Dt"]?.toString() ?? "";
  //
  //           return Card(
  //             margin: const EdgeInsets.symmetric(vertical: 6),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: Padding(
  //               padding: const EdgeInsets.symmetric(
  //                   horizontal: 16, vertical: 14),
  //               child: Row(
  //                 mainAxisAlignment:
  //                 MainAxisAlignment.spaceBetween,
  //                 crossAxisAlignment:
  //                 CrossAxisAlignment.start,
  //                 children: [
  //
  //                   // LEFT
  //                   Column(
  //                     crossAxisAlignment:
  //                     CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         "₹${item["totalAmount"] ?? 0}",
  //                         style: const TextStyle(
  //                           fontSize: 16,
  //                           fontWeight: FontWeight.bold,
  //                         ),
  //                       ),
  //                       const SizedBox(height: 6),
  //                       Text(
  //                         "Tests: ${item["tests"] ?? 0}",
  //                       ),
  //                     ],
  //                   ),
  //
  //                   // RIGHT
  //                   Column(
  //                     crossAxisAlignment:
  //                     CrossAxisAlignment.end,
  //                     children: [
  //                       Text(
  //                         item["status"] ?? "",
  //                         style: TextStyle(
  //                           fontWeight: FontWeight.bold,
  //                           color: statusColor,
  //                         ),
  //                       ),
  //                       const SizedBox(height: 6),
  //                       Text(
  //                         formattedDate,
  //                         style: const TextStyle(
  //                           fontSize: 12,
  //                           color: Colors.grey,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }
  Widget _buildRechargeHistory() {
    return StreamBuilder<DatabaseEvent>(
      stream: rechargeRef.onValue,
      builder: (context, snapshotMain) {

        return StreamBuilder<DatabaseEvent>(
          stream: rechargeRefTemp.onValue,
          builder: (context, snapshotTemp) {

            // 🔹 Show loading until both load
            if (snapshotMain.connectionState == ConnectionState.waiting ||
                snapshotTemp.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            List<Map<String, dynamic>> historyList = [];

            // 🔹 Main Recharge Data (approved / credited / rejected)
            if (snapshotMain.hasData &&
                snapshotMain.data!.snapshot.value != null) {

              final rawMain = snapshotMain.data!.snapshot.value;

              if (rawMain is Map) {
                rawMain.forEach((key, value) {
                  if (value is Map) {
                    historyList.add(
                        Map<String, dynamic>.from(value));
                  }
                });
              }
            }

            // 🔹 Temp Recharge Data (pending)
            if (snapshotTemp.hasData &&
                snapshotTemp.data!.snapshot.value != null) {

              final rawTemp = snapshotTemp.data!.snapshot.value;

              if (rawTemp is Map) {
                rawTemp.forEach((key, value) {
                  if (value is Map) {
                    historyList.add(
                        Map<String, dynamic>.from(value));
                  }
                });
              }
            }

            if (historyList.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No recharge history"),
              );
            }

            // 🔹 Sort by Dt (string date)
            historyList.sort((a, b) {
              final d1 = a["Dt"]?.toString() ?? "";
              final d2 = b["Dt"]?.toString() ?? "";
              return d2.compareTo(d1);
            });

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historyList.length,
              itemBuilder: (context, index) {

                final item = historyList[index];

                Color statusColor = Colors.orange;

                if (item["st"] == "approved") {
                  statusColor = Colors.blue;
                } else if (item["st"] == "credited") {
                  statusColor = Colors.green;
                } else if (item["st"] == "reject") {
                  statusColor = Colors.red;
                } else if (item["st"] == "pending") {
                  statusColor = Colors.orange;
                }

                String formattedDate =
                    item["Dt"]?.toString() ?? "";

                return Card(
                  margin:
                  const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [

                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Text(
                              "₹${item["pay"]?.toString() ??
                        item["totalAmount"]?.toString() ?? 0}",

                        // item["pay"]?.toString() ??
                        //     item["totalAmount"]?.toString() ??
                        //     "0") ??
                              style:
                              const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                                height: 6),
                            Text(
                              "Tests: ${item["tests"] ?? 0}",
                            ),
                          ],
                        ),

                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .end,
                          children: [
                            Text(
                              item["st"] ?? "",
                              style: TextStyle(
                                fontWeight:
                                FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(
                                height: 6),
                            Text(
                              formattedDate,
                              style:
                              const TextStyle(
                                fontSize: 12,
                                color:
                                Colors.grey,
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
          },
        );
      },
    );
  }
  void _openRechargeDialog() {
    final TextEditingController testController =
    TextEditingController();
    int enteredTests = 0;
    int totalAmount = 0;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Recharge Tests"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Price per Test: ₹$pricePerTest",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: testController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Enter Test Count",
                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        enteredTests =
                            int.tryParse(value) ?? 0;
                        setStateDialog(() {
                          totalAmount =
                              enteredTests * pricePerTest;
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total"),
                          Text(
                            "₹$totalAmount",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: enteredTests <= 0
                      ? null
                      : () async {
                    String formattedDate =
                    DateFormat('dd-MM-yy_hh:mm a').format(DateTime.now());

                    await rechargeRefTemp.child(formattedDate).set({
                      "tests": enteredTests,
                      "pay": totalAmount,
                      "st": "pending",
                      "Dt":formattedDate,
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                            "Recharge request sent"),
                      ),
                    );
                  },
                  child: const Text("Send"),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _downloadAndSharePDF2() async {
    final pdf = pw.Document();
    final formattedDate =
    DateFormat('dd/MM/yy hh:mm a').format(DateTime.now());
    // final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    // final ttf = pw.Font.ttf(fontData);

    final ttf = await PdfGoogleFonts.robotoRegular();

    final mainSnapshot = await rechargeRef.get();
    final tempSnapshot = await rechargeRefTemp.get();

    List<Map<String, dynamic>> historyList = [];

    if (mainSnapshot.value != null) {
      final data = Map<String, dynamic>.from(mainSnapshot.value as Map);
      data.forEach((key, value) {
        if (value is Map) {
          historyList.add(Map<String, dynamic>.from(value));
        }
      });
    }

    if (tempSnapshot.value != null) {
      final data = Map<String, dynamic>.from(tempSnapshot.value as Map);
      data.forEach((key, value) {
        if (value is Map) {
          historyList.add(Map<String, dynamic>.from(value));
        }
      });
    }

    // 🔹 Sort Latest First
    historyList.sort((a, b) {
      return (b["Dt"] ?? "").compareTo(a["Dt"] ?? "");
    });

    double totalAmount = 0;
    for (var item in historyList) {
      totalAmount += double.tryParse(
          item["pay"]?.toString() ??
              item["totalAmount"]?.toString() ??
              "0") ??
          0;
    }

    double totaltest = 0;
    for (var item in historyList) {
      totaltest += double.tryParse(
                  item["tests"]?.toString() ??
              "0") ??
          0;
    }

    final logo = await imageFromAssetBundle("assets/images/img.png");

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // ✅ APPLY FONT HERE
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttf,
        ),
        // 🔹 Footer with page number
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        },

        build: (context) => [

          /// 🔹 Watermark
          pw.Center(
            child: pw.Opacity(
              opacity: 0.08,
              child: pw.Transform.rotate(
                angle: -0.5,
                child: pw.Text(
                  "CONFIDENTIAL",
                  style: pw.TextStyle(
                    fontSize: 50,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          pw.SizedBox(height: 10),

          /// 🔹 Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, width: 60, height: 60),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    widget.user.name ?? "Doctor Name",
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text("Mobile: ${widget.user.mobile ?? ''}"),
                  pw.Text(
                    "Generated: ${formattedDate}",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          pw.Text(
            "Recharge History",
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 15),

          /// 🔹 Table
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration:
            const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellPadding: const pw.EdgeInsets.all(8),
            headers: [
              "Date",
              "Time",
              "Tests",
              "Amount",
              "Payment Mode",
              "Status",

            ],
            data: historyList.map((item) {

              String datePart = "";
              String timePart = "";

              final rawDate = item["Dt"] ?? "";

              if (rawDate.toString().isNotEmpty) {
                try {
                  final parsed =
                  DateFormat('dd-MM-yy_hh:mm a').parse(rawDate);

                  final datePart =
                  DateFormat('dd/MM/yy').format(parsed);

                  final timePart =
                  DateFormat('hh:mm a').format(parsed);


                } catch (e) {
                  // formattedDate = rawDate; // fallback
                }
              }

              return [
                "$datePart",
                "$timePart",
                "${item["tests"] ?? 0}",
                "₹${item["pay"] ?? item["totalAmount"] ?? 0}",
                "${item["paymentMode"] ?? "processing"}",
                "${item["status"] ?? item["st"] ?? ""}",
                // "${item["Dt"] ?? ""}",
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 25),

          /// 🔹 Total Section
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Text(
                "Total Test Pay Amount: ₹$totalAmount",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),

          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Text(
                "Total Added Test: ₹$totaltest",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 40),

          /// 🔹 Signature Area
          // pw.Row(
          //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          //   children: [
          //     pw.Column(
          //       children: [
          //         pw.Container(
          //           width: 150,
          //           child: pw.Divider(),
          //         ),
          //         pw.Text("Authorized Signature"),
          //       ],
          //     ),
          //     pw.Column(
          //       children: [
          //         pw.Container(
          //           width: 150,
          //           child: pw.Divider(),
          //         ),
          //         pw.Text("Doctor Signature"),
          //       ],
          //     ),
          //   ],
          // ),
        ],
      ),
    );



    final bytes = await pdf.save();
    final now = DateTime.now();
    final formatted =
    DateFormat('ddMMyyHHmm').format(now);

    final fileName =
        "doctor_recharge_history_$formatted.pdf";
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'application/pdf',
          name: fileName,
        )
      ],
      text: "Recharge History PDF",
    );
  }

  // Future<void> _downloadAndSharePDF(Future<File> Function() generateFunction) async {
  //
  //   // 🔹 Show Loading
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) => const Center(
  //       child: CircularProgressIndicator(),
  //     ),
  //   );
  //
  //   try {
  //
  //     // 🔹 Generate PDF
  //     // final file = await _generatePDF();
  //     final file = await  generateFunction();
  //
  //     Navigator.pop(context); // remove loading
  //
  //     // 🔹 Show Confirmation Dialog
  //     _showPDFDialog(file);
  //
  //   } catch (e) {
  //     Navigator.pop(context);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Failed to generate PDF")),
  //     );
  //   }
  // }
  Future<void> _downloadAndSharePDF(
      Future<File> Function() generateFunction) async {

    // 🔹 Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 🔹 Call the function dynamically
      final file = await generateFunction();

      Navigator.pop(context); // remove loading

      // 🔹 Show confirmation dialog
      _showPDFDialog(file);

    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to generate PDF")),
      );
    }
  }

  Future<File> _generatePDF() async {
    final pdf = pw.Document();
    final formattedDate =
    DateFormat('dd/MM/yy hh:mm a').format(DateTime.now());
    // 🔹 Load Unicode Font (for ₹ support)
    // final fontData =
    // await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    // final ttf = pw.Font.ttf(fontData);
    final ttf = await PdfGoogleFonts.robotoRegular();
    // 🔹 Fetch Firebase Data
    final mainSnapshot = await rechargeRef.get();
    final tempSnapshot = await rechargeRefTemp.get();

    List<Map<String, dynamic>> historyList = [];

    if (mainSnapshot.value != null) {
      final data = Map<String, dynamic>.from(mainSnapshot.value as Map);
      data.forEach((key, value) {
        if (value is Map) {
          historyList.add(Map<String, dynamic>.from(value));
        }
      });
    }

    if (tempSnapshot.value != null) {
      final data = Map<String, dynamic>.from(tempSnapshot.value as Map);
      data.forEach((key, value) {
        if (value is Map) {
          historyList.add(Map<String, dynamic>.from(value));
        }
      });
    }

    // 🔹 Sort Latest First
    historyList.sort((a, b) {
      return (b["Dt"] ?? "").compareTo(a["Dt"] ?? "");
    });

    // 🔹 Calculate Total
    double totalAmount = 0;
    for (var item in historyList) {
      totalAmount += double.tryParse(
          item["pay"]?.toString() ??
              item["totalAmount"]?.toString() ??
              "0") ??
          0;
    }
    double totaltest = 0;
    for (var item in historyList) {
      totaltest += double.tryParse(
          item["tests"]?.toString() ??
              "0") ??
          0;
    }

    final logo =
    await imageFromAssetBundle("assets/images/img.png");

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),

        // 🔹 Apply Font Globally
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttf,
        ),

        // 🔹 Fixed Header
        header: (context) {
          return pw.Column(
            children: [

              pw.Row(
                mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(logo, width: 60, height: 60),

                  pw.Column(
                    crossAxisAlignment:
                    pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        ("DR. ${(widget.user.name ?? 'DOCTOR NAME').toUpperCase()}"),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                          "Mobile: ${widget.user.mobile ?? ''}"),
                      pw.Text(
                        "Generated: ${formattedDate}",
                        style:
                        const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),

              pw.Text(
                "Recharge History",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 15),
            ],
          );
        },

        // 🔹 Watermark
        // background: (context) => pw.Center(
        //   child: pw.Opacity(
        //     opacity: 0.06,
        //     child: pw.Transform.rotate(
        //       angle: -0.5,
        //       child: pw.Text(
        //         "CONFIDENTIAL",
        //         style: pw.TextStyle(
        //           fontSize: 80,
        //           fontWeight: pw.FontWeight.bold,
        //         ),
        //       ),
        //     ),
        //   ),
        // ),

        // 🔹 Footer
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        },

        // 🔹 BODY CONTENT
        build: (context) => [

          /// TABLE
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration:
            const pw.BoxDecoration(
                color: PdfColors.blueGrey800),
            cellPadding:
            const pw.EdgeInsets.all(8),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
            },
            headers: [
              "Date",
              "Time",
              "Tests",
              "Amount",
              "Payment Mode",
              "Status",
            ],
            data: historyList.map((item) {
              String datePart = "";
              String timePart = "";

              final rawDate = item["Dt"] ?? "";

              if (rawDate.toString().isNotEmpty) {
                try {
                  final parsed =
                  DateFormat('dd-MM-yy_hh:mm a').parse(rawDate);

                  datePart =
                  DateFormat('dd/MM/yy').format(parsed);

                  timePart =
                  DateFormat('hh:mm a').format(parsed);


                } catch (e) {
                  // formattedDate = rawDate; // fallback
                }
              }

              return [
                "$datePart",
                "$timePart",
                "${item["tests"] ?? 0}",
                "₹${item["pay"] ?? item["totalAmount"] ?? 0}",
                "${item["payment"] ?? "Processing"}",
                "${item["status"] ?? item["st"] ?? ""}",
                // "${item["Dt"] ?? ""}",
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 25),


          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [

              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Text(
                  "Total Added Test: $totaltest",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Text(
                  "Total Test Pay Amount: ₹$totalAmount",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

            ],
          ),
          pw.SizedBox(height: 40),

          /// SIGNATURE SECTION
          // pw.Row(
          //   mainAxisAlignment:
          //   pw.MainAxisAlignment.spaceBetween,
          //   children: [
          //     pw.Column(
          //       children: [
          //         pw.Container(
          //             width: 150,
          //             child: pw.Divider()),
          //         pw.Text("Authorized Signature"),
          //       ],
          //     ),
          //     pw.Column(
          //       children: [
          //         pw.Container(
          //             width: 150,
          //             child: pw.Divider()),
          //         pw.Text("Doctor Signature"),
          //       ],
          //     ),
          //   ],
          // ),
        ],
      ),
    );



    // 🔹 Share Directly (No File Saved)
    final bytes = await pdf.save();
    final now = DateTime.now();
    final formatted =
    DateFormat('ddMMyyHHmm').format(now);

    final fileName =
        "doctor_recharge_history_$formatted.pdf";

    // await Share.shareXFiles(
    //   [
    //     XFile.fromData(
    //       bytes,
    //       mimeType: 'application/pdf',
    //       name: fileName,
    //     )
    //   ],
    //   text: "Recharge History PDF",
    // );
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/$fileName");

    await file.writeAsBytes(bytes);

    return file; // ✅ Now returning File
  }


  void _showPDFDialog(File file) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Recharge History Ready"),
        content: const Text(
            "Would you like to view the recharge History or share it?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Printing.layoutPdf(
                onLayout: (format) =>
                    file.readAsBytes(),
              );
            },
            child: const Text("View"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Share.shareXFiles(
                  [XFile(file.path)]);
            },
            child: const Text("Share"),
          ),
        ],
      ),
    );
  }

  // Future<void> _viewPDF(Uint8List bytes) async {
  //   final dir = await getTemporaryDirectory();
  //   final filePath = "${dir.path}/preview.pdf";
  //   final file = File(filePath);
  //   await file.writeAsBytes(bytes);
  //   await OpenFile.open(filePath);
  // }

  // Future<void> _sharePDF(Uint8List bytes) async {
  //
  //   final now = DateTime.now();
  //   final formatted =
  //   DateFormat('ddMMyyHHmm').format(now);
  //
  //   final fileName =
  //       "doctor_recharge_history_$formatted.pdf";
  //
  //   await Share.shareXFiles(
  //     [
  //       XFile.fromData(
  //         bytes,
  //         mimeType: 'application/pdf',
  //         name: fileName,
  //       )
  //     ],
  //   );
  // }
  @override
  void dispose() {
    _rechargeSubscription?.cancel();
    super.dispose();
  }


  void _showRechargeHistoryByDoctor_old() async {

    final snapshot = await FirebaseDatabase.instance
        .ref("Recharge/patient")
        .get();

    if (!snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No recharge history found")),
      );
      return;
    }

    Map allPatients = snapshot.value as Map;

    List<Map<String, dynamic>> rechargeList = [];

    allPatients.forEach((patientKey, patientData) {

      Map patientMap = Map<String, dynamic>.from(patientData);

      patientMap.forEach((dateKey, rechargeData) {

        Map item = Map<String, dynamic>.from(rechargeData);

        if (item["d_mob"] == widget.user.mobile) {
          rechargeList.add({
            "date": dateKey,
            ...item,
          });
        }
      });
    });

    if (rechargeList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No recharge history for this doctor")),
      );
      return;
    }

    rechargeList.sort((a, b) =>
        b["date"].toString().compareTo(a["date"].toString()));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("My Recharge History"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                border: TableBorder.all(color: Colors.grey.shade300),
                columns: const [
                  DataColumn(label: Text("Date")),
                  DataColumn(label: Text("Device")),
                  DataColumn(label: Text("Added Test")),
                  DataColumn(label: Text("Previous Patient Test")),
                  DataColumn(label: Text("Current Patient Test")),
                  DataColumn(label: Text("Previous Doctor Test")),
                  DataColumn(label: Text("Current Doctor Test")),
                  DataColumn(label: Text("Patient Mob")),
                ],
                rows: rechargeList.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(item["date"].toString())),
                      DataCell(Text(item["p_id"].toString())),
                      DataCell(Text(item["add"].toString())),
                      DataCell(Text(item["p_Old"].toString())),
                      DataCell(Text(item["p_New"].toString())),
                      DataCell(Text(item["d_Old"].toString())),
                      DataCell(Text(item["d_New"].toString())),
                      DataCell(Text(item["p_mob"].toString())),
                    ],
                  );
                }).toList(),
              ),
            ),
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
  void _showRechargeHistoryByDoctor() async {

    final snapshot = await FirebaseDatabase.instance
        .ref("Recharge/patient")
        .get();

    if (!snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No recharge history found")),
      );
      return;
    }

    Map allPatients = snapshot.value as Map;

    List<Map<String, dynamic>> rechargeList = [];

    allPatients.forEach((patientKey, patientData) {

      Map patientMap = Map<String, dynamic>.from(patientData);

      patientMap.forEach((dateKey, rechargeData) {

        Map item = Map<String, dynamic>.from(rechargeData);

        if (item["d_mob"] == widget.user.mobile) {
          rechargeList.add({
            "date": dateKey,
            ...item,
          });
        }
      });
    });

    rechargeList.sort((a, b) =>
        b["date"].toString().compareTo(a["date"].toString()));

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          // insetPadding: const EdgeInsets.all(16),
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                // Title
                const Center(
                  child: Text(
                    "Patient Recharge History",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Table Section
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Table(
                        border: TableBorder.all(
                          color: Colors.grey,
                          width: 1,
                        ),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        columnWidths: const {
                          0: FixedColumnWidth(70),
                          1: FixedColumnWidth(90),
                          2: FixedColumnWidth(60),
                          3: FixedColumnWidth(80),
                        },
                        children: [

                          // Header Row
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                            ),
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Center(child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Center(child: Text("Patient No", style: TextStyle(fontWeight: FontWeight.bold))),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Center(child: Text("Added Test", style: TextStyle(fontWeight: FontWeight.bold))),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Center(child: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
                              ),
                            ],
                          ),

                          // Data Rows
                          ...rechargeList.map((data) {
                            return TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Center(
                                    child: Text(
                                      (data["date"] ?? "")
                                          .toString()
                                          .split("_")[0],
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Center(
                                    child: Text(
                                      data["p_mob"] ?? "",
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Center(
                                    child: Text(
                                      data["add"]?.toString() ?? "0",
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Center(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        textStyle: const TextStyle(fontSize: 11),
                                      ),
                                      onPressed: () {
                                        _showRechargeDetails(data);
                                      },

                                      child: const Text("View"),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // _exportRechargeHistoryPDF(rechargeList);
                        _downloadAndSharePDF(() => _exportRechargeHistoryPDF(rechargeList));
                        // try {
                        //
                        //   // 🔹 Generate PDF
                        //   final file = await _exportRechargeHistoryPDF(rechargeList);
                        //
                        //   Navigator.pop(context); // remove loading
                        //
                        //   // 🔹 Show Confirmation Dialog
                        //   _showPDFDialog(file);
                        //
                        // } catch (e) {
                        //   Navigator.pop(context);
                        //   ScaffoldMessenger.of(context).showSnackBar(
                        //     const SnackBar(content: Text("Failed to generate PDF")),
                        //   );
                        // }
                      },
                      child: const Text("Export PDF"),
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

  void _showRechargeDetails(Map item) {

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Recharge Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text("Date: ${item["date"]}"),
            Text("Device ID: ${item["p_id"]}"),
            Text("Added: ${item["add"]}"),
            const Divider(),

            Text("Patient Old: ${item["p_Old"]}"),
            Text("Patient New: ${item["p_New"]}"),
            const SizedBox(height: 8),

            Text("Doctor Old: ${item["d_Old"]}"),
            Text("Doctor New: ${item["d_New"]}"),
            const SizedBox(height: 8),

            Text("Patient Mobile: ${item["p_mob"]}"),
            Text("Doctor Mobile: ${item["d_mob"]}"),
          ],
        ),
        actions: [

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Back"),
          ),

          ElevatedButton(
            onPressed: () {
              _downloadRechargePDF(item);
            },
            child: const Text("Download PDF"),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadRechargePDF(Map item) async {

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              pw.Text("Recharge Receipt",
                  style: pw.TextStyle(fontSize: 20)),

              pw.SizedBox(height: 20),

              pw.Text("Date: ${item["date"]}"),
              pw.Text("Device ID: ${item["p_id"]}"),
              pw.Text("Added: ${item["add"]}"),

              pw.SizedBox(height: 10),

              pw.Text("Patient Old: ${item["p_Old"]}"),
              pw.Text("Patient New: ${item["p_New"]}"),

              pw.SizedBox(height: 10),

              pw.Text("Doctor Old: ${item["d_Old"]}"),
              pw.Text("Doctor New: ${item["d_New"]}"),

              pw.SizedBox(height: 10),

              pw.Text("Patient Mobile: ${item["p_mob"]}"),
              pw.Text("Doctor Mobile: ${item["d_mob"]}"),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  Future<void> _exportRechargeHistoryPDF2(List<Map<String, dynamic>> data) async {

    if (data.isEmpty) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {

          return [
            pw.Center(
              child: pw.Text(
                "Doctor Recharge History",
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table.fromTextArray(
              headers: [
                "Date",
                "Device ID",
                "Added",
                "Patient Old",
                "Patient New",
                "Doctor Old",
                "Doctor New",
                "Patient Mobile",
                "Doctor Mobile"
              ],
              data: data.map((item) {
                return [
                  item["date"].toString(),
                  item["p_id"].toString(),
                  item["add"].toString(),
                  item["p_Old"].toString(),
                  item["p_New"].toString(),
                  item["d_Old"].toString(),
                  item["d_New"].toString(),
                  item["p_mob"].toString(),
                  item["d_mob"].toString(),
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              cellPadding: const pw.EdgeInsets.all(5),
            ),
          ];
        },
      ),
    );

    // Open share/print dialog
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  Future<File> _exportRechargeHistoryPDF(List<Map<String, dynamic>> historyList) async {
    final pdf = pw.Document();

    final formattedDate =
    DateFormat('dd/MM/yy hh:mm a').format(DateTime.now());

    final ttf = await PdfGoogleFonts.robotoRegular();

    // 🔹 Sort Latest First (based on date key)
    historyList.sort((a, b) {
      return (b["date"] ?? "").compareTo(a["date"] ?? "");
    });

    // 🔹 Calculate Total Added Tests
    int totalAdded = 0;
    for (var item in historyList) {
      totalAdded += int.tryParse(item["add"]?.toString() ?? "0") ?? 0;
    }
    final logo =
    await imageFromAssetBundle("assets/images/img.png");

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),

        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttf,
        ),

        // 🔹 HEADER
        header: (context) {
          return pw.Column(
            children: [

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(logo, width: 60, height: 60),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        widget.user.name ?? "Doctor Name",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text("Mobile: ${widget.user.mobile ?? ''}"),
                      pw.Text(
                        "Generated: $formattedDate",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),

              pw.Text(
                "Patient Recharge History",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 15),
            ],
          );
        },

        // 🔹 FOOTER
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        },

        // 🔹 BODY
        build: (context) => [

          pw.Table.fromTextArray(
            border: pw.TableBorder.all(),

            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
            const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellPadding: const pw.EdgeInsets.all(4),

            columnWidths: {
              0: const pw.FlexColumnWidth(1), // Date
              1: const pw.FlexColumnWidth(1), // Time
              2: const pw.FlexColumnWidth(1.3), // Patient
              3: const pw.FlexColumnWidth(2), // Device
              4: const pw.FlexColumnWidth(1),   // Added
              5: const pw.FlexColumnWidth(1),   // P Old
              6: const pw.FlexColumnWidth(1),   // P New
              7: const pw.FlexColumnWidth(1),   // D Old
              8: const pw.FlexColumnWidth(1),   // D New
            },

            headers: [
              "Date",
              "Time",
              "Patient",
              "Device",
              "Added Test",
              "Previous Patient Test",
              "Current Patient Test",
              "Previous Doctor Test",
              "Current Doctor Test",
            ],

            data: historyList.map((item) {

              String dateOnly = "";
              String timeOnly = "";
              final rawDate = item["date"] ?? "";

              if (rawDate.toString().contains("_")) {
                dateOnly = rawDate.toString().split("_")[0];
                timeOnly = rawDate.toString().split("_")[1];

              } else {
                dateOnly = rawDate.toString();
              }

              return [
                dateOnly,
                timeOnly,
                item["p_mob"] ?? "",
                item["p_id"] ?? "",
                item["add"]?.toString() ?? "0",
                item["p_Old"]?.toString() ?? "0",
                item["p_New"]?.toString() ?? "0",
                item["d_Old"]?.toString() ?? "0",
                item["d_New"]?.toString() ?? "0",
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 25),

          // 🔹 TOTAL SECTION
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Text(
                "Total Add Test's: $totalAdded",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final now = DateTime.now();
    final formatted = DateFormat('ddMMyyHHmm').format(now);

    final fileName = "patient_recharge_history_$formatted.pdf";

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/$fileName");

    await file.writeAsBytes(bytes);

    return file;
  }
}