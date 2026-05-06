class WorkoutRecord {
  final String id;
  final String date;
  final int totalTimeMs;
  final List<ExerciseSet> exercises;

  WorkoutRecord({
    required this.id,
    required this.date,
    required this.totalTimeMs,
    required this.exercises,
  });

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) {
    return WorkoutRecord(
      id: json['id'] as String,
      date: json['date'] as String,
      totalTimeMs: json['totalTimeMs'] as int,
      exercises: (json['exercises'] as List)
          .map((e) => ExerciseSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'totalTimeMs': totalTimeMs,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }
}

class ExerciseSet {
  final int exerciseNum;
  final String exerciseName;
  final int completed;
  final int target;

  ExerciseSet({
    required this.exerciseNum,
    this.exerciseName = '운동',
    required this.completed,
    required this.target,
  });

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      exerciseNum: json['exerciseNum'] as int,
      exerciseName: json['exerciseName'] as String? ?? '운동',
      completed: json['completed'] as int,
      target: json['target'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exerciseNum': exerciseNum,
      'exerciseName': exerciseName,
      'completed': completed,
      'target': target,
    };
  }
}