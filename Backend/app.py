from flask import Flask, render_template, request, jsonify
import os
from flask_cors import CORS
import bcrypt
from flask import Flask, render_template, request, jsonify, make_response # Import make_response and request
# Import all necessary functions from db_utils
from db_utils import (
    create_user, get_user_by_username_or_email, create_post, create_follow,
    create_like, create_comment, create_saved_post, create_message,
    create_notification, update_user_settings,
    get_user_by_id, get_all_posts, get_posts_by_user_id, get_likes_for_post,
    get_comments_for_post, get_messages_between_users, get_saved_posts_for_user,
    get_followers_for_user, get_following_for_user, get_user_settings,
    get_chat_summaries_for_user,
    delete_follow,
    get_notifications_for_user,
    mark_notification_as_read,
    get_home_feed_posts, # <-- YENİ IMPORT: Ana sayfa akışı için
    # İleride gerekirse: delete_like, delete_saved_post
    delete_like, # <-- Beğeniyi kaldırmak için (varsayımsal)
    delete_saved_post, # <-- Kaydedileni kaldırmak için (varsayımsal)
    get_post_like_count, # <-- Import the new function
    search_users # <-- Import the new function
)

# Varsayımsal: Beğeniyi ve kaydedileni kaldırma fonksiyonları db_utils'da olmalı
# Eğer yoksa, bunları db_utils.py içine eklemelisin.
# Örnek (db_utils.py içine eklenecek):
# def delete_like(user_id, post_id):
#     # ... DELETE FROM likes WHERE user_id = %s AND post_id = %s ...
#     return True # veya False
#
# def delete_saved_post(user_id, post_id):
#     # ... DELETE FROM saved_posts WHERE user_id = %s AND post_id = %s ...
#     return True # veya False


# Tell Flask where to find the templates and static files relative to this script
app = Flask(__name__, template_folder='../Web/templates', static_folder='../Web/static')
CORS(app) # This line allows requests from all origins (for development)

@app.after_request
def add_header(response):
    """
    Add headers to disable caching for static files during development.
    """
    # Apply no-cache headers to static files and API endpoints
    if request.path.startswith('/static/') or request.path.startswith('/api/'):
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
    return response

# --- Helper function to get user ID (Temporary for demonstration) ---
def get_current_user_id():
    # In a real app, this would involve token validation (JWT etc.)
    # For this task, we'll try to get it from a cookie or a query parameter
    user_id = request.cookies.get('user_id')
    if user_id:
        try:
            return int(user_id)
        except ValueError:
            return None # Invalid cookie value
    # Fallback for testing via query parameter (less secure)
    user_id = request.args.get('user_id')
    if user_id:
         try:
            return int(user_id)
         except ValueError:
            return None # Invalid query param value
    return None # No user ID found

# --- Web Page Routes ---

@app.route('/')
def signup_page():
    return render_template('signup.html')

@app.route('/login')
def login_page():
    return render_template('login.html')

@app.route('/forgot_password')
def forgot_password_page():
    return render_template('forgot_password.html')


@app.route('/home')
def home_page():
    user_id = get_current_user_id()
    if not user_id:
        return redirect(url_for('login_page')) # Redirect to login if not authenticated

    # TODO: Implement fetching personalized feed based on user_id
    # For now, still fetching all posts or implement get_home_feed_posts properly
    posts = get_all_posts() # Or get_home_feed_posts(user_id) if implemented
    return render_template('home.html', posts=posts)

@app.route('/messages')
def messages_page():
    # TODO: Web mesajları için kullanıcı oturumu gerektirir.
    # For now, just render the template. Frontend JS will handle fetching data
    # based on the user_id it obtains (e.g., from cookie).
    user_id = get_current_user_id()
    if not user_id:
        return redirect(url_for('login_page')) # Redirect to login if not authenticated
    return render_template('messages.html', current_user_id=user_id) # Pass user_id to the template

@app.route('/profile')
def profile_page():
    user_id = get_current_user_id()
    print(f"--- /profile route: Retrieved user_id from cookie/args: {user_id} ---") # Added logging
    if not user_id:
        print("--- /profile route: No user_id found, redirecting to login. ---") # Added logging
        return redirect(url_for('login_page')) # Redirect to login if not authenticated

    # Fetch the user data for the profile page
    user = get_user_by_id(user_id)
    print(f"--- /profile route: Result of get_user_by_id({user_id}): {user} ---") # Added logging
    if not user:
        # Handle case where user is not found (shouldn't happen if user_id comes from auth)
        print(f"--- /profile route: User with ID {user_id} not found. ---") # Added logging
        return jsonify({"error": "User not found"}), 404 # Or redirect to an error page

    # TODO: Web profili için URL'den username alınmalı ve o kullanıcının profili gösterilmeli.
    # Şu an sadece oturum açmış kullanıcının profilini gösteriyoruz.
    return render_template('profile.html', user=user, current_user_id=user_id)

