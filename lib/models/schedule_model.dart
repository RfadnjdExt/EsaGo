class WeeklySchedule {
  final String day;
  final List<ScheduleEntry> entries;

  WeeklySchedule({required this.day, required this.entries});
}

class ScheduleEntry {
  final String startTime;
  final String endTime;
  final String courseCode;
  final String courseName;
  final String session;
  final String room;
  final int? moodleCourseId; // ID matkul dari Moodle

  ScheduleEntry({
    required this.startTime,
    required this.endTime,
    required this.courseCode,
    required this.courseName,
    required this.session,
    required this.room,
    this.moodleCourseId,
  });
}

class DailySchedule {
  final String day;
  final List<DailyEntry> entries;

  DailySchedule({required this.day, required this.entries});
}

class DailyEntry {
  final String meeting;
  final String startTime;
  final String endTime;
  final String courseName;
  final String lecturer;
  final String type;
  final String topic;
  final String room;
  final String implementation;

  DailyEntry({
    required this.meeting,
    required this.startTime,
    required this.endTime,
    required this.courseName,
    required this.lecturer,
    required this.type,
    required this.topic,
    required this.room,
    required this.implementation,
  });
}

class ExamSchedule {
  final String day;
  final List<ExamEntry> entries;

  ExamSchedule({required this.day, required this.entries});
}

class ExamEntry {
  final String startTime;
  final String endTime;
  final String courseCode;
  final String courseName;
  final String session;
  final String examType;
  final String group;
  final String room;

  ExamEntry({
    required this.startTime,
    required this.endTime,
    required this.courseCode,
    required this.courseName,
    required this.session,
    required this.examType,
    required this.group,
    required this.room,
  });
}

class FullScheduleData {
  final List<WeeklySchedule> weeklySchedules;
  final List<DailySchedule> dailySchedules;
  final List<ExamSchedule> examSchedules;

  FullScheduleData({
    required this.weeklySchedules,
    required this.dailySchedules,
    required this.examSchedules,
  });
}
