from django.db import models


class Student(models.Model):
    student_id = models.CharField(max_length=50, primary_key=True)
    full_name = models.CharField(max_length=100)
    department = models.CharField(max_length=100)
    level = models.CharField(max_length=50, blank=True, null=True)
    device_unique_id = models.CharField(max_length=255, blank=True, null=True)
    status = models.CharField(max_length=50, default='inactive')

    class Meta:
        db_table = 'students'

    def __str__(self):
        return f'{self.student_id} - {self.full_name}'


class Professor(models.Model):
    academic_id = models.CharField(max_length=50, primary_key=True)
    full_name = models.CharField(max_length=100)
    department = models.CharField(max_length=100, blank=True, default='')
    device_uuid = models.CharField(max_length=255, blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'professors'

    def __str__(self):
        return f'{self.academic_id} - {self.full_name}'


class Lecture(models.Model):
    lecture_id = models.CharField(max_length=50, primary_key=True)
    course_name = models.CharField(max_length=200)
    room_name = models.CharField(max_length=100)
    time_slot = models.CharField(max_length=100)
    department = models.CharField(max_length=100)
    progress_percentage = models.PositiveSmallIntegerField(default=0)
    completed_topics = models.JSONField(default=list, blank=True)

    class Meta:
        db_table = 'lectures'

    def __str__(self):
        return f'{self.lecture_id} - {self.course_name}'


class Attendance(models.Model):
    lecture = models.ForeignKey(Lecture, on_delete=models.CASCADE, related_name='attendance_records')
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='attendance_records')
    student_name = models.CharField(max_length=100, blank=True, default='')
    device_address = models.CharField(max_length=255)
    attendance_timestamp = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'attendance'
        unique_together = ('lecture', 'student')
        ordering = ('-attendance_timestamp',)


class CurriculumProgress(models.Model):
    department = models.CharField(max_length=100)
    course_name = models.CharField(max_length=200)
    progress = models.PositiveSmallIntegerField(default=0)
    status_color = models.CharField(max_length=20)
    completed_topic = models.CharField(max_length=255, blank=True, default='')
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'curriculum_progress'
        ordering = ('-updated_at',)