@app.route('/create_post')
def create_post_page():
    # TODO: Web için kullanıcı oturumu kontrolü ekle
    return render_template('create_post.html')

@app.route('/settings')
def settings_page():
    # TODO: Web için kullanıcı oturumu kontrolü ekle
    return render_template('settings.html')

@app.route('/discover')
def discover_page():
    # TODO: Web keşfet sayfası için kullanıcı oturumu kontrolü ekle
    # ve keşfedilecek içerikleri getir.
    return render_template('discover.html')

@app.route('/notifications')
def notifications_page():
    # TODO: Web bildirimler sayfası için kullanıcı oturumu kontrolü ekle
    # ve kullanıcının bildirimlerini getir.
    return render_template('notifications.html')


# --- API Endpoints for Mobile and Web ---

# Remove the old placeholder helper function
# def get_user_id_from_token(auth_header):
#     return None

@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.get_json()
    username_or_email = data.get('username_or_email')
    password = data.get('password')

    if not username_or_email or not password:
        return jsonify({'success': False, 'message': 'Missing username/email or password'}), 400

    user = get_user_by_username_or_email(username_or_email)

    if user and bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
        # In production, generate a real JWT token here
        token = f"fake_token_for_user_{user['user_id']}" # Replace with actual token

        # Create a response object to set the cookie
        response = make_response(jsonify({
            'success': True,
            'message': 'Login successful',
            'user': {
                'user_id': user['user_id'],
                'username': user['username'],
                'email': user['email'],
                'full_name': user.get('full_name'),
                'profile_picture_url': user.get('profile_picture_url'),
                'created_at': user['created_at'],
                'updated_at': user['updated_at']
            },
            'token': token # Send the generated token
        }), 200)

        # Set a simple user_id cookie for demonstration purposes
        response.set_cookie('user_id', str(user['user_id']), httponly=True, samesite='Lax') # Add samesite='Lax'

        return response
    else:
        return jsonify({'success': False, 'message': 'Invalid username/email or password'}), 401

@app.route('/api/signup', methods=['POST'])
def api_signup():
    data = request.get_json()
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')
    full_name = data.get('full_name')
    profile_picture_url = data.get('profile_picture_url')

    if not username or not email or not password:
        return jsonify({'success': False, 'message': 'Missing username, email, or password'}), 400

    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())

    # Assuming create_user now only takes mandatory fields
    # Update create_user in db_utils if it should handle optional fields directly
    user_id = create_user(username, email, hashed_password.decode('utf-8'))

    if user_id:
        # In production, generate a real JWT token here
        token = f"fake_token_for_user_{user_id}" # Replace with actual token

        # Optionally update full_name and profile_picture_url if provided
        # You might need an update_user function in db_utils
        # update_user(user_id, full_name=full_name, profile_picture_url=profile_picture_url)

        # Create default settings
        update_user_settings(user_id)

        # Create a response object to set the cookie
        response = make_response(jsonify({
            'success': True,
            'message': 'Account created successfully',
            'user': { # Return basic user info needed after signup
                'user_id': user_id,
                'username': username,
                'email': email,
                'full_name': full_name,
                'profile_picture_url': profile_picture_url
            },
            'token': token # Send the generated token
        }), 201)

        # Set a simple user_id cookie for demonstration purposes
        response.set_cookie('user_id', str(user_id), httponly=True, samesite='Lax') # Add samesite='Lax'

        return response
    else:
        # This assumes create_user returns None on failure (e.g., duplicate user)
        return jsonify({'success': False, 'message': 'Username or email already exists'}), 409

# --- Post Endpoints ---

@app.route('/api/posts', methods=['POST'])
def api_create_post():
    # --- Get User ID ---
    user_id = get_current_user_id()
    if not user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    data = request.get_json()
    # user_id is now obtained from get_current_user_id(), remove from body expectation
    # user_id = data.get('user_id')
    # if not user_id:
    #     return jsonify({'success': False, 'message': 'Missing user_id in request body'}), 400
    # try:
    #     user_id = int(user_id)
    # except ValueError:
    #     return jsonify({'success': False, 'message': 'Invalid user_id in request body'}), 400
    # --- End Old User ID Handling ---

    content_text = data.get('content_text')
    image_url = data.get('image_url')

    if not content_text and not image_url:
        return jsonify({'success': False, 'message': 'Post must have content text or an image'}), 400

    post_id = create_post(user_id, content_text, image_url) # Use authenticated user_id

    if post_id:
        # Fetch the created post to return it (optional but good practice)
        # new_post = get_post_by_id(post_id) # Requires get_post_by_id in db_utils
        return jsonify({'success': True, 'message': 'Post created successfully', 'post_id': post_id}), 201
    else:
        return jsonify({'success': False, 'message': 'Failed to create post'}), 500

