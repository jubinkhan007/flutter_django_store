class VendorCustomer {
  final int id;
  final String username;
  final String email;
  final int totalOrders;
  final double totalSpend;

  const VendorCustomer({
    required this.id,
    required this.username,
    required this.email,
    required this.totalOrders,
    required this.totalSpend,
  });
}
