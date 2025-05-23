import 'package:flutter/material.dart';
import '../../../../services/bus_service.dart';
import '../../../../services/student_service.dart';

class BusEvents extends StatefulWidget {
  final int busId;
  final BusService busService = BusService();
  final StudentService studentService = StudentService();

  BusEvents({Key? key, required this.busId}) : super(key: key);

  @override
  _BusEventsState createState() => _BusEventsState();
}

class _BusEventsState extends State<BusEvents> {
  List<dynamic> events = [];
  bool isLoading = true;
  String? error;
  Map<int, String> studentNames = {};
  Map<String, dynamic>? busDetails;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Load bus details
      busDetails = await widget.busService.getBusDetails(widget.busId);
      
      // Load events
      final fetchedEvents = await widget.busService.getBusEvents(widget.busId);
      
      // Sort events by timestamp in descending order (newest first)
      fetchedEvents.sort((a, b) {
        final timeA = DateTime.parse(a['time'] ?? '');
        final timeB = DateTime.parse(b['time'] ?? '');
        return timeB.compareTo(timeA);
      });
      
      // Get unique student IDs
      final studentIds = fetchedEvents
          .where((event) => event['student_id'] != null)
          .map((event) => event['student_id'] as int)
          .toSet()
          .toList();

      // Fetch student names
      for (var studentId in studentIds) {
        try {
          final student = await widget.studentService.getStudentDetails(studentId);
          if (student != null) {
            studentNames[studentId] = '${student['first_name']} ${student['last_name']}';
          }
        } catch (e) {
          print('Error fetching student $studentId: $e');
        }
      }

      setState(() {
        events = fetchedEvents;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  String _getEventStatus(String eventType) {
    switch (eventType) {
      case 'unusual_enter':
        return 'Unusual Enter';
      case 'unusual_exit':
        return 'Unusual Exit';
      case 'enter':
        return 'Enter';
      case 'exit':
        return 'Exit';
      default:
        return eventType;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'enter':
      case 'exit':
        return Colors.green;
      case 'unusual_enter':
      case 'unusual_exit':
        return Colors.yellow;
      default:
        return Colors.red;
    }
  }

  String _getEventDetails(Map<String, dynamic> event) {
    final studentName = event['student_id'] != null 
        ? studentNames[event['student_id']] ?? 'Unknown Student'
        : null;
    
    switch (event['event_type']) {
      case 'unusual_enter':
        return studentName != null 
            ? '$studentName entered the bus away from their home'
            : 'Unfamiliar person entered the bus';
      case 'unusual_exit':
        return studentName != null 
            ? '$studentName exited the bus away from their home'
            : 'Unfamiliar person exited the bus';
      case 'enter':
        return studentName != null 
            ? '$studentName entered the bus'
            : 'Person entered the bus';
      case 'exit':
        return studentName != null 
            ? '$studentName exited the bus'
            : 'Person exited the bus';
      default:
        return 'Unknown event';
    }
  }

  String _formatTime(String timeString) {
    final dateTime = DateTime.parse(timeString);
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: screenHeight * 0.05,
        backgroundColor: Color(0xFFFCB041),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        error!,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      height: screenHeight * 0.17,
                      decoration: BoxDecoration(
                        color: Color(0xFFFCB041),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          CircleAvatar(
                            radius: screenWidth * 0.11,
                            backgroundColor: Color(0xFFFCB041),
                            child: Icon(Icons.directions_bus_rounded,
                                size: screenWidth * 0.25, color: Colors.white),
                          ),
                          Container(
                            width: screenWidth * 0.66,
                            height: screenHeight * 0.15,
                            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 20),
                            decoration: BoxDecoration(
                              border: Border.all(width: 1, color: Colors.black),
                              color: Color(0xFFF5F5FA),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_4_outlined),
                                      SizedBox(width: screenWidth * 0.02),
                                      Expanded(
                                        child: Text(
                                          "Bus ${widget.busId}",
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.033,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, color: Colors.black, size: screenWidth * 0.06),
                                      SizedBox(width: screenWidth * 0.03),
                                      Text(
                                        busDetails?['driver_name'] ?? 'Unknown Driver',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.03,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.phone, color: Colors.black, size: screenWidth * 0.06),
                                      SizedBox(width: screenWidth * 0.03),
                                      Text(
                                        busDetails?['driver_phone'] ?? 'No Phone',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.03,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(10),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          var event = events[index];
                          final status = _getEventStatus(event['event_type']);
                          final color = _getEventColor(event['event_type']);
                          final details = _getEventDetails(event);
                          final time = _formatTime(event['time']);
                          final studentName = event['student_id'] != null 
                              ? studentNames[event['student_id']]
                              : null;

                          return SizedBox(
                            height: screenHeight * 0.17,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: screenWidth * 0.085,
                                    height: screenHeight * 0.17,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                    ),
                                    child: Center(child: Icon(Icons.warning_amber_rounded)),
                                  ),
                                  Container(
                                    width: screenWidth * 0.4,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: Colors.black, width: 0.5),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (studentName != null)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.person),
                                              SizedBox(width: 5),
                                              Text(
                                                studentName,
                                                style: TextStyle(
                                                    fontSize: screenWidth * 0.028,
                                                    fontWeight: FontWeight.bold,
                                                    overflow: TextOverflow.visible),
                                              ),
                                            ],
                                          ),
                                        SizedBox(height: 6),
                                        Text(
                                          status,
                                          style: TextStyle(
                                              fontSize: screenWidth * 0.028,
                                              fontWeight: FontWeight.bold,
                                              overflow: TextOverflow.visible),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: SizedBox(
                                      width: screenWidth * 0.4,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          SizedBox(height: 5),
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                details,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    fontSize: screenWidth * 0.027,
                                                    fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.visible,
                                                maxLines: null,
                                              ),
                                            ),
                                          ),
                                          Text(time,
                                              style: TextStyle(
                                                  fontSize: screenWidth * 0.024,
                                                  color: Colors.black)),
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
