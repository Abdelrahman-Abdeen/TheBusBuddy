import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../services/parent_service.dart';

class UpdateLocationPage extends StatefulWidget {
  final int studentId;
  final Map<String, dynamic>? currentLocation;

  const UpdateLocationPage({
    Key? key,
    required this.studentId,
    this.currentLocation,
  }) : super(key: key);

  @override
  _UpdateLocationPageState createState() => _UpdateLocationPageState();
}

class _UpdateLocationPageState extends State<UpdateLocationPage> {
  Completer<GoogleMapController> _controller = Completer();
  LatLng _currentPosition = LatLng(31.955162860469148, 35.91534546775252); // Default to Amman
  TextEditingController _locationController = TextEditingController();
  String _currentAddress = "Searching address...";
  bool _isLoading = false;
  final _parentService = ParentService();

  @override
  void initState() {
    super.initState();
    if (widget.currentLocation != null) {
      _currentPosition = LatLng(
        widget.currentLocation!['latitude'] as double,
        widget.currentLocation!['longitude'] as double,
      );
      _getAddressFromLatLng(_currentPosition);
    } else {
      // Default to Amman city center
      _currentPosition = const LatLng(31.9539, 35.9106);
      _getAddressFromLatLng(_currentPosition);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please enable the location on your phone');
      }
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Please allow the app to use the location of your device');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Please allow the app to use the location of your device, by changing the permission rules in the settings -> apps');
      }
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _goToCurrentPosition();
        _getAddressFromLatLng(_currentPosition);
      });
    } catch (e) {
      print('Can\'t get the current location : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark address = placemarks[0];
        String addressStr;
        if (address.thoroughfare == "") {
          addressStr = "N/A, ${address.subLocality}";
        } else {
          addressStr = "${address.thoroughfare}, ${address.subLocality}";
        }
        setState(() {
          _currentAddress = addressStr;
        });
      }
    } catch (e) {
      print("Error getting address: $e");
      setState(() {
        _currentAddress = "Address not found";
      });
    }
  }

  Future<void> _goToCurrentPosition() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: _currentPosition,
        zoom: 16.0,
      ),
    ));
  }

  Future<void> _searchLocation(String location) async {
    try {
      List<Location> locations = await locationFromAddress(location);
      if (locations.isNotEmpty) {
        final target = LatLng(locations.first.latitude, locations.first.longitude);
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLng(target));
        setState(() {
          _currentPosition = target;
          _getAddressFromLatLng(_currentPosition);
        });
      }
    } catch (e) {
      print('$location is not found : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location not found: $e')),
      );
    }
  }

  Future<void> _updateLocation() async {
    try {
      setState(() => _isLoading = true);

      await _parentService.updateStudentDetails(widget.studentId, {
        'home_latitude': _currentPosition.latitude,
        'home_longitude': _currentPosition.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated successfully')),
        );
        Navigator.pop(context, _currentPosition);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenWidth = MediaQuery.sizeOf(context).width;
    final ScreenHeight = MediaQuery.sizeOf(context).height;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCB041),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Update Home Location",
          style: TextStyle(
            color: Colors.black,
            fontSize: MediaQuery.of(context).size.width * 0.045,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 12,
            ),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onCameraMove: (Position) {
              setState(() {
                _currentPosition = Position.target;
                _locationController.clear();
              });
            },
            onCameraIdle: () {
              _getAddressFromLatLng(_currentPosition);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: ScreenHeight * 0.09,
              decoration: BoxDecoration(
                color: const Color(0xFFFCB041),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                    height: ScreenHeight * 0.07,
                    width: ScreenWidth * 0.9,
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            decoration: InputDecoration(
                              hintText: _currentAddress,
                              border: InputBorder.none,
                            ),
                            style: TextStyle(fontSize: 12),
                            onTap: () {
                              setState(() {
                                _currentAddress = "";
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () {
                            if (_locationController.text.isNotEmpty) {
                              _searchLocation(_locationController.text);
                            }
                          },
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              margin: EdgeInsets.only(bottom: 10),
              child: Icon(
                Icons.location_on,
                size: 20.0,
                color: Colors.red,
              ),
            ),
          ),
          Positioned(
            width: MediaQuery.of(context).size.width,
            left: 0,
            height: MediaQuery.of(context).size.height * 0.13,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5FA),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFFCB041),
                    width: ScreenHeight * 0.025,
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _getCurrentLocation,
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.07,
                      width: MediaQuery.of(context).size.width * 0.2,
                      margin: EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: const Color(0xFFFCB041),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.navigation_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isLoading ? null : _updateLocation,
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.07,
                        width: MediaQuery.of(context).size.width * 0.6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFFCB041),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              _isLoading ? 'Updating...' : 'Confirm location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: MediaQuery.of(context).size.width * 0.04,
                                color: Colors.white,
                              ),
                            ),
                            Icon(
                              Icons.room_outlined,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
} 