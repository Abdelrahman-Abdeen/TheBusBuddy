import 'package:flutter/material.dart';
import '../../../services/parent_service.dart';

class ManageNotificationsPage extends StatefulWidget {
  const ManageNotificationsPage({Key? key}) : super(key: key);

  @override
  _ManageNotificationsPageState createState() => _ManageNotificationsPageState();
}

class _ManageNotificationsPageState extends State<ManageNotificationsPage> {
  final _parentService = ParentService();
  bool _isLoading = true;
  String? _error;
  Map<String, bool> _preferences = {
    'enter': false,
    'exit': false,
    'enter_at_school': false,
    'exit_at_school': false,
    'unusual_exit': false,
    'unusual_enter': false,
    'approach': false,
    'arrival': false,
    'unauthorized_enter': false,
    'unauthorized_exit': false,
  };
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final preferences = await _parentService.getNotificationPreferences();
      setState(() {
        _preferences = Map<String, bool>.from(preferences);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _parentService.updateNotificationPreferences(_preferences);
      setState(() {
        _isLoading = false;
        _hasChanges = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<bool> _handleBack() async {
    if (_hasChanges) {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Save Changes?'),
          content: Text('You have unsaved changes. Would you like to save them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Save'),
            ),
          ],
        ),
      );

      if (shouldSave == true) {
        try {
          setState(() => _isLoading = true);
          await _parentService.updateNotificationPreferences(_preferences);
          setState(() {
            _isLoading = false;
            _hasChanges = false;
          });
          return true;
        } catch (e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save changes: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
      } else {
        return true;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          backgroundColor: Color(0xFFFCB041),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              final shouldPop = await _handleBack();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Manage Notifications",
                style: TextStyle(color: Colors.black, fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold),
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
                          onPressed: _loadPreferences,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notifications, color: Colors.black),
                            SizedBox(width: 8),
                            Text(
                              "Notify me when :",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Expanded(
                          child: ListView(
                            children: _preferences.entries.map((entry) => NotificationToggle(
                              label: _getPreferenceTitle(entry.key),
                              value: entry.value,
                              onChanged: (newValue) {
                                setState(() {
                                  _preferences[entry.key] = newValue;
                                  _hasChanges = true;
                                });
                              },
                            )).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _getPreferenceTitle(String key) {
    switch (key) {
      case 'enter':
        return 'Student enters the bus';
      case 'exit':
        return 'Student exits the bus';
      case 'enter_at_school':
        return 'Student enters the bus at school';
      case 'exit_at_school':
        return 'Student exits the bus at school';
      case 'unusual_exit':
        return 'Student exits away from home';
      case 'unusual_enter':
        return 'Student enters away from home';
      case 'approach':
        return 'Bus approaches home';
      case 'arrival':
        return 'Bus arrives home';
      case 'unauthorized_enter':
        return 'Unfamiliar person enters the bus';
      case 'unauthorized_exit':
        return 'Unfamiliar person exits the bus';
      default:
        return key;
    }
  }
}

class NotificationToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const NotificationToggle({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.green,
              inactiveThumbColor: Colors.red,
              inactiveTrackColor: Colors.red[200],
            ),
          ],
        ),
      ),
    );
  }
}


