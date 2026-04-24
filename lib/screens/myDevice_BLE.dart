import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';



class MyDevicesPageBLE extends StatefulWidget {
  final String userMobile;
  const MyDevicesPageBLE({super.key, required this.userMobile});

  @override
  State<MyDevicesPageBLE> createState() => _MyDevicesPageStateBLE();
}

class _MyDevicesPageStateBLE extends State<MyDevicesPageBLE> {


  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;
  final dbRef = FirebaseDatabase.instance.ref();

  StreamSubscription<List<int>>? _notifySub;
  bool _busy = false;
  String _rxBuffer = "";
  // String status = "Idle";

  final Guid serviceUuid = Guid("000000FF-0000-1000-8000-00805F9B34FB");
  final Guid rxUuid = Guid("0000FF01-0000-1000-8000-00805F9B34FB");
  final Guid txUuid = Guid("0000FF02-0000-1000-8000-00805F9B34FB");

  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

  // 1️⃣ build() method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 30),
          onPressed: () {},
        ),

        centerTitle: true,
        title: const Text(
          "My Device BLE",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.blue),
                onPressed: () {     //add the device
                  // _showDeviceScanPopup();
                },

              ),
            ),
          ),
        ],
      ),

      body: Stack(
        children: [

          /// Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/main.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Device List From Realtime DB
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: StreamBuilder(

              stream: dbRef
                  .child("Devices/${widget.userMobile}")
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return const Center(
                    child: Text(
                      "No Device Found",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  );
                }

                Map<dynamic, dynamic> data =
                snapshot.data!.snapshot.value as Map;

                List deviceKeys = data.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: deviceKeys.length,
                  itemBuilder: (context, index) {
                    String key = deviceKeys[index];
                    Map device = data[key];

                    String status = device["st"] ?? "Inactive";
                    int testCount = device["testCount"] ?? 0;
                    bool active = status.toLowerCase() == "active";
                    String mac = device["mac"] ?? "";

                    return InkWell(
                      onTap: () {
                        _scanAndConnect();
                        // _handleDeviceTap(
                        //   context: context,
                        //   status: status,
                        //   testCount: testCount,
                        //   mac: mac,
                        // );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4)
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Row(
                              children: [
                                const Text(
                                  "Device Name",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                                const Spacer(),
                                Text(
                                  key,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text("status", style: TextStyle(
                                    fontSize: 12, color: Colors.black54),
                                ),
                                const Spacer(),
                                Text(
                                  active
                                      ? "Active | Remaining Test: $testCount"
                                      : "Inactive | Please Recharge",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: active ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              ],
                            )
                          ],
                        ),

                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // ---------------- TAP ENTRY ----------------
  Future<void> _scanAndConnect() async {
    if (_busy) return;
    _busy = true;

    try {
      if (_device == null) {
        await FlutterBluePlus.stopScan();

        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

        await for (final results in FlutterBluePlus.scanResults) {
          for (final r in results) {
            if (r.device.name.startsWith("SCINPY")) {
              _device = r.device;
              break;
            }
          }
          if (_device != null) break;
        }

        await FlutterBluePlus.stopScan();
      }

      if (_device == null) {
        _busy = false;
        return;
      }

      await _connect();
    } catch (_) {
      _busy = false;
    }
  }


  // ---------------- CONNECT ----------------

  Future<void> _connect() async {
    // setState(() => status = "Connecting...");
    try {
      await _device!.connect(
        license: License.commercial,
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
    } catch (_) {}

    await _discoverServices();
  }

  // ---------------- GATT ----------------

  Future<void> _discoverServices() async {
    final services = await _device!.discoverServices();

    final service =
    services.firstWhere((s) => s.uuid == serviceUuid);

    _rxChar = service.characteristics
        .firstWhere((c) => c.uuid == rxUuid);

    _txChar = service.characteristics
        .firstWhere((c) => c.uuid == txUuid);

    await _txChar!.setNotifyValue(true);



    _notifySub?.cancel();
    _notifySub = _txChar!.value.listen(_onDataReceived);

    // setState(() => status = "Connected");
    await Future.delayed(const Duration(milliseconds: 300));

    await _sendCommand(); // 🔥 AUTO SEND
  }

  // ---------------- SEND ----------------

  Future<void> _sendCommand() async {
    if (_rxChar == null) return;

    const cmd = "a\r\n";
    await _rxChar!.write(
      Uint8List.fromList(cmd.codeUnits),
      withoutResponse: false,
    );

    // setState(() => status = "Command sent");
  }

  // ---------------- RECEIVE ----------------

  void _onDataReceived(List<int> data) {
    _rxBuffer += String.fromCharCodes(data);

    if (_rxBuffer.contains("\r\n")) {
      final result = _rxBuffer.trim();
      _rxBuffer = "";

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("ESP32 Result"),
          content: Text(result),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),

            )
          ],
        ),
      );
    }
  }

  Future<void> _cleanup() async {
    await Future.delayed(const Duration(milliseconds: 300));

    await _notifySub?.cancel();

    try {
      await _device?.disconnect();
    } catch (_) {}

    _busy = false;
  }
  Future<void> _initPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }
}


