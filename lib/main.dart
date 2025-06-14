import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gsheets/gsheets.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'รายรับ เริ่มปี 2025',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  String? _selectedPayment;
  List<String> _categories = [];
  List<String> _payments = [];
  // Controllers for form fields
  final TextEditingController _sheetController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();
  final TextEditingController _customPaymentController = TextEditingController();

  // Google Apps Script Web App URL
  final String scriptUrl = 'https://script.google.com/macros/s/AKfycbyD38hlwKhwMh7nbd7Ty9w3J6lZEfQ33xyQwaClKOmRkjFUY3mXQzhCeFBBDP0WRp1r/exec';

  // Google Sheets API setup
  static const _spreadsheetId = '1zUpKFFtgpmP-8Xq8anweb6BK2DOT8Sy-8VSfzlJ27eU';
  static const _worksheetTitle = 'AppStorage'; // เปลี่ยนชื่อชีตตามที่ต้องการ
  static const _credentialsPath = 'assets/natural-ethos-462402-q7-ac45077029d5.json';

  // ตัวแปรสำหรับเก็บชื่อชีตล่าสุดจาก AppStorage
  String? _lastSheetName;

  // ฟังก์ชันดึงค่าชื่อชีตล่าสุดจาก Google Sheet (AppStorage!A2)
  Future<void> fetchLastSheetName() async {
    try {
      final response = await http.get(Uri.parse('$scriptUrl?action=getLastSheet'));
      print('DEBUG: response.body = ${response.body}');
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        print('DEBUG: parsed = $parsed');
        final lastSheet = parsed['lastSheet'] ?? '';
        print('DEBUG: lastSheet = ' + lastSheet);
        setState(() {
          _lastSheetName = lastSheet;
          _sheetController.text = lastSheet;
        });
      } else {
        setState(() {
          _lastSheetName = null;
        });
      }
    } catch (e) {
      print('DEBUG: fetchLastSheetName error: $e');
      setState(() {
        _lastSheetName = null;
      });
    }
  }

  // ฟังก์ชันดึงหมวดหมู่และชนิดการจ่ายเงินจาก backend ใหม่ (ใช้ /sheet/meta)
  Future<void> fetchCategoriesAndPayments() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/sheet/meta'));
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final List<String> categories = List<String>.from(parsed['categories'] ?? []);
        final List<String> payments = List<String>.from(parsed['paymenttypes'] ?? []);
        // เพิ่ม 'อื่น ๆ' และ 'กำหนดเอง' ต่อท้าย
        if (!categories.contains('อื่น ๆ')) categories.add('อื่น ๆ');
        if (!categories.contains('กำหนดเอง')) categories.add('กำหนดเอง');
        if (!payments.contains('อื่น ๆ')) payments.add('อื่น ๆ');
        if (!payments.contains('กำหนดเอง')) payments.add('กำหนดเอง');
        setState(() {
          _categories = categories;
          _payments = payments;
        });
      }
    } catch (e) {
      // ignore error
    }
  }

  Future<void> _addMetaToBackend(String type, String value) async {
    final url = Uri.parse('http://localhost:3000/sheet/add-meta');
    await http.post(url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'type': type, 'value': value}),
    );
  }

  Future<void> _submitToGoogleSheet() async {
    if (!_formKey.currentState!.validate()) return;
    // ถ้าเลือกกำหนดเอง ส่งค่าใหม่ไป backend ก่อน
    if (_selectedCategory == 'กำหนดเอง' && _customCategoryController.text.trim().isNotEmpty) {
      await _addMetaToBackend('category', _customCategoryController.text.trim());
    }
    if (_selectedPayment == 'กำหนดเอง' && _customPaymentController.text.trim().isNotEmpty) {
      await _addMetaToBackend('paymenttype', _customPaymentController.text.trim());
    }
    final url = Uri.parse('http://localhost:3000/sheet/append');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sheet': _selectedSheetName ?? _sheetController.text,
        'date': _dateController.text,
        'item': _itemController.text,
        'category': _selectedCategory == 'กำหนดเอง' ? _customCategoryController.text.trim() : _selectedCategory ?? '',
        'payment': _selectedPayment == 'กำหนดเอง' ? _customPaymentController.text.trim() : _selectedPayment ?? '',
        'amount': _amountController.text,
        'note': _noteController.text,
      }),
    );
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งข้อมูลสำเร็จ!')),
      );
      _formKey.currentState!.reset();
      _sheetController.clear();
      _dateController.clear();
      _itemController.clear();
      _amountController.clear();
      _noteController.clear();
      _customCategoryController.clear();
      _customPaymentController.clear();
      setState(() {
        _selectedCategory = null;
        _selectedPayment = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: \\${response.body}')),
      );
    }
  }

  Future<GSheets> getGSheets() async {
    final credentials = await File(_credentialsPath).readAsString();
    return GSheets(credentials);
  }

  Future<String?> readA2FromAppStorage() async {
    final gsheets = await getGSheets();
    final ss = await gsheets.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_worksheetTitle);
    if (sheet == null) return null;
    final value = await sheet.values.value(column: 1, row: 2); // A2
    return value;
  }

  // ตัวอย่างการใช้งาน (เช่น เรียกใน initState หรือปุ่ม)
  void fetchSheetNameFromGoogleSheet() async {
    final value = await readA2FromAppStorage();
    print('Value in AppStorage!A2: ${value ?? 'null'}');
    if (value != null && value.isNotEmpty) {
      setState(() {
        _sheetController.text = value;
      });
    }
  }

  // ฟังก์ชันดึงค่าชื่อชีตล่าสุดจาก backend API (แทนที่ Google Apps Script หรือ gsheets ตรง)
  Future<void> fetchLastSheetNameFromBackend() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/sheet/a2'));
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final lastSheet = parsed['value'] ?? '';
        setState(() {
          _lastSheetName = lastSheet;
          _sheetController.text = lastSheet;
        });
      } else {
        setState(() {
          _lastSheetName = null;
        });
      }
    } catch (e) {
      setState(() {
        _lastSheetName = null;
      });
    }
  }

  List<String> _sheetNames = [];
  String? _selectedSheetName;

  // ฟังก์ชันดึงรายชื่อชีตทั้งหมด (ยกเว้น AppStorage) จาก backend
  Future<void> fetchSheetNamesFromBackend() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/sheet/names'));
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final List<String> sheetNames = List<String>.from(parsed['sheets'] ?? []);
        setState(() {
          _sheetNames = sheetNames;
          if (_sheetNames.isNotEmpty) {
            _selectedSheetName = _sheetNames.first;
            _sheetController.text = _selectedSheetName!;
          }
        });
      }
    } catch (e) {
      // ignore error
    }
  }

  @override
  void initState() {
    super.initState();
    // ตั้งค่า default วันที่เป็นวันนี้
    final now = DateTime.now();
    final formatted = '${now.day} ${_monthNameTH(now.month)} ${now.year + 543}';
    _dateController.text = formatted;
    fetchSheetNamesFromBackend(); // ดึงรายชื่อชีตทั้งหมด
    fetchCategoriesAndPayments(); // ดึงหมวดหมู่และชนิดการจ่ายเงินจาก backend เท่านั้น
    // เติมค่าในช่องชื่อชีตเป้าหมายอัตโนมัติหลังจากดึงข้อมูลสำเร็จ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lastSheetName != null && _lastSheetName!.isNotEmpty) {
        _sheetController.text = _lastSheetName!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'รายรับ เริ่มปี 2025',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.teal[700], fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'กรอกข้อมูลรายรับของคุณเพื่อบันทึกลง Google Sheet',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: _selectedSheetName,
                        items: _sheetNames.isEmpty
                            ? []
                            : _sheetNames.map((name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              )).toList(),
                        onChanged: _sheetNames.isEmpty
                            ? null
                            : (val) {
                                setState(() {
                                  _selectedSheetName = val;
                                  _sheetController.text = val ?? '';
                                });
                              },
                        decoration: const InputDecoration(
                          labelText: 'ชื่อชีตเป้าหมาย',
                          prefixIcon: Icon(Icons.list_alt),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'กรุณาเลือกชีต' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'วันที่',
                          hintText: '12 มิถุนายน 2025',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            final formatted = '${picked.day} ${_monthNameTH(picked.month)} ${picked.year + 543}';
                            setState(() {
                              _dateController.text = formatted;
                            });
                          }
                        },
                        validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกวันที่' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _itemController,
                        decoration: const InputDecoration(
                          labelText: 'รายการ',
                          hintText: 'เช่น ค่าอาหารกลางวัน, เงินเดือน',
                          prefixIcon: Icon(Icons.description),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกรายการ' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'หมวดหมู่',
                          prefixIcon: Icon(Icons.label),
                        ),
                        value: _selectedCategory,
                        items: _categories
                            .map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val),
                        hint: const Text('เลือกหมวดหมู่'),
                        validator: (v) => v == null || v.isEmpty ? 'กรุณาเลือกหมวดหมู่' : null,
                      ),
                      if (_selectedCategory == 'กำหนดเอง')
                        TextFormField(
                          controller: _customCategoryController,
                          decoration: const InputDecoration(
                            labelText: 'ระบุหมวดหมู่เอง',
                            prefixIcon: Icon(Icons.edit),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'กรุณาระบุหมวดหมู่เอง' : null,
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'ชนิดการจ่ายเงิน',
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                        value: _selectedPayment,
                        items: _payments
                            .map((pay) => DropdownMenuItem(
                                  value: pay,
                                  child: Text(pay),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedPayment = val),
                        hint: const Text('เลือกชนิดการจ่ายเงิน'),
                        validator: (v) => v == null || v.isEmpty ? 'กรุณาเลือกชนิดการจ่ายเงิน' : null,
                      ),
                      if (_selectedPayment == 'กำหนดเอง')
                        TextFormField(
                          controller: _customPaymentController,
                          decoration: const InputDecoration(
                            labelText: 'ระบุชนิดการจ่ายเงินเอง',
                            prefixIcon: Icon(Icons.edit),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'กรุณาระบุชนิดการจ่ายเงินเอง' : null,
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'จำนวนเงิน',
                          hintText: 'เช่น 150, 25000, 99.99',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]*')),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'กรุณากรอกจำนวนเงิน';
                          if (!RegExp(r'^[0-9]+(\.[0-9]+)?').hasMatch(v)) return 'กรุณากรอกเฉพาะตัวเลขหรือทศนิยม';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: 'หมายเหตุ (ถ้ามี)',
                          hintText: 'รายละเอียดเพิ่มเติม (ถ้ามี)',
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _submitToGoogleSheet,
                        icon: const Icon(Icons.send),
                        label: const Text('ส่งข้อมูลเข้า Google Sheet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// เพิ่มฟังก์ชันแปลงเดือนเป็นภาษาไทย
String _monthNameTH(int month) {
  const months = [
    '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
  ];
  return months[month];
}
