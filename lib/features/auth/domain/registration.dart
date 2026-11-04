class Registration {
  const Registration({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.username,
    required this.password,
    required this.confirmPassword,
  });
  final String fullName;
  final String phone;
  final String email;
  final String username;
  final String password;
  final String confirmPassword;

  Map<String, dynamic> toJson() => {
    'fullName': fullName.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'username': username.trim(),
    'password': password,
    'confirmPassword': confirmPassword,
    'role': 'USER',
  };
}
