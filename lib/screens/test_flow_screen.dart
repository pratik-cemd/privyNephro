import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';

import 'testHistory.dart';
import 'user_model.dart';
import 'mydoctor.dart';
import 'myprofile.dart';
import 'myDevicesPage.dart';
import 'test_count_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:flutter_tts/flutter_tts.dart';//voice

class TestFlowScreen extends StatefulWidget {
  final BluetoothDevice device;
  final UserModel user;
  final String deviceId;
  const TestFlowScreen({super.key, required this.device,required this.user,required this.deviceId,});
  @override
  State<TestFlowScreen> createState() => _TestFlowScreenState();
}

class _TestFlowScreenState extends State<TestFlowScreen>
    with SingleTickerProviderStateMixin {
  FlutterTts tts = FlutterTts();  //voice
  Timer? calibTimer;
  GlobalKey<_CalibrationDialogState>? calibDialogKey;

  final dbRef = FirebaseDatabase.instance.ref();
  String selectedDeviceId = "";
  String bleBuffer = "";

  BluetoothCharacteristic? writeChar;
  StreamSubscription<List<int>>? notifySub;
  StreamSubscription? _netSub;
  StreamSubscription? connectionSub;
  bool isDeviceConnected = false;

  bool isRunning = false;
  bool isBlink = false;
  bool isResultShown = false;
  String status = "IDLE";
  double progress = 0;
  String runningTest = "";
  String? pendingTest;
  List<String> selectedTests = [];
  Set<String> completedTests = {};
  int availableTests =0;
  final List<String> allTests = ["PROTEIN", "SCRT", "UCRT"];
  late AnimationController _controller;

  Map<String, String> resultUnits = {
    "P": "mg/dL",
    "U": "mg/dL",
    "S": "mg/dL",
    "e": "mL/min/1.73m²",
    "r": "",
  };

  bool isMuted = false;
  String selectedLang = "en-IN"; // default

  Map<String, String> langMap = {
    "English": "en-IN",
    "Hindi": "hi-IN",
    "Gujarati": "gu-IN",
    "Marathi": "mr-IN",
  };
  bool isDeviceBusy = false;   // ESP se update karna
  String lastStatus = "";

  bool isReconnecting = false;      // optional


  @override
  void initState() {
    super.initState();

    tts.setLanguage("en-IN"); //voice
    tts.setSpeechRate(0.45); //voice
    tts.setPitch(1.0); //voice


    // selectedDeviceId = widget.device.remoteId.toString();
    selectedDeviceId = widget.deviceId;
    loadAvailableTests();
    _syncOfflineQueue();
    _netSub = FirebaseDatabase.instance.ref(".info/connected").onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        _syncOfflineQueue();
      }
    });

    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    notifySub?.cancel();
    widget.device.disconnect();
    _controller.dispose();
    connectionSub?.cancel();
    tts.stop(); //voice
    super.dispose();
  }

  // ---------------- TEST NAME ----------------
  String getName(String test) {
    switch (test) {
      case "PROTEIN":
        return "Protein Test";
      case "SCRT":
        return "Serum Creatinine Test";
      case "UCRT":
        return "Urine Creatinine Test";
      default:
        return "";
    }
  }

  // ---------------- START TEST ----------------
    Future<void> startTest(String test) async {
    if (isRunning) {
      setState(() {
        pendingTest = test;
        selectedTests.add(test);
      });
      return;
    }

    setState(() {
      isRunning = true;
      runningTest = test;
      status = "CONNECTING";
      progress = 0;
      selectedTests.add(test);
    });

    bool connected = await connectDevice();

    if (!connected) {
      setState(() {
        isRunning = false;
        status = "RETRYING CONNECTION";
        runningTest = "";
        progress = 0;
      });
      await speak("DEVICE NOT CONNECTED . Please connect device and try again");
      return;
    }


    await sendCommand("#START:$test");
  }

  // ---------------- PROGRESS ----------------
  void startProgress(String test) {
    int total = (test == "PROTEIN") ? 5 : 100;
    int current = 0;

    Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      current++;

      setState(() {
        progress = current / (total * 5);
        isBlink = !isBlink;
      });

      if (current >= total * 5) {
        timer.cancel();
        // await waitForBle();
        setState(() {
          progress = 0.99; // 🔥 HOLD HERE
        });

        print("⏳ Waiting for device DONE...");
      }
    });
  }

  // ---------------- BUZZER ----------------
  Widget buildBuzzer() {
    return Column(
      children: [
        AnimatedScale(
          scale: isBlink ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isBlink ? Icons.volume_up : Icons.volume_mute,
            size: 36,
            color: status == "DONE" ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          status == "DONE" ? "Done" : (isBlink ? "Beep..." : ""),
          style: TextStyle(
            fontSize: 12,
            color: status == "DONE" ? Colors.green : Colors.orange,
          ),
        )
      ],
    );
  }

  // ---------------- BLE WAIT ----------------
  Future<void> waitForBle() async {
    bool on = false;

    while (!on) {
      var state = await FlutterBluePlus.adapterState.first;
      if (state == BluetoothAdapterState.on) {
        on = true;
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    setState(() {
      status = "DONE";
      progress = 1;
      isRunning = false;

      // completedTests.add(runningTest); // ✅ ADD THIS
      if (!completedTests.contains(runningTest)) {
        completedTests.add(runningTest);
      }
      selectedTests.remove(runningTest);
    });

    if (pendingTest != null) showNextPopup();
  }

  // ---------------- BUTTON COLOR ----------------
  Color getButtonColor(String cmd) {
    if (cmd == runningTest && isRunning) {
      return Colors.blueAccent;
    } else if (cmd == pendingTest) {
      return Colors.orange.shade300;
    }
    else if (completedTests.contains(cmd))
    {
      return Colors.green.shade300;
    } else {
      return Colors.white;
    }
  }

  // ---------------- NEXT POPUP ----------------
  void showNextPopup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text("Next Test"),
        content: Text("Run ${getName(pendingTest!)}?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              pendingTest = null;
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              String next = pendingTest!;
              pendingTest = null;
              startTest(next);
            },
            child: const Text("Start"),
          )
        ],
      ),
    );
  }

  // ---------------- STATUS ICON ----------------
  Widget buildStatusIcon() {
    if (status == "RUNNING") {
      return RotationTransition(
        turns: _controller,
        child: const Icon(Icons.sync, size: 80, color: Colors.orange),
      );
    }

    if (status == "DONE") {
      return const Icon(Icons.check_circle,
          size: 80, color: Colors.green);
    }



    return const Icon(Icons.hourglass_empty,
        size: 80, color: Colors.grey);
  }

  // ---------------- CONNECT ----------------
  Future<bool> connectDevice() async {
    try {
      setState(() {
        status = "CONNECTING";
      });

      if (!widget.device.isConnected) {
        await widget.device
            .connect(
          license: License.commercial,
          timeout: const Duration(seconds: 5),
        )
            .timeout(const Duration(seconds: 8));
      }
      // ✅ ADD THIS BLOCK
      connectionSub?.cancel(); // 🔥 clear

      connectionSub = widget.device.connectionState.listen((state) {

        if (state == BluetoothConnectionState.connected) {
          isDeviceConnected = true;

          setState(() {
            if (isRunning) {
              // status = "CONNECTED";
            }
          });

          print("✅ Connected");
        } else {
          isDeviceConnected = false;

          setState(() {
            if (isRunning) {
              // status = "PROCESSING..."; // 🔥 MAIN FIX
            }
          });

          print("❌ Disconnected");
        }
      });
      var services = await widget.device.discoverServices();

      bool foundWrite = false;

      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write) {
            writeChar = c;
            foundWrite = true;
          }

          if (c.properties.notify) {
            await c.setNotifyValue(true);

            notifySub?.cancel();
            // notifySub = c.onValueReceived.listen((value) {
            //   String data = String.fromCharCodes(value);
            //   handleResponse(data);
            // });
            notifySub = c.onValueReceived.listen((value) {
              String chunk = String.fromCharCodes(value);

              debugPrint("CHUNK: [$chunk]");

              bleBuffer += chunk;

              // 🔥 iOS fix: handle split packets
              while (bleBuffer.contains("\n")) {
                int index = bleBuffer.indexOf("\n");

                String fullMessage = bleBuffer.substring(0, index).trim();

                bleBuffer = bleBuffer.substring(index + 1);

                if (fullMessage.isNotEmpty) {
                  debugPrint("FULL MSG: [$fullMessage]");
                  handleResponse(fullMessage);
                }
              }
            });
          }
        }
      }

      if (!foundWrite) {
        throw Exception("No writable characteristic found");
      }

      return true;
    } catch (e) {
      debugPrint("Connection failed: $e");

      setState(() {
        status = "CONNECTION FAILED";
        isRunning = false;
        progress = 0;
        runningTest = "";
      });

      return false;
    }
  }

  Future<void> sendCommand(String cmd) async {
    if (!isDeviceConnected) {
      print("❌ Skip send, not connected");
      return;
    }
    if (writeChar == null) {
      debugPrint("❌ writeChar NULL - command not sent");
      return;
    }

    try {
      await writeChar!.write((cmd + "\r\n").codeUnits);
      debugPrint("✅ Sent: $cmd");
    } catch (e) {
      debugPrint("❌ Write Error: $e");
    }
  }
  // ---------------- RESPONSE ----------------
  Future<void> handleResponse(String res) async {
    debugPrint("ESP: $res");

    res = res.trim().replaceAll("\r", "");

    // 🔥 empty ignore
    if (res.isEmpty) return;

    // 🔥 duplicate ignore (VERY IMPORTANT)
    if (res == lastStatus) return;
    lastStatus = res;

    debugPrint("Device: $res");

    if (res.contains("WAIT_SAMPLE")) {
      setState(() {
        status = "WAIT SAMPLE";
      });
     await speak("Please insert sample");
    }
    else if (res.contains("TEST_STARTED")) {
      setState(() {
        status = "RUNNING";
      });
      await speak("Test started");
      startProgress(runningTest);
      // 🔥 ADD THIS (IMPORTANT)
      waitReconnectAndCheckTest(runningTest == "PROTEIN" ? 5 : 100
      );
    }
    else if (res.contains("TST:DONE") ||res.contains("TEST_DONE")) {
      print("🔥 new  Test Done from device");

      setState(() {
        status = "DONE";
        progress = 1.0; // 🔥 FINAL COMPLETE
        isRunning = false;
        completedTests.add(runningTest);
        selectedTests.remove(runningTest);
      });

     await speak("Test completed");


    }
    // else if (res.contains("TEST_DONE")) {
    //   print("🔥 Test Done from device");
    //
    //   setState(() {
    //     status = "DONE";
    //     progress = 1.0;
    //     isRunning = false;
    //   });
    //
    //  await speak("Test completed");
    //
    //   completedTests.add(runningTest);
    //   selectedTests.remove(runningTest);
    // }

    else if (res.contains("ERR")) {
      setState(() {
        status = "ERROR";
        isRunning = false;
      });
     await speak("Error occurred during test");
    }
    else if (res.contains("#RESP:OK:Test not Performed")) {
      setState(() {
        status = "NO TEST PERFORMED";
        isRunning = false;
      });

      showResultPopup({
        "error": "No test was performed. Please run a test first."
      });
      await disconnectDevice();
    }
    // 🔥 CALIBRATION FLOW FIXED
    else if (res.startsWith("#RESP:CLB")) {
      // final state = res.split(":")[2].trim();
      // debugPrint("responce : $state");

      final parts = res.split(":");
      if (parts.length < 3) return;

      final state = parts[2].trim();

      if (state == lastStatus) return; // 🔥 duplicate ignore

      lastStatus = state;

      debugPrint("STATE: $state");


      if (calibDialogKey?.currentState == null) return;

      switch (state) {
        case "WAIT_BLANK":
          print("🔥 Wait blank");
         await speak("Wait blank sample");
          calibDialogKey!.currentState!.updateStep(0);
          break;

        case "BLANK_RUNNING":
          print("🔥 process blank");
          await speak("Processing blank sample");
          calibDialogKey!.currentState!.updateStep(-1);
          // stopCalibPolling(); // 🔥 ADD THIS

          // reconnectAfterProcessing(); // 🔥 ADD THIS
          // 🔥 WAIT + RECONNECT + CHECK
          waitReconnectAndCheck(15);
          break;

        case "BLANK_DONE":
          print("🔥 blank Done");
          await speak("Blank Sample Calibration completed.");
          calibDialogKey?.currentState?.updateStep(1);
          break;
        case "WAIT_STD":
          print("🔥 Wait STD");
          await speak("wait standard sample");
          calibDialogKey!.currentState!.updateStep(2);
          break;

        case "STD_RUNNING":
          print("🔥 RUN stad");
          calibDialogKey?.currentState?.updateStep(2);
          await speak("Processing standard sample");
          // 🔥 WAIT + RECONNECT + CHECK
          waitReconnectAndCheck(15);
          break;
        case "CALIB_DONE":
          print("🔥 Done Calib");
          await speak("Calibration completed");
          calibDialogKey!.currentState!.updateStep(3);
          break;

        case "ERROR":
          print("🔥 ERrro");
          await speak("Calibration error");
          break;
      }
    }

    // ✅ RESULT HANDLE
    // else if (res.startsWith("#RESP:OK") && !isResultShown) {
    else if ((res.startsWith("#RESP:OK") ||
        (res.contains("P:") && res.contains("U:")))
        && !isResultShown){


      setState(() {
        status = "RESULT RECEIVED";
        isRunning = false;
        isResultShown = true; // 🔥 MUST ADD
      });
      await speak("Test completed successfully");

      Map<String, dynamic> parsed = parseResult(res);

      // 🔥 DEBUG DIALOG (ADD THIS)
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   showIOSDebugDialog(res);
      // });
      // showResultPopup(parsed); // 🔥 POPUP SHOW

      if (!mounted) return;

      Future.delayed(Duration.zero, () {
        if (!mounted) return;
        showResultPopup_2(parsed);
      });
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   showResultPopup(parsed);
      // });
      // await disconnectDevice();
      // 🔥 SAVE TO DB HERE
      String pValue = "--";
      String sValue = "--";
      String uValue = "--";
      String eValue = "--";
      String rValue = "--";
      String refValue = "--";

      String rawP = parsed["P"]["raw"] ?? "";

      // final regex = RegExp(r'([\d.]+)\(([\d.]+)\)');
      // final regex = RegExp(r'([A-Za-z0-9.\s]+)\(([-\d.]+)\)');
      final regex = RegExp(r'([-\dA-Za-z0-9.\s]+)\(([-\d.]+)\)');
      // final regex = RegExp(r'([-\d.]+)\(([-\d.]+)\)');
      final match = regex.firstMatch(rawP);

      if (match != null) {
        pValue = match.group(1) ?? "--";
        refValue = match.group(2) ?? "--";
      } else {
        pValue = rawP;
        refValue = "--";
      }
      // 🔥 FORCE FIX FOR PROTEIN
      if (pValue.startsWith("-")) {
        pValue = "NA";
      }
      print("DEBUG REF VALUE: $refValue");
      sValue = parsed["S"]?["value"] ?? parsed["S"] ?? "--";
      uValue = parsed["U"]?["value"] ?? parsed["U"] ?? "--";
      eValue = parsed["e"]?["value"] ?? parsed["e"] ?? "--";
      rValue = parsed["r"]?["value"] ?? parsed["r"] ?? "--";
// 🔥 CLEAN HERE
      pValue = formatValue("P", pValue);
      // 🔥 HARD CHECK (important)
      if (pValue == "-1.00" || pValue == "-1" || pValue.startsWith("-")) {
        pValue = "NA";
      }
      sValue = formatValue("S", sValue);
      uValue = formatValue("U", uValue);
      eValue = formatValue("e", eValue);
      rValue = formatValue("r", rValue);


      if (refValue == "-1.00" || refValue == "-1.000000" || refValue.startsWith("-1")|| refValue == "--") {
        refValue = "NA";
      }
      Future.microtask(() async {
      await _updateResultDB(pValue,sValue,uValue,eValue,rValue,refValue,availableTests);

      await _decreaseTestCount();
      });
      setState(() {
        status = "IDLE";
        progress = 0;
        runningTest = "";
        isResultShown = false;
      });
    }
  }

  // ---------------- UI ----------------
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
          "TEST SCREEN ",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.tune_outlined, color: Colors.blue),
                onPressed: () {
                  // _showDeviceScanPopup();
                  // startCalibration(context);
                  isRunning ? null : startCalibration(context);
                },
              ),
            ),
          ),
        ],
      ),

      body: Stack(
        children: [

          // ✅ BACKGROUND IMAGE
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/main.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ✅ MAIN UI
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: SingleChildScrollView(
              child: Column(
                children: [

                  // STATUS CARD
                  GestureDetector(
                  onTap: () {
                  speakCurrentStatus();
                  },
                  child: ClipRRect(
                  // ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25), // ✅ not too transparent
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            // 🔵 BIG STATUS ICON
                            buildStatusIcon(),

                            const SizedBox(height: 20),

                            // 🔤 STATUS TEXT (main focus)
                            Text(
                              status,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // 🔔 BUZZER
                            buildBuzzer(),

                            const SizedBox(height: 8),

                            // 🧪 TEST NAME
                            Text(
                              getName(runningTest),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                      ),
                    ),
                  ),
                  ),
                 const SizedBox(height: 30),

                  // PROGRESS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor:
                      const AlwaysStoppedAnimation(Colors.green),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text("${(progress * 100).toInt()}%"
                    ,style: const TextStyle(color: Colors.white),),

                  const SizedBox(height: 30),

                  // BUTTONS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        buildButton("Protein Test", "PROTEIN"),
                        buildButton("Serum Creatinine Test", "SCRT"),
                        buildButton("Urine Creatinine Test", "UCRT"),
                        const SizedBox(height: 10),

                        buildFinishButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ LOADING OVERLAY
          if (isRunning)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildButton(String title, String cmd) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: ()  //startTest(cmd),
          {
            // if (completedTests.contains(cmd)) {
            //   showRetestDialog(cmd); // 🔥 confirm dialog
            // } else {
            // startTest(cmd);
            // }
            showTestConfirmDialog(cmd);
            
          },

        
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: getButtonColor(cmd),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        // 🔥 UPDATED CHILD
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ✅ SHOW CHECK ICON IF COMPLETED
            if (completedTests.contains(cmd)) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                size: 18,
                color: Colors.black,
              ),
            ],
          ],
        ),
      ),
    );
  }
  Widget buildFinishButton() {
    // bool isEnabled = selectedTests.isNotEmpty || runningTest.isNotEmpty;

    bool isEnabled = completedTests.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: isEnabled ? showFinishPopup : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: isEnabled ? Colors.redAccent : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),


          ),
        ),
        child: const Text(
          "Finish",
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );

  }


  List<String> getRemainingTests() {
    return allTests.where((test) => !completedTests.contains(test)).toList();
  }

  void showFinishPopup() {
    List<String> remainingTests = getRemainingTests();

    String completedNames = completedTests.isEmpty
        ? "None"
        : completedTests.map((e) => getName(e)).join("\n");

    String remainingNames = remainingTests.isEmpty
        ? ""
        : remainingTests.map((e) => getName(e)).join("\n");

    bool hasRemaining = remainingTests.isNotEmpty;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text("Test Summary"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text("✅ Completed Tests:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(completedNames),

              // 🔥 ONLY SHOW IF REMAINING EXISTS
              if (hasRemaining) ...[
                const SizedBox(height: 15),
                const Text("⏳ Remaining Tests:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(remainingNames),
              ],

              const SizedBox(height: 15),
              const Text("What do you want to do?"),
            ],
          ),
        ),
        actions: [

          // 🔥 ONLY SHOW BUTTON IF REMAINING EXISTS
          if (hasRemaining)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Remaining Test Process"),
            ),

          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await getResultFromDevice();
            },
            child: const Text("Get Result"),
          ),
        ],
      ),
    );
  }


  Future<void> getResultFromDevice() async {
    setState(() {
      status = "GETTING RESULT";
      isResultShown = false; // 🔥 ADD THIS
    });

    await connectDevice();
    await sendCommand("#GET:finalResult");
  }

   Map<String, dynamic> parseResult(String res) {
    Map<String, dynamic> result = {};

    try {
      String data = res.split("OK:")[1];
      List<String> parts = data.split(",");

      for (var p in parts) {
        List<String> kv = p.split(":");

        if (kv.length == 2) {
          String key = kv[0].trim();
          String value = kv[1].trim();

          if (key == "P") {
              final regex = RegExp(r'([-\d.]+)\(([-\d.]+)\)');
              final match = regex.firstMatch(value);

              String val = "--";
              String ref = "--";

              if (match != null) {
                val = match.group(1) ?? "--";
                ref = match.group(2) ?? "--";
              } else {
                val = value;
              }

              // 🔥 MAIN FIX (यहीं करो)
              if (val.startsWith("-")) {
                val = "NA";
              }

              if (ref.startsWith("-")) {
                ref = "NA";
              }

              result["P"] = {
                "value": val,
                "ref": ref,
                "raw": value
              };

          } else {
            result[key] = {
              "value": value,
              "ref": "",
              "raw": value
            };
          }
        }
      }
    } catch (e) {
      result["error"] = "Parsing Error";
    }

    return result;
  }
  String formatValue(String key, String value) {


    if (value.isEmpty) return "--";

    // 🔥 Remove bracket part: "2.56(0.123456)" → "2.56"
    if (value.contains("(")) {
      value = value.split("(")[0];
    }
    value = value.trim();
    // 🔥 handle all -1 formats (-1, -1.0, -1.00)
    // 🔥 Handle special cases
    if (value == "-1.00" || value == "-1") {
      return "NA";
    }

    if (value.toLowerCase() == "absent") {
      return "Absent";
    }

    // 🔥 Protein → 0 = Absent
    if (key == "P" && (value == "0.00" || value == "0" || value == "0.0")) {
      return "Absent";
    }
    if (key == "P" && (value == "-1.00" || value == "-1" || value == "-1.0")) {
      return "NA";
    }

    return value;
  }
  Future<void> showResultPopup(Map<String, dynamic> data) async {
    int latestCount = await getAvailableTestCount() - 1;

    if (!mounted) return;

    await Future.delayed(Duration(milliseconds: 100));

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("Test Result"),
        content: data.containsKey("error")
            ? Text(data["error"]!)
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resultRow(Icons.science, "Protein", "P", data),
            _resultRow(Icons.water_drop, "Urine Creatinine", "U", data),
            _resultRow(Icons.biotech, "Serum Creatinine", "S", data),
            _resultRow(Icons.bar_chart, "eGFR", "e", data),
            _resultRow(Icons.balance, "P/C Ratio", "r", data),
            const SizedBox(height: 12),
            Text(
              "Available Tests: $latestCount",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: getTestCountColor(latestCount),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // 🔥 pehle dialog band
            },
            child: const Text("OK"),
          )
        ],
      ),
    );

    // 🔥 dialog band hone ke baad navigation karo
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MyDevicesPage2(
          user: widget.user,
        ),
      ),
    );

    await disconnectDevice();

    // if (!mounted) return;
    //
    // setState(() {
    //   status = "IDLE";
    //   progress = 0;
    //   runningTest = "";
    //   isResultShown = false;
    // });
  }
  // Future<void> showResultPopup(Map<String, dynamic> data) async {
  //   int latestCount = await getAvailableTestCount() -1; // 🔥 fetch latest
  //   if (!mounted) return;
  //
  //   await Future.delayed(Duration(milliseconds: 100));
  //
  //   showDialog(
  //     context:  Navigator.of(context, rootNavigator: true).context, // 🔥 FIX
  //     builder: (context) => AlertDialog(
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(20),
  //       ),
  //       title: const Text("Test Result"),
  //       content: data.containsKey("error")
  //           ? Text(data["error"]!)
  //           : Column(
  //         mainAxisSize: MainAxisSize.min,
  //         // crossAxisAlignment: CrossAxisAlignment.start,
  //
  //         children: [
  //           _resultRow(Icons.science, "Protein", "P", data),
  //           _resultRow(Icons.water_drop, "Urine Creatinine", "U", data),
  //           _resultRow(Icons.biotech, "Serum Creatinine", "S", data),
  //           _resultRow(Icons.bar_chart, "eGFR", "e", data),
  //           _resultRow(Icons.balance, "P/C Ratio", "r", data),
  //           const SizedBox(height: 12),
  //
  //           // 🔥 NEW LINE
  //           Text(
  //             "Available Tests: $latestCount",
  //             style: TextStyle(
  //               fontWeight: FontWeight.bold,
  //               color: getTestCountColor(latestCount),
  //             ),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () async {
  //             Navigator.pushReplacement(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (_) => MyDevicesPage2(
  //                   user: widget.user,
  //                 ),
  //               ),
  //
  //             );
  //
  //             await disconnectDevice();
  //
  //             setState(() {
  //               status = "IDLE";
  //               progress = 0;
  //               runningTest = "";
  //               isResultShown = false;
  //             });
  //           },
  //           child: const Text("OK"),
  //         )
  //       ],
  //     ),
  //   );
  // }

  Future<void> disconnectDevice() async {
    try {
      notifySub?.cancel();
      notifySub = null;

      if (widget.device.isConnected) {
        await widget.device.disconnect();
      }

      debugPrint("BLE Disconnected");
    } catch (e) {
      debugPrint("Disconnect Error: $e");
    }
  }

  void showRetestDialog(String cmd) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Confirm"),
        content: Text("Do you want to run ${getName(cmd)} again?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ❌ NO → bas close
            },
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // dialog close
              startTest(cmd); // 🔥 dubara test start
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  Future<bool> _updateResultDB(String P_result,String S_result,String U_result,String e_result,String R_result, String refValue,int count) async {
    final now = DateTime.now();
    // final key =
    //     "${now.day}-${now.month}-${now.year}_${now.hour}:${now.minute}:${now
    //     .second}";

    final key = DateFormat('dd-MM-yy_HH:mm:ss').format(now);

    final data = {
      "dt": key,
      "id": selectedDeviceId,
      "p": P_result,
      "s":S_result,
      "u":U_result,
      "e":e_result,
      "r":R_result,
      "volt": refValue,
      "count": count,

    };

    try {
      await dbRef.child("NephroResult/${widget.user.mobile}/$key").set(data);
      // print("Result saved successfully");
      debugPrint("Result saved online");
      return true;
    } catch (e) {
      debugPrint("Online save failed → storing offline");

      await saveToOfflineQueue({
        "path": "NephroResult/${widget.user.mobile}/$key",
        "data": data,
      });

      return false;
      // print("Error saving result: $e");
      //
      // // Save locally in list
      // // pendingResults.add(data);
      //
      // print("Saved locally in pending list");
      // return false;
    }
  }

  Future<void> loadAvailableTests() async {
    int count = await getAvailableTestCount();

    setState(() {
      availableTests = count;
    });
  }
  Future<int> getAvailableTestCount() async {
    final ref = dbRef.child(
        "Devices/${widget.user.mobile}/$selectedDeviceId/testCount");

    final snapshot = await ref.get();

    if (!snapshot.exists) return 0;

    return (snapshot.value as num).toInt();
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

  Widget _resultRow(IconData icon, String label, String key, Map<String, dynamic> data) {

    final item = data[key];

    String value = "--";
    String ref = "";

    if (item is Map) {
      value = item["value"] ?? "--";
      ref = item["ref"] ?? "";
    } else if (item is String) {
      value = item;
    }

    // 🔥 Apply formatting
    value = formatValue(key, value);

    String unit = resultUnits[key] ?? "";
    value = value.trim();
    // 🔥 NA / Absent → NO UNIT
    if (value == "NA" || value == "Absent" || value == "inf") {
      unit = "";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 10),

          Expanded(
            child: Text(
              unit.isNotEmpty
                  ? "$label: $value $unit"
                  : "$label: $value",
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // 🔥 Show REF only for Protein and valid value
          // if (key == "P" && ref.isNotEmpty && value != "NA" && value != "Absent")
          //   Text(
          //     "($ref)",
          //     style: const TextStyle(fontSize: 12, color: Colors.grey),
          //   ),
        ],
      ),
    );
  }
  Color getTestCountColor(int count) {
    if (count == 0) {
      return Colors.red;
    } else if (count < 5) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  Future<void> saveToOfflineQueue(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> queue = prefs.getStringList("offline_queue") ?? [];

    queue.add(jsonEncode(data));

    await prefs.setStringList("offline_queue", queue);

    debugPrint("Saved to offline queue");
  }

  Future<void> _syncOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList("offline_queue") ?? [];

    if (queue.isEmpty) return;

    List<String> remaining = [];

    for (String item in queue) {
      try {
        final decoded = jsonDecode(item);

        await dbRef
            .child(decoded["path"])
            .set(decoded["data"]);

        debugPrint("Synced offline item");
      } catch (e) {
        remaining.add(item); // keep if still failing
      }
    }

    await prefs.setStringList("offline_queue", remaining);

    debugPrint("Offline sync completed. Remaining: ${remaining.length}");
  }

  Future<void> startCalibration(BuildContext context) async {
    bool connected = await connectDevice();

    if (!connected) {
      await speak("Device not connected");
      return;
    }

    calibDialogKey = GlobalKey<_CalibrationDialogState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CalibrationDialog(
        key: calibDialogKey,
        onStartStd: () async {
          // await sendSafeCommand("#START:CALIB_NEXT");
          await sendCommand("#START:CALIB_NEXT");
        },
        onCalibrationComplete: () async {
          await disconnectDevice(); // 🔥 BLE OFF HERE
          // 🔥 ADD THIS (MAIN FIX)
          setState(() {
            status = "IDLE";
            isRunning = false;
            progress = 0;
            runningTest = "";
          });

          await ("Device is ready");
        },
      ),
    );

    await Future.delayed(Duration(milliseconds: 200));

    // 🔥 Start Blank
    // await sendSafeCommand("#START:CALIB");

    await sendCommand("#START:CALIB");
    setState(() {
      isRunning = true;   // 🔥 ADD
      status = "CALIBRATION";
    });
    // UI update
    // calibDialogKey?.currentState?.updateStep(0);
    await speak("Insert blank sample");

    // 🔥 Start polling
    // startCalibPolling();
  }
  Future<void> waitReconnectAndCheckTest(int seconds) async {
    print("⏳ Waiting $seconds sec before reconnect (TEST)");

    await Future.delayed(Duration(seconds: seconds));

    int retry = 0;
    bool connected = false;

    while (retry < 10 && !connected) {
      print("🔄 Reconnect attempt ${retry + 1}");

      connected = await forceReconnect();

      if (!connected) {
        await Future.delayed(Duration(seconds: 5));
        retry++;
      }
    }

    if (!connected) {
      print("❌ Reconnect failed after retries");
      setState(() {
        status = "DEVICE NOT CONNECTED";
        isRunning = false;
      });
     await speak("Device not connected");
      return;
    }

    print("✅ Reconnected, checking status...");

    await sendCommand("#GET:TEST_STATUS");
  }
  Future<void> waitReconnectAndCheck(int seconds) async {
    print("⏳ Waiting $seconds sec before reconnect");

    await Future.delayed(Duration(seconds: seconds));

    bool connected = await forceReconnect();

    if (!connected) {
      print("❌ Reconnect failed, retrying...");

      await Future.delayed(Duration(seconds: 5));
      return waitReconnectAndCheck(seconds); // 🔁 retry
    }

    print("✅ Reconnected, checking status...");

    await sendCommand("#GET:CALIB_STATUS");
  }
  Future<void> reconnectAfterProcessing() async {
    // speak("wait for Reconnecting device");
    if (isReconnecting) return; // 🔥 avoid double

    isReconnecting = true;
    await Future.delayed(Duration(seconds: 10));

    // speak("Reconnecting device");
    bool connected = await connectDevice();

    isReconnecting = false; // 🔥 MUST ADD
  }

  Future<void> speak(String text) async {
    if (isMuted) return; // 🔥 mute control
    await tts.stop(); // 🔥 previous voice stop
    await tts.setLanguage(selectedLang); // 🔥 dynamic language
    await tts.speak(text);
  }

  Future<void> showTestConfirmDialog(String cmd) async {
    String name = getName(cmd);

   await speak("Do you want to start $name");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text("Start Test"),
        content: Text("Do you want to start $name?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await speak("Test cancelled");
            },
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

             await speak("Starting $name");

              startTest(cmd);
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  Future<void> speakCurrentStatus() async {
    if (isRunning) {
      await speak("$runningTest test is running. Status is $status");
    } else {
      await speak("No test is running");
    }
  }

   Future<bool> forceReconnect() async {
    try {
      // 🔴 STEP 1: Disconnect if already connected
      await disconnectDevice();
      await Future.delayed(const Duration(seconds: 2));

      // 🟢 STEP 2: Fresh connect
      bool connected = await connectDevice();

      if (connected) {
        debugPrint("✅ Reconnected successfully");
        return true;
      } else {
        debugPrint("❌ Reconnect failed");
        return false;
      }
    } catch (e) {
      debugPrint("Reconnect error: $e");
      return false;
    }
  }
  Future<bool> waitUntilDeviceFree() async {
    int retry = 0;

    while (retry < 10) {
      if (!isDeviceBusy) {
        return true;
      }

      debugPrint("⏳ Device busy... waiting");
      await Future.delayed(const Duration(seconds: 5));
      retry++;
    }

    return false;
  }

  Future<void> sendSafeCommand(String cmd) async {

    // 🔴 Step 1: check connection only
    if (!isDeviceConnected) {
      print("⚠️ Device not connected, skip: $cmd");
      return;
    }

    // 🟡 Step 2: optional busy check
    if (isDeviceBusy) {
      print("⏳ Device busy, skip: $cmd");
      return;
    }

    // 🟢 Step 3: send safely
    try {
      await sendCommand(cmd);
      print("✅ Sent: $cmd");
    } catch (e) {
      print("❌ Write Error: $e");
    }
  }

  // Future<void> showIOSDebugDialog(String message) async {
  //   if (!mounted) return;
  //
  //   Future.delayed(Duration.zero, () {
  //     if (!mounted) return;
  //
  //     showDialog(
  //       context: context,
  //       barrierDismissible: true,
  //       builder: (ctx) {
  //         return AlertDialog(
  //           title: Text("DEBUG"),
  //           content: SingleChildScrollView(
  //             child: Text(message),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.of(ctx).pop(),
  //               child: Text("OK"),
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //   });
  // }


  Future<void> showResultPopup_2(Map<String, dynamic> data) async {
    if (Platform.isIOS) {
      return showIOSResultDialog(data);
    } else {
      return showResultPopup(data);
    }
  }

  Future<void> showIOSResultDialog(Map<String, dynamic> data) async {
    int latestCount = await getAvailableTestCount();

    // 🔥 Firebase update ke baad hi -1 karo
    int displayCount = latestCount - 1;

    if (!mounted) return;

    Future.delayed(Duration.zero, () {
      if (!mounted) return;

      String message = "";

      if (data.containsKey("error")) {
        message = data["error"];
      } else {
        message =
            "Protein: ${data["P"]?["value"] ?? data["P"] ?? "--"}\n"
            "Urine Creatinine: ${data["U"]?["value"] ?? data["U"] ?? "--"}\n"
            "Serum Creatinine: ${data["S"]?["value"] ?? data["S"] ?? "--"}\n"
            "eGFR: ${data["e"]?["value"] ?? data["e"] ?? "--"}\n"
            "P/C Ratio: ${data["r"]?["value"] ?? data["r"] ?? "--"}\n\n";
            // 🔥 NEW LINE (Available Test)
            //     "Available Tests: $displayCount";
            }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text("Test Result"),
            content: SingleChildScrollView(
              child: Text(message),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();

                  if (!mounted) return;

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyDevicesPage2(user: widget.user),
                    ),
                  );

                  await disconnectDevice();
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    });
  }

  // Future<void> showIOSResultDialog(Map<String, dynamic> data) async {
  //
  //   int latestCount = await getAvailableTestCount() - 1;
  //
  //   if (!mounted) return;
  //
  //   Future.delayed(Duration.zero, () {
  //     if (!mounted) return;
  //
  //     String format(String label, dynamic value) {
  //       return "$label : ${value ?? "--"}";
  //     }
  //
  //     String message = "";
  //
  //     if (data.containsKey("error")) {
  //       message = data["error"];
  //     } else {
  //       message =
  //           "${format("Protein", data["P"]?["value"] ?? data["P"])}\n\n"
  //           "${format("Urine Creatinine", data["U"]?["value"] ?? data["U"])}\n\n"
  //           "${format("Serum Creatinine", data["S"]?["value"] ?? data["S"])}\n\n"
  //           "${format("eGFR", data["e"]?["value"] ?? data["e"])}\n\n"
  //           "${format("P/C Ratio", data["r"]?["value"] ?? data["r"])}\n\n";
  //           // "----------------------\n"
  //           "\nAvailable Tests : $latestCount";
  //     }
  //
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (ctx) {
  //         return AlertDialog(
  //           title: Text("Test Result"),
  //           content: SingleChildScrollView(
  //             child: Text(
  //               message,
  //               style: TextStyle(
  //                 height: 1.5, // 🔥 spacing improve
  //                 fontSize: 14,
  //               ),
  //             ),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () async {
  //                 Navigator.of(ctx).pop();
  //
  //                 if (!mounted) return;
  //
  //                 Navigator.pushReplacement(
  //                   context,
  //                   MaterialPageRoute(
  //                     builder: (_) => MyDevicesPage2(user: widget.user),
  //                   ),
  //                 );
  //
  //                 await disconnectDevice();
  //               },
  //               child: Text("OK"),
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //   });
  // }

}
class CalibrationDialog extends StatefulWidget {
  // final Function(String) sendCommand;

