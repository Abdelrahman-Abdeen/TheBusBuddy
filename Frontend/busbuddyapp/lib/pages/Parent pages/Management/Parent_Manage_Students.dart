import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../../services/parent_service.dart';
import 'UpdateLocationPage.dart';

class ManageStudentsPage extends StatefulWidget {
  const ManageStudentsPage({Key? key}) : super(key: key);

  @override
  _ManageStudentsPageState createState() => _ManageStudentsPageState();
}

class _ManageStudentsPageState extends State<ManageStudentsPage> {
  final _parentService = ParentService();
  List<Map<String, dynamic>> _students = [];
  String _centralizedPhone = "";
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (apiKey == null) {
        return 'Location ($lat, $lng)';
      }

      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          final components = data['results'][0]['address_components'];
          String? neighborhood;
          String? sublocality;
          String? administrativeArea;
          String? street;

          for (var comp in components) {
            final types = List<String>.from(comp['types']);
            if (types.contains('neighborhood')) {
              neighborhood = comp['long_name'];
            }
            if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
              sublocality = comp['long_name'];
            }
            if (types.contains('administrative_area_level_1')) {
              administrativeArea = comp['long_name'];
            }
            if (types.contains('route')) {
              street = comp['long_name'];
            }
          }

          // Build address string with available components
          final addressParts = <String>[];
          if (neighborhood != null) addressParts.add(neighborhood);
          if (sublocality != null) addressParts.add(sublocality);
          if (administrativeArea != null) addressParts.add(administrativeArea);
          if (street != null) addressParts.add(street);

          if (addressParts.isNotEmpty) {
            return addressParts.join(' - ');
          } else {
            return data['results'][0]['formatted_address'];
          }
        }
      }
      return 'Location ($lat, $lng)';
    } catch (e) {
      print('Error getting address: $e');
      return 'Location ($lat, $lng)';
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final students = await _parentService.getStudents();
      if (students.isNotEmpty) {
        // Convert coordinates to addresses for each student
        for (var student in students) {
          if (student['home_location'] != null) {
            final homeLocation = student['home_location'] as Map<String, dynamic>;
            final lat = homeLocation['latitude'] as double;
            final lng = homeLocation['longitude'] as double;
            
            final address = await _getAddressFromCoordinates(lat, lng);
            student['address'] = address;
          } else {
            student['address'] = 'No location set';
          }
        }

        setState(() {
          _students = students;
          _centralizedPhone = students[0]['phone_number'] ?? "";
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCentralizedPhone(String newPhone) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Update each student's phone number
      for (var student in _students) {
        await _parentService.updateStudentDetails(student['id'], {
          'phone_number': newPhone,
        });
      }

      setState(() {
        _centralizedPhone = newPhone;
        for (var student in _students) {
          student['phone_number'] = newPhone;
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update phone number: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAlternatePhone(int studentId, String newAlternatePhone) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _parentService.updateStudentDetails(studentId, {
        'alternate_phone': newAlternatePhone,
      });

      setState(() {
        final student = _students.firstWhere((s) => s['id'] == studentId);
        student['alternate_phone'] = newAlternatePhone;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update alternate phone: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePhoneNumber(int studentId, String newPhone) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _parentService.updateStudentDetails(studentId, {
        'phone_number': newPhone,
      });

      // Update the local state
      setState(() {
        final studentIndex = _students.indexWhere((s) => s['id'] == studentId);
        if (studentIndex != -1) {
          _students[studentIndex]['phone_number'] = newPhone;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone number updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update phone number: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCB041),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Manage Students",
              style: TextStyle(
                color: Colors.black,
                fontSize: MediaQuery.of(context).size.width * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
            Image.asset('assets/school_logo.png', height: 40),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                )
              : _students.isEmpty
                  ? Center(child: Text('No students found'))
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListView.builder(
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          return StudentCard(
                            name: '${student['first_name']} ${student['last_name']}',
                            phone: student['phone_number'] ?? "",
                            address: student['address'] ?? "No location set",
                            homeLocation: student['home_location'] ?? {},
                            onUpdatePhone: (newPhone) {
                              _updatePhoneNumber(student['id'], newPhone);
                            },
                            studentId: student['id'],
                          );
                        },
                      ),
                    ),
    );
  }
}

class StudentCard extends StatelessWidget {
  final String name;
  final String phone;
  final String address;
  final int studentId;
  final Map<String, dynamic> homeLocation;
  final Function(String) onUpdatePhone;

  const StudentCard({
    Key? key,
    required this.name,
    required this.phone,
    required this.address,
    required this.homeLocation,
    required this.onUpdatePhone,
    required this.studentId,
  }) : super(key: key);

  Future<void> _openGoogleMaps(BuildContext context) async {
    final lat = homeLocation['latitude'];
    final lng = homeLocation['longitude'];
    final url = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web URL if geo: scheme is not supported
        final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      print('Error launching Google Maps: $e');
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  child: const Icon(Icons.person, color: Colors.black54),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Phone Number
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    phone.isNotEmpty ? phone : "No phone number set",
                    style: TextStyle(fontSize: screenWidth * 0.032),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, size: 16, color: Colors.blue),
                  onPressed: () async {
                    final newPhone = await showDialog<String>(
                      context: context,
                      builder: (context) => EditPhoneDialog(phone: phone),
                    );
                    if (newPhone != null) {
                      onUpdatePhone(newPhone);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Address
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(fontSize: screenWidth * 0.032),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openGoogleMaps(context),
                    icon: Icon(Icons.map, size: 16, color: Colors.white),
                    label: Text(
                      "View Location",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.03,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                   onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UpdateLocationPage(
                            studentId: studentId,
                            currentLocation: homeLocation,
                          ),
                        ),
                      );
                      if (result != null) {
                        // Refresh the page to show updated location
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageStudentsPage(),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.edit_location, size: 16, color: Colors.white),
                    label: Text(
                      "Update Location",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.03,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 6),
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
}

class EditPhoneDialog extends StatefulWidget {
  final String phone;

  const EditPhoneDialog({Key? key, required this.phone}) : super(key: key);

  @override
  _EditPhoneDialogState createState() => _EditPhoneDialogState();
}

class _EditPhoneDialogState extends State<EditPhoneDialog> {
  late TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Edit Phone Number"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: "Phone Number",
              border: OutlineInputBorder(),
              errorText: _validatePhone(_phoneController.text),
            ),
            onChanged: (value) {
              setState(() {}); // Trigger rebuild to update error text
            },
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel"),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  final error = _validatePhone(_phoneController.text);
                  if (error == null) {
                    setState(() => _isLoading = true);
                    Navigator.pop(context, _phoneController.text.trim());
                  }
                },
          child: Text("Save"),
        ),
      ],
    );
  }

  String? _validatePhone(String phone) {
    if (phone.isEmpty) return 'Phone number is required';
    if (phone.length < 10) return 'Phone number must be at least 10 digits';
    return null;
  }
}