@app.route('/api/posts', methods=['GET'])
def api_get_home_feed_posts():
    # --- Get User ID ---
    user_id = get_current_user_id()
    if not user_id:
       return jsonify({"error": "Authentication required"}), 401
    # --- End Get User ID ---

    # user_id is now obtained from get_current_user_id(), remove from query param expectation
    # user_id = request.args.get('user_id')
    # if not user_id:
    #     return jsonify({"error": "Missing user_id query parameter for home feed"}), 400
    # try:
    #     user_id = int(user_id)
    # except ValueError:
    #     return jsonify({"error": "Invalid user_id query parameter"}), 400
    # --- End Old User ID Handling ---

    # Use the new function to get the personalized feed
    posts = get_home_feed_posts(user_id)

    # TODO: Enhance get_home_feed_posts or process here to add 'is_liked' and 'is_saved' status for the requesting user (user_id)
    # Example (if added to get_home_feed_posts):
    # for post in posts:
    #     post['is_liked'] = post.pop('is_liked_by_current_user', False) # Rename/default
    #     post['is_saved'] = post.pop('is_saved_by_current_user', False) # Rename/default

    return jsonify(posts), 200

# --- User Endpoints (General) ---

@app.route('/api/users', methods=['GET'])
def api_get_all_users():
    # --- Get User ID (Optional, depending on if user list is public) ---
    # If you want to exclude the current user from the list, get their ID
    requesting_user_id = get_current_user_id()
    # If you want to require authentication to see the user list:
    # if not requesting_user_id:
    #    return jsonify({"error": "Authentication required"}), 401
    # --- End Get User ID ---

    # Get the exclude_user_id from query parameters (still allow excluding others)
    exclude_user_id_str = request.args.get('exclude_user_id')
    exclude_user_id = None
    if exclude_user_id_str:
        try:
            exclude_user_id = int(exclude_user_id_str)
        except ValueError:
            return jsonify({"error": "Invalid exclude_user_id query parameter"}), 400

    # If no exclude_user_id is provided in query params, but user is authenticated,
    # exclude the current user by default.
    if exclude_user_id is None and requesting_user_id is not None:
        exclude_user_id = requesting_user_id

    # Assuming get_all_users exists in db_utils and can take exclude_user_id
    # Get the exclude_user_id from query parameters
    exclude_user_id_str = request.args.get('exclude_user_id')
    exclude_user_id = None
    if exclude_user_id_str:
        try:
            exclude_user_id = int(exclude_user_id_str)
        except ValueError:
            return jsonify({"error": "Invalid exclude_user_id query parameter"}), 400

    print(f"--- Attempting to fetch all users (exclude_user_id: {exclude_user_id}) ---")
    try:
        # Use the actual get_all_users function from db_utils
        users = get_all_users(exclude_user_id=exclude_user_id)
        print(f"--- Successfully fetched {len(users)} users ---")
        return jsonify(users), 200
    except Exception as e:
        print(f"!!! Error fetching all users: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({"error": "Failed to fetch users"}), 500

# --- User Search Endpoint ---
@app.route('/api/users/search', methods=['GET'])
def api_search_users():
    # --- Get User ID (Optional, to exclude current user from search results) ---
    requesting_user_id = get_current_user_id()
    # --- End Get User ID ---

    search_query = request.args.get('query')
    if not search_query:
        return jsonify({"error": "Missing 'query' parameter"}), 400

    exclude_user_id_str = request.args.get('exclude_user_id')
    exclude_user_id = None
    if exclude_user_id_str:
        try:
            exclude_user_id = int(exclude_user_id_str)
        except ValueError:
            return jsonify({"error": "Invalid exclude_user_id query parameter"}), 400

    # If no exclude_user_id is provided in query params, but user is authenticated,
    # exclude the current user by default.
    if exclude_user_id is None and requesting_user_id is not None:
        exclude_user_id = requesting_user_id


    print(f"--- Attempting to search users for query: '{search_query}' (exclude_user_id: {exclude_user_id}) ---")
    try:
        # Use the actual search_users function from db_utils, passing the correct keyword argument
        users = search_users(search_query, current_user_id=exclude_user_id)
        print(f"--- Successfully found {len(users)} users for query '{search_query}' ---")
        return jsonify(users), 200
    except Exception as e:
        print(f"!!! Error searching users: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({"error": "Failed to search users"}), 500


@app.route('/api/posts/<int:post_id>', methods=['GET'])
def api_get_post(post_id):
    # TODO: Implement get_post_by_id(post_id) in db_utils
    # For now, returning a placeholder or error
    return jsonify({"error": "Get post by ID endpoint not fully implemented yet"}), 501 # Not Implemented

@app.route('/api/users/<int:user_id>/posts', methods=['GET'])
def api_get_user_posts(user_id):
    # This endpoint gets posts specifically for a user's profile
    current_user_id = get_current_user_id() # Get the ID of the currently logged-in user
    posts = get_posts_by_user_id(user_id, current_user_id) # Pass current_user_id to get like/save status
    return jsonify(posts), 200

# --- Like Endpoints ---

@app.route('/api/posts/<int:post_id>/likes', methods=['POST'])
def api_like_post(post_id):
    # --- Get User ID ---
    user_id = get_current_user_id()
    if not user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    # user_id is now obtained from get_current_user_id(), remove from body expectation
    # data = request.get_json()
    # user_id = data.get('user_id') # Expecting user_id in body for POST
    # if not user_id:
    #     return jsonify({'success': False, 'message': 'Missing user_id in request body'}), 400
    # try:
    #     user_id = int(user_id)
    # except ValueError:
    #     return jsonify({'success': False, 'message': 'Invalid user_id in request body'}), 400
    # --- End Old User ID Handling ---

    try:
        like_id = create_like(user_id, post_id)
        if like_id:
            # Fetch the updated like count
            updated_like_count = get_post_like_count(post_id)
            return jsonify({'success': True, 'message': 'Post liked', 'like_id': like_id, 'likes_count': updated_like_count}), 201
        else:
            # Could be duplicate like (UniqueViolation) or other error
            return jsonify({'success': False, 'message': 'Failed to like post (maybe already liked?)'}), 409 # Conflict or 500
    except Exception as e:
        print(f"!!! Unexpected error in api_like_post: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': 'An internal error occurred'}), 500


@app.route('/api/posts/<int:post_id>/likes', methods=['DELETE'])
def api_unlike_post(post_id):
    # --- Get User ID ---
    user_id = get_current_user_id()
    if not user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    # user_id is now obtained from get_current_user_id(), remove from query param expectation
    # user_id = request.args.get('user_id') # Expecting user_id in query params for DELETE
    # if not user_id:
    #     return jsonify({'success': False, 'message': 'Missing user_id query parameter'}), 400
    # try:
    #     user_id = int(user_id)
    # except ValueError:
    #     return jsonify({'success': False, 'message': 'Invalid user_id query parameter'}), 400
    # --- End Old User ID Handling ---

    try:
        # Assumes db_utils.delete_like(user_id, post_id) exists
        success = delete_like(user_id, post_id)
        if success:
            # Fetch the updated like count
            updated_like_count = get_post_like_count(post_id)
            return jsonify({'success': True, 'message': 'Post unliked', 'likes_count': updated_like_count}), 200
        else:
            return jsonify({'success': False, 'message': 'Failed to unlike post (like not found?)'}), 404 # Not Found or 500
    except Exception as e:
        print(f"!!! Unexpected error in api_unlike_post: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': 'An internal error occurred'}), 500


@app.route('/api/posts/<int:post_id>/likes', methods=['GET'])
def api_get_post_likes(post_id):
    # Returns users who liked the post
    likes = get_likes_for_post(post_id)
    return jsonify(likes), 200

# --- Comment Endpoints ---

@app.route('/api/posts/<int:post_id>/comments', methods=['GET'])
def api_get_post_comments(post_id):
    comments = get_comments_for_post(post_id)
    return jsonify(comments), 200

@app.route('/api/comments', methods=['POST'])
def api_create_comment():
    # --- Get User ID ---
    user_id = get_current_user_id()
    if not user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    data = request.get_json()
    # user_id is now obtained from get_current_user_id(), remove from body expectation
    # user_id = data.get('user_id') # Expecting user_id in body
    # if not user_id:
    #     return jsonify({'success': False, 'message': 'Missing user_id in request body'}), 400
    # try:
    #     user_id = int(user_id)
    # except ValueError:
    #     return jsonify({'success': False, 'message': 'Invalid user_id in request body'}), 400
    # --- End Old User ID Handling ---

    post_id = data.get('post_id')
    comment_text = data.get('comment_text')

    if not post_id or not comment_text:
        return jsonify({'success': False, 'message': 'Missing post_id or comment_text'}), 400
    try:
        post_id = int(post_id)
    except ValueError:
         return jsonify({'success': False, 'message': 'Invalid post_id'}), 400


    comment_id = create_comment(user_id, post_id, comment_text) # Use authenticated user_id

    if comment_id:
        # Optionally, fetch the created comment to return it
        # comment = get_comment_by_id(comment_id) # Need this function in db_utils
        return jsonify({'success': True, 'message': 'Comment created successfully', 'comment_id': comment_id}), 201
    else:
        return jsonify({'success': False, 'message': 'Failed to create comment'}), 500

# --- Follow Endpoints ---

@app.route('/api/follow', methods=['POST'])
def api_create_follow():
    # --- Get User ID ---
    follower_user_id = get_current_user_id() # The user performing the action
    if not follower_user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    data = request.get_json()
    # follower_user_id is now obtained from get_current_user_id(), remove from body expectation
    # follower_user_id = data.get('follower_user_id') # Expect follower_user_id in body
    # if not follower_user_id:
    #     return jsonify({'success': False, 'message': 'Missing follower_user_id in request body'}), 400
    # try:
    #     follower_user_id = int(follower_user_id)
    # except ValueError:
    #     return jsonify({'success': False, 'message': 'Invalid follower_user_id in request body'}), 400
    # --- End Old User ID Handling ---

    followed_user_id = data.get('followed_user_id') # The user being followed

    if not followed_user_id:
        return jsonify({'success': False, 'message': 'Missing followed_user_id'}), 400
    try:
        followed_user_id = int(followed_user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid followed_user_id'}), 400

    if follower_user_id == followed_user_id:
         return jsonify({'success': False, 'message': 'User cannot follow themselves'}), 400

    follow_id = create_follow(follower_user_id, followed_user_id)

    if follow_id:
        # TODO: Create a notification for the followed user
        # create_notification(followed_user_id, follower_user_id, 'follow')
        return jsonify({'success': True, 'message': 'Follow relationship created', 'follow_id': follow_id}), 201
    else:
        # Might fail if the relationship already exists (UniqueViolation)
        return jsonify({'success': False, 'message': 'Failed to create follow relationship (might already exist)'}), 409 # Conflict or 500

@app.route('/api/follow', methods=['DELETE'])
def api_delete_follow():
    # --- Get User ID ---
    follower_user_id = get_current_user_id() # The user performing the action
    if not follower_user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    # follower_user_id is now obtained from get_current_user_id(), remove from query param expectation
    # follower_user_id = request.args.get('follower_user_id') # Expecting user_id in query params for DELETE
    # if not follower_user_id:
    #     return jsonify({'success': False, 'message': 'Missing follower_user_id query parameter'}), 400
    # try:
    #     follower_user_id = int(follower_user_id)
    # except ValueError:
    #     return jsonify({'success': False, 'message': 'Invalid follower_user_id query parameter'}), 400
    # --- End Old User ID Handling ---

    followed_user_id = request.args.get('followed_user_id') # The user being unfollowed

    if not followed_user_id:
        return jsonify({'success': False, 'message': 'Missing followed_user_id query parameter'}), 400
    try:
        followed_user_id = int(followed_user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid followed_user_id query parameter'}), 400

    success = delete_follow(follower_user_id, followed_user_id)

    if success:
        return jsonify({'success': True, 'message': 'Follow relationship deleted'}), 200
    else:
        return jsonify({'success': False, 'message': 'Follow relationship not found or failed to delete'}), 404 # Not Found or 500

@app.route('/api/users/<int:user_id>/followers', methods=['GET'])
def api_get_followers(user_id):
    followers = get_followers_for_user(user_id)
    return jsonify(followers), 200

@app.route('/api/users/<int:user_id>/following', methods=['GET'])
def api_get_following(user_id):
    following = get_following_for_user(user_id)
    return jsonify(following), 200

# --- Suggested Users Endpoint ---
@app.route('/api/suggested_users', methods=['GET'])
def api_get_suggested_users():
    # --- Get User ID ---
    current_user_id = get_current_user_id()
    if not current_user_id:
       return jsonify({"error": "Authentication required"}), 401
    # --- End Get User ID ---

    # Explicitly import here for debugging NameError
    from db_utils import get_suggested_users, is_following_user

    suggested_users = get_suggested_users(current_user_id)

    # Check follow status for each suggested user
    for user in suggested_users:
        user['is_following'] = is_following_user(current_user_id, user['user_id'])

    return jsonify(suggested_users), 200


# --- Saved Post (Bookmark) Endpoints ---

@app.route('/api/posts/<int:post_id>/saved', methods=['POST'])
def api_save_post(post_id):
    # --- Get User ID ---
    user_id = get_current_user_id()
    if not user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    # user_id is now obtained from get_current_user_id(), remove from body expectation
    # data = request.get_json()
    # user_id = data.get('user_id') # Expecting user_id in body for POST
    # if not user_id:
    #     return jsonify({'success': False, 'message': 'Missing user_id in request body'}), 400
    # try:
    #     user_id = int(user_id)
    # except ValueError:
    #     return jsonify({'success': False, 'message': 'Invalid user_id in request body'}), 400
    # --- End Old User ID Handling ---

    try:
        saved_post_id = create_saved_post(user_id, post_id)
        if saved_post_id:
            return jsonify({'success': True, 'message': 'Post saved', 'saved_post_id': saved_post_id}), 201
        else:
            return jsonify({'success': False, 'message': 'Failed to save post (maybe already saved?)'}), 409 # Conflict or 500
    except Exception as e:
        print(f"!!! Unexpected error in api_save_post: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': 'An internal error occurred'}), 500


@app.route('/api/posts/<int:post_id>/saved', methods=['DELETE'])
def api_unsave_post(post_id):
    # --- Get User ID ---
    user_id = get_current_user_id()
    if not user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    # user_id is now obtained from get_current_user_id(), remove from query param expectation
    # user_id = request.args.get('user_id') # Expecting user_id in query params for DELETE
    # if not user_id:
    #     return jsonify({'success': False, 'message': 'Missing user_id query parameter'}), 400
    # try:
    #     user_id = int(user_id)
    # except ValueError:
    #     return jsonify({'success': False, 'message': 'Invalid user_id query parameter'}), 400
    # --- End Old User ID Handling ---

    try:
        # Assumes db_utils.delete_saved_post(user_id, post_id) exists
        success = delete_saved_post(user_id, post_id)
        if success:
            return jsonify({'success': True, 'message': 'Post unsaved'}), 200
        else:
            return jsonify({'success': False, 'message': 'Failed to unsave post (save record not found?)'}), 404 # Not Found or 500
    except Exception as e:
        print(f"!!! Unexpected error in api_unsave_post: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': 'An internal error occurred'}), 500


@app.route('/api/users/<int:user_id>/saved-posts', methods=['GET'])
def api_get_saved_posts(user_id):
    # --- Auth Check (Important!) ---
    requesting_user_id = get_current_user_id()
    if not requesting_user_id or requesting_user_id != user_id:
        # Allow fetching only own saved posts unless admin/specific logic
        return jsonify({"error": "Unauthorized to view saved posts for this user"}), 403
    # --- End Auth Check ---

    saved_posts = get_saved_posts_for_user(user_id)
    return jsonify(saved_posts), 200

# --- Message Endpoints ---

@app.route('/api/messages', methods=['POST'])
def api_create_message():
     # --- Get User ID ---
    sender_user_id = get_current_user_id()
    if not sender_user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    data = request.get_json()
    # sender_user_id is now obtained from get_current_user_id(), remove from body expectation
    # sender_user_id = data.get('sender_id') # Use 'sender_id' to match api_service.dart
    # if not sender_user_id:
    #     return jsonify({'success': False, 'message': 'Missing sender_id in request body'}), 400
    # try:
    #     sender_user_id = int(sender_user_id)
    # except ValueError:
    #     return jsonify({'success': False, 'message': 'Invalid sender_id in request body'}), 400
    # --- End Old User ID Handling ---

    receiver_user_id = data.get('receiver_id')
    message_text = data.get('message_text')

    if not receiver_user_id or not message_text:
        return jsonify({'success': False, 'message': 'Missing receiver_id or message_text'}), 400
    try:
        receiver_user_id = int(receiver_user_id)
    except ValueError:
         return jsonify({'success': False, 'message': 'Invalid receiver_id'}), 400

    message_id = create_message(sender_user_id, receiver_user_id, message_text)
    if message_id:
        # TODO: Create notification for receiver_user_id
        # create_notification(receiver_user_id, sender_user_id, 'message', message_id=message_id)
        return jsonify({'success': True, 'message': 'Message sent', 'message_id': message_id}), 201
    else:
        return jsonify({'success': False, 'message': 'Failed to send message'}), 500


@app.route('/api/messages/<int:user1_id>/<int:user2_id>', methods=['GET'])
def api_get_messages(user1_id, user2_id):
    # --- Auth Check (Important!) ---
    requesting_user_id = get_current_user_id()
    if not requesting_user_id or (requesting_user_id != user1_id and requesting_user_id != user2_id):
        return jsonify({"error": "Unauthorized to view these messages"}), 403
    # --- End Auth Check ---

    messages = get_messages_between_users(user1_id, user2_id)
    return jsonify(messages), 200

@app.route('/api/users/<int:user_id>/chats', methods=['GET'])
def api_get_user_chats(user_id):
    # --- Auth Check ---
    requesting_user_id = get_current_user_id()
    if not requesting_user_id or requesting_user_id != user_id:
        return jsonify({"error": "Unauthorized to view chats for this user"}), 403
    # --- End Auth Check ---

    chat_summaries = get_chat_summaries_for_user(user_id)
    return jsonify(chat_summaries), 200

# Add a new route for '/api/users/me/chats'
@app.route('/api/users/me/chats', methods=['GET'])
def api_get_my_chats():
    # --- Auth Check ---
    user_id = get_current_user_id()
    if not user_id:
        return jsonify({"error": "Authentication required"}), 401
    # --- End Auth Check ---

    chat_summaries = get_chat_summaries_for_user(user_id)
    return jsonify(chat_summaries), 200

# --- User Search for New Message Endpoint ---
@app.route('/api/users/search_for_message', methods=['GET'])
def api_search_users_for_message():
    # --- Auth Check ---
    current_user_id = get_current_user_id()
    if not current_user_id:
        return jsonify({"error": "Authentication required"}), 401
    # --- End Auth Check ---

    search_term = request.args.get('username') # Get the username query parameter

    # Use the new db_utils function
    users = search_users_for_message(current_user_id, search_term)

    return jsonify(users), 200


# --- Notification Endpoints ---

@app.route('/api/users/<int:user_id>/notifications', methods=['GET'])
def api_get_user_notifications(user_id):
     # --- Auth Check ---
    requesting_user_id = get_current_user_id()
    if not requesting_user_id or requesting_user_id != user_id:
        return jsonify({"error": "Unauthorized to view notifications for this user"}), 403
    # --- End Auth Check ---

    notifications = get_notifications_for_user(user_id)
    return jsonify(notifications), 200

@app.route('/api/notifications/<int:notification_id>/read', methods=['PUT'])
def api_mark_notification_read(notification_id):
    # --- Auth Check (Important: ensure user owns the notification) ---
    requesting_user_id = get_current_user_id()
    if not requesting_user_id: return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # TODO: Add a check here to ensure the notification_id belongs to requesting_user_id
    # You might need a db_utils function like get_notification_recipient(notification_id)
    # recipient_id = get_notification_recipient(notification_id)
    # if recipient_id != requesting_user_id:
    #     return jsonify({'success': False, 'message': 'Unauthorized to mark this notification as read'}), 403
    # --- End Auth Check ---

    success = mark_notification_as_read(notification_id)
    if success:
        return jsonify({'success': True, 'message': 'Notification marked as read'}), 200
    else:
        return jsonify({'success': False, 'message': 'Notification not found or failed to update'}), 404 # Not Found

# --- User Settings Endpoint ---

@app.route('/api/users/<int:user_id>/settings', methods=['GET'])
def api_get_user_settings(user_id):
     # --- Auth Check ---
    requesting_user_id = get_current_user_id()
    if not requesting_user_id or requesting_user_id != user_id:
        return jsonify({"error": "Unauthorized to view settings for this user"}), 403
    # --- End Auth Check ---

    settings = get_user_settings(user_id)
    if settings:
        return jsonify(settings), 200
    else:
        # User might exist but settings might not have been created yet
        # Optionally create default settings here if not found
        return jsonify({"error": "User settings not found"}), 404

@app.route('/api/users/<int:user_id>/settings', methods=['PUT'])
def api_update_user_settings(user_id):
     # --- Auth Check ---
    requesting_user_id = get_current_user_id()
    if not requesting_user_id or requesting_user_id != user_id:
        return jsonify({"error": "Unauthorized to update settings for this user"}), 403
    # --- End Auth Check ---
    data = request.get_json()
    dark_mode = data.get('dark_mode_enabled') # Python uses snake_case generally
    email_notifications = data.get('email_notifications_enabled')

    # Only pass non-None values to the update function
    update_data = {}
    if dark_mode is not None:
        update_data['dark_mode_enabled'] = dark_mode
    if email_notifications is not None:
        update_data['email_notifications_enabled'] = email_notifications

    if not update_data:
         return jsonify({'success': False, 'message': 'No settings provided for update'}), 400

    # Pass keyword arguments to the update function
    setting_id = update_user_settings(user_id, **update_data)

    if setting_id:
        return jsonify({'success': True, 'message': 'Settings updated successfully', 'setting_id': setting_id}), 200
    else:
        return jsonify({'success': False, 'message': 'Failed to update user settings'}), 500

# --- User Profile Endpoint ---

@app.route('/api/users/<string:username>', methods=['GET'])
def api_get_user_by_username(username):
    user = get_user_by_username_or_email(username) # Can search by username or email
    if user:
        # Fetch counts (ensure these db_utils functions are efficient)
        followers_count = len(get_followers_for_user(user['user_id']))
        following_count = len(get_following_for_user(user['user_id']))
        post_count = len(get_posts_by_user_id(user['user_id'])) # Fetch post count

        user_data = {
            'user_id': user['user_id'],
            'username': user['username'],
            'email': user['email'], # Consider if email should be public
            'full_name': user.get('full_name'),
            'profile_picture_url': user.get('profile_picture_url'),
            'created_at': user['created_at'],
            'updated_at': user['updated_at'],
            'followers_count': followers_count,
            'following_count': following_count,
            'post_count': post_count # Include post count
        }
        return jsonify(user_data), 200
    else:
        return jsonify({"error": "User not found"}), 404

# --- Image Upload Endpoint (Example) ---
# Needs configuration for static file serving or cloud storage
UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/api/upload/image', methods=['POST'])
def upload_image():
    # --- Get User ID ---
    user_id = get_current_user_id()
    if not user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    # user_id is now obtained from get_current_user_id(), remove from form data expectation
    # user_id = request.form.get('user_id')
    # if not user_id:
    #     # If user_id is not provided in form data, use 'unknown' for filename
    #     user_id = 'unknown'
    # else:
    #     try:
    #         user_id = int(user_id)
    #     except ValueError:
    #         user_id = 'invalid_id' # Handle invalid user_id format
    # --- End Old User ID Handling ---

    try:
        if 'image' not in request.files:
            return jsonify({'success': False, 'message': 'No image file part'}), 400
        file = request.files['image']
        if file.filename == '':
            return jsonify({'success': False, 'message': 'No selected image file'}), 400
        if file and allowed_file(file.filename):
            # In production, use a secure filename generator and consider cloud storage
            # filename = secure_filename(file.filename) # Needs from werkzeug.utils import secure_filename
            # For simplicity, use a unique name (e.g., based on user_id and timestamp)
            filename = f"user_{user_id}_{int(time.time())}.{file.filename.rsplit('.', 1)[1].lower()}"
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            try:
                file.save(filepath)
                # Return the URL path to the uploaded image
                # This assumes your Flask app serves the 'uploads' folder statically
                image_url = f"/uploads/{filename}" # Adjust based on your static route
                return jsonify({'success': True, 'message': 'Image uploaded successfully', 'imageUrl': image_url}), 201
            except Exception as e:
                 print(f"Error saving uploaded file: {e}")
                 import traceback
                 traceback.print_exc() # Print the full traceback
                 return jsonify({'success': False, 'message': 'Failed to save image'}), 500
        else:
            return jsonify({'success': False, 'message': 'File type not allowed'}), 400
    except Exception as e:
        print(f"!!! Unexpected error in upload_image: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': 'An internal error occurred during upload'}), 500


# Configure static file serving for uploads
from flask import send_from_directory
@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

# --- Account Update Endpoint ---
@app.route('/update_account', methods=['POST'])
def update_account():
    # --- Get User ID ---
    user_id = get_current_user_id()
    if not user_id:
       return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Get User ID ---

    username = request.form.get('username')
    profile_picture_file = request.files.get('profile_picture')

    profile_picture_url = None
    if profile_picture_file and allowed_file(profile_picture_file.filename):
        # Use similar logic to the image upload endpoint to save the file
        try:
            filename = f"user_{user_id}_profile_{int(time.time())}.{profile_picture_file.filename.rsplit('.', 1)[1].lower()}"
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            profile_picture_file.save(filepath)
            profile_picture_url = f"/uploads/{filename}" # Adjust based on your static route
        except Exception as e:
            print(f"Error saving profile picture: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'message': 'Failed to save profile picture'}), 500
    elif profile_picture_file:
         return jsonify({'success': False, 'message': 'Profile picture file type not allowed'}), 400


    # Update user information in the database
    # Need a db_utils function for this
    # Assuming update_user_profile(user_id, username=None, profile_picture_url=None) exists
    try:
        # Only pass values that are provided in the request
        update_data = {}
        if username is not None:
            update_data['username'] = username
        if profile_picture_url is not None:
            update_data['profile_picture_url'] = profile_picture_url

        if not update_data:
             return jsonify({'success': False, 'message': 'No update data provided'}), 400

        success = update_user_profile(user_id, **update_data) # Need to implement update_user_profile in db_utils

        if success:
            return jsonify({'success': True, 'message': 'Account updated successfully'}), 200
        else:
            # This might happen if the username is already taken
            return jsonify({'success': False, 'message': 'Failed to update account (username might be taken)'}), 409 # Conflict or 500
    except Exception as e:
        print(f"!!! Unexpected error in update_account: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': 'An internal error occurred during account update'}), 500


if __name__ == '__main__':
    import time # Needed for temporary filename generation
    # In production, use a production-ready WSGI server like Gunicorn or uWSGI
    # And set debug=False
    app.run(debug=True, host='0.0.0.0', port=5000)
