import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';

class MyDevicesScanPage extends StatefulWidget {
  final String userMobile;

  const MyDevicesScanPage({super.key, required this.userMobile});

  @override
  State<MyDevicesScanPage> createState() => _MyDevicesScanPageState();
}

class _MyDevicesScanPageState extends State<MyDevicesScanPage> {
  List<BluetoothDiscoveryResult> devices = [];
  bool scanning = false;

  final db = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    var status = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    if (status.values.every((s) => s.isGranted)) {
      startScan();
    }
  }

  void startScan() {
    setState(() {
      devices.clear();
      scanning = true;
    });

    FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      var name = r.device.name ?? "";

      if (name.startsWith("SCINPY")) {
        bool exists =
        devices.any((d) => d.device.address == r.device.address);

        if (!exists) {
          setState(() => devices.add(r));
        }
      }
    }).onDone(() {
      setState(() => scanning = false);
    });
  }

  Future<void> saveDevice(String name, String address) async {
    await db
        .child("Devices/user_${widget.userMobile}/$name")
        .set({
      "activat": "active",
      "address": address,
      "testCount": 60,
      "dateTime": DateTime.now().toString()
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Device")),

      body: devices.isEmpty
          ? const Center(child: Text("Searching..."))
          : ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          var d = devices[index];

          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(d.device.name ?? ""),
            subtitle: Text(d.device.address),
            trailing:
            const Icon(Icons.add_circle, color: Colors.blue),
            onTap: () => saveDevice(
              d.device.name!,
              d.device.address,
            ),
          );
        },
      ),
    );
  }
}
