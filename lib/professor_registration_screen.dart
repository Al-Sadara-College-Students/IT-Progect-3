import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'professor_dashboard.dart';

class ProfessorRegistrationScreen extends StatefulWidget {
  const ProfessorRegistrationScreen({super.key});

  @override
  State<ProfessorRegistrationScreen> createState() => _ProfessorRegistrationScreenState();
}

class _ProfessorRegistrationScreenState extends State<ProfessorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _academicIdController = TextEditingController();

  bool _isLoading = false;
  String? _currentDeviceUuid;

  @override
  void initState() {
    super.initState();
    _loadOrCreateDeviceUuid();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _academicIdController.dispose();
    super.dispose();
  }

  /// جلب أو توليد معرف UUID مميز للهاتف لحفظه وربطه بحساب الأستاذ
  Future<String> _loadOrCreateDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuidStr = prefs.getString('professor_device_uuid');

    if (uuidStr == null || uuidStr.isEmpty) {
      // توليد UUID مميز جديد فريد لهذا الجهاز
      uuidStr = 'UUID-${const Uuid().v4()}';
      await prefs.setString('professor_device_uuid', uuidStr);
    }

    if (mounted) {
      setState(() {
        _currentDeviceUuid = uuidStr;
      });
    }
    return uuidStr;
  }

  /// التحقق من الأستاذ، فحص الـ UUID المميز، والربط بقاعدة البيانات
  Future<void> _submitProfessorLoginOrRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final academicId = _academicIdController.text.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      String deviceUuid = _currentDeviceUuid ?? await _loadOrCreateDeviceUuid();

final url = Uri.parse('http://127.0.0.1:8000/api/professor/login-register/');final requestPayload = {
        'full_name': name,
        'academic_id': academicId,
        'device_uuid': deviceUuid,
      };

      debugPrint('Sending Student Registration to Django: ${jsonEncode(requestPayload)}');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestPayload),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final profData = responseData['professor'] as Map<String, dynamic>? ?? {};

        final verifiedName = (profData['full_name'] as String?) ?? name;
        final verifiedId = (profData['academic_id'] as String?) ?? academicId;
        final department = (profData['department'] as String?) ?? 'علوم الحاسب وهندسة البرمجيات';
        final savedUuid = (profData['device_uuid'] as String?) ?? deviceUuid;

        // حفظ حالة الجلسة محلياً في ذاكرة الجهاز
        await prefs.setBool('isProfLoggedIn', true);
        await prefs.setString('profName', verifiedName);
        await prefs.setString('profAcademicId', verifiedId);
        await prefs.setString('profDepartment', department);
        await prefs.setString('professor_device_uuid', savedUuid);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'تم التحقق وتأكيد حساب الأستاذ بنجاح!'),
            backgroundColor: AppColors.primaryGold,
            duration: const Duration(seconds: 2),
          ),
        );

        // الانتقال المباشر للوحة الأستاذ ببياناته المعتمدة
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfessorHomeDashboard(
              professorName: verifiedName,
              academicId: verifiedId,
              department: department,
            ),
          ),
        );
      } else if (response.statusCode == 403) {
        // رفض الدخول لوجود عدم تطابق في UUID الجهاز (حساب مربوط بجهاز آخر)
        final errorData = jsonDecode(response.body);
        _showSecurityAlertDialog(
          errorData['error'] ?? 'هذا الحساب الأكاديمي مربوط بجهاز هاتف آخر مسبقاً لمنع التلاعب.',
        );
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorDialog(errorData['error'] ?? 'حدث خطأ أثناء معالجة الطلب.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      _showErrorDialog(
        'تعذر الاتصال بقاعدة بيانات Django/PostgreSQL. تأكد من تشغيل السيرفر.',
      );
    }
  }

  void _showSecurityAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A004E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.security_update_warning_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'حماية انتحال الشخصية',
              style: TextStyle(color: AppColors.accentGold, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: AppColors.primaryPurple,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('فهمت', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('تنبيه التحقق', style: TextStyle(color: AppColors.textGold, fontSize: 16)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: AppColors.accentGold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text(
          'تسجيل بيانات الأستاذ',
          style: TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.secondaryPurple,
        iconTheme: const IconThemeData(color: AppColors.accentGold),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // خلفية التدرج
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.secondaryPurple,
                  AppColors.primaryPurple,
                  AppColors.darkBackground,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // أيقونة الرأس
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryPurple,
                            border: Border.all(color: AppColors.primaryGold, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66D4AF37),
                                blurRadius: 15,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            size: 60,
                            color: AppColors.accentGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'تسجيل ودخول عضو هيئة التدريس',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),

                      const Text(
                        'يتم إنشاء وفحص معرّف UUID مميز وربطه بالجهاز في قاعدة البيانات لمنع انتحال الشخصية',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 25),

                      // بطاقة عرض الـ UUID المميز للجهاز
                      if (_currentDeviceUuid != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.fingerprint_rounded, color: AppColors.accentGold, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'المعرف الفريد للجهاز (Device UUID):',
                                      style: TextStyle(color: AppColors.textGold, fontSize: 10.5, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _currentDeviceUuid!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // 1. حقل اسم الأستاذ
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(
                          'الاسم الثلاثي أو الرباعي للأستاذ',
                          Icons.person_outline_rounded,
                          'مثال: د. محمد أحمد الكندي',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال اسم الأستاذ';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // 2. حقل الرقم الأكاديمي للأستاذ
                      TextFormField(
                        controller: _academicIdController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(
                          'الرقم الأكاديمي للأستاذ',
                          Icons.badge_outlined,
                          'مثال: 202603 أو PRF-101',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال الرقم الأكاديمي';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // زر التأكيد والدخول
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submitProfessorLoginOrRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          foregroundColor: AppColors.primaryPurple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: AppColors.primaryPurple, strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_user_rounded, size: 22),
                        label: Text(
                          _isLoading ? 'جاري التحقق والربط...' : 'تأكيد الحساب والدخول (UUID Binding)',
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // شارة الأمان
                      const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, color: AppColors.textGold, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'توثيق الأستاذ محمي بتقنية ربط الهواتف اللامركزية',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textGold, fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
      prefixIcon: Icon(icon, color: AppColors.accentGold),
      filled: true,
      fillColor: AppColors.primaryPurple.withValues(alpha: 0.6),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentGold, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
