// ✅ FULL MULTI TEST HISTORY PAGE

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'myDevicesPage.dart';
import 'mydoctor.dart';
import 'user_model.dart';
import  'myprofile.dart';

class TesthistoryPage extends StatefulWidget {
  final UserModel user;
  final String? patientMobile;

  const TesthistoryPage({
    super.key,
    required this.user,
    this.patientMobile,
  });

  @override
  State<TesthistoryPage> createState() => _TesthistoryPageState();
}

class _TesthistoryPageState extends State<TesthistoryPage> {
  final dbRef = FirebaseDatabase.instance.ref();

  late String targetMobile;

  DateTime? _selectedDate;
  DateTimeRange? _selectedRange;
  DateTime? _selectedMonth;

  bool _isLoading = false;


  final Map<String, String> resultUnits = {
    "p": "mg/dL",
    "u": "mg/dL",
    "s": "mg/dL",
    "e": "mL/min/1.73m²",
    "r": "",
  };


  @override
  void initState() {
    super.initState();
    targetMobile = widget.patientMobile ?? widget.user.mobile;
  }

  // ================= FILTER =================

  bool _applyFilter(DateTime date) {
    if (_selectedDate != null) {
      return date.year == _selectedDate!.year &&
          date.month == _selectedDate!.month &&
          date.day == _selectedDate!.day;
    } else if (_selectedRange != null) {
      return date.isAfter(_selectedRange!.start.subtract(const Duration(days: 1))) &&
          date.isBefore(_selectedRange!.end.add(const Duration(days: 1)));
    } else if (_selectedMonth != null) {
      return date.year == _selectedMonth!.year &&
          date.month == _selectedMonth!.month;
    }
    return true;
  }

  // ================= PDF =================

