import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ViewLocationPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String eventType;
  final String date;
  final String location;

  const ViewLocationPage({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.eventType,
    required this.date,
    required this.location,
  }) : super(key: key);

  @override
  _ViewLocationPageState createState() => _ViewLocationPageState();
}

class _ViewLocationPageState extends State<ViewLocationPage> {
  Completer<GoogleMapController> _controller = Completer();
  late LatLng _location;
  String _address = "Loading address...";

  @override
  void initState() {
    super.initState();
    _location = LatLng(widget.latitude, widget.longitude);
    _fetchAddressFromCoordinates();
  }

  Future<void> _fetchAddressFromCoordinates() async {
    final apiKey =
        "AIzaSyDD28-o7vbOR7YPpC-5w8E5IwvTlE_7ubU"; // Replace with your API key
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${widget.latitude},${widget.longitude}&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          setState(() {
            _address = data['results'][0]['formatted_address'];
          });
        } else {
          setState(() {
            _address = "Address not found";
          });
        }
      } else {
        setState(() {
          _address = "Failed to fetch address";
        });
      }
    } catch (e) {
      setState(() {
        _address = "Error fetching address";
      });
    }
  }

  Future<void> _goToLocation() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: _location,
        zoom: 16.0,
      ),
    ));
  }

  Future<void> _openInGoogleMaps() async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCB041),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "View Location",
          style: TextStyle(
            color: Colors.black,
            fontSize: MediaQuery.of(context).size.width * 0.045,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _location,
              zoom: 16.0,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('locationMarker'),
                position: _location,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                draggable: false, // Ensure the marker is not draggable
              ),
            },
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: false, // Disable user location
            myLocationButtonEnabled: false, // Disable location button
          ),
          // Floating Action Button for Re-centering
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFFFCB041),
              onPressed: _goToLocation,
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),
          // Notification Info Section
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Type
                  Row(
                    children: [
                      Icon(Icons.event,
                          size: 20, color: const Color(0xFFFCB041)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.eventType,
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.045,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Date
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 20, color: Colors.black54),
                      const SizedBox(width: 8),
                      Text(
                        widget.date,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Location (Address)
                  GestureDetector(
                    onTap: _openInGoogleMaps,
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 20, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _address,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
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
