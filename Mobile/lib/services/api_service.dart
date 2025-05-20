import 'dart:async'; // For TimeoutException
import 'dart:convert';
import 'dart:io'; // File class for image upload
import 'package:http/http.dart' as http;
import 'package:solara/constants/api_constants.dart'; // Import ApiConstants
import 'secure_storage_service.dart'; // Import SecureStorageService
// No need for provider/UserState here, ID should come from calling function

class ApiService {
  // Ensure this IP is correct and your backend is running and accessible
  // Use the baseUrl from api_constants.dart for flexibility
  final String baseUrl = ApiEndpoints.baseUrl + '/api';

  // --- Helper Methods ---

  // Helper for adding Auth Headers (if token exists)
  Future<Map<String, String>> _getHeaders({bool requiresAuth = false, bool isJson = true}) async {
    Map<String, String> headers = {};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (requiresAuth) {
      print("[ApiService _getHeaders] Attempting to retrieve token...");
      String? token;
      try {
        token = await SecureStorageService.getToken().timeout(
          const Duration(seconds: 10), // 10-second timeout for token retrieval
          onTimeout: () {
            print("[ApiService _getHeaders] Timeout retrieving token from SecureStorageService.");
            throw TimeoutException('Token retrieval timed out.');
          },
        );
        if (token != null) {
          print("[ApiService _getHeaders] Token retrieved successfully.");
          headers['Authorization'] = 'Bearer $token';
        } else {
          print("[ApiService _getHeaders] Warning: No token found after retrieval attempt (SecureStorageService.getToken() returned null).");
        }
      } on TimeoutException catch (e) {
        print("[ApiService _getHeaders] Caught TimeoutException during token retrieval: $e");
        // Optionally rethrow or handle as a critical error
        throw e; // Rethrow to be caught by the calling function
      }
      catch (e) {
        print("[ApiService _getHeaders] Error retrieving token: $e");
        // Optionally throw an error or handle missing token case
        throw Exception('Failed to retrieve token: $e'); // Rethrow to be caught by the calling function
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
    print('[ApiService] _handleResponse called.'); // Added log
    print('[ApiService] Response Status Code: ${response.statusCode}'); // Added log
    print('[ApiService] Response Headers: ${response.headers}'); // Added log
    print('[ApiService] Response Body: ${response.body}'); // Added log

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.headers['content-type']?.contains('application/json') == true && response.body.isNotEmpty) {
         try {
           return json.decode(response.body);
         } catch (e) {
           print("[ApiService] JSON Decode Error: ${e.toString()} \nBody: ${response.body}"); // Modified log
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
      String responseBodyPreview = response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body; // Limit body preview

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
      // Include status code and a preview of the response body in the exception message
      throw Exception('API request failed with status ${response.statusCode}. Body: $responseBodyPreview');
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

  // Like a comment
  Future<dynamic> likeComment(int commentId, int userId) async {
    try {
      // Assuming backend endpoint is /api/comments/{commentId}/likes and expects user_id in body
      final data = await post('comments/$commentId/likes', {'user_id': userId}, requiresAuth: true);
      return data;
    } catch (e) {
      print('Error liking comment $commentId: $e');
      rethrow;
    }
  }

  // Unlike a comment
  Future<dynamic> unlikeComment(int commentId, int userId) async {
    try {
      // Assuming backend endpoint is /api/comments/{commentId}/likes and expects user_id as query parameter for DELETE
      final data = await delete('comments/$commentId/likes?user_id=$userId', requiresAuth: true);
      return data;
    } catch (e) {
      print('Error unliking comment $commentId: $e');
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
  Future<dynamic> createComment(int userId, int postId, String commentText, {int? parentCommentId}) async {
    try {
      // Send user_id and parent_comment_id (if provided) in body
      final Map<String, dynamic> requestBody = {
        'user_id': userId,
        'post_id': postId,
        'comment_text': commentText,
      };
      if (parentCommentId != null) {
        requestBody['parent_comment_id'] = parentCommentId;
      }

      final data = await post('comments', requestBody, requiresAuth: true);
      return data;
    } catch (e) {
      print('Error creating comment for post $postId: $e');
      rethrow;
    }
  }

  // Fetch comments for a post
  Future<List<dynamic>> fetchComments(int postId) async {
    try {
      // Auth is now needed to get the current user's like status for comments
      final data = await get('posts/$postId/comments', requiresAuth: true); // Set requiresAuth to true
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
      String? token = await SecureStorageService.getToken(); // await SecureStorageService.getToken();
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

  Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    required String username,
    File? profileImageFile,
    required String currentProfileImageUrl, // To send if no new image is uploaded
  }) async {
    print('[ApiService] updateUserProfile: Called for userId: $userId, username: $username, hasFile: ${profileImageFile != null}');
    try {
      String? finalProfileImageUrl = currentProfileImageUrl;

      if (profileImageFile != null) {
        print('[ApiService] updateUserProfile: Profile image file provided. Attempting to upload...');
        try {
          String? uploadedImageUrl = await uploadImage(profileImageFile, userId);
          if (uploadedImageUrl != null) {
            finalProfileImageUrl = uploadedImageUrl;
            print('[ApiService] updateUserProfile: Image uploaded successfully. New URL: $finalProfileImageUrl');
          } else {
            print('[ApiService] updateUserProfile: Warning - Profile image upload returned null. Using current image URL: $currentProfileImageUrl');
          }
        } catch (e) {
          print('[ApiService] updateUserProfile: Error during image upload: $e. Proceeding with current image URL.');
          // Decide if you want to throw here or proceed with old image
          // For now, proceeding with old/current image URL
        }
      } else {
        print('[ApiService] updateUserProfile: No new profile image file provided.');
      }

      final Map<String, dynamic> requestBody = {
        'username': username,
        'profile_image_url': finalProfileImageUrl, // This will be either the new URL or the current one
      };
      print('[ApiService] updateUserProfile: Preparing to send PUT request to users/$userId/profile with body: $requestBody');

      final uri = Uri.parse('$baseUrl/users/$userId/profile');
      print('[ApiService updateUserProfile] Attempting http.put to $uri');
      final response = await http.put(
        uri,
        headers: await _getHeaders(requiresAuth: true, isJson: true), // Ensure headers are fetched for PUT
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 20), onTimeout: () {
        print('[ApiService updateUserProfile] PUT request timed out.');
        throw TimeoutException('The request to update profile timed out.');
      });
      print('[ApiService updateUserProfile] http.put call finished. Status: ${response.statusCode}');

      final data = _handleResponse(response);
      print('[ApiService] updateUserProfile: PUT request processed by _handleResponse. Response data: $data');

      if (data is Map<String, dynamic>) {
        return data;
      } else if (data == null && _handleResponseImpliesSuccessForNull(data)) { // Assuming 204 No Content is success
         print('[ApiService] updateUserProfile: PUT request returned null, considering it success (e.g. 204 No Content).');
        return {'success': true, 'message': 'Profile updated successfully (no content returned)'};
      }
       else {
        print('[ApiService] updateUserProfile: Unexpected response format: $data');
        throw Exception('Unexpected response format received from server after profile update.');
      }
    } catch (e, stackTrace) {
      print('[ApiService] updateUserProfile: Error updating user profile for user $userId: $e');
      print('[ApiService] updateUserProfile: StackTrace: $stackTrace');
      rethrow;
    }
  }

  // Helper to check if a null response from _handleResponse should be treated as success
  // This is a placeholder, you might need to adjust based on how _handleResponse actually behaves for 204
  bool _handleResponseImpliesSuccessForNull(dynamic data) {
    // If _handleResponse returns null for 204 (No Content), which is often a success for PUT.
    // This depends on the implementation of _handleResponse.
    // For now, let's assume null means it was a 204.
    return data == null;
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

   // Fetch user profile by user ID
   Future<Map<String, dynamic>> getUserProfile(int userId) async {
     try {
       // The backend endpoint /api/users/{userId} requires authentication.
       // Ensure requiresAuth is true to include the JWT token.
       final data = await get('users/$userId', requiresAuth: true); // Assuming backend endpoint is /api/users/{userId}
       if (data is Map<String, dynamic>) {
         return data;
       } else {
         print('Unexpected response format for getUserProfile: $data');
         throw Exception('Unexpected response format');
       }
     } catch (e) {
       print('Error fetching user profile for user ID $userId: $e');
       rethrow;
     }
   }

   // Update user's privacy status
   Future<dynamic> updatePrivacyStatus(bool isPrivate) async {
     try {
       // Backend endpoint is /api/users/me/privacy and expects {'is_private': bool}
       // Using 'me' assumes the backend identifies the user from the auth token
       final data = await put('users/me/privacy', {'is_private': isPrivate}, requiresAuth: true);
       return data;
     } catch (e) {
       print('Error updating privacy status: $e');
       rethrow;
     }
   }


   // --- Follow / Unfollow / Follow Requests ---
   Future<dynamic> followUser(int followedId) async {
     try {
       // The backend now determines if it's a direct follow or a request
       // We only need to send the ID of the user being followed.
       // The follower ID is obtained from the JWT on the backend.
       final data = await post('follow', {
         'followed_user_id': followedId
       }, requiresAuth: true);
       return data; // This will return either {'follow_id': ...} or {'follow_request_id': ...}
     } catch (e) {
       print('Error attempting to follow user $followedId: $e');
       rethrow;
     }
   }

   Future<dynamic> unfollowUser(int followedId) async {
     try {
       // The follower ID is obtained from the JWT on the backend.
       // We only need to send the ID of the user being unfollowed as a query parameter.
       final data = await delete(
         'follow?followed_user_id=$followedId',
         requiresAuth: true
       );
       return data;
     } catch (e) {
       print('Error unfollowing user $followedId: $e');
       rethrow;
     }
   }

   // Fetch follow requests for the current user
   Future<List<dynamic>> fetchFollowRequests() async {
     try {
       // Backend endpoint is /api/users/me/follow_requests
       final data = await get('users/me/follow_requests', requiresAuth: true);
       if (data is List) {
         return data;
       } else {
         print('Unexpected response format for fetchFollowRequests: $data');
         throw Exception('Unexpected response format');
       }
     } catch (e) {
       print('Error fetching follow requests: $e');
       rethrow;
     }
   }

   // Accept a follow request
   Future<dynamic> acceptFollowRequest(int requestId) async {
     try {
       // Backend endpoint is /api/follow_requests/<request_id>/accept
       final data = await put('follow_requests/$requestId/accept', {}, requiresAuth: true); // Send empty body
       return data; // Returns success message or error
     } catch (e) {
       print('Error accepting follow request $requestId: $e');
       rethrow;
     }
   }

   // Reject a follow request
   Future<dynamic> rejectFollowRequest(int requestId) async {
     try {
       // Backend endpoint is /api/follow_requests/<request_id>/reject
       final data = await put('follow_requests/$requestId/reject', {}, requiresAuth: true); // Send empty body
       return data; // Returns success message or error
     } catch (e) {
       print('Error rejecting follow request $requestId: $e');
       rethrow;
     }
   }

   // Fetch followers for a user
   Future<List<dynamic>> fetchFollowers(int userId) async {
     try {
       // Assuming backend endpoint is users/{userId}/followers
       final data = await get('users/$userId/followers', requiresAuth: true); // Auth might be needed
       if (data is List) {
         return data;
       } else {
         print('Unexpected response format for fetchFollowers: $data');
         throw Exception('Unexpected response format received from server.');
       }
     } catch (e) {
       print('Error fetching followers for user $userId: $e');
       rethrow;
     }
   }

   // Fetch users that a user is following
   Future<List<dynamic>> fetchFollowing(int userId) async {
     try {
       // Assuming backend endpoint is users/{userId}/following
       final data = await get('users/$userId/following', requiresAuth: true); // Auth might be needed
       if (data is List) {
         return data;
       } else {
         print('Unexpected response format for fetchFollowing: $data');
         throw Exception('Unexpected response format received from server.');
       }
     } catch (e) {
       print('Error fetching following for user $userId: $e');
       rethrow;
     }
   }

   // Search for users by username
   Future<List<dynamic>> searchUsers(String query, int currentUserId) async {
     try {
       // Assuming backend has an endpoint like /api/users/search that accepts query and exclude_user_id
       final data = await get('users/search?query=$query&exclude_user_id=$currentUserId', requiresAuth: true); // Auth might be needed
       if (data is List) {
         return data;
       } else {
         print('Unexpected response format for searchUsers: $data');
         throw Exception('Unexpected response format received from server.');
       }
     } catch (e) {
       print('Error searching users: $e');
       rethrow;
     }
   }

  // Fetch notifications for a user
  Future<List<dynamic>> fetchNotifications(int userId) async {
    print('[ApiService] fetchNotifications called for userId: $userId'); // Added logging
    try {
      // Check token before making the call
      final token = await SecureStorageService.getToken();
      print('[ApiService] fetchNotifications - Token status: ${token != null ? "Found" : "Not Found"}'); // Added logging

      final data = await get('users/$userId/notifications', requiresAuth: true);

      // Log response details from _handleResponse
      print('[ApiService] fetchNotifications - API response received.'); // Added logging
      // Note: _handleResponse already prints status code and body on error.
      // We can add more specific success logging here if needed, but _handleResponse
      // returning data implies success.

      if (data is List) {
        print('[ApiService] fetchNotifications - Response data is a List with ${data.length} items.'); // Added logging
        // Add logging to inspect each item before filtering
        for (var i = 0; i < data.length; i++) {
            print('[ApiService] fetchNotifications - Item $i: ${data[i]}');
        }
        // Filter out items that are not valid notifications or follow requests
        final filteredNotifications = data.where((item) {
          // Check if item is a Map
          if (item is! Map) {
            print('[ApiService] fetchNotifications - Filtering out item (not a Map): $item'); // Added logging
            return false;
          }
          // Check if it's a standard notification with notification_id
          if (item.containsKey('notification_id') && item['notification_id'] is int && item['notification_id'] != null) {
            print('[ApiService] fetchNotifications - Keeping item (standard notification): $item'); // Added logging
            return true;
          }
          // Check if it's a follow request notification with type 'follow_request' and request_id
          if (item.containsKey('type') && item['type'] == 'follow_request' && item.containsKey('follow_request_id') && item['follow_request_id'] is int && item['follow_request_id'] != null) {
             print('[ApiService] fetchNotifications - Keeping item (follow request notification): $item'); // Added logging
             return true;
          }
          // Otherwise, it's not a valid item to display
          print('[ApiService] fetchNotifications - Filtering out item (invalid type or missing ID): $item'); // Added logging
          return false;
        }).toList();
        print('[ApiService] fetchNotifications - Filtered ${data.length - filteredNotifications.length} invalid items.'); // Added logging
        return filteredNotifications;
      } else {
        print('[ApiService] fetchNotifications - Unexpected response format: $data'); // Added logging
        throw Exception('Unexpected response format');
      }
    } catch (e) {
      print('[ApiService] Error fetching notifications for user $userId: $e'); // Added logging
      rethrow;
    }
  }

  // Mark a notification as read
  Future<dynamic> markNotificationAsRead(int notificationId) async {
    try {
      // Backend expects PUT to /api/notifications/<notification_id>/read
      final data = await put('notifications/$notificationId/read', {}, requiresAuth: true); // Send empty body
      return data; // Returns success message or error
    } catch (e) {
      print('Error marking notification $notificationId as read: $e');
      rethrow;
    }
  }

  // Delete a notification
  Future<dynamic> deleteNotification(int notificationId) async {
    try {
      // Backend expects DELETE to /api/notifications/<notification_id>
      final data = await delete('notifications/$notificationId', requiresAuth: true);
      return data; // Returns success message or error
    } catch (e) {
      print('Error deleting notification $notificationId: $e');
      rethrow;
    }
  }

  // Mark a notification as deleted (sets is_deleted to true)
  Future<dynamic> markNotificationAsDeleted(int notificationId) async {
    try {
      // Assuming backend endpoint is PUT /api/notifications/<notification_id>/delete
      final data = await put('notifications/$notificationId/delete', {}, requiresAuth: true); // Send empty body
      return data; // Returns success message or error
    } catch (e) {
      print('Error marking notification $notificationId as deleted: $e');
      rethrow;
    }
  }
}
