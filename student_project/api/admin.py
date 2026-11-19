from django.contrib import admin
from .models import Student, Professor, Lecture, Attendance, CurriculumProgress


@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display = ('student_id', 'full_name', 'department', 'status')
    search_fields = ('student_id', 'full_name', 'department')


@admin.register(Professor)
class ProfessorAdmin(admin.ModelAdmin):
    list_display = ('academic_id', 'full_name', 'department', 'is_active')
    search_fields = ('academic_id', 'full_name')


@admin.register(Lecture)
class LectureAdmin(admin.ModelAdmin):
    list_display = ('lecture_id', 'course_name', 'department', 'progress_percentage')


@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = ('student', 'lecture', 'attendance_timestamp')


@admin.register(CurriculumProgress)
class CurriculumProgressAdmin(admin.ModelAdmin):
    list_display = ('course_name', 'progress', 'status_color', 'updated_at')
