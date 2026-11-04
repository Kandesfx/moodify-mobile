class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
    required this.role,
    required this.status,
    this.phone,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    bool authResponse = false,
  }) {
    final id = json[authResponse ? 'userId' : 'id'];
    if (id == null || id.toString().isEmpty) {
      throw const FormatException('Missing user id');
    }
    return UserProfile(
      id: id.toString(),
      fullName: _string(json, 'fullName'),
      email: _string(json, 'email'),
      username: _string(json, 'username'),
      role: _string(json, 'role'),
      status: _string(json, 'status'),
      phone: _optionalString(json, 'phone'),
      avatarUrl: _optionalString(json, 'avatarUrl'),
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String username;
  final String role;
  final String status;
  final String? phone;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'username': username,
    'role': role,
    'status': status,
    'phone': phone,
    'avatarUrl': avatarUrl,
  };
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.user,
  });

  factory AuthSession.fromAuthResponse(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final accessSeconds = json['expiresIn'];
    final refreshSeconds = json['refreshExpiresIn'];
    if (accessSeconds is! num ||
        refreshSeconds is! num ||
        accessSeconds <= 0 ||
        refreshSeconds <= 0) {
      throw const FormatException('Invalid token expiry');
    }
    final user = UserProfile.fromJson(json, authResponse: true);
    if (user.status != 'ACTIVE') {
      throw const FormatException('Inactive account');
    }
    return AuthSession(
      accessToken: _string(json, 'accessToken'),
      refreshToken: _string(json, 'refreshToken'),
      accessExpiresAt: now.toUtc().add(
        Duration(seconds: accessSeconds.toInt()),
      ),
      refreshExpiresAt: now.toUtc().add(
        Duration(seconds: refreshSeconds.toInt()),
      ),
      user: user,
    );
  }

  factory AuthSession.fromStored(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported session version');
    }
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Invalid stored user');
    }
    return AuthSession(
      accessToken: _string(json, 'accessToken'),
      refreshToken: _string(json, 'refreshToken'),
      accessExpiresAt: DateTime.parse(_string(json, 'accessExpiresAt')).toUtc(),
      refreshExpiresAt: DateTime.parse(
        _string(json, 'refreshExpiresAt'),
      ).toUtc(),
      user: UserProfile.fromJson(user),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
  final UserProfile user;

  AuthSession withUser(UserProfile value) => AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessExpiresAt: accessExpiresAt,
    refreshExpiresAt: refreshExpiresAt,
    user: value,
  );

  Map<String, dynamic> toStored() => {
    'version': 1,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessExpiresAt': accessExpiresAt.toIso8601String(),
    'refreshExpiresAt': refreshExpiresAt.toIso8601String(),
    'user': user.toJson(),
  };

  // Deliberately no token-bearing toString implementation.
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $key');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) {
    throw FormatException('Invalid $key');
  }
  return value as String?;
}
