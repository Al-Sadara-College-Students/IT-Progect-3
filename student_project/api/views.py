from datetime import datetime

from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import Attendance, CurriculumProgress, Lecture, Professor, Student


@api_view(['POST'])
def register_student(request):
    student_id = str(request.data.get('student_id', '')).strip()
    full_name = str(request.data.get('full_name', '')).strip()
    department = str(request.data.get('department', '')).strip()
    device_id = str(request.data.get('device_id', '')).strip()

    if not all((student_id, full_name, department, device_id)):
        return Response({'error': 'جميع بيانات الطالب ومعرف الجهاز مطلوبة.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        student = Student.objects.filter(student_id=student_id).first()
        if not student:
            return Response({'error': 'الرقم الأكاديمي غير مسجل في قاعدة البيانات.'}, status=status.HTTP_400_BAD_REQUEST)
        if student.full_name.strip() != full_name or student.department.strip().lower() != department.lower():
            return Response({'error': 'الاسم أو القسم الدراسي غير مطابق للبيانات المسجلة.'}, status=status.HTTP_400_BAD_REQUEST)
        if not student.device_unique_id:
            student.device_unique_id = device_id
            student.status = 'active'
            student.save(update_fields=['device_unique_id', 'status'])
        elif student.device_unique_id != device_id:
            return Response({'error': 'هذا الحساب مرتبط بجهاز آخر ولا يمكن تسجيل الدخول منه.'}, status=status.HTTP_403_FORBIDDEN)

        return Response({
            'message': 'تم التحقق وتسجيل الدخول بنجاح!',
            'student': {
                'student_id': student.student_id,
                'full_name': student.full_name,
                'department': student.department,
            },
        }, status=status.HTTP_200_OK)
    except Exception as exc:
        return Response({'error': str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
def login_or_register_professor(request):
    """التحقق من هوية الأستاذ المسجل مسبقاً في قاعدة البيانات وربط الجهاز عند السماح."""
    full_name = str(request.data.get('full_name', '')).strip()
    academic_id = str(request.data.get('academic_id', '')).strip()
    device_uuid = str(request.data.get('device_uuid', '')).strip()
    department = str(request.data.get('department', '')).strip()

    if not all((full_name, academic_id, device_uuid)):
        return Response(
            {'error': 'الاسم والرقم الأكاديمي ومعرف الجهاز مطلوبة.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        professor = Professor.objects.filter(academic_id=academic_id).first()

        # منع إنشاء حسابات جديدة عشوائية: يجب أن يكون الأستاذ مسجلاً مسبقاً
        if not professor:
            return Response(
                {'error': 'هذا الرقم الأكاديمي غير مسجل في النظام.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # التحقق من تطابق الاسم مع السجل المسجل
        if professor.full_name.strip().lower() != full_name.lower():
            return Response(
                {'error': 'الاسم غير مطابق للرقم الأكاديمي المسجل.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # التحقق من أن الحساب مفعّل/معتمد في قاعدة البيانات (إذا كان الحقل موجوداً في الموديل)
        if hasattr(professor, 'is_verified') and not professor.is_verified:
            return Response(
                {'error': 'الحساب غير مفعّل بعد من الإدارة.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # منع الدخول إذا كان الحساب مربوطاً بجهاز هاتف آخر
        if professor.device_uuid and professor.device_uuid != device_uuid:
            return Response(
                {'error': 'هذا الحساب الأكاديمي مربوط بجهاز آخر.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # ربط معرف الجهاز لأول مرة وتحديث القسم إذا أُرسل
        if not professor.device_uuid:
            professor.device_uuid = device_uuid
        if department:
            professor.department = department
        professor.save()

        return Response(
            {
                'message': 'تم التحقق وتأكيد حساب الأستاذ بنجاح!',
                'professor': {
                    'academic_id': professor.academic_id,
                    'full_name': professor.full_name,
                    'department': professor.department,
                    'device_uuid': professor.device_uuid,
                },
            },
            status=status.HTTP_200_OK,
        )
    except Exception as exc:
        return Response(
            {'error': str(exc)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
@api_view(['POST'])
def sync_attendance(request):
    action = str(request.data.get('action', '')).strip()

    if action == 'submit_attendance':
        student_id = str(request.data.get('student_id', '')).strip()
        lecture_id = str(request.data.get('lecture_id', '')).strip()
        device_address = str(request.data.get('device_mac_address', '')).strip()
        if not student_id or not lecture_id:
            return Response({'error': 'رقم الطالب ورمز المحاضرة مطلوبان.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            student = Student.objects.filter(student_id=student_id).first()
            lecture = Lecture.objects.filter(lecture_id=lecture_id).first()
            if not student:
                return Response({'error': 'الطالب غير مسجل في قاعدة البيانات.'}, status=status.HTTP_404_NOT_FOUND)
            if not lecture:
                return Response({'error': 'المحاضرة غير موجودة.'}, status=status.HTTP_404_NOT_FOUND)

            record, created = Attendance.objects.get_or_create(
                lecture=lecture,
                student=student,
                defaults={
                    'student_name': student.full_name,
                    'device_address': device_address,
                    'attendance_timestamp': timezone.now(),
                },
            )
            return Response({
                'message': 'تم تأكيد الحضور بنجاح!' if created else 'تم تسجيل حضورك مسبقاً',
                'lecture_id': lecture_id,
                'student_id': student_id,
            }, status=status.HTTP_200_OK)
        except Exception as exc:
            return Response({'error': str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    if action == 'sync_attendance_batch':
        lecture_id = str(request.data.get('lecture_id', '')).strip()
        course_name = str(request.data.get('course_name', '')).strip()
        logs = request.data.get('attendance_logs', [])

        try:
            lecture, _ = Lecture.objects.get_or_create(
                lecture_id=lecture_id,
                defaults={
                    'course_name': course_name or lecture_id,
                    'room_name': 'غير محدد',
                    'time_slot': 'غير محدد',
                    'department': 'غير محدد',
                },
            )
            if course_name:
                lecture.course_name = course_name
                lecture.save(update_fields=['course_name'])

            with transaction.atomic():
                for log in logs if isinstance(logs, list) else []:
                    student_id = str(log.get('student_id', '')).strip()
                    if not student_id:
                        continue
                    student = Student.objects.filter(student_id=student_id).first()
                    if not student:
                        student = Student.objects.create(
                            student_id=student_id,
                            full_name=str(log.get('student_name', f'طالب {student_id}')).strip(),
                            department='غير محدد',
                        )
                    timestamp = log.get('attendance_timestamp')
                    try:
                        attendance_time = datetime.fromisoformat(str(timestamp).replace('Z', '+00:00'))
                    except (TypeError, ValueError):
                        attendance_time = timezone.now()
                    Attendance.objects.update_or_create(
                        lecture=lecture,
                        student=student,
                        defaults={
                            'student_name': str(log.get('student_name', student.full_name)).strip(),
                            'device_address': str(log.get('device_mac_address', '')).strip(),
                            'attendance_timestamp': attendance_time,
                        },
                    )

            return Response({
                'message': 'تم مزامنة كشف الحضور بنجاح!',
                'lecture_id': lecture_id,
                'synced_count': len(logs) if isinstance(logs, list) else 0,
            }, status=status.HTTP_200_OK)
        except Exception as exc:
            return Response({'error': str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    return Response({'error': 'نوع عملية الحضور غير مدعوم.'}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
def update_curriculum_progress(request):
    department = str(request.data.get('department', '')).strip()
    course_name = str(request.data.get('course_name', '')).strip()
    progress = request.data.get('progress', 0)
    status_color = str(request.data.get('status_color', '')).strip()
    completed_topic = str(request.data.get('completed_topic', '')).strip()

    if not course_name:
        return Response({'error': 'اسم المقرر مطلوب.'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        progress = max(0, min(100, int(progress)))
    except (TypeError, ValueError):
        return Response({'error': 'نسبة التقدم غير صحيحة.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        record = CurriculumProgress.objects.create(
            department=department,
            course_name=course_name,
            progress=progress,
            status_color=status_color or ('ذهبي' if progress >= 80 else 'أخضر' if progress >= 50 else 'أحمر'),
            completed_topic=completed_topic,
        )
        lecture = Lecture.objects.filter(course_name=course_name).first()
        if lecture:
            lecture.progress_percentage = progress
            if completed_topic and completed_topic not in lecture.completed_topics:
                lecture.completed_topics = [*lecture.completed_topics, completed_topic]
            lecture.save(update_fields=['progress_percentage', 'completed_topics'])
        return Response({'message': 'تم تحديث إنجاز المنهج بنجاح!', 'progress': record.progress}, status=status.HTTP_200_OK)
    except Exception as exc:
        return Response({'error': str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
def academic_data(request):
    lectures = [
        {
            'lecture_id': item.lecture_id,
            'course_name': item.course_name,
            'room_name': item.room_name,
            'time_slot': item.time_slot,
            'department': item.department,
            'progress_percentage': item.progress_percentage,
            'completed_topics': item.completed_topics,
        }
        for item in Lecture.objects.all()
    ]
    progress = [
        {
            'department': item.department,
            'course_name': item.course_name,
            'progress': item.progress,
            'status_color': item.status_color,
            'completed_topic': item.completed_topic,
            'updated_at': item.updated_at.isoformat(),
        }
        for item in CurriculumProgress.objects.all()[:100]
    ]
    return Response({'lectures': lectures, 'curriculum_progress': progress}, status=status.HTTP_200_OK)

@api_view(['POST'])
def qr_login_student(request):
    qr_code_data = str(request.data.get('qr_code_data', '')).strip()
    device_uuid = str(request.data.get('device_uuid', '')).strip()

    if not qr_code_data:
        return Response({'error': 'بيانات QR البطاقة مطلوبة.'}, status=status.HTTP_400_BAD_REQUEST)

    cleaned_id = qr_code_data.replace('STUDENT_QR_', '').strip()
    student = (
        Student.objects.filter(student_id=qr_code_data).first()
        or Student.objects.filter(student_id=cleaned_id).first()
    )

    if not student:
        return Response({'error': 'بطاقة الطالب غير مسجلة في قاعدة البيانات.'}, status=status.HTTP_404_NOT_FOUND)

    if device_uuid:
        if not student.device_unique_id:
            student.device_unique_id = device_uuid
            student.status = 'active'
            student.save(update_fields=['device_unique_id', 'status'])
        elif student.device_unique_id != device_uuid:
            return Response({'error': 'هذا الحساب مرتبط بجهاز آخر.'}, status=status.HTTP_403_FORBIDDEN)

    return Response({
        'message': 'تم التحقق من البطاقة وتسجيل الدخول بنجاح!',
        'student': {
            'student_id': student.student_id,
            'full_name': student.full_name,
            'department': student.department,
        },
    }, status=status.HTTP_200_OK)