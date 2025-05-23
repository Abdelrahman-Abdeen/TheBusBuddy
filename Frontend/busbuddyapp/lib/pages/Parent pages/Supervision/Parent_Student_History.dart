import 'package:flutter/material.dart';
import 'Parent_View_Student_Event.dart';
import '../../../services/parent_service.dart';
import '../../../models/student.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ViewLocationPage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class StudentHistory extends StatefulWidget {
  const StudentHistory({Key? key}) : super(key: key);

  @override
  State<StudentHistory> createState() => _StudentHistoryState();
}

class _StudentHistoryState extends State<StudentHistory> {
  final ParentService _parentService = ParentService();
  Student? _student;
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _error;
  bool _hasLoaded = false;
  String? _busDriverName;

  // Function to convert coordinates to address
  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (apiKey == null) {
        return 'Location not available';
      }

      final response = await http.get(
        Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            data['results'].isNotEmpty) {
          
          // Try to find the most specific location first
          for (var result in data['results']) {
            final components = result['address_components'] as List;
            String? street;
            String? neighborhood;
            String? sublocality;
            String? locality;
            String? administrativeArea;

            for (var component in components) {
              final types = List<String>.from(component['types']);
              if (types.contains('route')) {
                street = component['long_name'];
              }
              if (types.contains('neighborhood')) {
                neighborhood = component['long_name'];
              }
              if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
                sublocality = component['long_name'];
              }
              if (types.contains('locality')) {
                locality = component['long_name'];
              }
              if (types.contains('administrative_area_level_1')) {
                administrativeArea = component['long_name'];
              }
            }

            // Build the address string with available components
            final addressParts = <String>[];
            
            // Add street if available
            if (street != null && street.isNotEmpty) {
              addressParts.add(street);
            }
            
            // Add the most specific area available
            if (neighborhood != null && neighborhood.isNotEmpty) {
              addressParts.add(neighborhood);
            } else if (sublocality != null && sublocality.isNotEmpty) {
              addressParts.add(sublocality);
            } else if (locality != null && locality.isNotEmpty) {
              addressParts.add(locality);
            } else if (administrativeArea != null && administrativeArea.isNotEmpty) {
              addressParts.add(administrativeArea);
            }

            if (addressParts.isNotEmpty) {
              return addressParts.join(', ');
            }
          }
          
          // If no specific location found, try to get a formatted address
          final formattedAddress = data['results'][0]['formatted_address'];
          if (formattedAddress != null && formattedAddress.isNotEmpty) {
            final addressParts = formattedAddress.split(',');
            if (addressParts.isNotEmpty) {
              return addressParts[0].trim();
            }
          }
          
