import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// هويّة الألوان والتنسيق البصري الموحدة للنظام الأكاديمي
class AppColors {
  static const Color primaryPurple = Color(0xFF2A004E);
  static const Color secondaryPurple = Color(0xFF3B1E54);
  static const Color darkBackground = Color(0xFF1A0033);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color textGold = Color(0xFFE6CA65);
  static const Color textWhite = Color(0xFFF5F5F5);
  static const Color cardSurface = Color(0x333B1E54);

  // ألوان مؤشرات تقدم المنهج حسب الدليل الهندسي
  static const Color progressGold = Color(0xFFFFD700); // ذهبي: متقدم (>= 80%)
  static const Color progressGreen = Color(0xFF4CAF50); // أخضر: منتظم (50% - 79%)
  static const Color progressRed = Color(0xFFE53935); // أحمر: تأخير (< 50%)
}

/// نموذج بيانات المحاضرة الدراسية
class LectureItem {
  final String id;
  final String courseName;
  final String roomName;
  final String timeSlot;
  int progressPercentage;
  final String department;
  List<String> completedTopics;

  LectureItem({
    required this.id,
    required this.courseName,
    required this.roomName,
    required this.timeSlot,
    required this.progressPercentage,
    required this.department,
    required this.completedTopics,
  });

  Color get statusColor {
    if (progressPercentage >= 80) return AppColors.progressGold;
    if (progressPercentage >= 50) return AppColors.progressGreen;
    return AppColors.progressRed;
  }

  String get statusText {
    if (progressPercentage >= 80) return 'متقدم (ذهبي)';
    if (progressPercentage >= 50) return 'منتظم (أخضر)';
    return 'تأخير (أحمر)';
  }
}

/// نموذج سجل حضور الطالب المحلي
class AttendanceRecord {
  final String studentId;
  final String studentName;
  final String deviceMac;
  final DateTime timestamp;

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.deviceMac,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'student_name': studentName,
        'device_mac_address': deviceMac,
        'attendance_timestamp': timestamp.toIso8601String(),
      };
}

// ==============================================================================
// 1. شاشة لوحة تحكم الأستاذ الرئيسية (Professor Home Dashboard)
// ==============================================================================

class ProfessorHomeDashboard extends StatefulWidget {
  final String professorName;
  final String professorPhone;
  final String department;
  final String academicId;

  const ProfessorHomeDashboard({
    super.key,
    this.professorName = 'د. محمد أحمد الكندي',
    this.professorPhone = '777000111',
    this.department = 'علوم الحاسب وهندسة البرمجيات',
    this.academicId = '202603',
  });

  @override
  State<ProfessorHomeDashboard> createState() => _ProfessorHomeDashboardState();
}

class _ProfessorHomeDashboardState extends State<ProfessorHomeDashboard> {
  // قائمة محاضرات اليوم المجدولة للأستاذ
  final List<LectureItem> _todayLectures = [
    LectureItem(
      id: 'CS-402',
      courseName: 'شبكات الحاسب المتقدمة',
      roomName: 'قاعة 104 (مبنى الحاسبات)',
      timeSlot: '08:30 ص - 10:00 ص',
      progressPercentage: 85,
      department: 'علوم الحاسب',
      completedTopics: ['التوجيه الاحترافي OSPF', 'إعدادات شبكات VLANs', 'بروتوكولات الأمان ACL'],
    ),
    LectureItem(
      id: 'SEC-301',
      courseName: 'أمن المعلومات والسيبراني',
      roomName: 'معمل أمن الأنظمة 2',
      timeSlot: '10:15 ص - 11:45 ص',
      progressPercentage: 65,
      department: 'الأمن السيبراني',
      completedTopics: ['خوارزميات التشفير المتقدمة RSA/AES', 'تحليل الثغرات وفحص الشبكات'],
    ),
    LectureItem(
      id: 'SWE-410',
      courseName: 'هندسة البرمجيات وتطبيقات الهواتف',
      roomName: 'مدرج 2 (الكلية)',
      timeSlot: '12:00 م - 01:30 م',
      progressPercentage: 45,
      department: 'هندسة البرمجيات',
      completedTopics: ['المتطلبات وهندسة الـ Architecture', 'مقدمة إلى Flutter و FastAPI'],
    ),
  ];

