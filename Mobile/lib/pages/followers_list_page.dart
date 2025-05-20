// lib/pages/followers_list_page.dart
import 'package:flutter/material.dart';
import 'package:solara/services/api_service.dart';
import 'package:solara/models/user_model.dart'; // Assuming you have a UserModel

class FollowersListPage extends StatefulWidget {
  final int userId;

  const FollowersListPage({required this.userId, super.key});

  @override
  State<FollowersListPage> createState() => _FollowersListPageState();
}

class _FollowersListPageState extends State<FollowersListPage> {
  late Future<List<User>> _followersFuture;

  @override
  void initState() {
    super.initState();
    _followersFuture = _fetchFollowers();
  }

  Future<List<User>> _fetchFollowers() async {
    final apiService = ApiService();
    final List<dynamic> data = await apiService.fetchFollowers(widget.userId);
    return data.map((json) => User.fromJson(json)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Takipçiler'),
      ),
      body: FutureBuilder<List<User>>(
        future: _followersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Henüz takipçi yok.'));
          } else {
            final followers = snapshot.data!;
            return ListView.builder(
              itemCount: followers.length,
              itemBuilder: (context, index) {
                final follower = followers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(follower.profilePictureUrl ?? 'https://via.placeholder.com/150'),
                  ),
                  title: Text(follower.username),
                  // TODO: Add onTap to navigate to follower's profile
                );
              },
            );
          }
        },
      ),
    );
  }
}
