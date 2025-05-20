// lib/pages/following_list_page.dart
import 'package:flutter/material.dart';
import 'package:solara/services/api_service.dart';
import 'package:solara/models/user_model.dart'; // Assuming you have a UserModel

class FollowingListPage extends StatefulWidget {
  final int userId;

  const FollowingListPage({required this.userId, super.key});

  @override
  State<FollowingListPage> createState() => _FollowingListPageState();
}

class _FollowingListPageState extends State<FollowingListPage> {
  late Future<List<User>> _followingFuture;

  @override
  void initState() {
    super.initState();
    _followingFuture = _fetchFollowing();
  }

  Future<List<User>> _fetchFollowing() async {
    final apiService = ApiService();
    final List<dynamic> data = await apiService.fetchFollowing(widget.userId);
    return data.map((json) => User.fromJson(json)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Takip Edilenler'),
      ),
      body: FutureBuilder<List<User>>(
        future: _followingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Henüz takip edilen yok.'));
          } else {
            final following = snapshot.data!;
            return ListView.builder(
              itemCount: following.length,
              itemBuilder: (context, index) {
                final followedUser = following[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(followedUser.profilePictureUrl ?? 'https://via.placeholder.com/150'),
                  ),
                  title: Text(followedUser.username),
                  // TODO: Add onTap to navigate to followed user's profile
                );
              },
            );
          }
        },
      ),
    );
  }
}
