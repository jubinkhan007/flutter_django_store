import '../../domain/entities/user.dart';

/// Data model that knows how to parse JSON from the API.
/// Extends the domain entity — Liskov Substitution: can be used anywhere User is expected.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.username,
    required super.type,
    super.walletBalance,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      type: json['type'] ?? 'CUSTOMER',
      walletBalance:
          double.tryParse(json['wallet_balance']?.toString() ?? '') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'type': type,
      'wallet_balance': walletBalance,
    };
  }
}
