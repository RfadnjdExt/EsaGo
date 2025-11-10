import 'dart:convert';

import 'package:esago/models/schedule_model.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

const String appGroupId = 'YOUR_APP_GROUP_ID';

@pragma('vm:entry-point')
void backgroundCallback(Uri? uri) async {
  // Ini tidak akan digunakan lagi dalam arsitektur baru, tetapi tetap ada
  // untuk menangani pembaruan widget standar.
  debugPrint('Background callback triggered, but no action taken for date navigation.');
}

class _UpcomingSchedule {
  final String title;
  final DateTime startTime;
  final String room;

  _UpcomingSchedule({
    required this.title,
    required this.startTime,
    required this.room,
  });
}

Future<void> sendDataToWidget(FullScheduleData? scheduleData) async {
  debugPrint('[WidgetUtils] Starting sendDataToWidget.');
  if (scheduleData == null) {
    // Hapus data widget jika logout
    await HomeWidget.saveWidgetData<String>('all_schedules_json', null);
    await HomeWidget.saveWidgetData<String>('next_schedule_course', null);
    await HomeWidget.saveWidgetData<String>('next_schedule_time', null);
    await HomeWidget.saveWidgetData<String>('next_schedule_room', null);
    // ... hapus data lain jika perlu
  } else {
    final now = DateTime.now();

    // --- Temukan jadwal terdekat untuk widget kecil ---
    final nextSchedule = _findNextUpcomingSchedule(scheduleData, now);
    if (nextSchedule != null) {
        await HomeWidget.saveWidgetData<String>('next_schedule_course', nextSchedule.title);
        await HomeWidget.saveWidgetData<String>('next_schedule_time', DateFormat('HH:mm', 'id_ID').format(nextSchedule.startTime));
        await HomeWidget.saveWidgetData<String>('next_schedule_room', nextSchedule.room);
    } else {
        if (scheduleData.dailySchedules.isEmpty && scheduleData.examSchedules.isEmpty) {
            // Jika tidak ada jadwal sama sekali, asumsikan pengguna belum login atau tidak punya data.
            // Hapus data widget untuk menampilkan pesan default "Masuk untuk melihat jadwal".
            await HomeWidget.saveWidgetData<String>('next_schedule_course', null);
            await HomeWidget.saveWidgetData<String>('next_schedule_time', null);
            await HomeWidget.saveWidgetData<String>('next_schedule_room', null);
        } else {
            // Jika ada jadwal tapi tidak ada yang akan datang, tampilkan pesan yang sesuai.
            await HomeWidget.saveWidgetData<String>('next_schedule_course', 'Tidak ada jadwal mendatang');
            await HomeWidget.saveWidgetData<String>('next_schedule_time', '--:--');
            await HomeWidget.saveWidgetData<String>('next_schedule_room', '');
        }
    }

    // --- Proses SEMUA jadwal menjadi satu JSON besar ---
    final allSchedulesJson = _getAllSchedulesAsJson(scheduleData);
    await HomeWidget.saveWidgetData<String>('all_schedules_json', allSchedulesJson);

    // --- Atur tanggal awal untuk widget besar ---
    final initialDate = nextSchedule?.startTime ?? now;
    await HomeWidget.saveWidgetData<String>("widget_current_date", DateFormat("yyyy-MM-dd").format(initialDate));
  }

  // --- Picu pembaruan widget ---
  await HomeWidget.updateWidget(
    name: 'ScheduleWidgetProvider',
    androidName: 'ScheduleWidgetProvider',
  );
  debugPrint('[WidgetUtils] Successfully requested widget update.');
}

String _getAllSchedulesAsJson(FullScheduleData scheduleData) {
  final List<Map<String, String>> allSchedules = [];
  final dateFormat = DateFormat('d MMMM yyyy', 'id_ID');
  final outputDateFormat = DateFormat('yyyy-MM-dd');

  void processEntries(List<dynamic> scheduleList, {bool isExam = false}) {
    for (var schedule in scheduleList) {
      final dateParts = schedule.day.split(', ');
      if (dateParts.length != 2) continue;

      try {
        final scheduleDate = dateFormat.parse(dateParts[1]);
        final dateString = outputDateFormat.format(scheduleDate);

        for (var entry in schedule.entries) {
          allSchedules.add({
            'date': dateString, // Field tanggal baru
            'time': '${entry.startTime} - ${entry.endTime}',
            'course': entry.courseName,
            'room': entry.room,
            'lecturer': (entry is DailyEntry) ? entry.lecturer : '',
            'topic': (entry is DailyEntry) ? entry.topic : '',
            'type': (isExam || entry is ExamEntry) ? "(Ujian) ${entry.examType ?? ''}".trim() : (entry is DailyEntry) ? entry.type : ''
          });
        }
      } catch (e) {
        debugPrint('[WidgetUtils] Error parsing date in _getAllSchedulesAsJson: $e');
      }
    }
  }

  processEntries(scheduleData.examSchedules, isExam: true);
  processEntries(scheduleData.dailySchedules);

  return jsonEncode(allSchedules);
}

_UpcomingSchedule? _findNextUpcomingSchedule(FullScheduleData scheduleData, DateTime now) {
  final List<_UpcomingSchedule> upcoming = [];
  final dateFormat = DateFormat('d MMMM yyyy', 'id_ID');

  void findInList(List<dynamic> scheduleList) {
      for (var schedule in scheduleList) {
      final dateParts = schedule.day.split(', ');
      if (dateParts.length != 2) continue;

      try {
        final scheduleDate = dateFormat.parse(dateParts[1]);
        for (var entry in schedule.entries) {
          final timeParts = entry.startTime.split(':');
          if (timeParts.length != 2) continue;

          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          final startTime = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day, hour, minute);

          if (startTime.isAfter(now)) {
            upcoming.add(_UpcomingSchedule(
              title: entry.courseName,
              startTime: startTime,
              room: entry.room,
            ));
          }
        }
      } catch (e) {
        debugPrint('[WidgetUtils] ERROR parsing date/time: $e');
      }
    }
  }
  
  findInList(scheduleData.examSchedules);
  findInList(scheduleData.dailySchedules);

  if (upcoming.isEmpty) return null;

  upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
  return upcoming.first;
}
