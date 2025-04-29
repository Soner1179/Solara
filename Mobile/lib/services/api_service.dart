import 'dart:convert';
import 'dart:io'; // File class for image upload
import 'package:http/http.dart' as http;
// No need for provider/UserState here, ID should come from calling function

class ApiService {
  // Ensure this IP is correct and your backend is running and accessible
  final String baseUrl = 'http://10.61.0.98:5000/api';

  // --- Helper Methods ---

  // Helper for adding Auth Headers (if token exists)
  Future<Map<String, String>> _getHeaders({bool requiresAuth = false, bool isJson = true}) async {
    Map<String, String> headers = {};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (requiresAuth) {
      // TODO: Implement token retrieval from secure storage
      // String? token = await SecureStorageService.getToken(); // Example
      String? token = null; // Replace with actual token retrieval
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        print("Warning: Auth required but no token found for request.");
        // Optionally throw an error or handle missing token case
      }
    }
    return headers;
  }


  // Helper method for making GET requests
  Future<dynamic> get(String endpoint, {bool requiresAuth = false}) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth, isJson: false); // GET doesn't need Content-Type: json
    final response = await http.get(Uri.parse('$baseUrl/$endpoint'), headers: headers);
    return _handleResponse(response);
  }

  // Helper method for making POST requests
  Future<dynamic> post(String endpoint, dynamic data, {bool requiresAuth = false}) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth, isJson: true);
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  // Helper method for making PUT requests
  Future<dynamic> put(String endpoint, dynamic data, {bool requiresAuth = false}) async {
     final headers = await _getHeaders(requiresAuth: requiresAuth, isJson: true);
    final response = await http.put(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  // Helper method for making DELETE requests
  Future<dynamic> delete(String endpoint, {bool requiresAuth = false}) async {
     final headers = await _getHeaders(requiresAuth: requiresAuth, isJson: false);
    final response = await http.delete(Uri.parse('$baseUrl/$endpoint'), headers: headers);
    return _handleResponse(response);
  }

  // Handle the HTTP response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.headers['content-type']?.contains('application/json') == true && response.body.isNotEmpty) {
         try {
           return json.decode(response.body);
         } catch (e) {
           print("JSON Decode Error: ${e.toString()} \nBody: ${response.body}");
           throw Exception('Failed to decode JSON response');
         }
      } else if (response.body.isEmpty && response.statusCode == 204) { // Handle No Content
          return null; // Or return a success indicator like {'success': true}
      }
       else {
        return response.body; // Return raw body for non-JSON or empty JSON responses
      }
    } else {
      print('API Error: ${response.statusCode}');
      print('Response body: ${response.body}');
      // Try to parse error message from JSON if available
      String errorMessage = 'API request failed with status ${response.statusCode}';
      if (response.headers['content-type']?.contains('application/json') == true && response.body.isNotEmpty) {
          try {
              final errorData = json.decode(response.body);
              if (errorData is Map && errorData.containsKey('message')) {
                  errorMessage = errorData['message'];
              } else if (errorData is Map && errorData.containsKey('error')) {
                 errorMessage = errorData['error'];
              }
          } catch (e) { /* Ignore decode error, use default message */ }
      }
      throw Exception(errorMessage); // Throw specific error message
    }
  }

  // --- Specific API Methods ---

  // Fetch home feed posts FOR THE CURRENT USER
  Future<List<dynamic>> fetchPosts(int currentUserId) async {
    try {
      // Pass user_id as query parameter as implemented in backend
      final data = await get('posts?user_id=$currentUserId', requiresAuth: true); // Auth might be needed
      if (data is List) {
        return data;
      } else {
        print('Unexpected response format for fetchPosts: $data');
        throw Exception('Unexpected response format received from server.');
      }
    } catch (e) {
      print('Error fetching posts for user $currentUserId: $e');
      rethrow;
    }
  }

    // Fetch posts for a specific user's profile
  Future<List<dynamic>> fetchUserPosts(int userId) async {
    try {
      final data = await get('users/$userId/posts'); // No auth needed? Or depends on privacy settings
      if (data is List) {
        return data;
      } else {
        print('Unexpected response format for fetchUserPosts: $data');
        throw Exception('Unexpected response format received from server.');
      }
    } catch (e) {
      print('Error fetching posts for user profile $userId: $e');
      rethrow;
    }
  }


  // Create a new post
  Future<dynamic> createPost(int userId, String? contentText, String? imageUrl) async {
    try {
      // Send user_id in the request body as implemented in backend
      final data = await post('posts', {
        'user_id': userId,
        'content_text': contentText,
        'image_url': imageUrl,
      }, requiresAuth: true); // Auth definitely needed
      return data;
    } catch (e) {
      print('Error creating post: $e');
      rethrow;
    }
  }

  // Like a post
  Future<dynamic> likePost(int postId, int userId) async {
    try {
      // Send user_id in body for POST as implemented in backend
      final data = await post('posts/$postId/likes', {'user_id': userId}, requiresAuth: true);
      return data;
    } catch (e) {
      print('Error liking post $postId: $e');
      rethrow;
    }
  }

  // Unlike a post
  Future<dynamic> unlikePost(int postId, int userId) async {
    try {
      // Pass user_id as query parameter for DELETE as implemented in backend
      final data = await delete('posts/$postId/likes?user_id=$userId', requiresAuth: true);
      return data;
    } catch (e) {
      print('Error unliking post $postId: $e');
      rethrow;
    }
  }

  // Bookmark a post (save)
  Future<dynamic> bookmarkPost(int postId, int userId) async {
    try {
       // Send user_id in body for POST as implemented in backend
      final data = await post('posts/$postId/saved', {'user_id': userId}, requiresAuth: true);
      return data;
    } catch (e) {
      print('Error bookmarking post $postId: $e');
      rethrow;
    }
  }

  // Unbookmark a post (remove from saved)
  Future<dynamic> unbookmarkPost(int postId, int userId) async {
    try {
       // Pass user_id as query parameter for DELETE as implemented in backend
      final data = await delete('posts/$postId/saved?user_id=$userId', requiresAuth: true);
      return data;
    } catch (e) {
      print('Error unbookmarking post $postId: $e');
      rethrow;
    }
  }

    // Fetch saved posts for a user
  Future<List<dynamic>> fetchSavedPosts(int userId) async {
    try {
      // Auth needed to ensure user is fetching their own saved posts
      final data = await get('users/$userId/saved-posts', requiresAuth: true);
      if (data is List) {
        return data;
      } else {
        print('Unexpected response format for fetchSavedPosts: $data');
        throw Exception('Unexpected response format');
      }
    } catch (e) {
      print('Error fetching saved posts: $e');
      rethrow;
    }
  }

  // Create a new comment
  Future<dynamic> createComment(int userId, int postId, String commentText) async {
    try {
      // Send user_id in body as implemented in backend
      final data = await post('comments', {
        'user_id': userId,
        'post_id': postId,
        'comment_text': commentText,
      }, requiresAuth: true);
      return data;
    } catch (e) {
      print('Error creating comment for post $postId: $e');
      rethrow;
    }
  }

  // Fetch comments for a post
  Future<List<dynamic>> fetchComments(int postId) async {
    try {
      // Auth may not be needed if comments are public
      final data = await get('posts/$postId/comments');
      if (data is List) {
        return data;
      } else {
        print('Unexpected response format for fetchComments for post $postId: $data');
        throw Exception('Unexpected response format');
      }
    } catch (e) {
      print('Error fetching comments for post $postId: $e');
      rethrow;
    }
  }

  // Fetch chat summaries for the current user
  Future<List<dynamic>> fetchChatSummaries(int userId) async {
    try {
      // Auth needed to get specific user's chats
      // Backend endpoint was /api/users/{userId}/chats
      final data = await get('users/$userId/chats', requiresAuth: true);
      if (data is List) {
        return data;
      } else {
        print('Unexpected response format for fetchChatSummaries: $data');
        throw Exception('Unexpected response format');
      }
    } catch (e) {
      print('Error fetching chat summaries: $e');
      rethrow;
    }
  }

  // Fetch messages between two users
  Future<List<dynamic>> fetchMessages(int user1Id, int user2Id) async {
    try {
      // Auth needed to ensure the requesting user is one of the participants
      // Backend endpoint was /api/messages/<user1_id>/<user2_id>
      final data = await get('messages/$user1Id/$user2Id', requiresAuth: true);
      if (data is List) {
        return data;
      } else {
        print('Unexpected response format for fetchMessages: $data');
        throw Exception('Unexpected response format');
      }
    } catch (e) {
      print('Error fetching messages: $e');
      rethrow;
    }
  }

  // Send a new message
  Future<dynamic> sendMessage(int senderId, int receiverId, String messageText) async {
    try {
      // Auth needed, backend expects sender_id in body
      final data = await post('messages', {
        'sender_id': senderId,
        'receiver_id': receiverId,
        'message_text': messageText,
      }, requiresAuth: true);
      return data;
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Upload an image file to the backend
  Future<String?> uploadImage(File imageFile, int userId) async { // Add userId for potential backend logic/naming
    try {
       // Auth needed for uploads
      final uri = Uri.parse('$baseUrl/upload/image');
      final request = http.MultipartRequest('POST', uri);

      // Add auth header to multipart request
      // TODO: Replace with actual token retrieval
      String? token = null; // await SecureStorageService.getToken();
      if (token != null) {
         request.headers['Authorization'] = 'Bearer $token';
      } else {
         print("Warning: Auth required for image upload but no token found.");
         // Handle missing token if necessary
      }

      // Add the file
      request.files.add(await http.MultipartFile.fromPath(
          'image', // Field name expected by backend
          imageFile.path
      ));

      // Add other fields if needed (e.g., user_id)
      request.fields['user_id'] = userId.toString();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Add logging for the response
      print('Image Upload Response Status Code: ${response.statusCode}');
      print('Image Upload Response Body: ${response.body}');
      print('Image Upload Response Headers: ${response.headers}');


      // Use _handleResponse for consistency (it checks status codes)
      final data = _handleResponse(response);

      // Assuming _handleResponse throws on error, we just check the result
      if (data is Map && data.containsKey('imageUrl')) {
        return data['imageUrl']; // Return the image URL
      } else {
         print('Image Upload Response body did not contain imageUrl: $data');
         throw Exception('Image upload completed but no URL received.');
      }
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  // --- User / Profile Methods ---
  Future<Map<String, dynamic>> fetchUserProfile(String username) async {
     try {
       final data = await get('users/$username'); // Endpoint uses username
       if (data is Map<String, dynamic>) {
         return data;
       } else {
         print('Unexpected response format for fetchUserProfile: $data');
         throw Exception('Unexpected response format');
       }
     } catch (e) {
       print('Error fetching user profile for $username: $e');
       rethrow;
     }
   }

   // Fetch all users (excluding the current user)
   Future<List<dynamic>> fetchAllUsers(int currentUserId) async {
     try {
       // Assuming backend has an endpoint like /api/users that accepts a query parameter for the current user to exclude
       final data = await get('users?exclude_user_id=$currentUserId', requiresAuth: true); // Auth might be needed
       if (data is List) {
         return data;
       } else {
         print('Unexpected response format for fetchAllUsers: $data');
         throw Exception('Unexpected response format received from server.');
       }
     } catch (e) {
       print('Error fetching all users: $e');
       rethrow;
     }
   }


   // --- Follow / Unfollow ---
   Future<dynamic> followUser(int followerId, int followedId) async {
     try {
       final data = await post('follow', {
         'follower_user_id': followerId,
         'followed_user_id': followedId
       }, requiresAuth: true);
       return data;
     } catch (e) {
       print('Error following user $followedId: $e');
       rethrow;
     }
   }

   Future<dynamic> unfollowUser(int followerId, int followedId) async {
     try {
       final data = await delete(
         'follow?follower_user_id=$followerId&followed_user_id=$followedId',
         requiresAuth: true
       );
       return data;
     } catch (e) {
       print('Error unfollowing user $followedId: $e');
       rethrow;
     }
   }


}
