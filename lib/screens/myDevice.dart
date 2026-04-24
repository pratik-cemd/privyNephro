import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class MyDevicesPage extends StatefulWidget {
  final String userMobile;
  const MyDevicesPage({super.key, required this.userMobile});

  @override
  State<MyDevicesPage> createState() => _MyDevicesPageState();
}

class _MyDevicesPageState extends State<MyDevicesPage> {
  final dbRef = FirebaseDatabase.instance.ref();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;
  StreamSubscription<List<int>>? _notifySub;

  String _rxBuffer = "";
  int _crCount=0;
  bool _busy = false;
  bool _isLoading = false;

  // UUIDs (must match ESP32)
  final Guid serviceUuid = Guid("000000FF-0000-1000-8000-00805F9B34FB");
  final Guid rxUuid = Guid("0000FF01-0000-1000-8000-00805F9B34FB");
  final Guid txUuid = Guid("0000FF02-0000-1000-8000-00805F9B34FB");

  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

  Future<void> _initPermissions() async {
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.location.request();


  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Device BLE3",
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
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
              stream: dbRef.child("Devices/${widget.userMobile}").onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return const Center(
                    child: Text(
                      "No Device Found",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final data =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final keys = data.keys.toList();

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
                          _showPopup("Status", "Please contact CEMD");
                          return;
                        }
                        if (testCount <= 0) {
                          _showPopup("Status", "Please Recharge");
                          return;
                        }
                        // await _connectSendAndRead(mac);
                        await _connectSendAndRead2(mac, key);
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
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
                                  color:
                                  active ? Colors.green : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
// // 🔥 LOADING OVERLAY (THIS WAS MISSING)
//           if (_isLoading)
//             Container(
//               color: Colors.black.withOpacity(0.4),
//               child: const Center(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     CircularProgressIndicator(color: Colors.white),
//                     SizedBox(height: 16),
//                     Text(
//                       "Communicating with device…",
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

        ],
      ),
    );
  }

  // ---------------- MAIN FLOW ----------------

  Future<void> _connectSendAndRead(String mac) async {
    if (_busy) return;
    _busy = true;
    _rxBuffer = "";


    try {
      await _connectByMac(mac);
      await _discoverServices();
      // _setLoading(true); // 👈 here
      await _sendCommand();


    } catch (e) {
      // _hideLoading();
      _setLoading(false);
      _busy = false;
      _showPopup("Error", e.toString());
      await _disconnectClean();
    }
  }

  Future<void> _connectSendAndRead2(String mac, String deviceName) async {
    if (_busy) return;
    _busy = true;
    _rxBuffer = "";
    _setLoading(true);

    try {
      await _connectByMac2(mac, deviceName);
      await _discoverServices();
      await _sendCommand();
    } catch (e) {
      _showPopup("Error", e.toString());
      await _disconnectClean();
    }
  }
  // ---------------- CONNECT ----------------

  Future<void> _connectByMac(String mac) async {
    _device = BluetoothDevice.fromId(mac);
    try {
      await _device!.connect(
        license: License.commercial,
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
    } catch (_) {
      // ignore already-connected error
    }
  }

  Future<void> _connectByMac2(String mac, String deviceName) async {
    final isIOS =
        Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      BluetoothDevice? foundDevice;

      FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      await for (final results in FlutterBluePlus.scanResults) {
        for (ScanResult r in results) {
          if (r.device.name == deviceName) {
            foundDevice = r.device;
            break;
          }
        }
        if (foundDevice != null) break;
      }

      await FlutterBluePlus.stopScan();

      if (foundDevice == null) {
        throw Exception("Device not found");
      }

      _device = foundDevice;
    } else {
      _device = BluetoothDevice.fromId(mac);
    }

    await _device!.connect(
      license: License.commercial,
      autoConnect: false,
      timeout: const Duration(seconds: 10),
    );

    await _device!.requestMtu(185);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // ---------------- GATT ----------------

  Future<void> _discoverServices2() async {
    final services = await _device!.discoverServices();

    final service =
    services.firstWhere((s) => s.uuid == serviceUuid);

    _rxChar =
        service.characteristics.firstWhere((c) => c.uuid == rxUuid);  // WRITE

    _txChar =
        service.characteristics.firstWhere((c) => c.uuid == txUuid);  // NOTIFY

    await _txChar!.setNotifyValue(true);
    // //
    // await Future.delayed(const Duration(milliseconds: 500));

    // // Enable notifications on RX (required for iOS)
    // await _rxChar!.setNotifyValue(true);

    // iOS needs time here
    await Future.delayed(const Duration(milliseconds: 500));

    _notifySub?.cancel();
    _notifySub = _txChar!.value.listen(_onDataReceived);
    // _notifySub = _rxChar!.value.listen(_onDataReceived); // ✅ CORRECT
  }

  // Future<void> _discoverServices() async {
  //   final services = await _device!.discoverServices();
  //
  //   for (var service in services) {
  //     if (service.uuid == serviceUuid) {
  //       for (var c in service.characteristics) {
  //         if (c.uuid == rxUuid) {
  //           _rxChar = c;
  //         }
  //         if (c.uuid == txUuid) {
  //           _txChar = c;
  //         }
  //       }
  //     }
  //   }
  //
  //   if (_txChar == null || _rxChar == null) {
  //     throw Exception("Characteristics not found");
  //   }
  //
  //   // IMPORTANT: iOS requires notify first
  //   await _txChar!.setNotifyValue(true);
  //
  //   await Future.delayed(const Duration(milliseconds: 500));
  //
  //   _notifySub?.cancel();
  //   _notifySub = _txChar!.lastValueStream.listen(_onDataReceived);
  // }

  Future<void> _discoverServices() async {
    if (_device == null) throw Exception("No device");

    final services = await _device!.discoverServices();

    BluetoothService? targetService;
    for (var s in services) {
      if (s.uuid == serviceUuid) {
        targetService = s;
        break;
      }
    }

    if (targetService == null) {
      throw Exception("Service $serviceUuid not found");
    }

    BluetoothCharacteristic? rx;
    BluetoothCharacteristic? tx;

    for (var c in targetService.characteristics) {
      if (c.uuid == rxUuid) rx = c;
      if (c.uuid == txUuid) tx = c;
    }

    if (rx == null || tx == null) {
      throw Exception("RX or TX characteristic missing");
    }

    _rxChar = rx;
    _txChar = tx;

    // ──────────────────────────────────────────────
    // VERY IMPORTANT FOR iOS
    // ──────────────────────────────────────────────
    await _txChar!.setNotifyValue(true);

    // Give CoreBluetooth time to enable notifications (critical on iOS)
    await Future.delayed(const Duration(milliseconds: 600));

    // Use lastValueStream – more reliable cross-platform
    _notifySub?.cancel();
    _notifySub = _txChar!.lastValueStream.listen(
      _onDataReceived,
      onError: (e) => print("Notify error: $e"),
    );
  }

  // // ---------------- SEND old ----------------
  //
  // Future<void> _sendCommand() async {
  //   if (_rxChar == null) return;
  //
  //   const cmd = "a\r\n";
  //   await _rxChar!.write(
  //     Uint8List.fromList(cmd.codeUnits),
  //     withoutResponse: false,
  //   );
  // }

  // ---------------- SEND ----------------

  // Future<void> _sendCommand() async {
  //   if (_txChar == null) return;
  //
  //   const cmd = "a\r\n";
  //
  //   await _txChar!.write(
  //     Uint8List.fromList(cmd.codeUnits),
  //     withoutResponse: true, // safer for iOS
  //   );
  // }

  // Future<void> _sendCommand() async {
  //   if (_rxChar == null) return;
  //
  //   const cmd = "a\r\n";
  //
  //   await _rxChar!.write(
  //     Uint8List.fromList(cmd.codeUnits),
  //     withoutResponse: false, // safer for iOS
  //   );
  // }

  // Future<void> _sendCommand() async {
  //   if (_rxChar == null) return;
  //
  //   const cmd = "a\r\n";
  //   final bytes = Uint8List.fromList(cmd.codeUnits);
  //
  //   if (_rxChar!.properties.writeWithoutResponse) {
  //     await _rxChar!.write(bytes, withoutResponse: true);
  //   } else if (_rxChar!.properties.write) {
  //     await _rxChar!.write(bytes, withoutResponse: false);
  //   } else {
  //     throw Exception("Characteristic does not support write");
  //   }
  // }

  Future<void> _sendCommand() async {
    if (_rxChar == null) return;

    const cmd = "a\r\n";
    final bytes = Uint8List.fromList(cmd.codeUnits);

    // Preferred order: try without response first (faster), fallback to with response
    try {
      if (_rxChar!.properties.writeWithoutResponse) {
        await _rxChar!.write(bytes, withoutResponse: true);
        print("Sent without response (fast path)");
      } else {
        await _rxChar!.write(bytes, withoutResponse: false);
        print("Sent with response");
      }
    } catch (e) {
      print("Write failed → fallback: $e");
      try {
        await _rxChar!.write(bytes, withoutResponse: false);
      } catch (e2) {
        print("Critical write error: $e2");
      }
    }
  }
  // ---------------- RECEIVE ----------------

  // void _onDataReceived(List<int> data) async {
  //   String chunk = String.fromCharCodes(data);
  //   _rxBuffer += chunk;
  //
  //   if (_rxBuffer.contains('\n')) {
  //     _setLoading(false); // 👈 stop loader immediately
  //     // final line = _rxBuffer.trim();
  //     final line = _rxBuffer
  //         .replaceAll('\r', '')
  //         .split('\n')
  //         .first
  //         .trim();
  //
  //     _rxBuffer = "";
  //
  //     // Split by spaces
  //     final parts = line.split(RegExp(r'\s+'));
  //
  //     // Safety check
  //     if (parts.length >= 5) {
  //       final valueAfter2ndPosition = parts[2];
  //
  //       await showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (_) => AlertDialog(
  //           title: const Text("Test Result"),
  //           content: Text(
  //             "Result: $valueAfter2ndPosition\n"
  //                 // "Full line: $line",
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text("OK"),
  //             ),
  //           ],
  //         ),
  //       );
  //     }
  //
  //     else if (parts.length >= 3) {
  //       final valueAfter2ndPosition = parts[2];
  //
  //       await showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (_) => AlertDialog(
  //           title: const Text("Test Result"),
  //           content: Text(
  //               "Result: $valueAfter2ndPosition\n"
  //             "Full line: $line",
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text("OK"),
  //             ),
  //           ],
  //         ),
  //       );
  //     }
  //
  //
  //
  //     await _disconnectClean();
  //   }
  // }
  // void _onDataReceived(List<int> data) async {
  //   final chunk = String.fromCharCodes(data);
  //   _rxBuffer += chunk;
  //
  //   if (_rxBuffer.contains('\n')) {
  //     // _setLoading(false);
  //
  //     final line = _rxBuffer
  //         .replaceAll('\r', '')
  //         .split('\n')
  //         .first
  //         .trim();
  //
  //     _rxBuffer = "";
  //
  //     final parts = line.split(RegExp(r'\s+'));
  //
  //     if (parts.length >= 3) {
  //       final value = parts[2];
  //
  //       await showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (_) => AlertDialog(
  //           title: const Text("Test Result"),
  //           content: Text("Result: $value"),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text("OK"),
  //             ),
  //           ],
  //         ),
  //       );
  //     }
  //
  //     await _disconnectClean();
  //   }
  // }

  void _onDataReceived(List<int> data) async {
    // _rxBuffer += String.fromCharCodes(data);

    String chunk = String.fromCharCodes(data);

    // Count how many '\r' came in this chunk
    // _crCount += ' '.allMatches(chunk).length;

    // Replace '\r' with 'x' for visibility
    // chunk = chunk.replaceAll(' ', 'x');

    _rxBuffer += chunk;
    print("Received: $chunk");
    if (_rxBuffer.contains("\n")) {
      final result = _rxBuffer.trim();
      _rxBuffer = "";

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Test Result"),
          // content: Text(result),
          content: Text(
            "Result: $result\n"
                // "CR count: $_crCount",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
     // Reset counter for next test
      _crCount = 0;
      await _disconnectClean();
    }
  }

  // // ---------------- DISCONNECT ----------------
  //
  // Future<void> _disconnectClean() async {
  //   try {
  //     await _notifySub?.cancel();
  //     await Future.delayed(const Duration(milliseconds: 200));
  //     await _device?.disconnect();
  //   } catch (_) {}
  //
  //   _notifySub = null;
  //   _device = null;
  //   _rxChar = null;
  //   _txChar = null;
  //   _busy = false;
  // }


// ---------------- DISCONNECT ----------------

  Future<void> _disconnectClean() async {
    _setLoading(false); // 👈 safety
    try {
      await _notifySub?.cancel();
      _notifySub = null;

      await _rxChar?.setNotifyValue(false);

      await _device?.disconnect();
    } catch (_) {}

    _busy = false;
  }

  // ---------------- POPUP ----------------

  void _showPopup(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    _device?.disconnect();
    super.dispose();
  }


  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() {
      _isLoading = value;
    });
  }

  // void _showLoading() {
  //   if (_loadingShown) return;
  //   _loadingShown = true;
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) => const AlertDialog(
  //       content: Row(
  //         children: [
  //           SizedBox(
  //             width: 24,
  //             height: 24,
  //             child: CircularProgressIndicator(strokeWidth: 2),
  //           ),
  //           SizedBox(width: 16),
  //           Text("Sending command…"),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // void _hideLoading() {
  //   if (!_loadingShown) return;
  //   _loadingShown = false;
  //
  //   Navigator.of(context, rootNavigator: true).pop();
  // }

}




