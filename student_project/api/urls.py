from django.urls import path
from .views import (
    register_student,
    qr_login_student,
    login_or_register_professor,
    sync_attendance,
    update_curriculum_progress,
    academic_data,
)

urlpatterns = [
    path('student/register/', register_student, name='register_student'),
    path('student/qr-login/', qr_login_student, name='qr_login_student'),
    path('professor/login-register/', login_or_register_professor, name='login_or_register_professor'),
    path('attendance/sync/', sync_attendance, name='sync_attendance'),
    path('curriculum/update-progress/', update_curriculum_progress, name='update_curriculum_progress'),
    path('academic-data/', academic_data, name='academic_data'),
]