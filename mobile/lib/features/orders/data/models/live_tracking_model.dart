class LatLngPoint {
  final double lat;
  final double lng;

  const LatLngPoint({required this.lat, required this.lng});

  factory LatLngPoint.fromJson(Map<String, dynamic> json) {
    return LatLngPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class LiveDeliveryTrackingModel {
  final int id;
  final int subOrderId;
  final String riderName;
  final String riderPhone;
  final String riderPhoto;
  final double riderRating;
  final String vehicleType;
  final String vehicleNumber;
  final String courierBrand;
  final String status;
  final String statusDisplay;

  final double originLatitude;
  final double originLongitude;
  final String originName;

  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationName;

  final double currentLatitude;
  final double currentLongitude;
  final double headingDegrees;
  final double speedKmh;
  final int etaMinutes;
  final double distanceKm;

  final List<LatLngPoint> routeWaypoints;
  final int currentWaypointIndex;
  final String lastLocationUpdate;

  const LiveDeliveryTrackingModel({
    required this.id,
    required this.subOrderId,
    required this.riderName,
    required this.riderPhone,
    required this.riderPhoto,
    required this.riderRating,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.courierBrand,
    required this.status,
    required this.statusDisplay,
    required this.originLatitude,
    required this.originLongitude,
    required this.originName,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationName,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.headingDegrees,
    required this.speedKmh,
    required this.etaMinutes,
    required this.distanceKm,
    required this.routeWaypoints,
    required this.currentWaypointIndex,
    required this.lastLocationUpdate,
  });

  bool get isDelivered => status == 'DELIVERED';
  bool get isOutForDelivery =>
      status == 'OUT_FOR_DELIVERY' || status == 'ARRIVING_SOON';

  factory LiveDeliveryTrackingModel.fromJson(Map<String, dynamic> json) {
    final rawWaypoints = json['route_waypoints'] as List? ?? [];
    final waypoints = rawWaypoints
        .map((e) => LatLngPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return LiveDeliveryTrackingModel(
      id: json['id'] ?? 0,
      subOrderId: json['sub_order_id'] ?? 0,
      riderName: json['rider_name'] ?? 'Rider',
      riderPhone: json['rider_phone'] ?? '',
      riderPhoto: json['rider_photo'] ?? '',
      riderRating: (json['rider_rating'] as num?)?.toDouble() ?? 4.9,
      vehicleType: json['vehicle_type'] ?? 'Motorcycle',
      vehicleNumber: json['vehicle_number'] ?? '',
      courierBrand: json['courier_brand'] ?? 'Courier',
      status: json['status'] ?? 'OUT_FOR_DELIVERY',
      statusDisplay: json['status_display'] ?? 'Out for Delivery',
      originLatitude: (json['origin_latitude'] as num?)?.toDouble() ?? 23.7925,
      originLongitude: (json['origin_longitude'] as num?)?.toDouble() ?? 90.4078,
      originName: json['origin_name'] ?? 'Vendor Hub',
      destinationLatitude:
          (json['destination_latitude'] as num?)?.toDouble() ?? 23.8103,
      destinationLongitude:
          (json['destination_longitude'] as num?)?.toDouble() ?? 90.4125,
      destinationName: json['destination_name'] ?? 'Delivery Address',
      currentLatitude:
          (json['current_latitude'] as num?)?.toDouble() ?? 23.7980,
      currentLongitude:
          (json['current_longitude'] as num?)?.toDouble() ?? 90.4095,
      headingDegrees: (json['heading_degrees'] as num?)?.toDouble() ?? 45.0,
      speedKmh: (json['speed_kmh'] as num?)?.toDouble() ?? 24.0,
      etaMinutes: json['eta_minutes'] ?? 14,
      distanceKm: double.tryParse(json['distance_km']?.toString() ?? '2.1') ?? 2.1,
      routeWaypoints: waypoints,
      currentWaypointIndex: json['current_waypoint_index'] ?? 0,
      lastLocationUpdate: json['last_location_update'] ?? '',
    );
  }
}
