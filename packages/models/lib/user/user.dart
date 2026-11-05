class User {
  final String id;
  final String email;
  final String? username;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    this.username,
    required this.createdAt,
  });
}
