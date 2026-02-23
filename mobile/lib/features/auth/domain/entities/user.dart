/// Domain entity for a User. Pure Dart — no framework dependencies.
class User {
  final int id;
  final String email;
  final String username;
  final String type; // CUSTOMER, VENDOR, ADMIN

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.type,
  });

  bool get isVendor => type == 'VENDOR';
  bool get isCustomer => type == 'CUSTOMER';
}
