import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleScanPage extends StatefulWidget {
  const BleScanPage({super.key});

  @override
  State<BleScanPage> createState() => _BleScanPageState();
}

class _BleScanPageState extends State<BleScanPage> {
  final FlutterReactiveBle flutterBle = FlutterReactiveBle();
  final List<DiscoveredDevice> _devices = [];
  StreamSubscription<DiscoveredDevice>? _scanSub;
  bool _scanning = false;

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    // Request permissions
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();

    setState(() {
      _devices.clear();
      _scanning = true;
    });

    _scanSub = flutterBle.scanForDevices(
      withServices: [], // scan for all devices
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      // Print all devices before filtering
      debugPrint("Found device -> Name: '${device.name}', ID: ${device.id}, RSSI: ${device.rssi}");

      // Filter SCINPY devices
      if (device.name.startsWith("SCIN")) {
        final exists = _devices.any((d) => d.id == device.id);
        if (!exists) {
          setState(() => _devices.add(device));
        }
      }
    }, onError: (error) {
      debugPrint("Scan error: $error");
    });
  }

  Future<void> _stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scan'),
        actions: [
          IconButton(
            icon: Icon(_scanning ? Icons.stop : Icons.search),
            onPressed: () async {
              if (_scanning) {
                await _stopScan();
              } else {
                await _startScan();
              }
            },
          ),
        ],
      ),
      body: _scanning && _devices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? const Center(child: Text("No SCINPY devices found"))
          : ListView.separated(
        itemCount: _devices.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final device = _devices[index];
          final name = device.name.isNotEmpty ? device.name : device.id;
          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(name),
            subtitle: Text("ID: ${device.id}"),
            trailing: Text("RSSI ${device.rssi}"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("$name selected")),
              );
            },
            // onTap: () async {
            //   final device = _devices[index];
            //
            //   // Optional: stop scan once a device is selected
            //   if (_scanning) {
            //     await _stopScan();
            //   }
            //
            //   final deviceID = device.name.isNotEmpty
            //       ? device.name
            //       : "SCIN_${device.id}";
            //
            //   final mac = device.id;
            //
            //   try {
            //     await _saveDeviceToFirebase(deviceID, mac);
            //
            //     if (!mounted) return;
            //
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       SnackBar(
            //         content: Text("$deviceID saved successfully"),
            //         backgroundColor: Colors.green,
            //       ),
            //     );
            //   } catch (e) {
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       SnackBar(
            //         content: Text("Failed to save device"),
            //         backgroundColor: Colors.red,
            //       ),
            //     );
            //   }
            // },

          );
        },
      ),
    );
  }
}


// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class BleScanPage extends StatefulWidget {
//   const BleScanPage({super.key});
//
//   @override
//   State<BleScanPage> createState() => _BleScanPageState();
// }
//
// class _BleScanPageState extends State<BleScanPage> {
//   final FlutterReactiveBle flutterBle = FlutterReactiveBle();
//
//   final List<DiscoveredDevice> _devices = [];
//   final Map<String, String> _deviceNames = {};
//
//   StreamSubscription<DiscoveredDevice>? _scanSub;
//   StreamSubscription<ConnectionStateUpdate>? _connectionSub;
//
//   bool _scanning = false;
//
//   final Uuid deviceNameUuid =
//   Uuid.parse("00002a00-0000-1000-8000-00805f9b34fb");
//
//   @override
//   void dispose() {
//     _scanSub?.cancel();
//     _connectionSub?.cancel();
//     super.dispose();
//   }
//
//   Future<void> _startScan() async {
//     await Permission.bluetoothScan.request();
//     await Permission.bluetoothConnect.request();
//     await Permission.locationWhenInUse.request();
//
//     setState(() {
//       _devices.clear();
//       _deviceNames.clear();
//       _scanning = true;
//     });
//
//     _scanSub = flutterBle
//         .scanForDevices(
//       withServices: [],
//       scanMode: ScanMode.lowLatency,
//     )
//         .listen((device) {
//       final exists = _devices.any((d) => d.id == device.id);
//       if (!exists) {
//         setState(() {
//           _devices.add(device);
//         });
//       }
//     }, onError: (e) {
//       debugPrint("Scan error: $e");
//     });
//   }
//
//   Future<void> _stopScan() async {
//     await _scanSub?.cancel();
//     _scanSub = null;
//     setState(() => _scanning = false);
//   }
//
//   void _connectAndReadName(DiscoveredDevice device) {
//     _connectionSub?.cancel();
//
//     _connectionSub = flutterBle
//         .connectToDevice(
//       id: device.id,
//       connectionTimeout: const Duration(seconds: 10),
//     )
//         .listen((update) async {
//       if (update.connectionState ==
//           DeviceConnectionState.connected) {
//         debugPrint("Connected to ${device.id}");
//         await _readDeviceName(device.id);
//         await _connectionSub?.cancel(); // disconnect
//       }
//     }, onError: (e) {
//       debugPrint("Connection error: $e");
//     });
//   }
//
//   Future<void> _readDeviceName(String deviceId) async {
//     final services = await flutterBle.discoverServices(deviceId);
//
//     for (final service in services) {
//       for (final characteristic in service.characteristics) {
//         if (characteristic.characteristicId == deviceNameUuid) {
//           final qualifiedCharacteristic = QualifiedCharacteristic(
//             deviceId: deviceId,
//             serviceId: service.serviceId,
//             characteristicId: characteristic.characteristicId,
//           );
//
//           final value = await flutterBle
//               .readCharacteristic(qualifiedCharacteristic);
//
//           final name = String.fromCharCodes(value);
//
//           setState(() {
//             _deviceNames[deviceId] = name;
//           });
//
//           debugPrint("Device name read: $name");
//           return;
//         }
//       }
//     }
//
//     debugPrint("Device Name characteristic not found");
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("BLE Scan"),
//         actions: [
//           IconButton(
//             icon: Icon(_scanning ? Icons.stop : Icons.search),
//             onPressed: () async {
//               if (_scanning) {
//                 await _stopScan();
//               } else {
//                 await _startScan();
//               }
//             },
//           ),
//         ],
//       ),
//       body: _scanning && _devices.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : _devices.isEmpty
//           ? const Center(child: Text("No devices found"))
//           : ListView.separated(
//         itemCount: _devices.length,
//         separatorBuilder: (_, __) => const Divider(),
//         itemBuilder: (context, index) {
//           final device = _devices[index];
//
//           final displayName =
//               _deviceNames[device.id] ??
//                   (device.name.isNotEmpty
//                       ? device.name
//                       : "Unknown device");
//
//           return ListTile(
//             leading: const Icon(Icons.bluetooth),
//             title: Text(displayName),
//             subtitle: Text("ID: ${device.id}"),
//             trailing: Text("RSSI ${device.rssi}"),
//             onTap: () {
//               _connectAndReadName(device);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text("Reading device name..."),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
