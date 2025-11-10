import 'dart:math';
import 'package:esago/models/moodle_user_model.dart';
import 'package:esago/services/moodle_service.dart';
import 'package:flutter/material.dart';

class CourseParticipantsPage extends StatefulWidget {
  final MoodleService moodleService;
  final int courseId;
  final String courseName;

  const CourseParticipantsPage({
    super.key,
    required this.moodleService,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<CourseParticipantsPage> createState() => _CourseParticipantsPageState();
}

class _CourseParticipantsPageState extends State<CourseParticipantsPage> {
  List<MoodleUser> _allUsers = [];
  List<MoodleUser> _filteredUsers = [];
  final Set<int> _selectedUserIds = {};
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
    _searchController.addListener(_filterUsers);
  }

  Future<void> _fetchParticipants() async {
    try {
      final users = await widget.moodleService.getEnrolledUsers(widget.courseId);
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        return user.fullname.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _onUserSelected(int userId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedUserIds.add(userId);
      } else {
        _selectedUserIds.remove(userId);
      }
    });
  }

  void _toggleSelectAll() {
    if (_filteredUsers.isEmpty) return;

    final allFilteredIds = _filteredUsers.map((u) => u.id).toSet();
    final areAllSelected = _selectedUserIds.containsAll(allFilteredIds);

    setState(() {
      if (areAllSelected) {
        _selectedUserIds.removeAll(allFilteredIds);
      } else {
        _selectedUserIds.addAll(allFilteredIds);
      }
    });
  }

  void _pickRandomUser() {
    List<MoodleUser> sourceList;
    if (_selectedUserIds.isNotEmpty) {
      sourceList = _allUsers.where((u) => _selectedUserIds.contains(u.id)).toList();
    } else {
      sourceList = _filteredUsers; // Pick from currently visible users
    }

    if (sourceList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada mahasiswa untuk dipilih.')),
      );
      return;
    }

    final random = Random();
    final pickedUser = sourceList[random.nextInt(sourceList.length)];

    _showResultDialog(content: _buildSingleUserResult(pickedUser));
  }

  void _showGroupCreationDialog() {
    final groupSizeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF183A5D),
          title: const Text('Buat Kelompok', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: groupSizeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Jumlah anggota per kelompok'),
          ),
          actions: [
            TextButton(
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Buat', style: TextStyle(color: Colors.orangeAccent)),
              onPressed: () {
                 final size = int.tryParse(groupSizeController.text) ?? 0;
                 if (size > 1 && size <= _selectedUserIds.length) {
                    Navigator.of(context).pop();
                    _generateGroups(size);
                 } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah tidak valid.')));
                 }
              },
            ),
          ],
        );
      },
    );
  }

  void _generateGroups(int groupSize) {
    final selectedUsers = _allUsers.where((u) => _selectedUserIds.contains(u.id)).toList();
    selectedUsers.shuffle();

    List<List<MoodleUser>> groups = [];
    for (var i = 0; i < selectedUsers.length; i += groupSize) {
      groups.add(selectedUsers.sublist(i, min(i + groupSize, selectedUsers.length)));
    }

    _showResultDialog(
      content: _buildGroupResult(groups),
      onRebuild: () => _generateGroups(groupSize), // Add rebuild capability
    );
  }

  void _showResultDialog({required Widget content, VoidCallback? onRebuild}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF183A5D),
        title: Text(onRebuild != null ? 'Hasil Kelompok' : 'Mahasiswa Terpilih', style: const TextStyle(color: Colors.white)),
        content: content,
        actions: [
          if (onRebuild != null) ...[
            TextButton(
              onPressed: () {
                 Navigator.of(context).pop();
                 onRebuild();
              },
              child: const Text('Buat Ulang', style: TextStyle(color: Colors.orangeAccent)),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleUserResult(MoodleUser user) {
     return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 40, backgroundImage: NetworkImage(user.profileImageUrl)),
            const SizedBox(height: 16),
            Text(user.fullname, style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
          ],
        );
  }

  Widget _buildGroupResult(List<List<MoodleUser>> groups) {
    return SizedBox(
      width: double.maxFinite,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: groups.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kelompok ${index + 1}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24),
                ...groups[index].map((user) => Text(user.fullname, style: const TextStyle(color: Colors.white70))),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool areAllFilteredSelected = 
        _filteredUsers.isNotEmpty && _selectedUserIds.containsAll(_filteredUsers.map((u) => u.id));

    return Scaffold(
      backgroundColor: const Color(0xFF0A1931),
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: const Color(0xFF0A1931),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(areAllFilteredSelected ? Icons.deselect : Icons.select_all),
            tooltip: areAllFilteredSelected ? 'Batalkan Semua' : 'Pilih Semua',
            onPressed: _toggleSelectAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari... (${_selectedUserIds.length} dipilih)',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF183A5D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedUserIds.length > 1)
            SizedBox(
              height: 40,
              width: 40,
              child: FloatingActionButton(
                onPressed: _showGroupCreationDialog,
                backgroundColor: Colors.blueAccent,
                tooltip: 'Buat Kelompok',
                heroTag: 'group_fab',
                child: const Icon(Icons.group_add, size: 20),
              ),
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _pickRandomUser,
            backgroundColor: Colors.orange,
            tooltip: 'Pilih 1 Mahasiswa Acak',
            heroTag: 'single_fab',
            child: const Icon(Icons.casino, color: Colors.white),
          ),
        ],
      )
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(child: Text('Gagal memuat: $_error', style: const TextStyle(color: Colors.redAccent)));
    }
    if (_filteredUsers.isEmpty) {
      return const Center(child: Text('Tidak ada mahasiswa yang cocok.', style: TextStyle(color: Colors.white70)));
    }

    return ListView.builder(
      itemCount: _filteredUsers.length,
      padding: const EdgeInsets.only(bottom: 150), // Increased space for FABs
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final isSelected = _selectedUserIds.contains(user.id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          color: isSelected ? const Color(0xFF0D47A1) : const Color(0xFF183A5D),
          elevation: isSelected ? 4 : 1,
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (bool? value) => _onUserSelected(user.id, value ?? false),
            secondary: CircleAvatar(
              backgroundImage: NetworkImage(user.profileImageUrl),
              child: user.profileImageUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
            title: Text(user.fullname, style: const TextStyle(color: Colors.white)),
            activeColor: Colors.orange,
            checkColor: Colors.white,
          ),
        );
      },
    );
  }
}
