import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Try to get the neighborhood/area name
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          return place.subLocality!;
        }
        
        // If no subLocality, try locality
        if (place.locality != null && place.locality!.isNotEmpty) {
          return place.locality!;
        }
        
        // If no locality, try subAdministrativeArea
        if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          return place.subAdministrativeArea!;
        }
      }
      return 'Location unavailable';
    } catch (e) {
      print('Error getting address: $e');
      return 'Location unavailable';
    }
  }
} 