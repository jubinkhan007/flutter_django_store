import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/vendor_profile.dart';
import '../../domain/repositories/vendor_repository.dart';

class VendorRepositoryImpl implements VendorRepository {
  final ApiClient _apiClient;

  VendorRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<VendorProfile> getPublicVendorProfile(int vendorId) async {
    final response = await _apiClient.get(
      ApiConfig.vendorPublicProfileUrl(vendorId),
      auth: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return VendorProfile.fromJson(data);
    } else {
      throw Exception('Failed to load vendor profile');
    }
  }
}