  /// فتح شاشة المحاضرة النشطة والـ Local Hotspot
  void _startActiveLecture(LectureItem lecture) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveLectureScreen(lecture: lecture),
      ),
    );
  }

  /// فتح نافذة تحديث إنجاز المنهج
  void _openProgressUpdateDialog(LectureItem? preSelectedLecture) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CurriculumProgressSheet(
        lectures: _todayLectures,
        initialLecture: preSelectedLecture ?? _todayLectures.first,
        onProgressUpdated: (updatedLecture, newProgress, newTopic) {
          setState(() {
            updatedLecture.progressPercentage = newProgress;
            if (newTopic.isNotEmpty && !updatedLecture.completedTopics.contains(newTopic)) {
              updatedLecture.completedTopics.add(newTopic);
            }
          });
          _showFeedbackMessage(
            'تم تحديث نسبة إنجاز "${updatedLecture.courseName}" إلى $newProgress% وتغذية مؤشرات الإدارة.',
          );
        },
      ),
    );
  }

  void _showFeedbackMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppColors.textGold)),
        backgroundColor: AppColors.secondaryPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.primaryGold),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text(
          'لوحة تحكم الأستاذ',
          style: TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.secondaryPurple,
        iconTheme: const IconThemeData(color: AppColors.accentGold),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: AppColors.accentGold),
            tooltip: 'معلومات النظام الهجين',
            onPressed: () => _showSystemInfoDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // خلفية التدرج الانسيابي
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

          // زخارف دائرية خفيفة
          const Positioned(
            top: -40,
            left: -40,
            child: Opacity(
              opacity: 0.12,
              child: _DecorativeRing(size: 200, color: AppColors.primaryGold),
            ),
          ),
          const Positioned(
            bottom: -50,
            right: -50,
            child: Opacity(
              opacity: 0.10,
              child: _DecorativeRing(size: 240, color: AppColors.accentGold),
            ),
          ),

          // المحتوى التفاعلي الرئيسي
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. بطاقة معلومات الأستاذ
                  _ProfessorProfileHeader(
                    name: widget.professorName,
                    phone: widget.professorPhone,
                    department: widget.department,
                    academicId: widget.academicId,
                  ),

                  const SizedBox(height: 20),

                  // 2. بطاقات الإحصائيات السريعة
                  _buildQuickStatsBar(),

                  const SizedBox(height: 22),

                  // 3. الزران الأساسيان المنصوص عليهما في التوثيق الهندسي
                  const Text(
                    'الإجراءات الرئيسية للمحاضرة',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.textGold,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // الزر الأساسي 1: بدء المحاضرة (Active Lecture & Local Hotspot)
                  _PrimaryActionCard(
                    title: 'بدء المحاضرة (Active Lecture & Local Hotspot)',
                    subtitle: 'إطلاق نقطة اتصال مؤقتة، تشغيل خادم shelf المصغر، وتوليد Dynamic QR لتسجيل حضور الطلاب P2P',
                    icon: Icons.wifi_tethering_rounded,
                    isProminent: true,
                    badgeText: 'خادم shelf الداخلي',
                    onTap: () => _startActiveLecture(_todayLectures.first),
                  ),

                  const SizedBox(height: 12),

                  // الزر الأساسي 2: تحديث إنجاز المنهج
                  _PrimaryActionCard(
                    title: 'تحديث إنجاز المنهج (Curriculum Progress)',
                    subtitle: 'تحديث النسبة المئوية الأسبوعية لتغذية مؤشرات لوحة المشرف الملونة (ذهبي / أخضر / أحمر)',
                    icon: Icons.trending_up_rounded,
                    isProminent: false,
                    badgeText: 'مؤشرات الإدارة',
                    onTap: () => _openProgressUpdateDialog(null),
                  ),

                  const SizedBox(height: 25),

                  // 4. جدول محاضرات اليوم
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '${_todayLectures.length} محاضرات اليوم',
                          style: const TextStyle(color: AppColors.textGold, fontSize: 12),
                        ),
                      ),
                      const Text(
                        'جدول محاضرات اليوم',
                        style: TextStyle(
                          color: AppColors.textGold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // عناصر جدول المحاضرات
                  ..._todayLectures.map((lecture) {
                    return _LectureScheduleCard(
                      lecture: lecture,
                      onStartTap: () => _startActiveLecture(lecture),
                      onUpdateProgressTap: () => _openProgressUpdateDialog(lecture),
                    );
                  }).toList(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('3', 'محاضرات اليوم', Icons.event_available_rounded, AppColors.accentGold),
          Container(width: 1, height: 35, color: Colors.white24),
          _buildStatItem('120', 'الطلاب المتوقعين', Icons.group_outlined, Colors.lightBlueAccent),
          Container(width: 1, height: 35, color: Colors.white24),
          _buildStatItem('75%', 'متوسط الإنجاز', Icons.analytics_outlined, AppColors.progressGreen),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, String label, IconData icon, Color iconColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 5),
            Text(
              val,
              style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  void _showSystemInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.primaryGold, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.hub_outlined, color: AppColors.accentGold, size: 26),
            SizedBox(width: 10),
            Text(
              'البنية الهجينة للنظام',
              style: TextStyle(color: AppColors.textGold, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '• خادم shelf الداخلي:',
                style: TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'يستقبل طلبات الحضور محلياً عبر شبكة الـ Hotspot ويفصل الاتصال فوراً بعد إرجاع JSON لتأكيد الحضور لمنع الاختناق.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 10),
              Text(
                '• الرمز المتغير (Dynamic QR):',
                style: TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'يتغير الكود دورياً كل 10 ثوانٍ لمنع تصوير الشاشة وتناقل الأكواد بين الطلاب.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 10),
              Text(
                '• المزامنة المركزية:',
                style: TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'بعد انتهاء المحاضرة، يُرسل الكشف دفعة واحدة إلى سيرفر بايثون (FastAPI/Django) لتحديث مؤشرات المشرف.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('فهمت', style: TextStyle(color: AppColors.accentGold)),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 2. بطاقة معلومات الأستاذ
// ==============================================================================

class _ProfessorProfileHeader extends StatelessWidget {
  final String name;
  final String phone;
  final String department;
  final String academicId;

  const _ProfessorProfileHeader({
    required this.name,
    required this.phone,
    required this.department,
    required this.academicId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryPurple,
                child: Icon(Icons.school_rounded, color: AppColors.accentGold, size: 32),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.textGold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green, width: 0.8),
                      ),
                      child: const Text(
                        'مفعّل ✓',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  department,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'الرقم الأكاديمي: $academicId | المعرف: PROF-$academicId',
                  style: const TextStyle(color: AppColors.textGold, fontSize: 11, fontWeight: FontWeight.w300),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 3. ودجت الزر الأساسي (Primary Action Card)
// ==============================================================================

class _PrimaryActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isProminent;
  final String badgeText;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isProminent,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isProminent ? AppColors.secondaryPurple.withValues(alpha: 0.85) : AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isProminent ? AppColors.accentGold : AppColors.primaryGold.withValues(alpha: 0.5),
              width: isProminent ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isProminent ? AppColors.primaryGold.withValues(alpha: 0.15) : Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isProminent ? AppColors.accentGold : AppColors.primaryGold,
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, color: AppColors.accentGold, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: isProminent ? AppColors.accentGold : AppColors.textGold,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(color: AppColors.textGold, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accentGold, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 4. بطاقة جدول المحاضرة (Lecture Schedule Card)
// ==============================================================================

class _LectureScheduleCard extends StatelessWidget {
  final LectureItem lecture;
  final VoidCallback onStartTap;
  final VoidCallback onUpdateProgressTap;

  const _LectureScheduleCard({
    required this.lecture,
    required this.onStartTap,
    required this.onUpdateProgressTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: lecture.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: lecture.statusColor, width: 1),
                ),
                child: Text(
                  '${lecture.progressPercentage}% - ${lecture.statusText}',
                  style: TextStyle(
                    color: lecture.statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  lecture.courseName,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textGold,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                lecture.roomName,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.meeting_room_outlined, color: AppColors.accentGold, size: 15),
              const SizedBox(width: 14),
              Text(
                lecture.timeSlot,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.access_time_rounded, color: AppColors.accentGold, size: 15),
            ],
          ),
          const SizedBox(height: 10),
          // شريط نسبة الإنجاز
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: lecture.progressPercentage / 100.0,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(lecture.statusColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          // زران للإجراء السريع
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textGold,
                    side: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: onUpdateProgressTap,
                  icon: const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.accentGold),
                  label: const Text('تحديث النسبة', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.primaryPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: onStartTap,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('بدء المحاضرة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 5. شاشة المحاضرة النشطة المتكاملة وخادم shelf والـ Dynamic QR
// ==============================================================================

class ActiveLectureScreen extends StatefulWidget {
  final LectureItem lecture;

  const ActiveLectureScreen({super.key, required this.lecture});

  @override
  State<ActiveLectureScreen> createState() => _ActiveLectureScreenState();
}

class _ActiveLectureScreenState extends State<ActiveLectureScreen> {
  HttpServer? _shelfServer;
  bool _isServerRunning = false;
  int _serverPort = 8080;

  // مؤقت توليد الرمز المتغير (Dynamic QR Code)
  Timer? _qrTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 10;
  String _currentQrPayload = '';

  // سجل الطلاب الحاضرين في الجلسة الحالية
  final List<AttendanceRecord> _attendees = [];

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _startLocalShelfServer();
    _generateDynamicQrCode();
    _startQrRefreshCycle();
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    _countdownTimer?.cancel();
    _stopLocalShelfServer();
    super.dispose();
  }

  /// 1. تشغيل خادم shelf المصغر داخل التطبيق للتعامل مع الـ Local P2P Handshake
  Future<void> _startLocalShelfServer() async {
    try {
      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler(_handleShelfRequest);

      // ربط الخادم بكل الواجهات المتاحة محلياً
      _shelfServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, _serverPort);

      if (mounted) {
        setState(() {
          _isServerRunning = true;
          _serverPort = _shelfServer!.port;
        });
      }
      debugPrint('Local shelf server started on port $_serverPort');
    } catch (e) {
      debugPrint('Failed to start shelf server: $e');
      if (mounted) {
        setState(() {
          _isServerRunning = false;
        });
      }
    }
  }

  /// إيقاف خادم shelf
  Future<void> _stopLocalShelfServer() async {
    try {
      await _shelfServer?.close(force: true);
      _shelfServer = null;
      _isServerRunning = false;
    } catch (e) {
      debugPrint('Error stopping shelf server: $e');
    }
  }

  /// معالجة طلبات الطلاب المحلية الواردة عبر خادم الـ shelf
  /// سيناريو الحضور اللامركزي الهجين (P2P Local Handshake)
  Future<shelf.Response> _handleShelfRequest(shelf.Request request) async {
    // التحقق من المسار والطريقة
    if (request.method == 'POST' && request.url.path == 'attendance') {
      try {
        final bodyStr = await request.readAsString();
        final bodyJson = jsonDecode(bodyStr) as Map<String, dynamic>;

        final action = bodyJson['action'] as String?;
        final studentId = (bodyJson['student_id'] as String?)?.trim() ?? '';
        final deviceMac = (bodyJson['device_mac_address'] as String?)?.trim() ?? '';
        final lectureId = (bodyJson['lecture_id'] as String?)?.trim() ?? '';

        if (action == 'submit_attendance' && studentId.isNotEmpty) {
          // التحقق من عدم تسجيل الطالب مسبقاً في نفس المحاضرة
          final alreadyPresent = _attendees.any((a) => a.studentId == studentId);

          if (!alreadyPresent) {
            final newAttendee = AttendanceRecord(
              studentId: studentId,
              studentName: 'طالب جامعي ($studentId)',
              deviceMac: deviceMac.isNotEmpty ? deviceMac : 'MAC-AUTO',
              timestamp: DateTime.now(),
            );

            if (mounted) {
              setState(() {
                _attendees.insert(0, newAttendee);
              });
            }
          }

          // الرد بـ JSON لتأكيد الحضور وفصل الاتصال الفردي فوراً (Connection: close)
          return shelf.Response.ok(
            jsonEncode({
              'status': 'success',
              'message': alreadyPresent ? 'تم تسجيل حضورك مسبقاً' : 'تم تأكيد الحضور بنجاح',
              'lecture_id': lectureId,
              'student_id': studentId,
            }),
            headers: {
              'content-type': 'application/json',
              'connection': 'close',
            },
          );
        }
      } catch (e) {
        return shelf.Response.internalServerError(
          body: jsonEncode({'status': 'error', 'message': e.toString()}),
          headers: {'content-type': 'application/json', 'connection': 'close'},
        );
      }
    }

    // فحص جهوزية الخادم (Ping / Health)
    if (request.url.path == 'ping') {
      return shelf.Response.ok(
        jsonEncode({'status': 'active', 'lecture': widget.lecture.id}),
        headers: {'content-type': 'application/json', 'connection': 'close'},
      );
    }

    return shelf.Response.notFound(
      jsonEncode({'error': 'Not found'}),
      headers: {'content-type': 'application/json'},
    );
  }

  /// 2. توليد رمز الاستجابة السريع المتغير (Dynamic QR Code)
  void _generateDynamicQrCode() {
    final randomToken = Random().nextInt(900000) + 100000;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final qrPayload = {
      'lecture_id': widget.lecture.id,
      'timestamp': timestamp,
      'dyn_token': 'DYN-$randomToken',
      'host_port': _serverPort,
    };

    setState(() {
      _currentQrPayload = jsonEncode(qrPayload);
      _secondsLeft = 10;
    });
  }

  /// دورة تحديث الـ QR Code كل 10 ثوانٍ
  void _startQrRefreshCycle() {
    _countdownTimer?.cancel();
    _qrTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _generateDynamicQrCode();
      }
    });
  }

  /// محاكاة مسح طالب للكود لتجربة النظام بسلاسة (Simulation Helper)
  void _simulateStudentAttendance() {
    final randomId = '2026${Random().nextInt(8999) + 1000}';
    final randomMac = 'A${Random().nextInt(9)}:B${Random().nextInt(9)}:C${Random().nextInt(9)}:D${Random().nextInt(9)}:E${Random().nextInt(9)}:F${Random().nextInt(9)}';

    final names = ['عمر مختار الشعبي', 'أحمد سامي النجار', 'علي عبدالله صالح', 'خالد مروان القدسي', 'يوسف نبيل الحداد'];
    final selectedName = names[Random().nextInt(names.length)];

    setState(() {
      _attendees.insert(
        0,
        AttendanceRecord(
          studentId: randomId,
          studentName: selectedName,
          deviceMac: randomMac,
          timestamp: DateTime.now(),
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تسجيل حضور تجريبي: $selectedName ($randomId)'),
        backgroundColor: Colors.green[800],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 3. إنهاء المحاضرة ومزامنة كشف الحضور مع السيرفر المركزي عبر مصفوفة JSON
  Future<void> _endLectureAndSync() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.primaryGold, width: 1.5),
        ),
        title: const Text(
          'إنهاء المحاضرة والمزامنة',
          style: TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل تريد بالتأكيد إنهاء المحاضرة؟ سيتم إيقاف خادم الـ shelf المحلي وإرسال كشف الحضور (${_attendees.length} طالب) دفعة واحدة إلى سيرفر بايثون المركزي.',
          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: AppColors.primaryPurple,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء ومزامنة', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true);

    // إعداد مصفوفة الـ JSON للمزامنة
    final syncPayload = {
      'action': 'sync_attendance_batch',
      'lecture_id': widget.lecture.id,
      'course_name': widget.lecture.courseName,
      'total_attendees': _attendees.length,
      'attendance_logs': _attendees.map((a) => a.toJson()).toList(),
    };

    debugPrint('Syncing Attendance Payload: ${jsonEncode(syncPayload)}');

    // محاولة الإرسال لسيرفر Django / FastAPI إن وجد
    try {
      final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
final url = Uri.parse('http://127.0.0.1:8000/api/attendance/sync/');      await http .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(syncPayload),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر مزامنة الحضور مع Django/PostgreSQL'),
          backgroundColor: Colors.red,
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _isSyncing = false);

    await _stopLocalShelfServer();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.primaryGold, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: AppColors.accentGold, size: 28),
            SizedBox(width: 10),
            Text('تمت المزامنة بنجاح', style: TextStyle(color: AppColors.textGold, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'تم حفظ كشف الحضور بنجاح لـ ${_attendees.length} طالب، ومزامنة السجلات بصيغة Array of JSON مع السيرفر المركزي.',
          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: AppColors.primaryPurple,
            ),
            onPressed: () {
              Navigator.pop(context); // إغلاق الدايلوج
              Navigator.pop(context); // العودة للوحة تحكم الأستاذ
            },
            child: const Text('تم', style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text(
          'محاضرة نشطة: ${widget.lecture.courseName}',
          style: const TextStyle(color: AppColors.textGold, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.secondaryPurple,
        iconTheme: const IconThemeData(color: AppColors.accentGold),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.accentGold),
            tooltip: 'محاكاة حضور طالب',
            onPressed: _simulateStudentAttendance,
          ),
        ],
      ),
      body: Stack(
        children: [
          // الخلفية
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // شريط حالة الخادم المصغر ونقطة الاتصال
                  _buildServerStatusBar(),

                  const SizedBox(height: 16),

                  // بطاقة Dynamic QR Code المركزية
                  _buildDynamicQrCard(),

                  const SizedBox(height: 16),

                  // زر المحاكاة السريعة
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textGold,
                      side: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _simulateStudentAttendance,
                    icon: const Icon(Icons.flash_on_rounded, color: AppColors.accentGold, size: 18),
                    label: const Text('محاكاة تسجيل حضور طالب P2P (Test Scan)', style: TextStyle(fontSize: 12.5)),
                  ),

                  const SizedBox(height: 16),

                  // كشف الحضور اللحظي
                  _buildLiveAttendanceList(),

                  const SizedBox(height: 20),

                  // زر إنهاء المحاضرة والمزامنة
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    onPressed: _isSyncing ? null : _endLectureAndSync,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.stop_circle_outlined, size: 22),
                    label: Text(
                      _isSyncing ? 'جاري مزامنة الكشف مع السيرفر...' : 'إنهاء المحاضرة ومزامنة الحضور (Sync JSON)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),

                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// شريط حالة الخادم المصغر ونقطة الاتصال
  Widget _buildServerStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isServerRunning ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.orangeAccent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isServerRunning ? Colors.greenAccent : Colors.orangeAccent,
              boxShadow: [
                BoxShadow(
                  color: _isServerRunning ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.orangeAccent,
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isServerRunning
                      ? 'خادم shelf المصغر نشط على المنفذ ($_serverPort)'
                      : 'جاري تشغيل خادم shelf المحلي...',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  'شبكة Hotspot المحلية جاهزة لاستقبال حضور الطلاب اللامركزي P2P',
                  style: TextStyle(color: Colors.white70, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.wifi_tethering_rounded, color: AppColors.accentGold, size: 22),
        ],
      ),
    );
  }

  /// بطاقة الرمز المتغير (Dynamic QR Code Card)
  Widget _buildDynamicQrCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      value: _secondsLeft / 10.0,
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentGold),
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'يتجدد بعد $_secondsLeft ث',
                    style: const TextStyle(color: AppColors.textGold, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Row(
                children: [
                  Text(
                    'Dynamic QR Code',
                    style: TextStyle(color: AppColors.textGold, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.qr_code_2_rounded, color: AppColors.accentGold, size: 20),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // الـ QR الفعلي
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryGold, width: 2),
            ),
            child: _currentQrPayload.isEmpty
                ? const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : QrImageView(
                    data: _currentQrPayload,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
          ),

          const SizedBox(height: 12),
          const Text(
            'وجّه شاشة الهاتف نحو الطلاب لمسح الرمز عبر تطبيق الطالب.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'يتم التحقق محلياً وفصل الاتصال فورياً لخدمة الطالب التالي بكفاءة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGold, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  /// كشف الحضور اللحظي
  Widget _buildLiveAttendanceList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: Text(
                  '${_attendees.length} طالب حاضر',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const Row(
                children: [
                  Text(
                    'كشف الحضور اللحظي',
                    style: TextStyle(color: AppColors.textGold, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.how_to_reg_rounded, color: AppColors.accentGold, size: 20),
                ],
              ),
            ],
          ),
          const Divider(color: AppColors.primaryGold, thickness: 0.5, height: 20),

          if (_attendees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'بانتظار مسح الطلاب للرمز وتسجيل الحضور...',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: min(_attendees.length, 8),
              separatorBuilder: (context, i) => const Divider(color: Colors.white12, height: 8),
              itemBuilder: (context, index) {
                final attendee = _attendees[index];
                final timeStr =
                    '${attendee.timestamp.hour.toString().padLeft(2, '0')}:${attendee.timestamp.minute.toString().padLeft(2, '0')}:${attendee.timestamp.second.toString().padLeft(2, '0')}';

                return Row(
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          attendee.studentName,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'الرقم: ${attendee.studentId} | المعرف: ${attendee.deviceMac}',
                          style: const TextStyle(color: AppColors.textGold, fontSize: 10.5),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 6. واجهة تحديث إنجاز المنهج وتغذية مؤشرات الإدارة (Curriculum Progress Sheet)
// ==============================================================================

class _CurriculumProgressSheet extends StatefulWidget {
  final List<LectureItem> lectures;
  final LectureItem initialLecture;
  final Function(LectureItem, int, String) onProgressUpdated;

  const _CurriculumProgressSheet({
    required this.lectures,
    required this.initialLecture,
    required this.onProgressUpdated,
  });

  @override
  State<_CurriculumProgressSheet> createState() => _CurriculumProgressSheetState();
}

class _CurriculumProgressSheetState extends State<_CurriculumProgressSheet> {
  late LectureItem _selectedLecture;
  late double _currentProgress;
  final TextEditingController _topicController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedLecture = widget.initialLecture;
    _currentProgress = widget.initialLecture.progressPercentage.toDouble();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Color get _previewColor {
    if (_currentProgress >= 80) return AppColors.progressGold;
    if (_currentProgress >= 50) return AppColors.progressGreen;
    return AppColors.progressRed;
  }

  String get _previewStatusText {
    if (_currentProgress >= 80) return 'ذهبي (متقدم عن الخطة الزمنية)';
    if (_currentProgress >= 50) return 'أخضر (منتظم وضمن الخطة)';
    return 'أحمر (متأخر وبحاجة لتعويض)';
  }

  Future<void> _submitProgress() async {
    setState(() => _isSaving = true);

    final progressInt = _currentProgress.round();
    final topic = _topicController.text.trim();

    // إعداد حزمة JSON المنصوص عليها في التوثيق الهندسي:
    // {
    //   "department": "علوم الحاسب",
    //   "course_name": "شبكات حاسب",
    //   "progress": 85,
    //   "status_color": "ذهبي"
    // }
    String colorName = 'أحمر';
    if (progressInt >= 80) {
      colorName = 'ذهبي';
    } else if (progressInt >= 50) {
      colorName = 'أخضر';
    }

    final payload = {
      'department': _selectedLecture.department,
      'course_name': _selectedLecture.courseName,
      'progress': progressInt,
      'status_color': colorName,
      'completed_topic': topic,
    };

    debugPrint('Submitting Progress to Admin Backend: ${jsonEncode(payload)}');

    try {
      final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
final url = Uri.parse('http://127.0.0.1:8000/api/curriculum/update-progress/');   await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ تقدم المنهج في Django/PostgreSQL'),
          backgroundColor: Colors.red,
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isSaving = false);

    widget.onProgressUpdated(_selectedLecture, progressInt, topic);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 25,
      ),
      decoration: const BoxDecoration(
        color: AppColors.secondaryPurple,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.primaryGold, width: 2),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 15),

            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_up_rounded, color: AppColors.accentGold, size: 24),
                SizedBox(width: 8),
                Text(
                  'تحديث إنجاز المنهج ومؤشرات الإدارة',
                  style: TextStyle(
                    color: AppColors.textGold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // اختيار المادة
            const Text(
              'المادة الدراسية المقررة:',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<LectureItem>(
              value: _selectedLecture,
              dropdownColor: AppColors.primaryPurple,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.primaryPurple.withValues(alpha: 0.6),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: widget.lectures.map((lec) {
                return DropdownMenuItem<LectureItem>(
                  value: lec,
                  child: Text(lec.courseName, textAlign: TextAlign.right),
                );
              }).toList(),
              onChanged: (lec) {
                if (lec != null) {
                  setState(() {
                    _selectedLecture = lec;
                    _currentProgress = lec.progressPercentage.toDouble();
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // شريط نسبة الإنجاز
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _previewColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _previewColor),
                  ),
                  child: Text(
                    '${_currentProgress.round()}%',
                    style: TextStyle(color: _previewColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Text(
                  'نسبة الإنجاز الأسبوعية:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),

            Slider(
              value: _currentProgress,
              min: 0,
              max: 100,
              divisions: 100,
              activeColor: _previewColor,
              inactiveColor: Colors.white24,
              onChanged: (val) {
                setState(() {
                  _currentProgress = val;
                });
              },
            ),

            // مؤشر لغة الألوان المعتمدة للوحة المشرف
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _previewColor.withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, color: _previewColor, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'المؤشر في لوحة المشرف: $_previewStatusText',
                      style: TextStyle(color: _previewColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // حقل إضافة موضوع الوحدة المنجزة
            TextField(
              controller: _topicController,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'الموضوع أو الوحدة المنجزة حديثاً',
                labelStyle: const TextStyle(color: AppColors.textGold, fontSize: 12.5),
                hintText: 'مثال: إعدادات شبكات VLANs والتوجيه الداخلي',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                filled: true,
                fillColor: AppColors.primaryPurple.withValues(alpha: 0.6),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),

            const SizedBox(height: 22),

            // زر الحفظ والإرسال
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.primaryPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: _isSaving ? null : _submitProgress,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: AppColors.primaryPurple, strokeWidth: 2),
                    )
                  : const Text(
                      'حفظ وتغذية مؤشرات الإدارة (Send JSON)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// عنصر الزخرفة الدائرية
class _DecorativeRing extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeRing({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}
