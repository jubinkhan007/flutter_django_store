import 'dart:convert';
import 'package:http/http.dart' as http;

class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  /// Searches for places matching the query, limited to Bangladesh,
  /// and requests address details to extract city and area.
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    final uri = Uri.parse(
      '$_baseUrl?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5&countrycodes=BD',
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          // Nominatim requires a User-Agent header to identify the application
          'User-Agent': 'EcommerceAppFlutter/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Extracts the best representation of City from a Nominatim result
  String extractCity(Map<String, dynamic> item) {
    if (item['address'] == null) return '';
    final address = item['address'] as Map<String, dynamic>;

    return address['city'] ??
        address['town'] ??
        address['village'] ??
        address['county'] ??
        address['state_district'] ??
        '';
  }

  /// Extracts the best representation of Area/Neighborhood from a Nominatim result
  String extractArea(Map<String, dynamic> item) {
    if (item['address'] == null) return '';
    final address = item['address'] as Map<String, dynamic>;

    return address['suburb'] ??
        address['neighbourhood'] ??
        address['residential'] ??
        address['commercial'] ??
        address['city_district'] ??
        '';
  }
}
