class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String uniqueId;
  final String? upiId;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.uniqueId,
    this.upiId,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    uid: json['uid'] as String,
    displayName: json['display_name'] as String,
    email: (json['email'] as String?) ?? '',
    uniqueId: json['unique_id'] as String,
    upiId: json['upi_id'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'display_name': displayName,
    'email': email,
    'unique_id': uniqueId,
    'upi_id': upiId,
    'created_at': createdAt.toIso8601String(),
  };

  UserModel copyWith({
    String? displayName,
    String? upiId,
  }) => UserModel(
    uid: uid,
    displayName: displayName ?? this.displayName,
    email: email,
    uniqueId: uniqueId,
    upiId: upiId ?? this.upiId,
    createdAt: createdAt,
  );
}
