// lib/cubit/data/data_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api_service.dart';
import '../../models/student.dart';
import '../../models/doctor.dart';
import '../../models/subject.dart';
import '../../models/lecture.dart';
import '../../models/grade.dart';
import '../../models/attendance.dart';
import 'data_state.dart';

class DataCubit extends Cubit<DataState> {
  DataCubit() : super(DataState.initial());
  
  Future<void> loadAllData() async {
    if (state.loadingState.isLoading) return;
    
    emit(DataState.loading());
    
    try {
      final results = await Future.wait([
        ApiService.getStudents(),
        ApiService.getDoctors(),
        ApiService.getSubjects(),
        ApiService.getLectures(),
      ]);
      
      final students = results[0].map((j) => Student.fromJson(j)).toList();
      final doctors = results[1].map((j) => Doctor.fromJson(j)).toList();
      final subjects = results[2].map((j) => Subject.fromJson(j)).toList();
      final lectures = results[3].map((j) => Lecture.fromJson(j)).toList();
      
      // طباعة معلومات التصحيح للمواد
      print('=' * 50);
      print('📚 SUBJECTS LOADED: ${subjects.length}');
      for (var subject in subjects) {
        print('   - ${subject.code}: ${subject.name}');
        print('     Doctor: ${subject.doctorName} (ID: ${subject.doctorId})');
        print('     Credits: ${subject.credits} | Credit Hours: ${subject.creditHours}');
        print('     Level: ${subject.level} | Semester: ${subject.semester}');
        print('     Department: ${subject.department}');
      }
      
      // طباعة معلومات التصحيح للمحاضرات
      print('\n📚 LECTURES LOADED: ${lectures.length}');
      for (var lecture in lectures) {
        print('   - ${lecture.subjectName}');
        print('     Doctor: ${lecture.doctorName} (ID: ${lecture.doctorId})');
        print('     Day: ${lecture.day} | Time: ${lecture.timeDisplay}');
        print('     Location: ${lecture.locationName} | Level: ${lecture.level}');
      }
      
      // طباعة معلومات التصحيح للأطباء
      print('\n👨‍⚕️ DOCTORS LOADED: ${doctors.length}');
      for (var doctor in doctors) {
        final doctorSubjects = subjects.where((s) => s.doctorId == doctor.id).toList();
        final doctorLectures = lectures.where((l) => l.doctorId == doctor.id).toList();
        print('   - Dr. ${doctor.name} (ID: ${doctor.id})');
        print('     Username: ${doctor.username}');
        print('     Email: ${doctor.email ?? "Not provided"}');
        print('     Subjects: ${doctorSubjects.length}');
        for (var sub in doctorSubjects) {
          print('       • ${sub.code}: ${sub.name}');
        }
        print('     Lectures: ${doctorLectures.length}');
        for (var lec in doctorLectures) {
          print('       • ${lec.subjectName} (${lec.day} ${lec.timeDisplay})');
        }
      }
      
      print('=' * 50);
      
      emit(DataState.loaded(
        students: students,
        doctors: doctors,
        subjects: subjects,
        lectures: lectures,
      ));
      
      print('✅ Data loaded successfully');
      print('   Students: ${students.length}');
      print('   Doctors: ${doctors.length}');
      print('   Subjects: ${subjects.length}');
      print('   Lectures: ${lectures.length}');
    } catch (e) {
      emit(DataState.error('Failed to load data: ${e.toString()}'));
      print('❌ Error loading data: $e');
    }
  }
  
  Future<void> loadStudentGrades(int studentId) async {
    try {
      final response = await ApiService.getStudentGrades(studentId);
      final grades = response.map((j) => Grade.fromJson(j)).toList();
      
      emit(state.copyWith(grades: grades));
      print('📊 Grades loaded: ${grades.length}');
      for (var g in grades) {
        print('   - ${g.subjectName}: ${g.total} (Visible: ${g.isVisible})');
      }
    } catch (e) {
      print('❌ Error loading grades: $e');
    }
  }
  
  Future<void> loadStudentGradesWithToken(int studentId, String token) async {
    print('📊 Loading grades for student $studentId with token');
    
    try {
      final response = await ApiService.getStudentGradesWithToken(studentId, token);
      final grades = response.map((j) => Grade.fromJson(j)).toList();
      
      print('✅ Loaded ${grades.length} grades');
      for (var g in grades) {
        print('   - ${g.subjectName}: ${g.total} (Visible: ${g.isVisible})');
      }
      
      emit(state.copyWith(grades: grades));
    } catch (e) {
      print('❌ Error loading grades: $e');
    }
  }
  
  Future<void> checkGradesStatus(int studentId, String token) async {
    try {
      final status = await ApiService.checkGradesStatus(studentId, token);
      print('📊 Grades Status: $status');
    } catch (e) {
      print('❌ Error checking grades status: $e');
    }
  }
  
  Future<void> loadAttendance(String? token) async {
    try {
      final response = await ApiService.getAttendance(token);
      final attendance = response.map((j) => AttendanceRecord.fromJson(j)).toList();
      
      emit(state.copyWith(attendance: attendance));
      print('📋 Attendance loaded: ${attendance.length}');
    } catch (e) {
      print('❌ Error loading attendance: $e');
    }
  }
  
  void clearData() {
    emit(DataState.initial());
  }
}