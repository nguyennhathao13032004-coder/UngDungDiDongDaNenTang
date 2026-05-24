import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BmiScreen extends StatefulWidget {
  const BmiScreen({super.key});

  @override
  State<BmiScreen> createState() => _BmiScreenState();
}

class _BmiScreenState extends State<BmiScreen> {
  final supabase = Supabase.instance.client;

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  double? _bmi;
  String _bmiCategory = '';
  Color _bmiColor = Colors.grey;
  IconData _bmiIcon = Icons.help_outline;

  bool _isSaving = false;
  List<dynamic> _bmiHistory = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadBmiHistory();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _calculateBMI() {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);

    if (height == null || weight == null || height <= 0 || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập chiều cao và cân nặng hợp lệ!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final heightInM = height / 100;
    final bmi = weight / (heightInM * heightInM);

    setState(() {
      _bmi = bmi;
      if (bmi < 18.5) {
        _bmiCategory = 'Thiếu cân';
        _bmiColor = Colors.blue;
        _bmiIcon = Icons.arrow_downward;
      } else if (bmi < 25.0) {
        _bmiCategory = 'Bình thường';
        _bmiColor = Colors.green;
        _bmiIcon = Icons.check_circle;
      } else if (bmi < 30.0) {
        _bmiCategory = 'Thừa cân';
        _bmiColor = Colors.orange;
        _bmiIcon = Icons.arrow_upward;
      } else {
        _bmiCategory = 'Béo phì';
        _bmiColor = Colors.red;
        _bmiIcon = Icons.warning;
      }
    });
  }

  Future<void> _saveBMI() async {
    if (_bmi == null) return;
    setState(() => _isSaving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('bmi_records').insert({
        'user_id': userId,
        'height_cm': double.parse(_heightController.text),
        'weight_kg': double.parse(_weightController.text),
        'bmi': double.parse(_bmi!.toStringAsFixed(2)),
        'category': _bmiCategory,
        'recorded_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu chỉ số BMI!'), backgroundColor: Colors.green),
        );
        _loadBmiHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu BMI: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadBmiHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('bmi_records')
          .select()
          .eq('user_id', userId)
          .order('recorded_at', ascending: false)
          .limit(5);
      setState(() => _bmiHistory = data);
    } catch (e) {
      print('Lỗi tải lịch sử BMI: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Thiếu cân': return Colors.blue;
      case 'Bình thường': return Colors.green;
      case 'Thừa cân': return Colors.orange;
      case 'Béo phì': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Chỉ số BMI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CARD NHẬP LIỆU
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nhập thông số của bạn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Chiều cao (cm)',
                        hintText: 'VD: 170',
                        prefixIcon: const Icon(Icons.height, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.teal, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cân nặng (kg)',
                        hintText: 'VD: 65',
                        prefixIcon: const Icon(Icons.monitor_weight, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.teal, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _calculateBMI,
                        icon: const Icon(Icons.calculate),
                        label: const Text('Tính BMI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // KẾT QUẢ BMI
              if (_bmi != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _bmiColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _bmiColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_bmiIcon, color: _bmiColor, size: 32),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_bmi!.toStringAsFixed(1), style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: _bmiColor)),
                              Text(_bmiCategory, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _bmiColor)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBmiScaleBar(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveBMI,
                          icon: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Đang lưu...' : 'Lưu kết quả', style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bmiColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // BẢNG PHÂN LOẠI
              const SizedBox(height: 20),
              const Text('Bảng phân loại BMI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildBmiTable(),

              // LỊCH SỬ
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lịch sử đo gần đây', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.teal), onPressed: _loadBmiHistory),
                ],
              ),
              const SizedBox(height: 8),
              _isLoadingHistory
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.teal)))
                  : _bmiHistory.isEmpty
                      ? _buildEmptyHistory()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _bmiHistory.length,
                          itemBuilder: (context, index) {
                            final record = _bmiHistory[index];
                            final date = DateTime.parse(record['recorded_at']).toLocal();
                            final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                            final category = record['category'] ?? '';
                            final color = _getCategoryColor(category);
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: color.withOpacity(0.15),
                                  child: Text(record['bmi'].toStringAsFixed(1), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                title: Text(category, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                                subtitle: Text('${record['height_cm']}cm · ${record['weight_kg']}kg', style: TextStyle(color: Colors.grey.shade600)),
                                trailing: Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                              ),
                            );
                          },
                        ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBmiScaleBar() {
    final bmiValue = _bmi!.clamp(10.0, 40.0);
    final progress = (bmiValue - 10.0) / 30.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(height: 12, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.blue, Colors.green, Colors.orange, Colors.red]))),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment(progress * 2 - 1, 0),
          child: Icon(Icons.arrow_drop_up, color: _bmiColor, size: 28),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['10', '18.5', '25', '30', '40']
              .map((e) => Text(e, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildBmiTable() {
    final rows = [
      {'range': 'Dưới 18.5', 'label': 'Thiếu cân', 'color': Colors.blue},
      {'range': '18.5 – 24.9', 'label': 'Bình thường', 'color': Colors.green},
      {'range': '25.0 – 29.9', 'label': 'Thừa cân', 'color': Colors.orange},
      {'range': '30.0 trở lên', 'label': 'Béo phì', 'color': Colors.red},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          final color = row['color'] as Color;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade100))),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Text(row['label'] as String, style: TextStyle(fontWeight: FontWeight.w600, color: color))),
              Text(row['range'] as String, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(child: Column(children: [
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle), child: Icon(Icons.history, size: 40, color: Colors.teal.shade300)),
      const SizedBox(height: 12),
      Text('Chưa có lịch sử đo BMI.\nHãy tính và lưu kết quả đầu tiên!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, height: 1.5)),
      const SizedBox(height: 12),
    ]));
  }
}