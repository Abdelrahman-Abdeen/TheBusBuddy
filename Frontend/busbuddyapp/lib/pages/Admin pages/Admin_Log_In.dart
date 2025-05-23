import 'package:flutter/material.dart';
import 'Admin_Home.dart'; // Ensure correct file name
import '../../services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AdminLogInScreen extends StatefulWidget {
  const AdminLogInScreen({Key? key}) : super(key: key);

  @override
  State<AdminLogInScreen> createState() => _AdminLogInScreenState();
}

class _AdminLogInScreenState extends State<AdminLogInScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkTokenAndNavigate();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkTokenAndNavigate() async {
    final token = await _authService.getToken();
    if (token != null && !JwtDecoder.isExpired(token)) {
      final decoded = JwtDecoder.decode(token);
      final role = decoded["role"];
      if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminHome()),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _authService.adminLogin(
        _phoneController.text,
        _passwordController.text,
      );

      await _authService.storeToken(token);
      
      // Get and store FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await storage.write(key: 'fcm_token', value: fcmToken);
        
        // Get user ID from token
        final decoded = JwtDecoder.decode(token);
        final userId = decoded["sub"];
        
        // Check current device token
        final currentToken = await _authService.getUserDeviceToken(userId);
        
        // Update if token is null or different
        if (currentToken == null || currentToken != fcmToken) {
          try {
            await _authService.updateDeviceToken(userId, fcmToken);
            print('Device token updated successfully');
          } catch (e) {
            print('Failed to update device token: $e');
            // Continue with navigation even if token update fails
          }
        }
      }
      
      final decoded = JwtDecoder.decode(token);
      final role = decoded["role"];
      
      if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminHome()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Color(0xFFFCB041),
      body: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            SizedBox(
              height: screenHeight*0.05,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
              
                children: [
                  Positioned(
                    top: 20,
                    left: 16,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.black, size: 30),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  Image.asset('assets/bus_logo.png', height: screenHeight *0.1),
                  
                ],
              ),
            ),
            // White Top Section with Squiggly Line
            ClipPath(
              clipper: CustomClipperPath(),
              child: Container(
                height: screenHeight*0.9 , // Reduced white section height
                width: screenWidth,
                color: Colors.white,
                child: Column(
                  children: [
                    SizedBox(
                      height: screenHeight*0.1,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal:32),
                          child: Text(
                            "Log In",
                            style: TextStyle(fontSize: screenWidth*0.065, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text("As An Admin", style: TextStyle(
                            fontSize: screenWidth*0.065 , fontWeight: FontWeight.bold , color: Colors.black
                          ),),
                        ),
                        SizedBox(height: 30),
                    
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Phone Number", style: TextStyle(fontSize: screenWidth*0.035)),
                              SizedBox(height: 2),
                              SizedBox(
                                height: screenHeight*0.072,
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0),
                                    borderSide: BorderSide(color: Colors.black , width: 1.5)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0),
                                    borderSide: BorderSide(color: Colors.black , width: 1.5)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Phone Number',
                                  ),
                                ),
                              ),
                              SizedBox(height: 5),
                              Text("Password", style: TextStyle(fontSize: screenWidth*0.035)),
                              SizedBox(height: 2),
                              SizedBox(
                                height: screenHeight*0.072,
                                child: TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0),
                                    borderSide: BorderSide(color: Colors.black , width: 1.5)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0),
                                    borderSide: BorderSide(color: Colors.black , width: 1.5)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Password',
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: screenHeight*0.055,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                              ),
                              child: _isLoading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    'Submit',
                                    style: TextStyle(color: Colors.white, fontSize: screenWidth*0.045,),
                                  ),
                            ),
                          ),
                        ),
                    
                        SizedBox(height: 15),
                    
                        
                    
                        SizedBox(height: 30),
                    
                        Center(child: Image.asset('assets/school_logo.png', height: screenHeight*0.12)),
                    
                      ],
                    ),
                  ],
                ),
              ),
              
            ),
            
            
            // Login Form Section (Now Positioned Properly Below the Wave)
            
          ],
        ),
      ),
    );
  }
}


class CustomClipperPath extends CustomClipper<Path> {
  @override
 Path getClip(Size size) {
    Path path = Path();

    // Start from the mid-left of the container
     path.lineTo(0, size.height * 0.1);

    // Create a wave pattern along the top border
    path.quadraticBezierTo(
      size.width * 0.15,  // Control point X
      size.height * 0.05, // Control point Y
      size.width * 0.45,   // End point X
      size.height * 0.1,  // End point Y
    );
    path.quadraticBezierTo(
      size.width * 0.75,  // Control point X
      size.height * 0.15, // Control point Y
      size.width,         // End point X
      size.height * 0.1,  // End point Y
    );

    // Draw straight lines to complete the container
    path.lineTo(size.width, size.height); // Bottom-right corner
    path.lineTo(0, size.height);       
    path.close(); // Complete the path

    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}