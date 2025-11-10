class MoodleUser {
  final int id;
  final String fullname;
  final String profileImageUrl;
  final List<String> roles;

  MoodleUser({
    required this.id,
    required this.fullname,
    required this.profileImageUrl,
    required this.roles,
  });

  factory MoodleUser.fromJson(Map<String, dynamic> json) {
    List<String> roleShortnames = [];
    if (json['roles'] is List) {
      roleShortnames = (json['roles'] as List)
          .map((role) => role['shortname'] as String? ?? '')
          .toList();
    }

    return MoodleUser(
      id: json['id'] ?? 0,
      fullname: json['fullname'] ?? 'Nama Tidak Diketahui',
      profileImageUrl: json['profileimageurl'] ?? '',
      roles: roleShortnames,
    );
  }
}
