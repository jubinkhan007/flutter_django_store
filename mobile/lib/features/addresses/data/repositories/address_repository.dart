import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/address_model.dart';
import 'dart:convert';

class AddressRepository {
  final ApiClient _apiClient;

  AddressRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<AddressModel>> getAddresses() async {
    final response = await _apiClient.get(ApiConfig.addressesUrl);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => AddressModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load addresses');
    }
  }

  Future<AddressModel> createAddress(AddressModel address) async {
    final response = await _apiClient.post(
      ApiConfig.addressesUrl,
      body: address.toJson(),
    );
    if (response.statusCode == 201) {
      return AddressModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create address: ${response.body}');
    }
  }

  Future<AddressModel> updateAddress(AddressModel address) async {
    final response = await _apiClient.put(
      '${ApiConfig.addressesUrl}${address.id}/',
      body: address.toJson(),
    );
    if (response.statusCode == 200) {
      return AddressModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update address: ${response.body}');
    }
  }

  Future<void> deleteAddress(int id) async {
    final response = await _apiClient.delete('${ApiConfig.addressesUrl}$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete address');
    }
  }
}
