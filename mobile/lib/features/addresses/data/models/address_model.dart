class AddressModel {
  final int id;
  final String label;
  final String phoneNumber;
  final String addressLine;
  final String area;
  final String city;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.label,
    required this.phoneNumber,
    required this.addressLine,
    required this.area,
    required this.city,
    required this.isDefault,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'],
      label: json['label'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      addressLine: json['address_line'] ?? '',
      area: json['area'] ?? '',
      city: json['city'] ?? '',
      isDefault: json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'phone_number': phoneNumber,
      'address_line': addressLine,
      'area': area,
      'city': city,
      'is_default': isDefault,
    };
  }

  // CopyWith method for easy updating
  AddressModel copyWith({
    int? id,
    String? label,
    String? phoneNumber,
    String? addressLine,
    String? area,
    String? city,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      addressLine: addressLine ?? this.addressLine,
      area: area ?? this.area,
      city: city ?? this.city,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
