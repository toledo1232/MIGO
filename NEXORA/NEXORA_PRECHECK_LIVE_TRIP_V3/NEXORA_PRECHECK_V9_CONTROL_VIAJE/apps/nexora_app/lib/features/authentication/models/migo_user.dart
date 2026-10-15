class MigoUser {
  const MigoUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.accountActive,
    required this.driverApproved,
  });

  final String id;
  final String fullName;
  final String phone;
  final String email;
  final bool accountActive;
  final bool driverApproved;

  factory MigoUser.fromJson(Map<String, dynamic> json) {
    return MigoUser(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      accountActive: json['account_active'] as bool,
      driverApproved: json['driver_approved'] as bool,
    );
  }
}
