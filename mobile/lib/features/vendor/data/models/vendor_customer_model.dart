import '../../domain/entities/vendor_customer.dart';

class VendorCustomerModel extends VendorCustomer {
  const VendorCustomerModel({
    required super.id,
    required super.username,
    required super.email,
    required super.totalOrders,
    required super.totalSpend,
  });

  factory VendorCustomerModel.fromJson(Map<String, dynamic> json) {
    return VendorCustomerModel(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      totalOrders: json['total_orders'] ?? 0,
      totalSpend: double.tryParse(json['total_spend'].toString()) ?? 0.0,
    );
  }
}
