import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// User model representing a user in the application
class User {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create User from JSON (Supabase response)
  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// Convert User to JSON for Supabase
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Create a copy with updated fields
  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Send email verification to user
  Future<void> sendEmailVerification() async {
    await supabase.Supabase.instance.client.auth.resend(
      type: supabase.OtpType.signup,
      email: email,
    );
  }

  /// Refresh user data from Supabase
  Future<User> refreshUser() async {
    final response = await supabase.Supabase.instance.client
        .from('users')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) throw Exception('User not found');
    return User.fromJson(response);
  }
}