// // import 'dart:async';
// // import 'dart:typed_data';
// // import 'package:flutter/material.dart';
// // import 'package:firebase_database/firebase_database.dart';
// // import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// // import 'package:permission_handler/permission_handler.dart';
// //
// // class MyDevicesPage extends StatefulWidget {
// //   final String userMobile;
// //   const MyDevicesPage({super.key, required this.userMobile});
// //
// //   @override
// //   State<MyDevicesPage> createState() => _MyDevicesPageState();
// // }
// //
// // class _MyDevicesPageState extends State<MyDevicesPage> {
// //   final dbRef = FirebaseDatabase.instance.ref();
// //   BluetoothConnection? _connection;
// //   StreamSubscription<Uint8List>? _inputSub;
// //   bool _isConnecting = false;
// //   String _rxBuffer = "";
// //
// // // 1️⃣ build() method
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       extendBodyBehindAppBar: true,
// //
// //       appBar: AppBar(
// //         backgroundColor: Colors.transparent,
// //         elevation: 0,
// //
// //         leading: IconButton(
// //           icon: const Icon(Icons.menu, color: Colors.white, size: 30),
// //           onPressed: () {},
// //         ),
// //
// //         centerTitle: true,
// //         title: const Text(
// //           "My Device",
// //           style: TextStyle(
// //             color: Colors.white,
// //             fontSize: 22,
// //             fontWeight: FontWeight.bold,
// //           ),
// //         ),
// //
// //         actions: [
// //           Padding(
// //             padding: const EdgeInsets.only(right: 10),
// //             child: CircleAvatar(
// //               backgroundColor: Colors.white,
// //               child: IconButton(
// //                 icon: const Icon(Icons.add, color: Colors.blue),
// //                 // onPressed: () {
// //                 //   Navigator.push(
// //                 //     context,
// //                 //     MaterialPageRoute(
// //                 //       builder: (_) => MyDevicesScanPage(
// //                 //         userMobile: widget.userMobile,
// //                 //       ),
// //                 //     ),
// //                 //   );
// //                 // },
// //                 onPressed: () {
// //                   _showDeviceScanPopup();
// //                 },
// //
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //
// //       body: Stack(
// //         children: [
// //
// //           /// Background Image
// //           Container(
// //             decoration: const BoxDecoration(
// //               image: DecorationImage(
// //                 image: AssetImage("assets/images/main.png"),
// //                 fit: BoxFit.cover,
// //               ),
// //             ),
// //           ),
// //
// //           // Device List From Realtime DB
// //           Padding(
// //             padding: const EdgeInsets.only(top: 100),
// //             child: StreamBuilder(
// //
// //               stream: dbRef
// //                   .child("Devices/${widget.userMobile}")
// //                   .onValue,
// //               builder: (context, snapshot) {
// //                 if (snapshot.connectionState == ConnectionState.waiting) {
// //                   return const Center(child: CircularProgressIndicator());
// //                 }
// //
// //                 if (!snapshot.hasData ||
// //                     snapshot.data?.snapshot.value == null) {
// //                   return const Center(
// //                     child: Text(
// //                       "No Device Found",
// //                       style: TextStyle(color: Colors.white, fontSize: 18),
// //                     ),
// //                   );
// //                 }
// //
// //                 Map<dynamic, dynamic> data =
// //                 snapshot.data!.snapshot.value as Map;
// //
// //                 List deviceKeys = data.keys.toList();
// //
// //                 return ListView.builder(
// //                   padding: const EdgeInsets.all(12),
// //                   itemCount: deviceKeys.length,
// //                   itemBuilder: (context, index) {
// //                     String key = deviceKeys[index];
// //                     Map device = data[key];
// //
// //                     String status = device["st"] ?? "Inactive";
// //                     int testCount = device["testCount"] ?? 0;
// //                     bool active = status.toLowerCase() == "active";
// //                     String mac = device["mac"] ?? "";
// //
// //                     return InkWell(
// //                       onTap: () {
// //                         _handleDeviceTap(
// //                           context: context,
// //                           status: status,
// //                           testCount: testCount,
// //                           mac: mac,
// //                         );
// //                       },
// //                       child: Container(
// //                         margin: const EdgeInsets.only(bottom: 15),
// //                         padding: const EdgeInsets.all(14),
// //                         decoration: BoxDecoration(
// //                           color: Colors.white,
// //                           borderRadius: BorderRadius.circular(12),
// //                           boxShadow: const [
// //                             BoxShadow(color: Colors.black26, blurRadius: 4)
// //                           ],
// //                         ),
// //                         child: Column(
// //                           crossAxisAlignment: CrossAxisAlignment.start,
// //
// //                             children: [
// //                               Row(
// //                                 children: [
// //                                   const Text(
// //                                     "Device Name",
// //                                     style: TextStyle(
// //                                         fontSize: 12, color: Colors.black54),
// //                                   ),
// //                                   const Spacer(),
// //                                   Text(
// //                                     key,
// //                                     style: const TextStyle(
// //                                       fontSize: 12,
// //                                       color: Colors.blue,
// //                                       fontWeight: FontWeight.w600,
// //                                     ),
// //                                   ),
// //                                 ],
// //                               ),
// //
// //                               const SizedBox(height: 8),
// //                               Row(
// //                                 children: [
// //                                   const Text("status", style: TextStyle(
// //                                       fontSize: 12, color: Colors.black54),
// //                                   ),
// //                                   const Spacer(),
// //                                   Text(
// //                                     active
// //                                         ? "Active | Remaining Test: $testCount"
// //                                         : "Inactive | Please Recharge",
// //                                     style: TextStyle(
// //                                       fontSize: 12,
// //                                       color: active ? Colors.green : Colors.red,
// //                                       fontWeight: FontWeight.w600,
// //                                     ),
// //                                   )
// //                                 ],
// //                               )
// //                             ],
// //                           ),
// //
// //                       ),
// //                     );
// //
// //
// //                     // return Container(
// //                     //   margin: const EdgeInsets.only(bottom: 15),
// //                     //   padding: const EdgeInsets.all(14),
// //                     //   decoration: BoxDecoration(
// //                     //     color: Colors.white,
// //                     //     borderRadius: BorderRadius.circular(12),
// //                     //     boxShadow: const [
// //                     //       BoxShadow(color: Colors.black26, blurRadius: 4)
// //                     //     ],
// //                     //   ),
// //                     //   child: Column(
// //                     //     crossAxisAlignment: CrossAxisAlignment.start,
// //                     //     children: [
// //                     //       Row(
// //                     //         children: [
// //                     //           const Text(
// //                     //             "Device Name",
// //                     //             style: TextStyle(
// //                     //                 fontSize: 12, color: Colors.black54),
// //                     //           ),
// //                     //           const Spacer(),
// //                     //           Text(
// //                     //             key,
// //                     //             style: const TextStyle(
// //                     //               fontSize: 12,
// //                     //               color: Colors.blue,
// //                     //               fontWeight: FontWeight.w600,
// //                     //             ),
// //                     //           ),
// //                     //         ],
// //                     //       ),
// //                     //
// //                     //       const SizedBox(height: 8),
// //                     //       Row(
// //                     //         children: [
// //                     //           const Text("status", style: TextStyle(
// //                     //               fontSize: 12, color: Colors.black54),
// //                     //           ),
// //                     //           const Spacer(),
// //                     //           Text(
// //                     //             active
// //                     //                 ? "Active | Remaining Test: $testCount"
// //                     //                 : "Inactive | Please Recharge",
// //                     //             style: TextStyle(
// //                     //               fontSize: 12,
// //                     //               color: active ? Colors.green : Colors.red,
// //                     //               fontWeight: FontWeight.w600,
// //                     //             ),
// //                     //           )
// //                     //         ],
// //                     //       )
// //                     //     ],
// //                     //   ),
// //                     // );
// //                   },
// //                 );
// //               },
// //             ),
// //           )
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // 2️ helper functions go here
// //   void _showDeviceScanPopup() {
// //     // keep persistent state here so re-builds don't recreate them
// //     final List<BluetoothDiscoveryResult> _popupDevices = [];
// //     bool _popupScanning = false;
// //     StreamSubscription<BluetoothDiscoveryResult>? _popupSubscription;
// //
// //     Future<void> _startPopupScan(StateSetter setState) async {
// //       // ensure permissions
// //       await Permission.bluetooth.request();
// //       await Permission.bluetoothScan.request();
// //       await Permission.bluetoothConnect.request();
// //       await Permission.locationWhenInUse.request();
// //       await Permission.location.request();
// //
// //       // ensure Bluetooth is enabled
// //       final isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
// //       if (!isEnabled) {
// //         // request to enable it (this shows Android's enable prompt)
// //         final enabled = await FlutterBluetoothSerial.instance.requestEnable();
// //         if (enabled != true) {
// //           ScaffoldMessenger.of(context).showSnackBar(
// //             const SnackBar(content: Text("Please enable Bluetooth to scan.")),
// //           );
// //           return;
// //         }
// //       }
// //
// //       // clear old results
// //       _popupDevices.clear();
// //       setState(() => _popupScanning = true);
// //
// //       // short delay (helps on many devices)
// //       await Future.delayed(const Duration(milliseconds: 300));
// //
// //       // add already paired/bonded devices first (optional)
// //       try {
// //         final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
// //         for (var d in bonded) {
// //           final name = d.name ?? "";
// //           if (name.startsWith("SCINPY")) {
// //             final exists = _popupDevices.any((e) => e.device.address == d.address);
// //             if (!exists) {
// //               _popupDevices.add(BluetoothDiscoveryResult(device: d, rssi: 0));
// //               // refresh dialog UI
// //               setState(() {});
// //             }
// //           }
// //         }
// //       } catch (e) {
// //         // ignore, continue with discovery
// //       }
// //
// //       // start discovery and keep subscription so we can cancel it
// //       _popupSubscription = FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
// //         final name = r.device.name ?? "";
// //         final rssi = r.rssi ?? 0;
// //
// //         // Skip devices with RSSI = 0
// //         if (rssi == 0) return;
// //
// //
// //         if (name.startsWith("SCINPY")) {
// //           final exists = _popupDevices.any((e) => e.device.address == r.device.address);
// //           if (!exists) {
// //             _popupDevices.add(r);
// //             setState(() {}); // update UI
// //           }
// //         }
// //       }, onError: (err) {
// //         // handle errors if needed
// //       });
// //
// //       // when discovery finishes, set scanning = false
// //       _popupSubscription?.onDone(() {
// //         setState(() => _popupScanning = false);
// //       });
// //     }
// //
// //     // show the dialog
// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (dialogContext) {
// //         return StatefulBuilder(
// //           builder: (dialogContext, setState) {
// //             // Start scanning once when the dialog is built
// //             // use Future.microtask so it runs after build
// //             Future.microtask(() {
// //               if (!_popupScanning && _popupDevices.isEmpty && _popupSubscription == null) {
// //                 _startPopupScan(setState);
// //               }
// //             });
// //
// //             return WillPopScope(
// //               // ensure discovery stops when dialog is closed via back button
// //               onWillPop: () async {
// //                 try {
// //                   await _popupSubscription?.cancel();
// //                 } catch (_) {}
// //                 _popupSubscription = null;
// //                 return true;
// //               },
// //               child: AlertDialog(
// //                 title: Row(
// //                   children: [
// //                     const Expanded(child: Text("Search Devices", textAlign: TextAlign.center)),
// //                     IconButton(
// //                       icon: Icon(_popupScanning ? Icons.hourglass_empty : Icons.refresh),
// //                       onPressed: () async {
// //                         if (_popupScanning) return;
// //                         // restart scan
// //                         await _popupSubscription?.cancel();
// //                         _popupSubscription = null;
// //                         _popupDevices.clear();
// //                         setState(() => _popupScanning = true);
// //                         await _startPopupScan(setState);
// //                       },
// //                     ),
// //                   ],
// //                 ),
// //                 content: SizedBox(
// //                   width: double.maxFinite,
// //                   height: 320,
// //                   child: _popupScanning && _popupDevices.isEmpty
// //                       ? Column(
// //                     mainAxisAlignment: MainAxisAlignment.center,
// //                     children: const [
// //                       CircularProgressIndicator(),
// //                       SizedBox(height: 12),
// //                       Text("Scanning for SCINPY devices…"),
// //                     ],
// //                   )
// //                       : _popupDevices.isEmpty
// //                       ? Column(
// //                     mainAxisAlignment: MainAxisAlignment.center,
// //                     children: const [
// //                       Icon(Icons.search_off, size: 48),
// //                       SizedBox(height: 8),
// //                       Text("No SCINPY devices found"),
// //                       SizedBox(height: 8),
// //                       Text("Make sure the device is powered on and Bluetooth is visible.")
// //                     ],
// //                   )
// //                       : ListView.separated(
// //                     itemCount: _popupDevices.length,
// //                     separatorBuilder: (_, __) => const Divider(height: 1),
// //                     itemBuilder: (context, i) {
// //                       final r = _popupDevices[i];
// //                       final deviceName = r.device.name ?? "Unknown";
// //                       final mac = r.device.address;
// //                       final rssi = r.rssi ?? 0;
// //                       return ListTile(
// //                         leading: const Icon(Icons.bluetooth),
// //                         title: Text(deviceName),
// //                         subtitle: Text("MAC: $mac"),
// //                         trailing: Text("RSSI $rssi"),
// //                         onTap: () async {
// //                           // stop discovery first
// //                           await _popupSubscription?.cancel();
// //                           _popupSubscription = null;
// //
// //                           // save to Firebase or handle selection here
// //                           // Example: call your save function (adjust to your db)
// //                           await _saveDeviceToFirebase(deviceName, mac);
// //
// //                           Navigator.pop(dialogContext); // close dialog
// //
// //                           ScaffoldMessenger.of(context).showSnackBar(
// //                             SnackBar(content: Text("$deviceName selected ($mac)")),
// //                           );
// //                         },
// //                       );
// //                     },
// //                   ),
// //                 ),
// //                 actions: [
// //                   TextButton(
// //                     onPressed: () async {
// //                       await _popupSubscription?.cancel();
// //                       _popupSubscription = null;
// //                       Navigator.pop(dialogContext);
// //                     },
// //                     child: const Text("Close"),
// //                   ),
// //                 ],
// //               ),
// //             );
// //           },
// //         );
// //       },
// //     ).then((_) async {
// //       // cleanup after dialog closes (ensure subscription stopped)
// //       try {
// //         await _popupSubscription?.cancel();
// //       } catch (_) {}
// //       _popupSubscription = null;
// //     });
// //   }
// //   // ---------------- POPUP ----------------
// //
// //   void _showPopup(String title, String msg) {
// //     showDialog(
// //       context: context,
// //       builder: (_) => AlertDialog(
// //         title: Text(title),
// //         content: Text(msg),
// //         actions: [
// //           TextButton(
// //               onPressed: () => Navigator.pop(context),
// //               child: const Text("OK"))
// //         ],
// //       ),
// //     );
// //   }
// //
// //   void _onDataReceived(Uint8List data) {
// //     _rxBuffer += String.fromCharCodes(data);
// //
// //     if (_rxBuffer.contains("\r\n")) {
// //       final result = _rxBuffer.trim();
// //       _rxBuffer = "";
// //
// //       _showPopup("Device Result", result);
// //     }
// //   }
// //   void _showStatusPopup(
// //       BuildContext context,
// //       String message, {
// //         Color? bgColor,
// //       }) {
// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (_) => AlertDialog(
// //         backgroundColor: bgColor ?? Colors.white,
// //         title: const Text("Device Status"),
// //         content: Text(message),
// //         actions: [
// //           TextButton(
// //             onPressed: () => Navigator.pop(context),
// //             child: const Text("OK"),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   Future<void> _handleDeviceTap({
// //     required BuildContext context,
// //     required String status,
// //     required int testCount,
// //     required String mac, // pass MAC here
// //   })
// //   async {
// //     final st = status.toLowerCase();
// //
// //     // Device inactive
// //     if (st != "active") {
// //       _showStatusPopup(context, "Please contact to CEMD");
// //       return;
// //     }
// //
// //     // No tests left
// //     if (testCount == 0) {
// //       _showStatusPopup(context, "Please Recharge");
// //       return;
// //     }
// //
// //     // Low test balance
// //     if (testCount < 5) {
// //       _showStatusPopup(
// //         context,
// //         "Low balance\nRemaining tests: $testCount",
// //         // bgColor: Colors.yellow.shade200,
// //       );
// //       return;
// //     }
// //
// //     // // Test allowed
// //     // _showStatusPopup(
// //     //   context,
// //     //   "Test is performed",
// //     //   bgColor: Colors.green.shade100,
// //     //
// //     // ✅ Test allowed
// //     await _connectToDevice(mac);
// //     await _sendTestCommand();
// //
// //   }
// //   Future<void> _sendTestCommand() async {
// //     if (_connection == null || !_connection!.isConnected) {
// //       _showStatusPopup(context, "Device not connected");
// //       return;
// //     }
// //
// //     final command = "##1\r\n";
// //
// //     _connection!.output.add(Uint8List.fromList(command.codeUnits));
// //     await _connection!.output.allSent;
// //   }
// //
// //   Future<void> _connectToDevice(String mac) async {
// //     if (_connection != null && _connection!.isConnected) {
// //       return;
// //     }
// //
// //     try {
// //       setState(() => _isConnecting = true);
// //
// //       _connection = await BluetoothConnection.toAddress(mac);
// //
// //       // Listen for incoming data
// //       _inputSub = _connection!.input!.listen(_onDataReceived);
// //
// //       setState(() => _isConnecting = false);
// //     } catch (e) {
// //       setState(() => _isConnecting = false);
// //       _showStatusPopup(context, "Bluetooth connection failed");
// //     }
// //   }
// //
// //
// //
// //
// //   Future<void> _saveDeviceToFirebase(String deviceID, String mac) async {
// //     final now = DateTime.now();
// //
// //     String formattedDate =
// //         "${now.day.toString().padLeft(2, '0')}/"
// //         "${now.month.toString().padLeft(2, '0')}/"
// //         "${now.year.toString().substring(2)} "
// //         "${now.hour.toString().padLeft(2, '0')}:"
// //         "${now.minute.toString().padLeft(2, '0')}";
// //
// //     await dbRef
// //         .child("Devices")
// //         .child(widget.userMobile)
// //         .child(deviceID)
// //         .set({
// //       "st": "Inactive",
// //       "testCount": 0,
// //       "mac": mac,
// //       "dt": formattedDate,
// //     });
// //   }
// // }
// //
//
// import 'dart:async';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class MyDevicesPage extends StatefulWidget {
//   final String userMobile;
//   const MyDevicesPage({super.key, required this.userMobile});
//
//   @override
//   State<MyDevicesPage> createState() => _MyDevicesPageState();
// }
//
//
// class _MyDevicesPageState extends State<MyDevicesPage> {
//   BluetoothDevice? _device;
//   BluetoothCharacteristic? _rxChar;
//   BluetoothCharacteristic? _txChar;
//
//   StreamSubscription<List<int>>? _notifySub;
//   String _rxBuffer = "";
//   String status = "Idle";
//
//   final Guid serviceUuid = Guid("000000FF-0000-1000-8000-00805F9B34FB");
//   final Guid rxUuid = Guid("0000FF01-0000-1000-8000-00805F9B34FB");
//   final Guid txUuid = Guid("0000FF02-0000-1000-8000-00805F9B34FB");
//
//   @override
//   void initState() {
//     super.initState();
//     _initPermissions();
//   }
//
//   Future<void> _initPermissions() async {
//     await Permission.bluetoothScan.request();
//     await Permission.bluetoothConnect.request();
//     await Permission.location.request();
//   }
//
//   // ---------------- SCAN ----------------
//
//   Future<void> _scanAndConnect() async {
//     setState(() => status = "Scanning...");
//     await FlutterBluePlus.stopScan();
//
//     BluetoothDevice? found;
//
//     await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
//
//     await for (final results in FlutterBluePlus.scanResults) {
//       for (final r in results) {
//         final name = r.device.name;
//         if (name.startsWith("SCINPY")) {
//           found = r.device;
//           break;
//         }
//       }
//       if (found != null) break;
//     }
//
//     await FlutterBluePlus.stopScan();
//
//     if (found == null) {
//       setState(() => status = "Device not found");
//       return;
//     }
//
//     _device = found;
//     await _connect();
//   }
//
//   // ---------------- CONNECT ----------------
//
//   Future<void> _connect() async {
//     setState(() => status = "Connecting...");
//     try {
//       await _device!.connect(
//         autoConnect: false,
//         timeout: const Duration(seconds: 10),
//       );
//     } catch (_) {}
//
//     await _discoverServices();
//   }
//
//   // ---------------- GATT ----------------
//
//   Future<void> _discoverServices() async {
//     final services = await _device!.discoverServices();
//
//     final service =
//     services.firstWhere((s) => s.uuid == serviceUuid);
//
//     _rxChar = service.characteristics
//         .firstWhere((c) => c.uuid == rxUuid);
//
//     _txChar = service.characteristics
//         .firstWhere((c) => c.uuid == txUuid);
//
//     await _txChar!.setNotifyValue(true);
//
//     _notifySub = _txChar!.value.listen(_onDataReceived);
//
//     setState(() => status = "Connected");
//     await Future.delayed(const Duration(milliseconds: 300));
//
//     await _sendCommand(); // 🔥 AUTO SEND
//   }
//
//   // ---------------- SEND ----------------
//
//   Future<void> _sendCommand() async {
//     if (_rxChar == null) return;
//
//     const cmd = "a\r\n";
//     await _rxChar!.write(
//       Uint8List.fromList(cmd.codeUnits),
//       withoutResponse: false,
//     );
//
//     setState(() => status = "Command sent");
//   }
//
//   // ---------------- RECEIVE ----------------
//
//   void _onDataReceived(List<int> data) {
//     _rxBuffer += String.fromCharCodes(data);
//
//     if (_rxBuffer.contains("\r\n")) {
//       final result = _rxBuffer.trim();
//       _rxBuffer = "";
//
//       showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           title: const Text("ESP32 Result"),
//           content: Text(result),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("OK"),
//             )
//           ],
//         ),
//       );
//     }
//   }
//
//   // ---------------- UI ----------------
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("ESP32 BLE Demo")),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Text("Status: $status"),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _scanAndConnect,
//               child: const Text("Scan & Connect"),
//             ),
//             const SizedBox(height: 10),
//             ElevatedButton(
//               onPressed: _sendCommand,
//               child: const Text("Send Test Command"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _notifySub?.cancel();
//     _device?.disconnect();
//     super.dispose();
//   }
// }
//
