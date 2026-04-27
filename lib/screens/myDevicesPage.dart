import 'dart:async';
import 'dart:io' ;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'testHistory.dart';
import 'user_model.dart';

import 'mydoctor.dart';
import 'myprofile.dart';
import 'test_count_screen.dart';
import 'package:intl/intl.dart';
import 'test_flow_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';//voice

class MyDevicesPage2 extends StatefulWidget {
  // final String userMobile;
  final UserModel user;
  // const MyDevicesPage2({super.key, required this.userMobile});
  const MyDevicesPage2({
    super.key,
    required this.user,
  });

  @override
  State<MyDevicesPage2> createState() => _MyDevicesPageState2();
}

class _MyDevicesPageState2 extends State<MyDevicesPage2> {
  final dbRef = FirebaseDatabase.instance.ref();
  FlutterTts tts = FlutterTts();  //voice
  bool isMuted = false; //voice
  String selectedLang = "en-IN"; // default voice
  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;
  StreamSubscription<List<int>>? _notifySub;

  bool _isLoading = false;
  bool _busy = false;
  bool _isConnecting = false;

  String selectedDeviceId = "";
  String _rxBuffer = "";

  // Make sure you have these maps in your state:
  Map<String, String?> deviceResult = {}; // shows processing/result text
  Map<String, int> deviceStage = {};

  final Map<String, int> _previousCounts = {};
  List<Map<String, dynamic>> updatedNewTest = [];
  StreamSubscription<DatabaseEvent>? _deviceListener;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Set<String> _syncingDevices = {};
  Map<String, DateTime> _lastSyncAttempt = {};
  List<Map<String, dynamic>> pendingResults = [];

  // In your state
  Set<String> readyDevices = {}; // devices ready to send A2
  // TestState testState = TestState.idle;

  final Guid serviceUuid = Guid("000000FF-0000-1000-8000-00805F9B34FB");
  final Guid rxUuid = Guid("0000FF01-0000-1000-8000-00805F9B34FB");
  final Guid txUuid = Guid("0000FF02-0000-1000-8000-00805F9B34FB");

  @override
  void initState() {
    super.initState();
    _warmupBluetooth(); // 🔥 ADD THIS
    _initPermissions(); //ok
    _startupValidation(); //ok
    // _loadPendingUpdates();
    _listenToDevices();

    tts.setLanguage("en-IN"); //voice
    tts.setSpeechRate(0.45); //voice
    tts.setPitch(1.0); //voice
    // syncPendingResults();
  }

