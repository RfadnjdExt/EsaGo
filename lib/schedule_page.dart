import 'package:esago/course_participants_page.dart';
import 'package:esago/models/schedule_model.dart';
import 'package:esago/services/moodle_service.dart';
import 'package:esago/widget_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SchedulePage extends StatefulWidget {
  final FullScheduleData scheduleData;
  final MoodleService moodleService;

  const SchedulePage({
    super.key, 
    required this.scheduleData, 
    required this.moodleService
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _platform = MethodChannel('com.esadigitallabs.esago/widget');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleWidgetAction() async {
    try {
      await sendDataToWidget(widget.scheduleData);
      final bool widgetAdded = await _platform.invokeMethod('isWidgetAdded');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(widgetAdded ? 'Jadwal untuk widget telah disinkronkan.' : 'Widget berhasil ditambahkan!'),
          ),
        );
        if (!widgetAdded) {
          await _platform.invokeMethod('requestPinWidget');
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1931),
      appBar: AppBar(
        title: const Text('Jadwal Kuliah'),
        backgroundColor: const Color(0xFF0A1931),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_home_screen),
            tooltip: 'Tambah atau Sinkronkan Widget',
            onPressed: _handleWidgetAction,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Mingguan'), Tab(text: 'Harian'), Tab(text: 'Ujian')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildWeeklyView(), _buildDailyView(), _buildExamView()],
      ),
    );
  }

  Widget _buildWeeklyView() {
    return ListView.builder(
      itemCount: widget.scheduleData.weeklySchedules.length,
      itemBuilder: (context, index) => _buildWeeklySchedule(widget.scheduleData.weeklySchedules[index]),
    );
  }

  Widget _buildDailyView() {
    return ListView.builder(
      itemCount: widget.scheduleData.dailySchedules.length,
      itemBuilder: (context, index) => _buildDailySchedule(widget.scheduleData.dailySchedules[index]),
    );
  }

  Widget _buildExamView() {
    return ListView.builder(
      itemCount: widget.scheduleData.examSchedules.length,
      itemBuilder: (context, index) => _buildExamSchedule(widget.scheduleData.examSchedules[index]),
    );
  }

  Widget _buildWeeklySchedule(WeeklySchedule weekly) {
    final isElearningOnline = widget.moodleService.isElearningOnline;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF183A5D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(weekly.day, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(color: Colors.white24),
            ...weekly.entries.map((entry) {
              return ListTile(
                title: Text('${entry.courseName} (${entry.courseCode})', style: const TextStyle(color: Colors.white)),
                subtitle: Text('Ruang: ${entry.room} | Sesi: ${entry.session}', style: const TextStyle(color: Colors.white70)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${entry.startTime} - ${entry.endTime}', style: const TextStyle(color: Colors.white70)),
                    if (isElearningOnline && entry.moodleCourseId != null)
                      IconButton(
                        icon: const Icon(Icons.group, color: Colors.orangeAccent),
                        tooltip: 'Lihat Peserta Kelas',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CourseParticipantsPage(
                                moodleService: widget.moodleService,
                                courseId: entry.moodleCourseId!,
                                courseName: entry.courseName,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySchedule(DailySchedule daily) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF183A5D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(daily.day, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(color: Colors.white24),
            ...daily.entries.map((entry) {
              return InkWell(
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: entry.lecturer));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: Colors.green, content: Text('Nama dosen disalin ke clipboard.')),
                  );
                },
                child: ListTile(
                  title: Text(entry.courseName, style: const TextStyle(color: Colors.white)),
                  subtitle: Text('${entry.lecturer}\nTopik: ${entry.topic} | ${entry.implementation}', style: const TextStyle(color: Colors.white70)),
                  trailing: Text('${entry.startTime} - ${entry.endTime}', style: const TextStyle(color: Colors.white70)),
                  isThreeLine: true,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildExamSchedule(ExamSchedule exam) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF183A5D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exam.day, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(color: Colors.white24),
            ...exam.entries.map((entry) => ListTile(
                  title: Text('${entry.courseName} (${entry.courseCode})', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Ruang: ${entry.room} | ${entry.examType}', style: const TextStyle(color: Colors.white70)),
                  trailing: Text('${entry.startTime} - ${entry.endTime}', style: const TextStyle(color: Colors.white70)),
                )),
          ],
        ),
      ),
    );
  }
}
