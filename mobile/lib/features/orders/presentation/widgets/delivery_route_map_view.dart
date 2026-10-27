import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/live_tracking_model.dart';

class DeliveryRouteMapView extends StatefulWidget {
  final LiveDeliveryTrackingModel tracking;
  final VoidCallback? onRefresh;

  const DeliveryRouteMapView({
    super.key,
    required this.tracking,
    this.onRefresh,
  });

  @override
  State<DeliveryRouteMapView> createState() => _DeliveryRouteMapViewState();
}

class _DeliveryRouteMapViewState extends State<DeliveryRouteMapView>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _pulseController;

  static const double _canvasWidth = 720.0;
  static const double _canvasHeight = 520.0;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnRider();
    });
  }

  @override
  void didUpdateWidget(covariant DeliveryRouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracking.currentLatitude != widget.tracking.currentLatitude ||
        oldWidget.tracking.currentLongitude !=
            widget.tracking.currentLongitude) {
      _centerOnRider();
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Offset _latLngToCanvas(double lat, double lng, _GeoBounds bounds) {
    final xNorm = (lng - bounds.minLng) / (bounds.maxLng - bounds.minLng);
    final yNorm = (bounds.maxLat - lat) / (bounds.maxLat - bounds.minLat);
    const pad = 70.0;
    final w = _canvasWidth - (pad * 2);
    final h = _canvasHeight - (pad * 2);
    return Offset(pad + (xNorm * w), pad + (yNorm * h));
  }

  _GeoBounds _calculateBounds() {
    final pts = <LatLngPoint>[
      LatLngPoint(
        lat: widget.tracking.originLatitude,
        lng: widget.tracking.originLongitude,
      ),
      LatLngPoint(
        lat: widget.tracking.destinationLatitude,
        lng: widget.tracking.destinationLongitude,
      ),
      LatLngPoint(
        lat: widget.tracking.currentLatitude,
        lng: widget.tracking.currentLongitude,
      ),
      ...widget.tracking.routeWaypoints,
    ];

    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;

    for (final p in pts) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    final dLat = math.max((maxLat - minLat) * 0.25, 0.005);
    final dLng = math.max((maxLng - minLng) * 0.25, 0.005);

    return _GeoBounds(
      minLat: minLat - dLat,
      maxLat: maxLat + dLat,
      minLng: minLng - dLng,
      maxLng: maxLng + dLng,
    );
  }

  void _centerOnRider() {
    if (!mounted) return;
    final bounds = _calculateBounds();
    final riderOffset = _latLngToCanvas(
      widget.tracking.currentLatitude,
      widget.tracking.currentLongitude,
      bounds,
    );

    final viewW = MediaQuery.of(context).size.width;
    const viewH = 340.0;
    const scale = 1.35;

    final targetX = (viewW / 2) - (riderOffset.dx * scale);
    final targetY = (viewH / 2) - (riderOffset.dy * scale);

    // ignore: deprecated_member_use
    final matrix = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(targetX, targetY)
      // ignore: deprecated_member_use
      ..scale(scale);

    _transformController.value = matrix;
  }

  void _zoom(double factor) {
    final current = _transformController.value;
    final viewW = MediaQuery.of(context).size.width;
    const viewH = 340.0;

    // ignore: deprecated_member_use
    final matrix = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(viewW / 2, viewH / 2)
      // ignore: deprecated_member_use
      ..scale(factor)
      // ignore: deprecated_member_use
      ..translate(-viewW / 2, -viewH / 2)
      ..multiply(current);

    _transformController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _calculateBounds();

    return SizedBox(
      height: 340,
      child: Stack(
        children: [
          // ── Interactive Map Canvas ──
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              color: const Color(0xFF181C24),
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.6,
                maxScale: 3.5,
                boundaryMargin: const EdgeInsets.all(300),
                child: SizedBox(
                  width: _canvasWidth,
                  height: _canvasHeight,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _DeliveryMapPainter(
                          tracking: widget.tracking,
                          bounds: bounds,
                          pulseValue: _pulseController.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // ── Top Gradient Overlay ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Speed & Courier Badge ──
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF11141A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.tracking.courierBrand} • ${widget.tracking.speedKmh.toStringAsFixed(0)} km/h',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Compass / Heading Indicator ──
          Positioned(
            top: 12,
            right: 12,
            child: Transform.rotate(
              angle: (widget.tracking.headingDegrees * math.pi / 180),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF11141A).withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.navigation,
                  size: 16,
                  color: Colors.cyanAccent,
                ),
              ),
            ),
          ),

          // ── Floating Zoom & Recenter Controls ──
          Positioned(
            bottom: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapButton(
                  icon: Icons.my_location,
                  tooltip: 'Center on Rider',
                  onTap: _centerOnRider,
                  highlight: true,
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onTap: () => _zoom(1.25),
                ),
                const SizedBox(height: 6),
                _MapButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onTap: () => _zoom(0.8),
                ),
              ],
            ),
          ),

          // ── Bottom Street Status Hint ──
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF11141A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_bike_outlined,
                    size: 14,
                    color: Colors.cyanAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.tracking.isDelivered
                        ? 'Package Delivered'
                        : 'On Route • ${widget.tracking.distanceKm.toStringAsFixed(1)} km to destination',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlight;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? AppColors.lightPrimary : const Color(0xFF1E232B),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: highlight ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _GeoBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const _GeoBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}

class _DeliveryMapPainter extends CustomPainter {
  final LiveDeliveryTrackingModel tracking;
  final _GeoBounds bounds;
  final double pulseValue;

