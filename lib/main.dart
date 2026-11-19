import 'dart:convert';
import 'package:flutter/material.dart';
import 'student_manual_input_screen.dart';
import 'professor_registration_screen.dart';

/// هويّة الألوان والتنسيق البصري (AppColors)
class AppColors {
  // الألوان الرئيسية
  static const Color primaryPurple = Color(0xFF2A004E); // بنفسجي ملكي عميق
  static const Color secondaryPurple = Color(0xFF3B1E54); // بنفسجي متوسط للبطاقات
  static const Color darkBackground = Color(0xFF1A0033);

  // الألوان الذهبية المزخرفة
  static const Color primaryGold = Color(0xFFD4AF37); // ذهبي كلاسيكي
  static const Color accentGold = Color(0xFFFFD700); // ذهبي مشرق للأزرار والتوهج
  static const Color textGold = Color(0xFFE6CA65);

  // النصوص والخلفيات الشفافة
  static const Color textWhite = Color(0xFFF5F5F5);
  static const Color cardSurface = Color(0x333B1E54); // بنفسجي مائل للشفافية
}

void main() {
  runApp(const AcademicSystemApp());
}

class AcademicSystemApp extends StatelessWidget {
  const AcademicSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام ادارة الجداول الاكاديمي الذكي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        primaryColor: AppColors.primaryPurple,
        fontFamily: 'Roboto',
      ),
      home: const OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);

  @override
  void dispose() {
    _isLoading.dispose();
    super.dispose();
  }

  // --- ربط الباك إند والسريان البرمجي (Backend Data Flow) ---

  /// مسار الطالب: تصوير البطاقة واستخراج الـ OCR ومعرف الجهاز (Device MAC)
  Future<void> _handleStudentOcrOnboarding() async {
    _isLoading.value = true;

    const String simulatedStudentId = "20261055";
    const String simulatedDeviceMac = "A1:B2:C3:D4:E5:F6";

    final requestBody = {
      "action": "student_onboarding",
      "student_id": simulatedStudentId,
      "device_mac": simulatedDeviceMac,
    };

    debugPrint("Sending JSON to FastAPI: ${jsonEncode(requestBody)}");

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    _isLoading.value = false;
    _showSnackBar(
      "تم مسح البطاقة بنجاح! تم التقاط الرقم ($simulatedStudentId) والربط بالجهاز ($simulatedDeviceMac).",
      isError: false,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red[900] : AppColors.secondaryPurple,
        content: Text(
          message,
          style: TextStyle(color: isError ? Colors.white : AppColors.textGold),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: isError ? Colors.red : AppColors.primaryGold),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. خلفية التدرج الانسيابي (Linear Gradient)
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

          // 2. زخارف هندسية خفيفة في الزوايا (Watermark Patterns)
          const Positioned(
            top: -40,
            right: -40,
            child: Opacity(
              opacity: 0.15,
              child: _DecorativeCircle(size: 200, color: AppColors.primaryGold, width: 3),
            ),
          ),
          const Positioned(
            bottom: -50,
            left: -50,
            child: Opacity(
              opacity: 0.12,
              child: _DecorativeCircle(size: 240, color: AppColors.accentGold, width: 2),
            ),
          ),

          // 3. محتوى الشاشة
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HeaderSection(),
                    const SizedBox(height: 25),
                    StudentAccessCard(
                      onOcrTap: _handleStudentOcrOnboarding,
                      onManualTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StudentManualInputScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    ProfessorAccessCard(
                      onRegisterTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfessorRegistrationScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    const FooterSection(),
                  ],
                ),
              ),
            ),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, isLoading, child) {
              if (!isLoading) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentGold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ================= مكونات الواجهة المُحسّنة (Widgets Components) =================

/// عنصر إضافي خاص بالزخارف لتقليل تكرار الأكواد (Performance Optimization)
class _DecorativeCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double width;

  const _DecorativeCircle({
    required this.size,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: width),
      ),
    );
  }
}

/// الجزء العلوي (Header) - تم إضافة const لتحسين الأداء
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accentGold, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66D4AF37),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: const CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.primaryPurple,
            child: Icon(
              Icons.school_rounded,
              color: AppColors.accentGold,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "نظام ادارة الجداول الاكاديمي الذكي",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textGold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "مرحباً بك، يرجى اختيار نوع الحساب للمتابعة",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 13,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

/// بطاقة "حساب طالب" (Student Access Card)
class StudentAccessCard extends StatelessWidget {
  final VoidCallback onOcrTap;
  final VoidCallback onManualTap;

  const StudentAccessCard({
    super.key,
    required this.onOcrTap,
    required this.onManualTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primaryGold.withOpacity(0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, color: AppColors.accentGold, size: 26),
              SizedBox(width: 10),
              Text(
                "حساب طالب (Student Access)",
                style: TextStyle(
                  color: AppColors.textGold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(
              color: AppColors.primaryGold, thickness: 0.5, height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: AppColors.primaryPurple,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 4,
            ),
            onPressed: onOcrTap,
            icon: const Icon(Icons.camera_alt_rounded, size: 20),
            label: const Text(
              "تسجيل آلي عبر تصوير البطاقة الجامعية",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textGold,
              side: const BorderSide(color: AppColors.primaryGold, width: 1),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onManualTap,
            icon: const Icon(Icons.edit_note_rounded,
                size: 20, color: AppColors.accentGold),
            label: const Text(
              "إدخال البيانات يدوياً",
              style: TextStyle(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة "حساب أستاذ" (Professor Access Card)
class ProfessorAccessCard extends StatelessWidget {
  final VoidCallback onRegisterTap;

  const ProfessorAccessCard({
    super.key,
    required this.onRegisterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.school_outlined,
                  color: AppColors.accentGold, size: 26),
              SizedBox(width: 10),
              Text(
                "حساب أستاذ (Professor Access)",
                style: TextStyle(
                  color: AppColors.textGold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(
              color: AppColors.primaryGold, thickness: 0.5, height: 20),
          const Text(
            "تسجيل ودخول الأستاذ ومطابقة معرف الجهاز الآمن (Device UUID Binding):",
            style: TextStyle(color: AppColors.textWhite, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: AppColors.primaryPurple,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 4,
            ),
            onPressed: onRegisterTap,
            icon: const Icon(Icons.how_to_reg_rounded, size: 20),
            label: const Text(
              "تسجيل / دخول الأستاذ",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// الجزء السفلي (Footer)
class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.security_rounded, color: AppColors.textGold, size: 14),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            "جميع البيانات محمية ومربوطة بمعرف الجهاز لتأمين الحسابات (Device Binding)",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textGold,
              fontSize: 11,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }
}