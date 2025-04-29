import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Assuming Provider is used for state management
import '../services/api_service.dart';
import '../services/user_state.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({Key? key}) : super(key: key);

  @override
  _DiscoverPageState createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late Future<List<dynamic>> _usersFuture;

  @override
  void initState() {
    super.initState();
    // Fetch users when the page initializes
    _fetchUsers();
  }

  void _fetchUsers() {
    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id']; // Corrected key to 'user_id'

    if (currentUserId != null) {
      _usersFuture = ApiService().fetchAllUsers(currentUserId);
    } else {
      // Handle case where current user is not logged in (shouldn't happen if this page requires auth)
      _usersFuture = Future.error('User not logged in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keşfet'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Added detailed error logging
            print('DiscoverPage Error: ${snapshot.error}');
            print('DiscoverPage Stack Trace: ${snapshot.stackTrace}');
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            print('DiscoverPage: No users found or data is null/empty.');
            return const Center(child: Text('No users found.'));
          } else {
            // Display the list of users
            final users = snapshot.data!;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                // Assuming user object has 'username' and 'id'
                return ListTile(
                  leading: CircleAvatar(
                    // You might want to display a user profile picture here
                    backgroundColor: Colors.blueGrey,
                    child: Text(user['username'][0].toUpperCase()),
                  ),
                  title: Text(user['username']),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      // Implement follow functionality
                      final userState = Provider.of<UserState>(context, listen: false);
                      final currentUserId = userState.currentUser?['user_id'];
                      final followedUserId = user['user_id']; // Assuming user object has 'user_id'

                      if (currentUserId != null && followedUserId != null) {
                        try {
                          // Call the follow API
                          await ApiService().followUser(currentUserId, followedUserId);
                          print('Successfully followed ${user['username']}');
                          // TODO: Update UI to show "Following" or similar
                        } catch (e) {
                          print('Error following user ${user['username']}: $e');
                          // TODO: Show an error message to the user
                        }
                      } else {
                         print('Cannot follow: current user or followed user ID is null');
                      }
                    },
                    child: const Text('Takip Et'),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