  _DeliveryMapPainter({
    required this.tracking,
    required this.bounds,
    required this.pulseValue,
  });

  Offset _toCanvas(double lat, double lng, Size size) {
    final xNorm = (lng - bounds.minLng) / (bounds.maxLng - bounds.minLng);
    final yNorm = (bounds.maxLat - lat) / (bounds.maxLat - bounds.minLat);
    const pad = 70.0;
    final w = size.width - (pad * 2);
    final h = size.height - (pad * 2);
    return Offset(pad + (xNorm * w), pad + (yNorm * h));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw stylized city grid & arterial roads background
    _paintCityGrid(canvas, size);

    // 2. Draw Route Polyline
    final waypoints = tracking.routeWaypoints.isNotEmpty
        ? tracking.routeWaypoints
        : [
            LatLngPoint(
              lat: tracking.originLatitude,
              lng: tracking.originLongitude,
            ),
            LatLngPoint(
              lat: tracking.currentLatitude,
              lng: tracking.currentLongitude,
            ),
            LatLngPoint(
              lat: tracking.destinationLatitude,
              lng: tracking.destinationLongitude,
            ),
          ];

    final path = Path();
    for (int i = 0; i < waypoints.length; i++) {
      final pt = _toCanvas(waypoints[i].lat, waypoints[i].lng, size);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }

    // Outer Glow / Highway casing
    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.22)
      ..strokeWidth = 9.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // Main route line
    final routePaint = Paint()
      ..color = const Color(0xFF00B0FF)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, routePaint);

    // 3. Draw Origin Hub Pin
    final originPt = _toCanvas(
      tracking.originLatitude,
      tracking.originLongitude,
      size,
    );
    _paintHubMarker(canvas, originPt, tracking.originName);

    // 4. Draw Destination Pin
    final destPt = _toCanvas(
      tracking.destinationLatitude,
      tracking.destinationLongitude,
      size,
    );
    _paintDestinationMarker(canvas, destPt, tracking.destinationName);

    // 5. Draw Animated Courier Rider
    final riderPt = _toCanvas(
      tracking.currentLatitude,
      tracking.currentLongitude,
      size,
    );
    _paintRiderMarker(canvas, riderPt);
  }

  void _paintCityGrid(Canvas canvas, Size size) {
    // Stylized city block rectangles
    final blockPaint = Paint()
      ..color = const Color(0xFF1E242E)
      ..style = PaintingStyle.fill;

    const blockSize = 56.0;
    const gap = 14.0;
    for (double x = 10; x < size.width; x += blockSize + gap) {
      for (double y = 10; y < size.height; y += blockSize + gap) {
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, blockSize, blockSize),
          const Radius.circular(6),
        );
        canvas.drawRRect(r, blockPaint);
      }
    }

    // Secondary streets
    final streetPaint = Paint()
      ..color = const Color(0xFF26303E)
      ..strokeWidth = 2.0;

    for (double y = 40; y < size.height; y += 70) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), streetPaint);
    }
    for (double x = 50; x < size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), streetPaint);
    }
  }

  void _paintHubMarker(Canvas canvas, Offset pt, String label) {
    // Halo
    canvas.drawCircle(
      pt,
      14,
      Paint()..color = Colors.amber.withValues(alpha: 0.22),
    );

    // Pin circle
    canvas.drawCircle(
      pt,
      9,
      Paint()..color = const Color(0xFFFFA000),
    );
    canvas.drawCircle(
      pt,
      4,
      Paint()..color = Colors.white,
    );

    // Label
    _drawText(canvas, 'Hub', pt + const Offset(0, 13), Colors.amberAccent);
  }

  void _paintDestinationMarker(Canvas canvas, Offset pt, String label) {
    // Halo
    canvas.drawCircle(
      pt,
      16,
      Paint()..color = Colors.redAccent.withValues(alpha: 0.2),
    );

    // Outer circle
    canvas.drawCircle(
      pt,
      10,
      Paint()..color = const Color(0xFFFF5252),
    );
    // Inner white dot
    canvas.drawCircle(
      pt,
      4,
      Paint()..color = Colors.white,
    );

    _drawText(canvas, 'Dropoff', pt + const Offset(0, 14), Colors.redAccent);
  }

  void _paintRiderMarker(Canvas canvas, Offset pt) {
    // Expanding Radar Pulse
    final pulseRadius = 14.0 + (pulseValue * 22.0);
    final pulseAlpha = (1.0 - pulseValue) * 0.45;
    canvas.drawCircle(
      pt,
      pulseRadius,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Inner Glow
    canvas.drawCircle(
      pt,
      16,
      Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.3),
    );

    // Elevated Rider Disc
    canvas.drawCircle(
      pt,
      12,
      Paint()..color = const Color(0xFF00E5FF),
    );
    canvas.drawCircle(
      pt,
      8,
      Paint()..color = const Color(0xFF001E3C),
    );

    // Rider direction needle
    final rad = (tracking.headingDegrees - 90) * math.pi / 180;
    final needleEnd = pt + Offset(math.cos(rad) * 11, math.sin(rad) * 11);
    canvas.drawLine(
      pt,
      needleEnd,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Label: Rider Name
    _drawText(
      canvas,
      tracking.riderName,
      pt + const Offset(0, -18),
      Colors.cyanAccent,
      isBold: true,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    bool isBold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, offset - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant _DeliveryMapPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.tracking.currentLatitude != tracking.currentLatitude ||
        oldDelegate.tracking.currentLongitude != tracking.currentLongitude;
  }
}
