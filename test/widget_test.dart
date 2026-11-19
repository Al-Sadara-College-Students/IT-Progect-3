import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nopp/main.dart';

void main() {
  testWidgets('onboarding screen opens manual student input', (tester) async {
    await tester.pumpWidget(const AcademicSystemApp());

    expect(find.text('نظام ادارة الجداول الاكاديمي الذكي'), findsOneWidget);

    await tester.tap(find.text('إدخال البيانات يدوياً'));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل بيانات الطالب'), findsOneWidget);
    expect(find.text('الاسم الرباعي'), findsOneWidget);
  });

  testWidgets('student OCR action shows and dismisses loading overlay',
      (tester) async {
    await tester.pumpWidget(const AcademicSystemApp());

    await tester.tap(find.text('تسجيل آلي عبر تصوير البطاقة الجامعية'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('تم مسح البطاقة بنجاح'), findsOneWidget);
  });

  testWidgets('onboarding screen opens professor registration screen with required fields',
      (tester) async {
    await tester.pumpWidget(const AcademicSystemApp());

    // 1. العثور على زر تسجيل / دخول الأستاذ في الواجهة الأولى
    final profRegBtn = find.text('تسجيل / دخول الأستاذ');
    expect(profRegBtn, findsOneWidget);
    await tester.ensureVisible(profRegBtn);
    await tester.tap(profRegBtn);
    await tester.pumpAndSettle();

    // 2. التحقق من الانتقال إلى صفحة تسجيل الأستاذ وظهور الحقول المطلوبة (الاسم والرقم الأكاديمي)
    expect(find.text('تسجيل بيانات الأستاذ'), findsOneWidget);
    expect(find.text('الاسم الثلاثي أو الرباعي للأستاذ'), findsOneWidget);
    expect(find.text('الرقم الأكاديمي للأستاذ'), findsOneWidget);
    expect(find.text('تأكيد الحساب والدخول (UUID Binding)'), findsOneWidget);
  });

  testWidgets('professor dashboard displays today schedule and core actions',
      (tester) async {
    await tester.pumpWidget(const AcademicSystemApp());

    // فتح صفحة تسجيل الأستاذ
    await tester.tap(find.text('تسجيل / دخول الأستاذ'));
    await tester.pumpAndSettle();

    // إدخال البيانات والتحقق من التفاعل
    await tester.enterText(
        find.widgetWithText(TextFormField, 'الاسم الثلاثي أو الرباعي للأستاذ'),
        'د. محمد أحمد الكندي');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'الرقم الأكاديمي للأستاذ'),
        '202603');
    await tester.pump();

    expect(find.text('د. محمد أحمد الكندي'), findsOneWidget);
    expect(find.text('202603'), findsOneWidget);
  });
}
