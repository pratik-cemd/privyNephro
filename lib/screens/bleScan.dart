import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleScan extends StatefulWidget {
  const BleScan({super.key});

  @override
  State<BleScan> createState() => _BleScanState();
}

class _BleScanState extends State<BleScan> {
  final FlutterReactiveBle flutterBle = FlutterReactiveBle();

  final List<DiscoveredDevice> devices = [];
  StreamSubscription<DiscoveredDevice>? scanSub;

  bool scanning = false;

  Future<void> requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  Future<void> startScan() async {
    await requestPermissions();

    setState(() {
      devices.clear();
      scanning = true;
    });

    scanSub = flutterBle.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
      requireLocationServicesEnabled: false,
    ).listen((device) {

      debugPrint("Device found -> Name: ${device.name}, ID: ${device.id}, RSSI: ${device.rssi}");

      final exists = devices.any((d) => d.id == device.id);

      if (!exists) {
        setState(() {
          devices.add(device);
        });
      }

    }, onError: (error) {
      debugPrint("Scan error: $error");
    });
  }


  Future<void> stopScan() async {
    await scanSub?.cancel();
    scanSub = null;

    setState(() {
      scanning = false;
    });
  }

  @override
  void dispose() {
    scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BLE Scanner"),
        actions: [
          IconButton(
            icon: Icon(scanning ? Icons.stop : Icons.search),
            onPressed: scanning ? stopScan : startScan,
          )
        ],
      ),
      body: devices.isEmpty
          ? const Center(child: Text("No BLE devices found"))
          : ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];

          final name = device.name.isNotEmpty
              ? device.name
              : "Unknown Device";

          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(name),
            subtitle: Text(device.id),
            trailing: Text("RSSI ${device.rssi}"),
          );
        },
      ),
    );
  }
}
