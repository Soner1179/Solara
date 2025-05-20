import 'package:flutter/material.dart';
import 'package:solara/services/api_service.dart'; // Assuming api_service.dart is in this path
import 'package:solara/services/user_state.dart'; // Assuming user_state.dart is in this path
import 'package:provider/provider.dart'; // Assuming provider is used for state management

class PrivacySecuritySettingsPage extends StatefulWidget {
  const PrivacySecuritySettingsPage({super.key});

  @override
  _PrivacySecuritySettingsPageState createState() => _PrivacySecuritySettingsPageState();
}

class _PrivacySecuritySettingsPageState extends State<PrivacySecuritySettingsPage> {
  bool _isPrivate = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPrivacyStatus();
  }

  Future<void> _fetchPrivacyStatus() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final userState = Provider.of<UserState>(context, listen: false);
      final userId = userState.currentUser?['user_id'];

      if (userId != null) {
        // Use the correct method to fetch user profile by ID
        final userData = await apiService.getUserProfile(userId);
        setState(() {
          _isPrivate = userData['is_private'] ?? false; // Assuming 'is_private' is returned in user profile
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        // Handle case where user ID is not available
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ID not available.')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch privacy status: $e')),
      );
    }
  }

  Future<void> _togglePrivateAccount(bool newValue) async {
    setState(() {
      _isPrivate = newValue;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.updatePrivacyStatus(newValue); // Assuming an API call to update privacy status
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Privacy status updated.')),
      );
    } catch (e) {
      // Revert the switch state if the API call fails
      setState(() {
        _isPrivate = !newValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update privacy status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gizlilik ve Güvenlik'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Gizli Hesap'),
                  secondary: Icon(Icons.visibility_off_outlined),
                  value: _isPrivate,
                  onChanged: _togglePrivateAccount,
                ),
              ],
            ),
    );
  }
}
