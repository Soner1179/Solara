import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Assuming Provider is used for state management
import '../services/api_service.dart';
import '../services/user_state.dart';
import '../pages/profile_page.dart'; // Import ProfilePage

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({Key? key}) : super(key: key);

  @override
  _DiscoverPageState createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late Future<List<dynamic>> _usersFuture;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch users when the page initializes
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      // Trigger search when query changes
      _fetchUsers();
    });
  }

  void _fetchUsers() {
    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];

    if (currentUserId != null) {
      if (_searchQuery.isNotEmpty) {
        // Only search if the query is not empty
        _usersFuture = ApiService().searchUsers(_searchQuery, currentUserId);
      } else {
        // If the query is empty, return an empty list
        _usersFuture = Future.value([]);
      }
    } else {
      _usersFuture = Future.error('User not logged in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keşfet'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Kullanıcı ara...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  print('DiscoverPage Error: ${snapshot.error}');
                  print('DiscoverPage Stack Trace: ${snapshot.stackTrace}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  print('DiscoverPage: No users found or data is null/empty.');
                  return const Center(child: Text('No users found.'));
                } else {
                  final users = snapshot.data!;
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        onTap: () {
                          // Navigate to the profile page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfilePage(username: user['username']),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Text(user['username'][0].toUpperCase()),
                        ),
                        title: Text(user['username']),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final userState = Provider.of<UserState>(context, listen: false);
                            final currentUserId = userState.currentUser?['user_id'];
                            final targetUserId = user['user_id'];
                            final isFollowing = user['is_following'] ?? false; // Get the follow status

                            if (currentUserId != null && targetUserId != null) {
                              try {
                                if (isFollowing) {
                                  // If currently following, unfollow
                                  await ApiService().unfollowUser(targetUserId);
                                  print('Successfully unfollowed ${user['username']}');
                                } else {
                                  // If not following, follow
                                  await ApiService().followUser(targetUserId);
                                  print('Successfully followed ${user['username']}');
                                }
                                // Refresh the user list to update button states
                                _fetchUsers();
                              } catch (e) {
                                print('Error performing follow/unfollow action for ${user['username']}: $e');
                                // TODO: Show an error message to the user
                              }
                            } else {
                               print('Cannot perform action: current user or target user ID is null');
                            }
                          },
                          // Conditionally display button text
                          child: Text(user['is_following'] == true ? 'Takipten Çık' : 'Takip Et'),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
