import 'package:flutter/material.dart';
import 'package:solara/services/api_service.dart';
import 'package:solara/services/secure_storage_service.dart';
import 'package:solara/models/user_model.dart'; // Assuming a simple User model
import './messages_page.dart';

class NewChatSearchPage extends StatefulWidget {
  const NewChatSearchPage({super.key});

  @override
  State<NewChatSearchPage> createState() => _NewChatSearchPageState();
}

class _NewChatSearchPageState extends State<NewChatSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  List<User> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _currentUserId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _searchController.addListener(() {
      if (_searchController.text != _searchQuery) {
        _searchQuery = _searchController.text;
        if (_searchQuery.trim().isNotEmpty) {
          _performSearch();
        } else {
          setState(() {
            _searchResults = [];
            _errorMessage = null;
          });
        }
      }
    });
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final userIdString = await SecureStorageService.getUserId();
      if (userIdString != null) {
        _currentUserId = int.tryParse(userIdString);
      }
    } catch (e) {
      print("Error loading current user ID: $e");
      // Handle error if needed, though search might still work if backend doesn't strictly require excluding current user
    }
  }

  Future<void> _performSearch() async {
    if (_searchQuery.trim().isEmpty || _currentUserId == null) {
      setState(() {
        _searchResults = [];
        _errorMessage = _currentUserId == null ? "Kullanıcı bilgisi yüklenemedi." : null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Using existing searchUsers which excludes current user by default if ID is passed
      final List<dynamic> resultsData = await _apiService.searchUsers(_searchQuery, _currentUserId!);
      // Assuming User.fromJson can handle the structure from searchUsers API
      // The searchUsers API in backend returns: user_id, username, full_name, profile_picture_url
      final List<User> users = resultsData.map((data) {
          return User.fromJson(data as Map<String, dynamic>);
      }).toList();

      setState(() {
        _searchResults = users;
        _isLoading = false;
        if (users.isEmpty) {
          _errorMessage = "Sonuç bulunamadı.";
        }
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Kullanıcı aranırken bir hata oluştu: ${e.toString()}';
      });
    }
  }

  void _navigateToChatWithUser(User user) {
    Navigator.pop(context, true); // Pop this page and indicate a potential refresh
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessagesPage(
          chatPartnerId: user.userId,
          chatPartnerName: user.fullName ?? user.username, // Use fullName if available
          chatPartnerUsername: user.username,
          chatPartnerAvatarUrl: user.profilePictureUrl ?? "assets/images/default_avatar.png",
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Sohbet Başlat'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Kullanıcı adı ile ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null && _searchResults.isEmpty)
            Expanded(child: Center(child: Text(_errorMessage!)))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user.profilePictureUrl ?? ''),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Handle error, perhaps show a default avatar icon
                      },
                      child: (user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(user.fullName ?? user.username),
                    subtitle: Text('@${user.username}'),
                    onTap: () => _navigateToChatWithUser(user),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
