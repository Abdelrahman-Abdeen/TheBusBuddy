import 'package:flutter/material.dart';
import 'Admin_Notifications.dart';
import '../Admin_Home.dart';
import '../Admin_Log_In.dart';
import '../../../services/notification_service.dart';
import '../../../services/bus_service.dart';
import '../../../services/student_service.dart';

class CreateNotificationPage extends StatefulWidget {
  final String? busName;
  final int? busId;

  CreateNotificationPage({this.busName, this.busId});

  @override
  _CreateNotificationPageState createState() => _CreateNotificationPageState();
}

class _CreateNotificationPageState extends State<CreateNotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();
  final BusService _busService = BusService();
  final StudentService _studentService = StudentService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedBusOption = "All Buses";
  String _selectedStudentOption = "All Students";
  int? _selectedBusId;
  List<int> _selectedStudentIds = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  List<Map<String, dynamic>> busList = [];
  List<Map<String, dynamic>> studentList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadBuses();
    
    // If busId is provided (from tracking page), set it as selected
    if (widget.busId != null) {
      _selectedBusId = widget.busId;
      _selectedBusOption = "Specific Bus";
      _loadStudentsForBus(widget.busId!);
    }
    
    _searchController.addListener(_filterStudents);
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = studentList.where((student) {
        final name = '${student['first_name']} ${student['last_name']}'.toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _loadBuses() async {
    try {
      final buses = await _busService.getAllBuses();
      setState(() {
        busList = buses;
      });
    } catch (e) {
      print('Error loading buses: $e');
    }
  }

  Future<void> _loadStudentsForBus(int busId) async {
    try {
      final busDetails = await _busService.getBusDetails(busId);
      // Get only students from this specific bus
      final busStudents = await _studentService.getStudentsInBus(busId);
      
      setState(() {
        studentList = busStudents;
        _filteredStudents = busStudents;
        if (_selectedStudentOption == "Currently In Bus Student") {
          final currentStudentIds = List<int>.from(busDetails['currently_in_bus_students'] ?? []);
          _selectedStudentIds = currentStudentIds;
        }
      });
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  Future<void> _sendNotification() async {
    try {
      if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please fill in the title and description"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      List<int> recipientIds = [];

      // If we came from a specific bus tracking page, always use that bus
      if (widget.busId != null) {
        if (_selectedStudentOption == "All Students") {
          // Get all students from this specific bus
          final busStudents = await _studentService.getStudentsInBus(widget.busId!);
          recipientIds = busStudents.map((s) => s['id'] as int).toList();
        } else if (_selectedStudentOption == "Currently In Bus Student") {
          // Get currently in bus students from this specific bus
          final busDetails = await _busService.getBusDetails(widget.busId!);
          recipientIds = List<int>.from(busDetails['currently_in_bus_students'] ?? []);
        } else if (_selectedStudentOption == "Custom") {
          recipientIds = _selectedStudentIds;
        }
      } else {
        // Normal flow when not coming from bus tracking
        if (_selectedStudentOption == "All Students") {
          if (_selectedBusOption == "All Buses") {
            final allStudents = await _studentService.getAllStudents();
            recipientIds = allStudents.map((s) => s['id'] as int).toList();
          } else if (_selectedBusOption == "Specific Bus" && _selectedBusId != null) {
            final busStudents = await _studentService.getStudentsInBus(_selectedBusId!);
            recipientIds = busStudents.map((s) => s['id'] as int).toList();
          }
        } else if (_selectedStudentOption == "Currently In Bus Student") {
          if (_selectedBusOption == "All Buses") {
            for (var bus in busList) {
              final busDetails = await _busService.getBusDetails(bus['id'] as int);
              recipientIds.addAll(List<int>.from(busDetails['currently_in_bus_students'] ?? []));
            }
          } else if (_selectedBusOption == "Specific Bus" && _selectedBusId != null) {
            final busDetails = await _busService.getBusDetails(_selectedBusId!);
            recipientIds = List<int>.from(busDetails['currently_in_bus_students'] ?? []);
          }
        } else if (_selectedStudentOption == "Custom" && _selectedStudentIds.isNotEmpty) {
          recipientIds = _selectedStudentIds;
        }
      }

      if (recipientIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No recipients selected"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _notificationService.createNotification(
        title: _titleController.text,
        message: _descriptionController.text,
        recipientIds: recipientIds,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Success"),
            content: Text("Notification sent successfully."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to previous screen
                },
                child: Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _notificationService.dispose();
    super.dispose();
  }

  // Handle Tab Selection
  void _handleTabSelection() {
    if (_tabController.index == 0) {
      // Navigate to Home Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminHome()),
      );
    } else if (_tabController.index == 1) {
      // Stay on Notifications Page (or navigate to it if needed)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminNotifications()),
      );
    } else if (_tabController.index == 2) {
      // Log Out and Navigate to Login Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminLogInScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFCB041),
        elevation: 0,
        title: Text(
          "Create Notifications",
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 22),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Select Recipients (Bus)
              if (widget.busName == null) ...[
                _buildSectionTitle("Select Recipients (Bus)", screenWidth),
                _buildCard(
                  child: Column(
                    children: [
                      _buildRadioTile("All Buses", _selectedBusOption, (value) {
                        setState(() {
                          _selectedBusOption = value;
                          _selectedBusId = null;
                        });
                      }, screenWidth),
                      _buildRadioTile("Specific Bus", _selectedBusOption, (value) {
                        setState(() {
                          _selectedBusOption = value;
                        });
                      }, screenWidth),
                      if (_selectedBusOption == "Specific Bus")
                        _buildBusDropdown(screenWidth),
                    ],
                  ),
                ),
              ] else ...[
                _buildSectionTitle(
                    "Sending Notification for ${widget.busName}", screenWidth),
              ],
              // Select Recipients (Students)
              _buildSectionTitle("Select Recipients (Students)", screenWidth),
              _buildCard(
                child: Column(
                  children: [
                    _buildRadioTile("All Students", _selectedStudentOption, (value) {
                      setState(() {
                        _selectedStudentOption = value;
                        _selectedStudentIds.clear();
                      });
                    }, screenWidth),
                    _buildRadioTile("Currently In Bus Student", _selectedStudentOption, (value) {
                      setState(() {
                        _selectedStudentOption = value;
                        _selectedStudentIds.clear();
                      });
                    }, screenWidth),
                    _buildRadioTile("Custom", _selectedStudentOption, (value) {
                      setState(() {
                        _selectedStudentOption = value;
                      });
                    }, screenWidth),
                    if (_selectedStudentOption == "Custom")
                      _buildStudentMultiSelect(screenWidth),
                  ],
                ),
              ),
              // Title Input
              _buildSectionTitle("Title", screenWidth),
              _buildTextInput(_titleController, "Notification Title Here...", screenWidth),
              // Description Input
              _buildSectionTitle("Description", screenWidth),
              _buildTextInput(_descriptionController, "Notification Description Here...", screenWidth, maxLines: 3),
              // Buttons
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: screenWidth * 0.35,
                      child: _buildButton("Cancel", Colors.red, Colors.white, screenWidth, () {
                        Navigator.pop(context);
                      }),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildButton("Send Notification", Colors.black, Colors.white, screenWidth, () {
                        if ((_selectedBusOption == "Specific Bus" && _selectedBusId == null) ||
                            (_selectedStudentOption == "Custom" && _selectedStudentIds.isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Please fill all required fields."),
                            ),
                          );
                        } else {
                          _sendNotification();
                        }
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Section Title Widget
  Widget _buildSectionTitle(String title, double screenWidth) {
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
            fontSize: screenWidth * 0.035, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Card Wrapper for Sections
  Widget _buildCard({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(10),
        child: child,
      ),
    );
  }

  // Radio Button Tile
  Widget _buildRadioTile(String title, String groupValue,
      Function(String) onChanged, double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1),
      child: RadioListTile<String>(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: TextStyle(fontSize: screenWidth * 0.033)),
        value: title,
        groupValue: groupValue,
        onChanged: (value) async {
          onChanged(value!);
          // Reset selected students when switching options
          setState(() {
            _selectedStudentIds.clear();
          });
          
          if (value == "Custom") {
            try {
              if (_selectedBusOption == "All Buses") {
                // Load all students if All Buses is selected
                final allStudents = await _studentService.getAllStudents();
                setState(() {
                  studentList = allStudents;
                  _filteredStudents = allStudents;
                });
              } else if (_selectedBusOption == "Specific Bus" && _selectedBusId != null) {
                // Load only students from the selected bus
                final busStudents = await _studentService.getStudentsInBus(_selectedBusId!);
                setState(() {
                  studentList = busStudents;
                  _filteredStudents = busStudents;
                });
              }
            } catch (e) {
              print('Error loading students: $e');
            }
          } else if (value == "All Students") {
            try {
              if (_selectedBusOption == "All Buses") {
                final allStudents = await _studentService.getAllStudents();
                setState(() {
                  _selectedStudentIds = allStudents.map((s) => s['id'] as int).toList();
                });
              } else if (_selectedBusOption == "Specific Bus" && _selectedBusId != null) {
                final busStudents = await _studentService.getStudentsInBus(_selectedBusId!);
                setState(() {
                  _selectedStudentIds = busStudents.map((s) => s['id'] as int).toList();
                });
              }
            } catch (e) {
              print('Error loading all students: $e');
            }
          } else if (value == "Currently In Bus Student") {
            try {
              if (_selectedBusOption == "All Buses") {
                // For all buses, get currently in bus students from each bus
                List<int> allCurrentStudents = [];
                for (var bus in busList) {
                  final busDetails = await _busService.getBusDetails(bus['id'] as int);
                  final currentStudentIds = List<int>.from(busDetails['currently_in_bus_students'] ?? []);
                  allCurrentStudents.addAll(currentStudentIds);
                }
                setState(() {
                  _selectedStudentIds = allCurrentStudents;
                });
              } else if (_selectedBusOption == "Specific Bus" && _selectedBusId != null) {
                final busDetails = await _busService.getBusDetails(_selectedBusId!);
                final currentStudentIds = List<int>.from(busDetails['currently_in_bus_students'] ?? []);
                setState(() {
                  _selectedStudentIds = currentStudentIds;
                });
              }
            } catch (e) {
              print('Error loading currently in bus students: $e');
            }
          }
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildBusDropdown(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonFormField<int>(
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            prefixIcon: Icon(Icons.directions_bus, color: Color(0xFFFCB041)),
          ),
          hint: Text(
            "Select Bus",
            style: TextStyle(
              fontSize: screenWidth * 0.033,
              color: Colors.grey.shade600,
            ),
          ),
          value: _selectedBusId,
          isExpanded: true,
          dropdownColor: Colors.white,
          style: TextStyle(
            fontSize: screenWidth * 0.033,
            color: Colors.black,
          ),
          icon: Icon(Icons.arrow_drop_down, color: Color(0xFFFCB041)),
          items: busList.map((bus) {
            return DropdownMenuItem(
              value: bus['id'] as int,
              child: Row(
                children: [
                  Icon(Icons.directions_bus, 
                    color: Color(0xFFFCB041),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    bus['name'] ?? 'Bus ${bus['id']}',
                    style: TextStyle(
                      fontSize: screenWidth * 0.033,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) async {
            setState(() {
              _selectedBusId = value;
            });
            if (value != null) {
              try {
                final busStudents = await _studentService.getStudentsInBus(value);
                setState(() {
                  studentList = busStudents;
                  _filteredStudents = busStudents;
                });
              } catch (e) {
                print('Error loading students for bus: $e');
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildStudentMultiSelect(double screenWidth) {
    if (studentList.isEmpty) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              height: 35,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFFCB041), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  isDense: true,
                ),
              ),
            ),
          ),
          // Students List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredStudents.length,
              itemBuilder: (context, index) {
                final student = _filteredStudents[index];
                final studentName = '${student['first_name']} ${student['last_name']}';
                final isSelected = _selectedStudentIds.contains(student['id'] as int);
                
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: CircleAvatar(
                      radius: 15,
                      backgroundColor: isSelected ? Color(0xFFFCB041) : Colors.grey.shade300,
                      child: Icon(
                        isSelected ? Icons.check : Icons.person,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      studentName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Color(0xFFFCB041) : Colors.black,
                      ),
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedStudentIds.add(student['id'] as int);
                          } else {
                            _selectedStudentIds.remove(student['id'] as int);
                          }
                        });
                      },
                      activeColor: Color(0xFFFCB041),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedStudentIds.remove(student['id'] as int);
                        } else {
                          _selectedStudentIds.add(student['id'] as int);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput(TextEditingController controller, String hint, double screenWidth, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: hint,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        hintStyle: TextStyle(fontSize: screenWidth * 0.033),
        filled: true,
        fillColor: Colors.white,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFFCB041), width: 2),
        ),
      ),
    );
  }

  // Button Widget
  Widget _buildButton(String text, Color bgColor, Color textColor,
      double screenWidth, Function onPressed) {
    return ElevatedButton(
      onPressed: () => onPressed(),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        elevation: 2,
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: screenWidth * 0.035, fontWeight: FontWeight.bold)),
    );
  }
}