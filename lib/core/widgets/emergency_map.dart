import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Reusable map widget for displaying emergency GPS coordinates and responder markers
/// using OpenStreetMap tiles.
class EmergencyMap extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final double? responderLatitude;
  final double? responderLongitude;
  final double initialZoom;
  final double height;
  final String? title;
  final Color markerColor;
  final IconData markerIcon;
  final bool interactive;

  const EmergencyMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.responderLatitude,
    this.responderLongitude,
    this.initialZoom = 14.0,
    this.height = 200.0,
    this.title,
    this.markerColor = AppColors.primary,
    this.markerIcon = Icons.location_on,
    this.interactive = true,
  });

  bool get _hasValidCoordinates {
    if (latitude == null || longitude == null) return false;
    if (latitude! < -90.0 || latitude! > 90.0) return false;
    if (longitude! < -180.0 || longitude! > 180.0) return false;
    return true;
  }

  bool get _hasValidResponderCoordinates {
    if (responderLatitude == null || responderLongitude == null) return false;
    if (responderLatitude! < -90.0 || responderLatitude! > 90.0) return false;
    if (responderLongitude! < -180.0 || responderLongitude! > 180.0) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidCoordinates) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: AppDimensions.borderRadiusMd,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 40, color: Colors.grey.withValues(alpha: 0.7)),
              const SizedBox(height: AppDimensions.spaceSm),
              const Text(
                'Location Coordinates Unavailable',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final point = LatLng(latitude!, longitude!);

    final primaryMarker = Marker(
      point: point,
      width: 44,
      height: 44,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: markerColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(markerIcon, color: AppColors.white, size: 20),
          ),
        ],
      ),
    );

    final markers = <Marker>[primaryMarker];

    if (_hasValidResponderCoordinates) {
      final responderPoint = LatLng(responderLatitude!, responderLongitude!);
      markers.add(
        Marker(
          point: responderPoint,
          width: 44,
          height: 44,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondaryLight.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.local_shipping, color: AppColors.white, size: 20),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppDimensions.borderRadiusMd,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: initialZoom,
              interactionOptions: InteractionOptions(
                flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pukaar.emergency_app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          if (title != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title!,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_hasValidResponderCoordinates)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.secondaryLight.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping, size: 12, color: AppColors.secondaryLight),
                    SizedBox(width: 4),
                    Text(
                      'Responder Pin Active',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary),
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
