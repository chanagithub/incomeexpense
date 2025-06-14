import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class IncomeFormPage extends StatefulWidget {
  const IncomeFormPage({super.key});

  @override
  State<IncomeFormPage> createState() => _IncomeFormPageState();
}

class _IncomeFormPageState extends State<IncomeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _sheetController = TextEditingController();
  List<String> _sheetNames = [];
  String? _selectedSheetName;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final formatted = '${now.day} ${_monthNameTH(now.month)} ${now.year + 543}';
    _dateController.text = formatted;
    fetchSheetNamesFromBackend();
  }

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

  Future<void> _submitIncome() async {
    if (!_formKey.currentState!.validate()) return;
    final url = Uri.parse('http://localhost:3000/sheet/append-income');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sheet': _selectedSheetName ?? _sheetController.text,
        'date': _dateController.text,
        'item': _itemController.text,
        'category': _categoryController.text,
        'amount': _amountController.text,
        'note': _noteController.text,
      }),
    );
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกรายรับสำเร็จ!')),
      );
      _formKey.currentState!.reset();
      _sheetController.clear();
      final now = DateTime.now();
      final formatted = '${now.day} ${_monthNameTH(now.month)} ${now.year + 543}';
      _dateController.text = formatted;
      _itemController.clear();
      _categoryController.clear();
      _amountController.clear();
      _noteController.clear();
      setState(() {
        _selectedSheetName = _sheetNames.isNotEmpty ? _sheetNames.first : null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ฟอร์มรายรับ')),
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
                        'บันทึกรายรับ',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.teal[700], fontWeight: FontWeight.bold),
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
                          prefixIcon: Icon(Icons.description),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกรายการ' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'หมวดหมู่',
                          prefixIcon: Icon(Icons.label),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกหมวดหมู่' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'จำนวนเงิน',
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
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _submitIncome,
                        icon: const Icon(Icons.send),
                        label: const Text('บันทึกรายรับ'),
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

String _monthNameTH(int month) {
  const months = [
    '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
  ];
  return months[month];
}
