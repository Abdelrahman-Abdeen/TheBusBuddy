import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _controller = AnimationController(
      duration: Duration(seconds: 3), // Duration of the animation
      vsync: this,
    );

    // Define the animation to move the bus from left to right
    _animation = Tween<double>(begin: -1, end: 1).animate(_controller);

    // Start the animation
    _controller.repeat(reverse: false);

    // Navigate to the login screen after 3 seconds
    Timer(Duration(seconds: 3), () {
      _controller.stop(); // Stop the animation when navigating
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top wave design
          ClipPath(
            clipper: CustomClipperPath(),
            child: Container(
              height: screenHeight * 0.3,
              width: screenWidth,
              color: Color(0xFFFCB041),
              child: Center(
                child: Text(
                  'Welcome to BusBuddy',
                  style: TextStyle(
                    fontSize: screenWidth * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Logo
          SizedBox(height: screenHeight * 0.05),
          Center(
            child: Image.asset(
              'assets/bus_logo.png', // Replace with your actual logo asset
              height: screenHeight * 0.2,
            ),
          ),
          SizedBox(height: screenHeight * 0.05),

          // App name
          Text(
            'BusBuddy',
            style: TextStyle(
              fontSize: screenWidth * 0.08,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),

          // Tagline or description
          Text(
            'Your trusted companion for school transportation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              color: Colors.black54,
            ),
          ),
          Spacer(),

          // Moving bus icon (side-view bus image)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_animation.value * screenWidth, 0),
                child: Image.asset(
                  'assets/side_bus.png', // Reference to the side-view bus image
                  height: 60.0, // Increased the height to make the bus larger
                ),
              );
            },
          ),
          SizedBox(height: screenHeight * 0.05),
        ],
      ),
    );
  }
}

class CustomClipperPath extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.9,
        size.width * 0.5, size.height * 0.8);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.7, size.width, size.height * 0.9);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