  Future<void> _generatePdf(Map data) async {
    List<Map<String, dynamic>> list = [];

    for (var key in data.keys) {
      final parts = key.split("_");
      final date = DateFormat("dd-MM-yyyy").parse(parts[0]);

      if (_applyFilter(date)) {
        final d = data[key];

        list.add({
          "time": key,
          "id": d["id"] ?? "-",
          "p": d["p"] ?? "-",
          "u": d["u"] ?? "-",
          "s": d["s"] ?? "-",
          "e": d["e"] ?? "-",
          "r": d["r"] ?? "-",
        });
      }
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text("Nephro Test Report",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            headers: ["No", "Device", "Date", "Time", "P", "U", "S", "E", "R"],
            data: List.generate(list.length, (i) {
              final item = list[i];
              final parts = item["time"].split("_");

              return [
                "${i + 1}",
                item["id"],
                parts[0],
                parts.length > 1 ? parts[1] : "-",
                item["p"],
                item["u"],
                item["s"],
                item["e"],
                item["r"],
              ];
            }),
          )
        ],
      ),
    );

    final bytes = await pdf.save();

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/report.pdf");

    await file.writeAsBytes(bytes);

    await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
  }

  // ================= UI =================

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

        /// 🔹 LEFT MENU
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
                const PopupMenuItem(
                  value: "device",
                  child: Row(
                    children: [
                      Icon(Icons.devices, color: Colors.black),
                      SizedBox(width: 8),
                      Text("My Device",
                          style: TextStyle(color: Colors.black)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: "doctor",
                  child: Row(
                    children: [
                      Icon(Icons.people, color: Colors.black),
                      SizedBox(width: 8),
                      Text("My Doctor",
                          style: TextStyle(color: Colors.black)),
                    ],
                  ),
                ),
              ],
            );


            if (selected == "home") {
              Navigator.pushNamed(context, "/home");
            }
            else if (selected == "device") {
              // Navigator.pushNamed(context, "/myDevice");
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyDevicesPage2(
                    user: widget.user,
                  ),
                ),
              );
            }
            else if (selected == "profile") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyProfileScreen(
                    user: widget.user,
                  ),
                ),
              );
            }
            else if (selected == "doctor") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyDoctorPage(
                    user: widget.user,
                  ),
                ),
              );
            }
          },
        ),

        title: const Text(
          "Test History",
          style: TextStyle(color: Colors.white),
        ),

        /// 🔹 RIGHT MENU (FILTER + PDF)
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showPopupMenu,
          ),
        ],
      ),

      body: Stack(
        children: [

          /// 🔹 BACKGROUND
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/main.png"),
                fit: BoxFit.cover,
              ),
            ),

            child: Padding(
              padding: const EdgeInsets.only(top: 90),

              child: StreamBuilder<DatabaseEvent>(
                stream: dbRef.child("NephroResult/$targetMobile").onValue,
                builder: (context, snapshot) {

                  if (!snapshot.hasData ||
                      snapshot.data?.snapshot.value == null) {
                    return const Center(
                      child: Text(
                        "No Result Found",
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final data = Map<dynamic, dynamic>.from(
                      snapshot.data!.snapshot.value as Map);

                  List<String> filteredKeys = [];

                  for (var key in data.keys) {
                    try {
                      final parts = key.toString().split("_");
                      final date =
                      DateFormat("dd-MM-yy").parse(parts[0]);

                      if (_applyFilter(date)) {
                        filteredKeys.add(key);
                      }
                    } catch (_) {}
                  }

                  /// SORT
                  filteredKeys.sort(
                          (a, b) => b.toString().compareTo(a.toString()));

                  if (filteredKeys.isEmpty) {
                    return const Center(
                      child: Text(
                        "No Result Found for \n Selected Filter",
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  /// 🔥 LIST VIEW
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredKeys.length,
                    itemBuilder: (context, index) {

                      final key = filteredKeys[index];
                      final testData =
                      Map<dynamic, dynamic>.from(data[key]);

                      final p = testData["p"] ?? "-";
                      final u = testData["u"] ?? "-";
                      final s = testData["s"] ?? "-";
                      final e = testData["e"] ?? "-";
                      final r = testData["r"] ?? "-";
                      String date = "--";
                      String time = "--";

                      if (key.contains("_")) {
                        final parts = key.split("_");
                        date = parts[0];
                        time = parts[1];
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              /// 🔹 Title Center
                              const Center(
                                child: Text(
                                  "Nephro Test Result",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              /// 🔹 Row 1 (FIXED ALIGNMENT)
                              Row(
                                children: [
                                  Expanded(child: _valueItem("Protein", testData["p"],"p")),

                                  _verticalDivider(),

                                  Expanded(child: _valueItem("Urine Creatinine", testData["u"],"u")),

                                  _verticalDivider(),

                                  Expanded(child: _valueItem("Serum Creatinine", testData["s"],"s")),
                                ],
                              ),

                              const SizedBox(height: 5),

                              const Divider(thickness: 1),

                              const SizedBox(height: 5),

                              /// 🔹 Row 2
                              Row(
                                children: [
                                  Expanded(child: _valueItem("eGFR", testData["e"],"e")),

                                  _verticalDivider(),

                                  Expanded(child: _valueItem("P/C Ratio",testData["r"],"r")),

                                  _verticalDivider(),

                                  Expanded(child: _dateTimeItem(date, time)),

                                ],
                              ),

                              // const SizedBox(height: 12),

                              /// 🔹 Date
                              // Row(
                              //   children: [
                              //     const Text(
                              //       "Test Execution Date & Time: ",
                              //       style: TextStyle(
                              //         fontSize: 13,
                              //         color: Colors.grey,
                              //       ),
                              //     ),
                              //     Expanded(
                              //       child: Text(
                              //         key,
                              //         style: const TextStyle(
                              //           fontSize: 13,
                              //           fontWeight: FontWeight.w500,
                              //         ),
                              //       ),
                              //     ),
                              //   ],
                              // ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          /// 🔹 LOADING
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      "Loading ....",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  void _showPopupMenu() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 0, 0),
      items: [
        const PopupMenuItem(
          value: "filter",
          // child: Text("Filter by Date"),
          child: Row(
            children: [
              Icon(Icons.find_in_page_outlined, color: Colors.orange),
              SizedBox(width: 10),
              Text("Filter by Date"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: "pdf",
          // child: Text("Export as PDF"),
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.blue),
              SizedBox(width: 10),
              Text("Export as PDF"),
            ],
          ),
        ),

        if (_selectedDate != null ||
            _selectedRange != null ||
            _selectedMonth != null)
          const PopupMenuItem(
            value: "clear",
            child: Row(
              children: [
                Icon(Icons.reply_all, color: Colors.green),
                SizedBox(width: 10),
                Text("Clear Filter"),
              ],
            ),
          ),
      ],
    );

    if (selected == "filter") {
      // _showFilterOptions();
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _isLoading = false);
      _showFilterOptions();

    } else if (selected == "pdf") {
      // _generateTablePdf();
      setState(() => _isLoading = true);
      await _generateTablePdf();
      setState(() => _isLoading = false);
    }
    else if (selected == "clear") {
      // _clearFilter();
      setState(() => _isLoading = true);
      _clearFilter();
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _isLoading = false);
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              title: const Text("Single Date"),
              onTap: () {
                Navigator.pop(context);
                _pickSingleDate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.green),
              title: const Text("Date Range"),
              onTap: () {
                Navigator.pop(context);
                _pickDateRange();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.orange),
              title: const Text("Filter by Month"),
              onTap: () {
                Navigator.pop(context);
                _pickMonth();
              },
            ),


          ],
        ),
      ),
    );
  }
// ---------------- FILTER ----------------

  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedRange = null;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
        _selectedDate = null;
      });
    }
  }
  Future<void> _pickMonth() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: "Select Month",
      fieldLabelText: "Month/Year",
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
        _selectedDate = null;
        _selectedRange = null;
      });
    }
  }
  void _clearFilter() {
    setState(() {
      _selectedDate = null;
      _selectedRange = null;
      _selectedMonth=null;
    });
  }

  Future<void> _generateTablePdf() async {
    final snapshot =
    await dbRef.child("NephroResult/$targetMobile").get();

    if (!snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data available")),
      );
      return;
    }

    final data =
    Map<dynamic, dynamic>.from(snapshot.value as Map);

    List<Map<String, dynamic>> filteredData = [];

    for (var key in data.keys) {
      try {
        final parts = key.toString().split("_");
        final date =
        DateFormat("dd-MM-yy").parse(parts[0]);

        bool include = false;

        if (_selectedDate != null) {
          include =
              date.year == _selectedDate!.year &&
                  date.month == _selectedDate!.month &&
                  date.day == _selectedDate!.day;
        } else if (_selectedRange != null) {
          include = date.isAfter(_selectedRange!.start
              .subtract(const Duration(days: 1))) &&
              date.isBefore(_selectedRange!.end
                  .add(const Duration(days: 1)));
        } else if (_selectedMonth != null) {
          include =
              date.year == _selectedMonth!.year &&
                  date.month == _selectedMonth!.month;
        } else {
          include = true;
        }

        if (include) {
          filteredData.add({
            "timestamp": key,
            "p": data[key]["p"] ?? "N/A",
            "u": data[key]["u"] ?? "N/A",
            "s": data[key]["s"] ?? "N/A",
            "e": data[key]["e"] ?? "N/A",
            "r": data[key]["r"] ?? "N/A",
            "deviceId": data[key]["id"] ?? "-",
          });
        }
      } catch (_) {}
    }

    if (filteredData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("No data for selected filter")),
      );
      return;
    }

    filteredData.sort(
            (a, b) => b["timestamp"].compareTo(a["timestamp"]));

    final pdf = pw.Document();
    final ttf = await PdfGoogleFonts.robotoRegular();
    final logo =
    await imageFromAssetBundle("assets/images/img.png");

    final now = DateFormat("dd-MM-yyyy HH:mm:ss")
        .format(DateTime.now());

    // String title = "PATIENT TEST HISTORY";
    //
    // if (_selectedDate != null) {
    //   title +=
    //   "\nDate: ${DateFormat("dd/MM/yyyy").format(_selectedDate!)}";
    // }
    // else if (_selectedRange != null) {
    //   title +=
    //   "\nRange: ${DateFormat("dd/MM/yyyy").format(_selectedRange!.start)}"
    //       " to ${DateFormat("dd/MM/yyyy").format(_selectedRange!.end)}";
    // }
    // else if (_selectedMonth != null) {
    //   title +=
    //   "\nMonth: ${DateFormat("MMMM yyyy").format(_selectedMonth!)}";
    // }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),

        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttf,
        ),

        /// HEADER
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
                        widget.user.name.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight:
                          pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text("Mobile: $targetMobile"),
                      pw.Text(
                          "Age/Gender: ${widget.user.age}Y / ${widget.user.gender}"),
                      pw.Text("Generated: $now",
                          style: const pw.TextStyle(
                              fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              // pw.Text(
              //   title,
              //   style: pw.TextStyle(
              //     fontSize: 18,
              //     fontWeight: pw.FontWeight.bold,
              //   ),
              // ),

              pw.Column(
                children: [
                  pw.Text(
                    "PATIENT TEST HISTORY",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  if (_selectedDate != null)
                    pw.Text(
                      "Date: ${DateFormat("dd/MM/yyyy").format(_selectedDate!)}",
                      style: const pw.TextStyle(fontSize: 11),
                    ),

                  if (_selectedRange != null)
                    pw.Text(
                      "Range: ${DateFormat("dd/MM/yyyy").format(_selectedRange!.start)}"
                          " to ${DateFormat("dd/MM/yyyy").format(_selectedRange!.end)}",
                      style: const pw.TextStyle(fontSize: 11),
                    ),

                  if (_selectedMonth != null)
                    pw.Text(
                      "Month: ${DateFormat("MMMM yyyy").format(_selectedMonth!)}",
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                ],
              ),
              pw.SizedBox(height: 15),
            ],
          );
        },

        /// FOOTER
        footer: (context) => pw.Column(
          children: [
            pw.Divider(),
            pw.Text(
                "Device Sensitivity: 94.2%   Specificity: 94.5%"),
            pw.Text(
                "Powered by: Cutting Edge Medical Device Pvt. Ltd, Indore"),
            pw.Text("www.cemd.in",
                style: pw.TextStyle(
                    color: PdfColors.blue)),
            pw.Row(
              mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Computer Generated PDF",
                    style:
                    pw.TextStyle(fontSize: 10)),
                pw.Text(
                    "Page ${context.pageNumber}/${context.pagesCount}",
                    style:
                    const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),

        /// TABLE
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(2),
              5: const pw.FlexColumnWidth(2.5),
              6: const pw.FlexColumnWidth(2.5),
              7: const pw.FlexColumnWidth(2),
              8: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    color: PdfColors.grey300),
                children: [
                  _headerCell("S.No"),
                  _headerCell("Device ID"),
                  _headerCell("Date"),
                  _headerCell("Time"),
                  _headerCell("Protein"),
                  _headerCell("Urine Certinine"),
                  _headerCell("Serum Certinine"),
                  _headerCell("eGFR"),
                  _headerCell("P/C Ratio"),
                ],
              ),

              ...List.generate(filteredData.length,
                      (index) {
                    final item = filteredData[index];
                    final parts =
                    item["timestamp"].split("_");

                    return pw.TableRow(
                      children: [
                        _normalCell("${index + 1}"),
                        _singleLineCell(item["deviceId"]),
                        _singleLineCell(parts[0]),
                        _singleLineCell(parts.length > 1
                            ? parts[1]
                            : "-"),

                        _resultCell(
                            item["p"], resultUnits["p"]!),
                        _resultCell(
                            item["u"], resultUnits["u"]!),
                        _resultCell(
                            item["s"], resultUnits["s"]!),
                        _resultCell(
                            item["e"], resultUnits["e"]!),
                        _resultCell(
                            item["r"], resultUnits["r"]!),
                      ],
                    );
                  }),
            ],
          ),
        ],
      ),
    );

    // final bytes = await pdf.save();
    //
    // await Printing.layoutPdf(
    //   onLayout: (format) async => bytes,
    // );
    // Directory dir;
    // if (Platform.isAndroid) {
    //   dir = Directory('/storage/emulated/0/Download');
    // } else {
    //   dir = await getApplicationDocumentsDirectory();
    // }

    final Uint8List bytes = await pdf.save();
    // final file = File("${dir.path}/History_${widget.user.name}.pdf");

    final dir = await getExternalStorageDirectory();
    final file = File("${dir!.path}/History_${widget.user.name}.pdf");

    // await file.writeAsBytes(bytes);
    //
    // _showShareDialog(file);
    await file.writeAsBytes(bytes);

    print("PDF PATH: ${file.path}");




    // final Uint8List bytes = await pdf.save();
    // final dir = await getExternalStorageDirectory();
    // final file =
    // File("${dir?.path}/History_${widget.user.name}.pdf");
    //
    // print("PDF PATH: ${file.path}");

    // await file.writeAsBytes(bytes);

    _showShareDialog(file);
  }
  Future<void> _generateTablePdf_formatingissue() async {
    final snapshot =
    await dbRef.child("NephroResult/$targetMobile").get();

    if (!snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data available")),
      );
      return;
    }

    final data =
    Map<dynamic, dynamic>.from(snapshot.value as Map);

    List<Map<String, dynamic>> filteredData = [];

    for (var key in data.keys) {
      try {
        final parts = key.toString().split("_");
        final date =
        DateFormat("dd-MM-yyyy").parse(parts[0]);

        bool include = false;

        if (_selectedDate != null) {
          include =
              date.year == _selectedDate!.year &&
                  date.month == _selectedDate!.month &&
                  date.day == _selectedDate!.day;
        } else if (_selectedRange != null) {
          include = date.isAfter(_selectedRange!.start
              .subtract(const Duration(days: 1))) &&
              date.isBefore(_selectedRange!.end
                  .add(const Duration(days: 1)));
        } else if (_selectedMonth != null) {
          include =
              date.year == _selectedMonth!.year &&
                  date.month == _selectedMonth!.month;
        } else {
          include = true;
        }

        if (include) {
          filteredData.add({
            "timestamp": key,
            // "result": data[key]["p"] ?? "N/A",
            "p": data[key]["p"] ?? "N/A",
            "u": data[key]["u"] ?? "N/A",
            "s": data[key]["s"] ?? "N/A",
            "e": data[key]["e"] ?? "N/A",
            "r": data[key]["r"] ?? "N/A",
            "deviceId": data[key]["id"] ?? "-",
          });
        }
      } catch (_) {}
    }

    if (filteredData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("No data for selected filter")),
      );
      return;
    }

    filteredData.sort(
            (a, b) => b["timestamp"].compareTo(a["timestamp"]));

    final pdf = pw.Document();
    final ttf = await PdfGoogleFonts.robotoRegular();
    final logo =
    await imageFromAssetBundle("assets/images/img.png");

    final now = DateFormat("dd-MM-yyyy HH:mm:ss")
        .format(DateTime.now());

    String title = "PATIENT TEST HISTORY";

    if (_selectedDate != null) {
      title +=
      "\nDate: ${DateFormat("dd/MM/yy").format(_selectedDate!)}";
    } else if (_selectedRange != null) {
      title +=
      "\nRange: ${DateFormat("dd/MM/yy").format(_selectedRange!.start)} "
          "to ${DateFormat("dd/MM/yy").format(_selectedRange!.end)}";
    } else if (_selectedMonth != null) {
      title +=
      "\nMonth: ${DateFormat("MMMM yy").format(_selectedMonth!)}";
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),

        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttf,
        ),

        /// HEADER (LIKE RECHARGE PDF)
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
                        widget.user.name.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text("Mobile: $targetMobile"),

                      pw.Text(
                          "Age/Gender: ${widget.user.age}Y / ${widget.user.gender}"),
                      pw.Text(
                        "Generated: $now",
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
                title,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 15),
            ],
          );
        },
        /// 🔹 FOOTER SECTION
        footer: (context) => pw.Column(
          children: [

            pw.Divider(),

            pw.SizedBox(height: 5),

            pw.Text(
                "Device Sensitivity: 94.2%   Specificity: 94.5%"),

            pw.Text(
                "Powered by: Cutting Edge Medical Device Pvt. Ltd, Indore"),

            pw.Text("www.cemd.in" ,style: pw.TextStyle(
              color: PdfColors.blue,
            ),),

            /// Computer Generated + Page No on same line
            pw.Stack(
              children: [

                /// Center Text
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "Computer Generated PDF",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),

                /// Right Side Page Number
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    "Page No. ${context.pageNumber} / ${context.pagesCount}",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),

            // pw.SizedBox(height: 8),

            /// Page Number
            // pw.Text(
            //   "Page ${context.pageNumber} / ${context.pagesCount}",
            //   style: const pw.TextStyle(fontSize: 10),
            // ),

            // /// Page number aligned to right
            // pw.Row(
            //   mainAxisAlignment: pw.MainAxisAlignment.end,
            //   children: [
            //     pw.Text(
            //       "Page No. ${context.pageNumber} / ${context.pagesCount}",
            //       style: const pw.TextStyle(fontSize: 10),
            //     ),
            //   ],
            // ),
          ],
        ),

        build: (context) => [


          pw.Table.fromTextArray(
            headers: [
              "S.No",
              "Device ID",
              "Date",
              "Time",
              "Protein",
              "Urine Certinine",
              "Serum Certinine",
              "eGFR",
              "P/C Ratio"
            ],
            headerStyle:
            pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration:
            const pw.BoxDecoration(
                color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
            headerAlignment: pw.Alignment.center,
            data: List.generate(
                filteredData.length, (index) {
              final item = filteredData[index];
              final parts =
              item["timestamp"].split("_");

              return [
                "${index + 1}",
                item["deviceId"],
                parts[0],
                parts.length > 1 ? parts[1] : "-",

                // _formatPdfValue(item["p"], "mg/dL"),
                // _formatPdfValue(item["u"], "mg/dL"),
                // _formatPdfValue(item["s"], "mg/dL"),
                // _formatPdfValue(item["e"], "mL/min/1.73m²"),
                // _formatPdfValue(item["r"], ""),

                _formatPdfValue(item["p"], resultUnits["p"]!),
                _formatPdfValue(item["u"], resultUnits["u"]!),
                _formatPdfValue(item["s"], resultUnits["s"]!),
                _formatPdfValue(item["e"], resultUnits["e"]!),
                _formatPdfValue(item["r"], resultUnits["r"]!),
              ];
            }),
          ),
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file =
    File("${dir.path}/History_${widget.user.name}.pdf");

    await file.writeAsBytes(bytes);

    _showShareDialog(file);
  }


  void _showShareDialog(File file) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Choose Action"),
        content:
        const Text("Would you like to View or Share the Test History PDF?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Printing.layoutPdf(
                onLayout: (_) => file.readAsBytes(),
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
  Widget _valueItem(String label, dynamic value, String key) {
    String displayValue = value?.toString() ?? "--";
    displayValue=displayValue.trim();
    // 🔥 Clean values
    if (displayValue == "-1" || displayValue == "-1.00" ) {
      displayValue = "NA";
    }

    if (displayValue.toLowerCase() == "absent") {
      displayValue = "Absent";
    }

    String unit = resultUnits[key] ?? "";

    // 🔥 NA / Absent → no unit
    if (displayValue == "NA" || displayValue == "Absent" || displayValue == "inf") {
      unit = "";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unit.isNotEmpty ? "$displayValue $unit" : displayValue,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  // Widget _valueItem(String label, dynamic value) {
  //   String displayValue = value?.toString() ?? "--";
  //
  //   // 🔥 Clean value
  //   if (displayValue == "-1" || displayValue == "-1.00") {
  //     displayValue = "NA";
  //   }
  //
  //   if (displayValue.toLowerCase() == "absent") {
  //     displayValue = "Absent";
  //   }
  //
  //   return Column(
  //     children: [
  //       Text(
  //         label,
  //         style: const TextStyle(
  //           fontSize: 12,
  //           color: Colors.grey,
  //         ),
  //       ),
  //       const SizedBox(height: 4),
  //       Text(
  //         displayValue,
  //         style: const TextStyle(
  //           fontSize: 14,
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _dateTimeItem(String date, String time) {
    return Column(
      children: [
        const Text(
          "Date & Time",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          time,
          style: const TextStyle(
            fontSize: 13,
          ),
        ),
      ],
    );
  }
  Widget _verticalDivider() {
    return Container(
      height: 40,
      width: 3,
      color: Colors.grey.shade400,
      margin: const EdgeInsets.symmetric(horizontal: 3),

    );

  }

  // String _formatPdfValue(dynamic value, String unit) {
  //   String v = value?.toString().trim() ?? "N/A";
  //
  //   if (v == "-1" || v == "-1.00") return "NA";
  //   if (v.toLowerCase() == "absent") return "Absent";
  //   return unit.isNotEmpty ? "$v $unit" : v;
  // }

  String _formatPdfValue(dynamic value, String unit) {
    String v = value?.toString().trim() ?? "NA";

    // normalize
    if (v.isEmpty) return "NA";

    String lower = v.toLowerCase();

    // invalid values
    if (v == "-1" || v == "-1.00") return "NA";
    if (lower == "na") return "NA";
    if (lower == "inf") return "inf";

    // special case
    if (lower == "absent") return "Absent";

    // ✅ ONLY valid values get unit
    return unit.isNotEmpty ? "$v $unit" : v;
  }

  pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _normalCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }

  pw.Widget _singleLineCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        maxLines: 1,
        textAlign: pw.TextAlign.center,
        overflow: pw.TextOverflow.clip,
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }

  pw.Widget _resultCell(dynamic value, String unit) {
    String val = value?.toString() ?? "N/A";

    val = val.trim(); // 🔥 IMPORTANT FIX

    if (val.toLowerCase() == "inf") {
      val = "inf";
      unit = "";
    }

    if (val.toUpperCase() == "NA") {
      val = "NA";
      unit = "";
    }

    if (val.toLowerCase() == "absent") {
      unit = "";
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            val,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (unit.isNotEmpty) // 🔥 only show if unit exists
            pw.SizedBox(height: 2),

          if (unit.isNotEmpty)
            pw.Text(
              unit,
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey700,
              ),
            ),
        ],
      ),
    );
  }

}