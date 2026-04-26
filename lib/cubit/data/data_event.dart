import 'package:equatable/equatable.dart';

abstract class DataEvent extends Equatable {
  const DataEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadAllDataEvent extends DataEvent {}

class LoadStudentGradesEvent extends DataEvent {
  final int studentId;
  
  const LoadStudentGradesEvent(this.studentId);
  
  @override
  List<Object?> get props => [studentId];
}

class LoadAttendanceEvent extends DataEvent {
  final String? token;
  
  const LoadAttendanceEvent(this.token);
  
  @override
  List<Object?> get props => [token];
}

class ClearDataEvent extends DataEvent {}