import 'package:flutter/material.dart';

class ParentViewStudentEvent extends StatelessWidget {
  final Map<String, dynamic> event;

  const ParentViewStudentEvent({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Stack(
            children: [
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
                  child: Center(
                    child: Text(
                      'Student Event Details',
                      style: TextStyle(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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
          // Event details section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: screenHeight * 0.02),
                      _buildInfoRow(Icons.event, 'Event Type:', 
                          event['type'] ?? 'Unknown', screenWidth),
                      SizedBox(height: screenHeight * 0.03),
                      _buildInfoRow(Icons.person, 'Student Name:', 
                          event['student_name'] ?? 'Unknown', screenWidth),
                      SizedBox(height: screenHeight * 0.03),
                      _buildInfoRow(Icons.location_on, 'Location:', 
                          event['location'] ?? 'Unknown', screenWidth),
                      SizedBox(height: screenHeight * 0.03),
                      _buildInfoRow(Icons.calendar_month, 'Date:', 
                          event['date'] ?? 'Unknown', screenWidth),
                      SizedBox(height: screenHeight * 0.03),
                      _buildInfoRow(Icons.watch, 'Time:', 
                          event['time'] ?? 'Unknown', screenWidth),
                      SizedBox(height: screenHeight * 0.03),
                      _buildInfoRow(Icons.info, 'Details:', 
                          event['details'] ?? 'No additional details', screenWidth),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, double screenWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF0A061F), size: screenWidth * 0.06),
        SizedBox(width: screenWidth * 0.03),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: '$label ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.04,
                color: Colors.black,
              ),
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: screenWidth * 0.04,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