          return 'Amman';
        }
      }
      return 'Location not available';
    } catch (e) {
      print('Error getting address: $e');
      return 'Location not available';
    }
  }

  // Function to split datetime into date and time
  Map<String, String> _splitDateTime(String? datetime) {
    if (datetime == null) {
      return {'date': 'Unknown Date', 'time': 'Unknown Time'};
    }

    try {
      final dateTime = DateTime.parse(datetime);
      final date =
          '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
      final time =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      return {'date': date, 'time': time};
    } catch (e) {
      print('Error parsing datetime: $e');
      return {'date': 'Unknown Date', 'time': 'Unknown Time'};
    }
  }

  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    try {
      final apiKey =
          dotenv.env['GOOGLE_MAPS_API_KEY']; // Ensure your API key is set
      if (apiKey == null) {
        print('Google Maps API key is missing');
        return null;
      }

      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final latitude = location['lat'];
          final longitude = location['lng'];
          return LatLng(latitude, longitude);
        }
      }
      print('Failed to fetch coordinates for address: $address');
      return null;
    } catch (e) {
      print('Error fetching coordinates: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      _loadData();
      _hasLoaded = true;
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get student ID from route arguments
      final Map<String, dynamic>? args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args == null || !args.containsKey('studentId')) {
        throw 'Student ID not provided';
      }
      final int studentId = args['studentId'];

      // Fetch student details and events
      final studentData = await _parentService.getStudentDetails(studentId);
      final eventsData = await _parentService.getStudentEvents(studentId);

      // Fetch bus details if bus ID is available
      if (studentData['bus_id'] != null) {
        final busData =
            await _parentService.getBusDetails(studentData['bus_id']);
        setState(() {
          _busDriverName = busData['driver_name'] ?? 'Unknown Driver';
        });
      }

      // Process events data
      final processedEvents = await Future.wait(eventsData.map((event) async {
        // Parse the datetime from the 'time' field
        final datetime = _splitDateTime(event['time']?.toString());

        // Handle location if coordinates are available
        String location = 'Location not available';
        if (event['location'] != null) {
          try {
            // Check if location is a Map with latitude and longitude
            if (event['location'] is Map) {
              final locationData = event['location'] as Map<String, dynamic>;
              if (locationData['latitude'] != null && locationData['longitude'] != null) {
                final latitude = double.parse(locationData['latitude'].toString());
                final longitude = double.parse(locationData['longitude'].toString());
                location = await _getAddressFromCoordinates(latitude, longitude);
              }
            } 
            // Check if location is a string with coordinates
            else {
              final locationStr = event['location'].toString();
              final coordinateMatch = RegExp(r'Location \(([-\d.]+), ([-\d.]+)\)').firstMatch(locationStr);
              
              if (coordinateMatch != null) {
                final latitude = double.parse(coordinateMatch.group(1)!);
                final longitude = double.parse(coordinateMatch.group(2)!);
                location = await _getAddressFromCoordinates(latitude, longitude);
              } else {
                location = locationStr;
              }
            }
          } catch (e) {
            print('Error processing location: $e');
            location = event['location'].toString();
          }
        }

        return {
          ...event,
          'date': datetime['date'],
          'time': datetime['time'],
          'location': location,
          'sort_time': event['time'] != null
              ? DateTime.parse(event['time'])
              : DateTime(0),
        };
      }));

      // Sort events by time in descending order (newest first)
      processedEvents.sort((a, b) =>
          (b['sort_time'] as DateTime).compareTo(a['sort_time'] as DateTime));

      setState(() {
        _student = Student.fromJson(studentData);
        _events = processedEvents;
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _loadData: $e'); // Add debug print
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadData,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // Profile header container
              Container(
                height: screenHeight * 0.23,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCB041),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 35.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CircleAvatar(
                        radius: screenWidth * 0.11,
                        backgroundColor: const Color(0xFFFCB041),
                        child: Icon(
                          Icons.person,
                          size: screenWidth * 0.25,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        width: screenWidth * 0.66,
                        height: screenHeight * 0.15,
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 20),
                        decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.black),
                          color: const Color(0xFFF5F5FA),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.person_4_outlined),
                                  SizedBox(width: screenWidth * 0.02),
                                  Expanded(
                                    child: Text(
                                      _student?.name ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.033,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                children: [
                                  Icon(Icons.directions_bus,
                                      color: Colors.black,
                                      size: screenWidth * 0.06),
                                  SizedBox(width: screenWidth * 0.03),
                                  Text(
                                    "${_student?.busNumber ?? '-'} ${_busDriverName != null ? '(${_busDriverName})' : ''}",
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.03,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.circle,
                                    color: _student?.isOnBus ?? false
                                        ? Colors.green
                                        : Colors.red,
                                    size: 16),
                                SizedBox(width: screenWidth * 0.02),
                                Text(
                                  _student?.isOnBus ?? false
                                      ? "In-Bus"
                                      : "Off-Bus",
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.03,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Back button
              Positioned(
                top: 40,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 10, bottom: 5),
            child: Text(
              "Events",
              style: TextStyle(
                  fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                return _buildEventCard(
                    context, _events[index], screenWidth, screenHeight);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event,
      double screenWidth, double screenHeight) {
    // Format event type to include "Student" prefix
    String formatEventType(String? type) {
      if (type == null) return 'Unknown Event';
      switch (type) {
        case 'exit':
          return 'Student Exit';
        case 'enter':
          return 'Student Enter';
        case 'unusual_exit':
          return 'Student Unusual Exit';
        case 'unusual_enter':
          return 'Student Unusual Enter';
        default:
          final words = type.replaceAll('_', ' ').split(' ');
          final capitalizedWords = words
              .map((word) => word.isNotEmpty
                  ? '${word[0].toUpperCase()}${word.substring(1)}'
                  : '')
              .join(' ');
          return 'Student $capitalizedWords';
      }
    }

    return Container(
      height: screenHeight * 0.2,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Type
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  formatEventType(event['event_type']?.toString()),
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0A061F),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Divider(
              color: Colors.black12,
              thickness: 1,
              height: 2,
            ),
            SizedBox(height: screenHeight * 0.01),
            // Date and Time Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoRow(Icons.calendar_month,
                    event['date'] ?? 'Unknown Date', screenWidth),
                _buildInfoRow(
                    Icons.watch, event['time'] ?? 'Unknown Time', screenWidth),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),
            // Location and View Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildInfoRow(
                    Icons.location_on_sharp,
                    event['location'] ?? 'Unknown Location',
                    screenWidth,
                    truncate: true,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    if (event['location'] != null) {
                      final location =
                          event['location'].toString(); // Get the location
                      print('Location data: $location'); // Debug print

                      // Check if the location is in the format "Location (latitude, longitude)"
                      final coordinateMatch =
                          RegExp(r'Location \(([-\d.]+), ([-\d.]+)\)')
                              .firstMatch(location);
                      if (coordinateMatch != null) {
                        // Extract latitude and longitude from the match
                        final latitude =
                            double.tryParse(coordinateMatch.group(1)!);
                        final longitude =
                            double.tryParse(coordinateMatch.group(2)!);

                        if (latitude != null && longitude != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewLocationPage(
                                  latitude: latitude,
                                  longitude: longitude,
                                  eventType: event['event_type'] ?? 'Unknown Event',
                                  date: event['date'] ?? 'Unknown Date',
                                  location: event['location'] ?? 'Unknown Location',
                                ),
                            ),
                          );
                          return;
                        }
                      }

                      // If not coordinates, treat it as an address and fetch coordinates
                      final coordinates =
                          await _getCoordinatesFromAddress(location);
                      if (coordinates != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewLocationPage(
                              latitude: coordinates.latitude,
                              longitude: coordinates.longitude,
                              eventType: event['event_type'] ?? 'Unknown Event',
                              date: event['date'] ?? 'Unknown Date',
                              location: event['location'] ?? 'Unknown Location',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Unable to fetch location coordinates')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Location data is not available')),
                      );
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCB041),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'View',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.035,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, double screenWidth,
      {bool truncate = false}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0A061F), size: 20),
        SizedBox(width: screenWidth * 0.02),
        truncate
            ? Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.032,
                    color: const Color(0xFF0A061F),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0A061F),
                  fontSize: screenWidth * 0.032,
                ),
              ),
      ],
    );
  }
}