  /* -------------------- STARTUP VALIDATION -------------------- */
  Future<void> _initPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }
  }

  Future<void> _startupValidation() async {
    _setLoading(true);

    bool hasInternet = await _checkInternetConnection();

    if (!hasInternet) {
      _setLoading(false);
      _showPopup("No Internet", "Please check your internet connection.");
      return;
    }

    final snapshot =
    await dbRef.child("Devices/${widget.user.mobile}").get();

    if (!snapshot.exists) {
      _setLoading(false);
      _showPopup("No Devices", "No devices found for this user.");
      return;
    }

    _setLoading(false);
    _listenToDevices();
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty &&
          result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncPendingResults() async {
    for (var item in List.from(pendingResults)) {
      try {
        await dbRef
            .child("Result/${widget.user.mobile}/${item["key"]}")
            .set(item);

        pendingResults.remove(item);
        print("Synced: ${item["key"]}");
      } catch (e) {
        print("Still failed: ${item["key"]}");
      }
    }
  }
  Color getTestColor(int count) {
    if (count <= 0) {
      return Colors.red;        // ❌ No balance
    } else if (count < 6) {
      return Colors.orange;     // ⚠️ Low balance
    } else {
      return Colors.green;      // ✅ Good balance
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDoctor = widget.user.type == "doctor";

    final historyTitle = isDoctor ? "Test Count’s" : "Test History";
    final doctorTitle = isDoctor ? "My Patient" : "My Doctor";
    final historyIcon = isDoctor ? Icons.account_balance_wallet : Icons.history;
    final doctorIcon = isDoctor ? Icons.groups : Icons.person;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),

          onPressed: () async {
            final selected = await showMenu<String>(
              context: context,
              position: const RelativeRect.fromLTRB(0, 80, 0, 0),
              items: [
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

                PopupMenuItem(
                  value: "doctor",
                  child: Row(
                    children: [
                      Icon(doctorIcon, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(doctorTitle,
                          style: const TextStyle(color: Colors.black)),
                    ],
                  ),
                ),

                const PopupMenuItem(
                  value: "profile",
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.black),
                      SizedBox(width: 8),
                      Text("My Profile",
                          style: TextStyle(color: Colors.black)),
                    ],
                  ),
                ),

                PopupMenuItem(
                  value: "Sound",
                  child: Row(
                    children: [
                      Icon(
                        isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isMuted ? "Sound OFF" : "Sound ON",
                        style: const TextStyle(color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (selected == null) return;

            if (selected == "home") {
              Navigator.pushNamed(context, "/home");
            }
            else if (selected == "history") {
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


            else if (selected == "doctor") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MyDoctorPage(
                        user: widget.user,
                      ),
                ),
              );
            }
            else if (selected == "profile") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MyProfileScreen(
                        user: widget.user,
                      ),
                ),
              );
            }
            else if (selected == "Sound") {
              setState(() {
                isMuted = !isMuted;
              });

              if (!isMuted) {
                await speak("Sound enabled");
              } else {
                await speak("Sound disabled");
              }
            }
          },
        ),
        title: const Text(
          "My Device ",
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.blue),
                onPressed: () {
                  _showDeviceScanPopup();
                },
              ),
            ),
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
            child: StreamBuilder(
              stream: dbRef
                  .child("Devices/${widget.user.mobile}")
                  .onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return const Center(
                    child: Text("No Device Found",
                        style: TextStyle(color: Colors.white)),
                  );
                }

                final data = snapshot.data!.snapshot.value as Map<dynamic,dynamic>;
                final keys = data.keys.toList();
                // In ListView.builder
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: keys.length,
                  itemBuilder: (context, i) {
                    final key = keys[i];
                    final device = data[key];

                    final status = device["st"] ?? "Inactive";
                    final testCount = device["testCount"] ?? 0;
                    final mac = device["mac"] ?? "";
                    final active = status.toLowerCase() == "active";

                    return InkWell(

                      onTap: () async {
                        if (!active) {
                          await speak("Device is not active. Please contact C E M D support");
                          _showPopup("Status", "Please contact CEMD");
                          return;
                        }
                        if (testCount <= 0) {
                          await speak("No tests remaining. Please recharge");
                          _showPopup("Status", "Please Recharge");
                          return;
                        }
                        // ⚠️ If test count < 5 → show warning
                        if (testCount < 6) {
                          await speak("Warning Low balance. Only $testCount tests remaining or left.");
                          bool? proceed = await _showConfirmDialogLOW(
                            "Low Balance",
                            testCount,
                          );

                          // if (proceed != true) return; // user cancelled
                          if (proceed != true) {
                            await speak("Test cancelled");
                            return;
                          }

                          await speak("Starting test");
                        }
                            final now = DateTime.now();
                            // Format date → ddMMyy
                            String date =
                                "${now.day.toString().padLeft(2, '0')}"
                                "${now.month.toString().padLeft(2, '0')}"
                                "${now.year.toString().substring(2)}";

                            // Format time → HH:mm:ss
                            String time =
                                "${now.hour.toString().padLeft(2, '0')}"
                                "${now.minute.toString().padLeft(2, '0')}"
                                "${now.second.toString().padLeft(2, '0')}";

                        String dis = widget.user.disease;

                        if (widget.user != null) {
                          if (widget.user.disease == null || widget.user.disease.isEmpty) {
                            // If no disease → fallback based on type
                            if (widget.user.type == "doctor") {
                              dis = "doct";
                            } else if (widget.user.type == "admin") {
                              dis = "admi";
                            }
                          }
                        }
                            // 🟢 Send patient details to ESP32
                        String patientData =
                            "#SET:PATIENT:${widget.user.mobile},${widget.user
                            .gender},${widget.user.age},$dis,$date,$time";
                        //
                        //     // setState(() {
                        //     //   deviceResult[key] = "Processing start...";
                        //     //   deviceStage[key] = 1; // 🔥 SHOW LOADER
                        //     //   testState = TestState.waitingPatientSave;
                        //     // });
                            await _disconnectClean();
                            await _connectSendAndRead(mac, key, patientData);
                        //     // return; // ⛔ wait for ESP32 response
                        //     break;
                        //
                        //   // case TestState.testStarted:
                        //   // // 👉 SECOND TAP → GET RESULT
                        //   //   setState(() {
                        //   //     deviceResult[key] = "Getting result...";
                        //   //     deviceStage[key] = 1; // 🔥 loader again
                        //   //     testState = TestState.waitingResult;
                        //   //   });
                        //   //
                        //   //   await _connectSendAndRead(mac, key, "a2");
                        //   //   break;
                        //   //
                        //   // default:
                        //   // // Ignore taps in other states
                        //   //   break;
                        //
                        //
                        // }


                        await Future.delayed(const Duration(seconds: 2));

                        // setState(() {
                        //   deviceStage[key] = 0;
                        //   deviceStage[selectedDeviceId] = 0; // 🔥 CLEAR UI
                        //   deviceResult[key] = null;
                        // });
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Single left-side box

                              SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: () {
                                    final stage = deviceStage[key] ?? 0;
                                    if (stage == 1) {
                                      return const CircularProgressIndicator(
                                        color: Colors.blue,
                                        strokeWidth: 3,
                                      );
                                    } else if (stage == 2) {
                                      return const Icon(Icons.science, color: Colors.blue);
                                    } else {
                                      return const SizedBox.shrink();
                                    }
                                  }(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Device info + result
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Device: $key"),
                                    const SizedBox(height: 6),
                                    Text(
                                      active
                                          ? "Active | Remaining: $testCount"
                                          : "Inactive",
                                      style: TextStyle(
                                        color: active
                                          ? getTestColor(testCount) // 🔥 dynamic color
                                       : Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (deviceResult[key] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          deviceResult[key]!,
                                          style: const TextStyle(color: Colors.orange),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
                //   },
                // );
              },
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Connecting with device…",
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _checkTestCountChange(String deviceId, int currentTestCount,String status, String mac) async {
    if (status.toLowerCase() != "active") return;

    final previous = _previousCounts[deviceId];

    if (previous == null) {
      _previousCounts[deviceId] = currentTestCount;
      return;
    }

    final difference = (previous - currentTestCount).abs();

    if (difference > 1) {
      _showPopup(
        "Test Count Updated",
        "Device: $deviceId\nPrevious Test : $previous\nCurrent Test : $currentTestCount",
      );

      // bool sent = await _sendTestCountToDevice(deviceId, currentTestCount);
      //
      // if (!sent) {
      //   // Only add to retry list if sending failed
      //   _addOrUpdateDevice(deviceId, currentTestCount);
      //   print("Added to retry list: $updatedNewTest");
      //
      //   if (_scanSub == null) {
      //     _startScanning();
      //   }
      // } else {
      //   print("Sync success immediately");
      // }
    }

    _previousCounts[deviceId] = currentTestCount;
  }

  Future<void> _connectSendAndRead(String mac, String deviceName,String cmd) async {
    if (_busy || _isConnecting) return;

    _busy = true;
    _setLoading(true);

    selectedDeviceId = deviceName;
    _rxBuffer = "";

    try {
      await _disconnectClean(); // 🔥 fix
      await _connectToDevice(mac, deviceName);
      // await _discoverServices();
      await _sendCommand(cmd);
    } catch (e) {
      print("Error" + e.toString());
      _showPopup("Error",
          "Device not found.\nPlease check if the device is available and turned on.");
      await _disconnect();
    }
    _setLoading(false);
    _busy = false;
  }

  Future<void> _connectToDevice(String mac, String deviceName) async {
    if (_isConnecting) return;
    _isConnecting = true;
    await FlutterBluePlus.stopScan();
    try {
      // final state = await FlutterBluePlus.adapterState.first;
      // if (state != BluetoothAdapterState.on) {
      //   _showPopup("Bluetooth Off", "Please turn on Bluetooth.");
      //   return;
      // }

      final state = await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw Exception("Bluetooth not ready");
      });
      if (state != BluetoothAdapterState.on) {
          _showPopup("Bluetooth Off", "Please turn on Bluetooth.");
          return;
        }
      if (_device != null) {
        try {
          await _device!.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (_) {}
      }
      if (Platform.isIOS) {
        // BluetoothDevice? foundDevice;
        //         //
        //         // await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
        //         //
        //         // await for (final results in FlutterBluePlus.scanResults) {
        //         //   for (final r in results) {
        //         //     if (r.device.name == deviceName || r.device.advName == deviceName) {
        //         //       foundDevice = r.device;
        //         //       break;
        //         //     }
        //         //   }
        //         //   if (foundDevice != null) break;
        //         // }
        //         //
        //         // await FlutterBluePlus.stopScan();
        //         //
        //         // if (foundDevice == null) {
        //         //   throw Exception("Device not found");
        //         // }
        //         //
        //         // _device = foundDevice;

        BluetoothDevice? foundDevice;

        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

        _scanSub?.cancel();

        _scanSub = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            final name = r.device.platformName.isNotEmpty
                ? r.device.platformName
                : r.advertisementData.localName;

            // if (name == deviceName) {
            if (name.isNotEmpty && name.contains(deviceName)){
              foundDevice = r.device;
              break;
            }
          }
        });

        await Future.delayed(const Duration(seconds: 5));
        await FlutterBluePlus.stopScan();
        await _scanSub?.cancel();

        if (foundDevice == null) {
          throw Exception("Device not found");
        }

        _device = foundDevice;
      } else {
        _device = BluetoothDevice.fromId(mac);
      }

      // await _device!.connect(
      //   license: License.commercial,
      //   timeout: const Duration(seconds: 12),
      //   autoConnect: false,
      // );
      try {
        await _device!.connect(
          license: License.commercial,
          timeout: const Duration(seconds: 12),
          autoConnect: false,
        );
      } catch (e) {
        print("Retry connect...");
        await Future.delayed(const Duration(seconds: 1));

        await _device!.connect(
          license: License.commercial,
          timeout: const Duration(seconds: 12),
          autoConnect: false,
        );
      }
      // 🔥 ADD THIS
      await Future.delayed(const Duration(milliseconds: 200));
      await _discoverServices();
    } catch (e) {
      _showPopup("Connection Error", "Device not found or unreachable.");
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _discoverServices() async {
    final services = await _device!.discoverServices();

    final service = services.firstWhere((s) => s.uuid == serviceUuid);

    _rxChar = service.characteristics.firstWhere((c) => c.uuid == rxUuid);

    _txChar = service.characteristics.firstWhere((c) => c.uuid == txUuid);
    await _notifySub?.cancel();
    await _txChar!.setNotifyValue(true);
    _notifySub = _txChar!.lastValueStream.listen(_onDataReceived);
  }

  Future<void> _sendCommand(String command) async {
    final cmd = "$command\r\n";
    await _rxChar!.write(
      Uint8List.fromList(cmd.codeUnits),
      withoutResponse: _rxChar!.properties.writeWithoutResponse,
    );
  }

  Future<void> _onDataReceived(List<int> data) async {
    final chunk = String.fromCharCodes(data);
    _rxBuffer += chunk;

    if (_rxBuffer.contains("\n")) {
      final rawResult = _rxBuffer.trim();
      _rxBuffer = "";

      print("Device RESPONSE => [$rawResult]");

      // 🔥 1️⃣ Handle Stored Counter FIRST
      if (rawResult.contains("Stored Counter")) {
        print("Counter stored successfully on device");

        await _disconnectClean();

        return; // 🚫 absolutely stop
      }

      if (rawResult.contains("PATIENT_SAVED")) {

        if (!mounted) return;

        await speak(
            "Before starting the test, please follow all instructions carefully. "
                "Make sure the device is charged, not connected to charging, "
                "cuvette is clean, reagent is available, and sample is prepared properly. "
                "Do you want to start the test now?"
        );
        bool? confirmSteps = await _showConfirmDialog(
            "⚠️Pre-Test Preparation"," please confirm:\n\n"
            "•Make sure the device is fully charged and turned on.\n"
            "•Do not perform the test while the device is charging.\n"
            "•Ensure the cuvette is clean before starting the test.\n"
            "•Confirm that enough reagent is available.\n"
            "•Make sure the sample is properly collected and prepared.\n"
            "•Place the device on a stable surface before starting the test.\n\n"
            "Do you want to start the test now?"
        );

        if (confirmSteps == true) {
            tts.stop();
          // ✅ Store MAC first
          final device = _device; // ✅ store full object safely

          if (device == null) {
            print("Device is null, cannot navigate");
            return;
          }

          print("MAC before disconnect: ${device.remoteId.str}");

          await _disconnectClean();

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TestFlowScreen(
                device: device, // ✅ use stored device
                user: widget.user,
                deviceId: selectedDeviceId, // 🔥 PASS KEY HERE
              ),
            ),
          );
        }

        return;
      }


      // ✅ Patient saved response
      // if (rawResult.toLowerCase().contains("patient save")) {
      //
      //   if (!mounted) return;
      //
      //   bool? confirmSteps = await _showConfirmDialog(
      //     "Instructions",
      //     "Before test:\n\n"
      //         "• Take cuvette\n"
      //         "• Add 3ml urine\n"
      //         "• Add 5 drops reagent\n"
      //         "• Mix 3 times\n"
      //         "• Close cap & clean\n\n"
      //         "Have you followed all steps?",
      //   );
      //
      //   // if (confirmSteps == true) {
      //   //   setState(() {
      //   //     deviceResult[selectedDeviceId] = "Starting test...";
      //   //     deviceStage[selectedDeviceId] = 1; // still loading
      //   //     testState = TestState.waitingTestStart;
      //   //   });
      //   //
      //   //   await _connectSendAndRead(_device!.remoteId.str, selectedDeviceId, "#startProtineTest");
      //   // } else {
      //   //   testState = TestState.idle;
      //   // }
      //
      //   return;
      // }

      // if (rawResult.toLowerCase().contains("test start")) {
      //
      //   setState(() {
      //     deviceResult[selectedDeviceId] = "Test running...";
      //     deviceStage[selectedDeviceId] = 2; // 🔥 SHOW ICON
      //     testState = TestState.testStarted;
      //   });
      //
      //   _showPopup(
      //     "Test Started",
      //     "If long beep then tap again to get result",
      //   );
      //
      //   return;
      // }

      // ✅ NEW RESULT FORMAT
      // else if (rawResult.contains("#TEST,RESULT,P,")) {
      //   final parts = rawResult.split(",");
      //
      //   if (parts.length >= 5) { // 🔥 yaha fix hai
      //     final type = parts[2].trim();
      //     final value = parts[3].trim(); // 02.1 mg/100ml
      //     final level = parts[4].trim(); // 0.001333
      //     // final count = int.tryParse(parts[5].trim()) ?? 0; // 35
      //
      //     // 🔥 Title decide karo based on type
      //     String title = "Test Result";
      //
      //     if (type == "P") {
      //       title = "Protein Test Result";
      //     }
      //
      //
      //     int updatedCount = 0;
      //     updatedCount = await _decreaseTestCount();
      //
      //     print("✅ Updated Test Count: $updatedCount");
      //
      //     final finalResult = "$value,$level,$updatedCount";
      //     // optional DB save
      //     bool saved = await _updateResultDB(value, level, updatedCount);
      //
      //     if (saved) {
      //       if (!mounted) return;
      //
      //       _showPopup(title, finalResult);
      //
      //       await _disconnectClean();
      //     }
      //     else
      //     {
      //
      //     }
      //
      //     // 🔥 RESET EVERYTHING
      //     setState(() {
      //       testState = TestState.idle;
      //       deviceResult[selectedDeviceId] = null;
      //     });
      //     return;
      //   }
      // }

      String displayResult = rawResult;
      String refcesValue = "";

      // 🔹 No Data Found
      if (rawResult == "No Data Found") {
        displayResult = "No Data Found";
      }


      // 🔹 Only treat as test result if format is EXACTLY like Result_Value
      else if (rawResult.contains("_") &&!rawResult.contains("Stored Counter")) {
        final parts = rawResult.split("_");

        displayResult = parts[0].trim();
        refcesValue = parts.length > 1 ? parts[1].trim() : "";

        // await _updateResultDB(displayResult, refcesValue);
        // await _decreaseTestCount(); // 🔥 decrease only here
        int count = int.tryParse(parts[2].trim()) ?? 0;

        // await _updateResultDB(result, ref, count);

        bool saved = await _updateResultDB(displayResult, refcesValue, count);

        if (saved) {
          // _showPopup("Success", "Result saved successfully.");
          await _decreaseTestCount();
        } else {
          _showPopup("Error", "Failed to save result.");
        }
      }

      await _disconnectClean();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            AlertDialog(
              title: const Text("Test Result all"),
              content: Text(displayResult),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _disconnectClean() async {
    try {
      await _notifySub?.cancel();
      // await _txChar?.setNotifyValue(false);
      // await _device?.disconnect();
      if (_txChar != null) {
        await _txChar!.setNotifyValue(false);
      }

      if (_device != null) {
        await _device!.disconnect();
        // 🔥 WAIT until actually disconnected
        await _device!.connectionState
            .where((state) => state == BluetoothConnectionState.disconnected)
            .first;
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {}

    _device = null;
    _rxChar = null;
    _txChar = null;
  }

  Future<int> _decreaseTestCount() async {
    final ref = dbRef.child(
        "Devices/${widget.user.mobile}/$selectedDeviceId/testCount");

    int newValue = 0;

    await ref.runTransaction((current) {
      if (current == null) {
        newValue = 0;
        return Transaction.success(0);
      }

      final val = (current as num).toInt();
      newValue = val > 0 ? val - 1 : 0;

      return Transaction.success(newValue);
    });

    return newValue; // 🔥 important
  }

  Future<bool> _updateResultDB(String result, String refValue,int count) async {
    final now = DateTime.now();
    // final key =
    //     "${now.day}-${now.month}-${now.year}_${now.hour}:${now.minute}:${now
    //     .second}";

    final key = DateFormat('dd-MM-yy_HH:mm:ss').format(now);

    final data = {
      "key": key,
      "id": selectedDeviceId,
      "result": result,
      "volt": refValue,
      "count": count,
    };

    try {
      await dbRef.child("Result/${widget.user.mobile}/$key").set(data);
      print("Result saved successfully");
      return true;
    } catch (e) {
      print("Error saving result: $e");

      // Save locally in list
      pendingResults.add(data);

      print("Saved locally in pending list");
      return false;
    }
  }

  Future<void> _disconnect() async {
    await _notifySub?.cancel();
    if (_txChar != null) {
      await _txChar!.setNotifyValue(false);
    }
    await _device?.disconnect();

    _device = null;
    _rxChar = null;
    _txChar = null;
  }

  void _showPopup(String title, String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                )
              ],
            ),
      );
    });
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => _isLoading = value);
  }

  Future<void> _saveDeviceToFirebase(String deviceID, String mac) async {
    final now = DateTime.now();
    // Format date → ddMMyy
    String date =
        "${now.day.toString().padLeft(2, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.year.toString().substring(2)} ";

    // Format time → HH:mm:ss
    // String time =
    "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}:"
        "${now.second.toString().padLeft(2, '0')}";
    await dbRef.child("Devices/${widget.user.mobile}/$deviceID").set({
      "dt" : date,
      "st": "Inactive",
      "testCount": 0,
      "mac": mac,
    });
  }

  void _showDeviceScanPopup() {
    List<ScanResult> found = [];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Search SCINTIGLO Devices"),
          content: SizedBox(
            height: 500,
            child: FutureBuilder(
              future: FlutterBluePlus.startScan(
                  timeout: const Duration(seconds: 8)),
              builder: (_, __) {
                FlutterBluePlus.scanResults.listen((results) {
                  for (var r in results) {
                    final name = r.device.name;
                    if (name.startsWith("SCINPY") &&
                        !found.any((d) =>
                        d.device.remoteId == r.device.remoteId)) {
                      found.add(r);
                    }
                  }
                });

                return ListView.builder(
                  itemCount: found.length,
                  itemBuilder: (_, i) {
                    final r = found[i];
                    return ListTile(
                      title: Text(r.device.name),
                      subtitle: Text(r.device.remoteId.str),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _saveDeviceToFirebase(
                            r.device.name, r.device.remoteId.str);
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _addOrUpdateDevice(String deviceName, int newCount) {
    final index = updatedNewTest.indexWhere((d) => d["deviceId"] == deviceName);

    if (index != -1) {
      updatedNewTest[index]["testCount"] = newCount;
    } else {
      updatedNewTest.add({
        "deviceId": deviceName,
        "testCount": newCount,
      });
    }
  }

  Future<void> syncUpdatedDevices() async {
    if (updatedNewTest.isEmpty) {
      print("No devices to sync");
      return;
    }
    _setLoading(true);
    try {
      final List<Map<String, dynamic>> devicesToProcess = List.from(
          updatedNewTest);

      for (var device in devicesToProcess) {
        final deviceId = device["deviceId"];
        final testCount = device["testCount"];

        // bool sent = await _sendTestCountToDevice(deviceId, testCount);
        //
        // if (sent) {
        //   updatedNewTest.removeWhere((d) => d["deviceId"] == deviceId);
        //   print("$deviceId synced and removed");
        // } else {
        //   print("$deviceId not available");
        // }
      }
    } finally {
      _setLoading(false);
    }

    print("Remaining Devices: $updatedNewTest");
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    _device?.disconnect();
    _deviceListener?.cancel();
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    tts.stop(); //voice
    super.dispose();
  }

  Future<void> speak(String text) async {
    if (isMuted) return; // 🔥 mute control
    await tts.stop(); // 🔥 previous voice stop
    await tts.setLanguage(selectedLang); // 🔥 dynamic language
    await tts.speak(text);
  }


  void _listenToDevices() {
    final devicesRef = dbRef.child("Devices").child(widget.user.mobile);

    _deviceListener = devicesRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      for (var entry in data.entries) {
        final deviceId = entry.key;
        final device = Map<String, dynamic>.from(entry.value);

        final status = (device["st"] ?? "Inactive").toString();
        final testCount = (device["testCount"] ?? 0) as int;
        final mac = device["mac"] ?? "";

        if (status.toLowerCase() != "active") continue;

        _checkTestCountChange(deviceId, testCount, status, mac);
      }
    });
  }

  Future<int?> getLatestOldTestCount(String deviceId) async {
    final resultRef = dbRef.child("Result").child(widget.user.mobile);

    final snapshot = await resultRef.get();
    if (!snapshot.exists) return null;

    final data = Map<String, dynamic>.from(snapshot.value as Map);

    DateTime? latestDate;
    int? latestCount;

    data.forEach((dateKey, value) {
      final item = Map<String, dynamic>.from(value);

      if (item["id"] == deviceId) {
        final parsedDate = _parseCustomDate(dateKey);

        if (latestDate == null || parsedDate.isAfter(latestDate!)) {
          latestDate = parsedDate;
          latestCount = (item["count"] as num).toInt();
        }
      }
    });

    return latestCount;
  }

  DateTime _parseCustomDate(String key) {
    final parts = key.split('_');
    final date = parts[0].split('-');
    final time = parts[1].split(':');

    return DateTime(
      2000 + int.parse(date[2]),
      int.parse(date[1]),
      int.parse(date[0]),
      int.parse(time[0]),
      int.parse(time[1]),
      int.parse(time[2]),
    );
  }

  Future<bool> _sendTestCountToDevice(String deviceId, int testCount) async {
    try {
      await _disconnect();
      final deviceSnap = await dbRef
          .child("Devices")
          .child(widget.user.mobile)
          .child(deviceId)
          .get();

      if (!deviceSnap.exists) return false;

      final mac = deviceSnap
          .child("mac")
          .value
          .toString();

      String formattedCount = testCount.toString().padLeft(3, '0');
      String command = "\$$formattedCount";


      await _connectToDevice(mac, deviceId);
      await _sendCommand(command);
      print("Sync success → $deviceId : $command");
      return true;
    } catch (e) {
      print("Sync failed: $e");
      return false;
    } finally {
      await _disconnect();
    }
  }

  // void _startScanning() {
  //   if (_scanSub != null) return;
  //
  //   FlutterBluePlus.startScan();
  //
  //   _scanSub = FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
  //     for (ScanResult result in results) {
  //       String name = result.device.platformName;
  //       if (name == '') name = result.advertisementData.localName ?? '';
  //       if (!name.startsWith('SCINPY')) continue;
  //
  //       final index = updatedNewTest.indexWhere((d) => d['deviceId'] == name);
  //       if (index == -1) continue;
  //       if (_syncingDevices.contains(name)) continue;
  //
  //       final last = _lastSyncAttempt[name];
  //       if (last != null &&DateTime.now().difference(last) < const Duration(seconds: 30)) continue;
  //
  //       _lastSyncAttempt[name] = DateTime.now();
  //       _syncingDevices.add(name);
  //
  //       final count = updatedNewTest[index]['testCount'] as int;
  //
  //       _sendTestCountToDevice(name, count).then((bool success) {
  //         _syncingDevices.remove(name);
  //         if (success) {
  //           updatedNewTest.removeAt(index);
  //           _showPopup("Sync Success", "Test count updated for $name");
  //           if (updatedNewTest.isEmpty) {
  //             _stopScanning();
  //           }
  //         }
  //       });
  //     }
  //   });
  // }
  //
  // void _stopScanning() {
  //   _scanSub?.cancel();
  //   _scanSub = null;
  //   FlutterBluePlus.stopScan();
  // }

  // Future<bool?> _showConfirmDialog(String title, String message) {
  //   return showDialog<bool>(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: Text(title),
  //         content: Text(message),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context, false),
  //             child: const Text("No"),
  //           ),
  //           ElevatedButton(
  //             onPressed: () => Navigator.pop(context, true),
  //             child: const Text("Yes"),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }


  // Future<bool?> _showConfirmDialog(String title, String message) {
  //   return showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) {
  //       return AlertDialog(
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(14),
  //         ),
  //
  //         // ✅ CENTER TITLE (single line)
  //         title: Text(
  //           title,
  //           textAlign: TextAlign.center,
  //           maxLines: 1,
  //           overflow: TextOverflow.ellipsis,
  //           style: const TextStyle(
  //             fontWeight: FontWeight.w600,
  //           ),
  //         ),
  //
  //         content: SingleChildScrollView(
  //           child: Text(
  //             message.trim(),
  //             style: const TextStyle(fontSize: 14, height: 1.4),
  //           ),
  //         ),
  //
  //         // ❗ custom alignment for buttons
  //         actionsPadding:
  //         const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  //
  //         actions: [
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ left-right
  //             children: [
  //               TextButton(
  //                 onPressed: () => Navigator.pop(context, false),
  //                 child: const Text("Cancel"),
  //               ),
  //
  //               ElevatedButton(
  //                 onPressed: () => Navigator.pop(context, true),
  //                 child: const Text("Confirmed"),
  //               ),
  //             ],
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  Future<bool?> _showConfirmDialogLOW(String title, int testCount) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.black, fontSize: 14),
              children: [
                const TextSpan(text: "Your test balance is low ("),
                TextSpan(
                  text: "$testCount",
                  style: TextStyle(
                    color: getTestColor(testCount), // 🔥 dynamic color
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: " left). Do you want to continue?"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );
  }
  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),

          // 🔴 TITLE (center + proper fit)
          title: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),

          // 📄 CONTENT
          content: SingleChildScrollView(
            child: Text(
              message.trim(),
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5, // ✅ better spacing
              ),
            ),
          ),

          // 🔘 BUTTONS (left-right)
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Start Test"),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _warmupBluetooth() async {
    try {
      await FlutterBluePlus.adapterState.first;
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}
  }
}