  // const CalibrationDialog({super.key, required this.sendCommand});
  final VoidCallback onStartStd;
  final VoidCallback onCalibrationComplete;

  const CalibrationDialog({
    super.key,
    required this.onStartStd,
    required this.onCalibrationComplete,
  });

  @override
  State<CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<CalibrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int step = -1; // 🔥 start unknown

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  void updateStep(int newStep) {
    setState(() => step = newStep);

    // 🔥 ROTATION CONTROL
    if (newStep == -1 || newStep == 2) {
      _controller.repeat(); // running states
    } else {
      _controller.stop();
    }

    if (newStep == 3) {
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) {
          widget.onCalibrationComplete(); // 🔥 BLE OFF
          Navigator.pop(context);
        }
      });
    }
  }

  double get progress {
    switch (step) {
      case -1:
        return 0.1; // blank running
      case 0:
        return 0.3;
      case 1:
        return 0.6; // waiting std
      case 2:
        return 0.85; // std running
      case 3:
        return 1.0; // done
      default:
        return 0.0;
    }
  }
  String get message {
    switch (step) {
      case -1:
        return "Calibration in progress...\nPlease wait";
      case 0:
        return "Insert Blank Sample";
      case 1:
        return "Insert Standard Sample and press continue";
      case 2:
        return "Processing...";
      case 3:
        return "Calibration Completed Successfully";
      default:
        return "";
    }
  }

  String get buttonText {
    switch (step) {
      case 1:
        return "NEXT";
      case 3:
        return "FINISH";
      default:
        return "Please Wait..!";
    }
  }

  void next() {
    if (step == 1) {
      // widget.sendCommand("#START:CALIB_NEXT");
      widget.onStartStd();
    } else if (step == 3) {
      Navigator.pop(context);

    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: const [
          Icon(Icons.science, color: Colors.blue),
          SizedBox(width: 10),
          Text("Device Calibration"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          /// 🔹 STEP INDICATOR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepCircle(0, "Blank"),
              _stepLine(),
              _stepCircle(1, "Standard"),
              _stepLine(),
              _stepCircle(3, "Done"),
            ],
          ),

          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: step == 3
                ? Icon(
              Icons.check_circle,
              key: ValueKey(step),
              size: 50,
              color: Colors.green,
            )
                : RotationTransition(
              turns: _controller,
              child: Icon(
                Icons.settings,
                key: ValueKey(step),
                size: 50,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 15),

          /// 🔹 MESSAGE
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),

          const SizedBox(height: 20),

          /// 🔹 PROGRESS BAR
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, _) {
              return Column(
                children: [
                  LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${(value * 100).toInt()}%",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
        ],
      ),

      /// 🔹 ACTION BUTTON
      actions: [
        TextButton(
          onPressed: (step == 1 || step == 3) ? next : null,
          child: Text(buttonText),
        ),
      ],
    );
  }
  Widget _stepCircle(int stepIndex, String label) {
    bool isActive = step >= stepIndex;

    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: isActive ? Colors.blue : Colors.grey.shade300,
          child: isActive
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
            "${stepIndex == 3 ? 3 : stepIndex + 1}",
            style: const TextStyle(fontSize: 10),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.blue : Colors.grey,
          ),
        )
      ],
    );
  }

  Widget _stepLine() {
    return Expanded(
      child: Container(
        height: 2,
        color: Colors.grey.shade300,
      ),
    );
  }

}




