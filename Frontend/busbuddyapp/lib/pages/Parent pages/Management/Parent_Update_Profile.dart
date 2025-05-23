import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import '../../../services/parent_service.dart';

class ParentUpdateProfilePage extends StatefulWidget {
  final String currentName;
  final String currentPhone;
  final String currentEmail;

  const ParentUpdateProfilePage({
    Key? key,
    required this.currentName,
    required this.currentPhone,
    required this.currentEmail,
  }) : super(key: key);

  @override
  _ParentUpdateProfilePageState createState() =>
      _ParentUpdateProfilePageState();
}

class _ParentUpdateProfilePageState extends State<ParentUpdateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final _parentService = ParentService();

  late String _name;
  late String _phoneNumber;
  late String _email;
  String _newPassword = '';
  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _name = widget.currentName;
    _phoneNumber = widget.currentPhone;
    _email = widget.currentEmail;
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Split name into first and last name
        final nameParts = _name.trim().split(' ');
        final firstName = nameParts.first;
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        // Prepare update data
        final updateData = {
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': _phoneNumber,
          'email': _email,
        };

        // Add password if provided
        if (_newPassword.isNotEmpty) {
          updateData['password'] = _newPassword;
        }

        // Call API to update profile
        await _parentService.updateProfile(updateData);

        // Update local storage
        await _storage.write(key: 'name', value: _name);
        await _storage.write(key: 'phone_number', value: _phoneNumber);
        await _storage.write(key: 'email', value: _email);
        if (_newPassword.isNotEmpty) {
          await _storage.write(key: 'password', value: _newPassword);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update profile: ${e.toString()}'),
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
  }

  void _cancelChanges() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Profile'),
        backgroundColor: const Color(0xFFFCB041),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : _cancelChanges,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _name,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        if (value.trim().split(' ').length < 2) {
                          return 'Please enter both first and last name';
                        }
                        return null;
                      },
                      onChanged: (value) => _name = value,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _phoneNumber,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        if (value == null || value.length != 10) {
                          return 'Must be 10 digits';
                        }
                        return null;
                      },
                      onChanged: (value) => _phoneNumber = value,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _email,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Invalid email format';
                        }
                        final parts = value.split('@');
                        if (parts.length != 2) {
                          return 'Invalid email format';
                        }
                        final domain = parts[1];
                        if (!domain.contains('.')) {
                          return 'Domain must contain a dot';
                        }
                        final firstDotIndex = domain.indexOf('.');
                        if (firstDotIndex < 1) {
                          return 'Invalid domain format';
                        }
                        final domainParts = domain.split('.');
                        final lastPart = domainParts.last;
                        if (lastPart.isEmpty || lastPart.length < 1) {
                          return 'Domain extension required';
                        }
                        return null;
                      },
                      onChanged: (value) => _email = value,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'New Password (Optional)',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _showPassword = !_showPassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: !_showPassword,
                      validator: (value) {
                        if (value != null && value.isNotEmpty && value.length < 6) {
                          return 'Minimum 6 characters';
                        }
                        return null;
                      },
                      onChanged: (value) => _newPassword = value,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _cancelChanges,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}