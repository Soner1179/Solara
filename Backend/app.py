from flask import Flask, render_template, request, jsonify, make_response, redirect, url_for
import os
import time # Ensure time is imported, it's used later
from flask_cors import CORS
import bcrypt
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity, JWTManager
from datetime import datetime # Import datetime for timestamp formatting
import psycopg2.errors # Explicitly import psycopg2.errors
# Import all necessary functions from db_utils
from db_utils import (
    create_user, get_user_by_username_or_email, create_post, create_follow,
    create_like, create_comment, create_saved_post, create_message,
    create_notification, update_user_settings,
    get_user_by_id, get_all_users, get_all_posts, get_posts_by_user_id, get_likes_for_post,
    get_comments_for_post, get_messages_between_users, get_saved_posts_for_user,
    get_followers_for_user, get_following_for_user, get_user_settings,
    get_chat_summaries_for_user,
    delete_follow,
    get_notifications_for_user,
    get_post_by_id, # <-- Import the new function
    mark_notification_as_read,
    get_home_feed_posts, # <-- YENİ IMPORT: Ana sayfa akışı için
    create_comment_like, # <-- Import for comment likes
    delete_comment_like, # <-- Import for deleting comment likes
    get_comment_like_count, # <-- Import for comment like counts
    # İleride gerekirse: delete_like, delete_saved_post
    delete_like, # <-- Beğeniyi kaldırmak için (varsayımsal)
    delete_saved_post, # <-- Kaydedileni kaldırmak için (varsayımsal)
    get_post_like_count, # <-- Import the new function
    search_users, # <-- Import the new function
    update_user_profile, # <-- Import for profile updates
    is_follow_request_pending # <-- Import for checking pending follow requests
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

# Configure JWT settings
app.config["JWT_SECRET_KEY"] = "your-super-secret-jwt-key-change-this"  # Change this in your environment!
jwt = JWTManager(app)

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
    access_token_cookie = request.cookies.get('access_token_cookie')
    if not access_token_cookie:
        return redirect(url_for('login_page'))

    try:
        # Verify the token and get the identity
        from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
        verify_jwt_in_request(locations=["cookies"]) # Look for token in cookies
        user_id = int(get_jwt_identity()) # Get user ID from JWT

        # TODO: Implement fetching personalized feed based on user_id
        # For now, still fetching all posts or implement get_home_feed_posts properly
        posts = get_all_posts() # Or get_home_feed_posts(user_id) if implemented
        return render_template('home.html', posts=posts, user_id=user_id)
    except Exception as e:
        print(f"Error verifying JWT cookie for /home: {e}")
        # If token is invalid or expired, redirect to login
        return redirect(url_for('login_page'))


@app.route('/messages')
def messages_page():
    access_token_cookie = request.cookies.get('access_token_cookie')
    if not access_token_cookie:
        return redirect(url_for('login_page'))

    try:
        from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
        verify_jwt_in_request(locations=["cookies"])
        user_id = int(get_jwt_identity())
        return render_template('messages.html', user_id=user_id)
    except Exception as e:
        print(f"Error verifying JWT cookie for /messages: {e}")
        return redirect(url_for('login_page'))


@app.route('/profile')
def profile_page():
    access_token_cookie = request.cookies.get('access_token_cookie')
    if not access_token_cookie:
        print("--- /profile route: No access_token_cookie found, redirecting to login. ---")
        return redirect(url_for('login_page'))

    try:
        from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
        verify_jwt_in_request(locations=["cookies"])
        user_id = int(get_jwt_identity())
        print(f"--- /profile route: Retrieved user_id from JWT cookie: {user_id} ---")

        # Fetch the user data for the profile page
        user = get_user_by_id(user_id)
        print(f"--- /profile route: Result of get_user_by_id({user_id}): {user} ---")
        if not user:
            print(f"--- /profile route: User with ID {user_id} not found. ---")
            return jsonify({"error": "User not found"}), 404

        # TODO: Web profili için URL'den username alınmalı ve o kullanıcının profili gösterilmeli.
        # Şu an sadece oturum açmış kullanıcının profilini gösteriyoruz.
        return render_template('profile.html', user=user, user_id=user_id)
    except Exception as e:
        print(f"Error verifying JWT cookie for /profile: {e}")
        print(traceback.format_exc())
        return redirect(url_for('login_page'))


@app.route('/create_post')
def create_post_page():
    access_token_cookie = request.cookies.get('access_token_cookie')
    if not access_token_cookie:
        return redirect(url_for('login_page'))

    try:
        from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
        verify_jwt_in_request(locations=["cookies"])
        user_id = int(get_jwt_identity())
        return render_template('create_post.html', user_id=user_id)
    except Exception as e:
        print(f"Error verifying JWT cookie for /create_post: {e}")
        return redirect(url_for('login_page'))


@app.route('/settings')
def settings_page():
    access_token_cookie = request.cookies.get('access_token_cookie')
    if not access_token_cookie:
        return redirect(url_for('login_page'))

    try:
        from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
        verify_jwt_in_request(locations=["cookies"])
        user_id = int(get_jwt_identity())
        return render_template('settings.html', user_id=user_id)
    except Exception as e:
        print(f"Error verifying JWT cookie for /settings: {e}")
        return redirect(url_for('login_page'))


@app.route('/discover')
def discover_page():
    access_token_cookie = request.cookies.get('access_token_cookie')
    if not access_token_cookie:
        return redirect(url_for('login_page'))

    try:
        from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
        verify_jwt_in_request(locations=["cookies"])
        user_id = int(get_jwt_identity())
        return render_template('discover.html', user_id=user_id)
    except Exception as e:
        print(f"Error verifying JWT cookie for /discover: {e}")
        return redirect(url_for('login_page'))


@app.route('/notifications')
def notifications_page():
    access_token_cookie = request.cookies.get('access_token_cookie')
    if not access_token_cookie:
        return redirect(url_for('login_page'))

    try:
        from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
        verify_jwt_in_request(locations=["cookies"])
        user_id = int(get_jwt_identity())
        return render_template('notifications.html', user_id=user_id)
    except Exception as e:
        print(f"Error verifying JWT cookie for /notifications: {e}")
        return redirect(url_for('login_page'))


@app.route('/saved_posts')
def saved_posts_page():
    access_token_cookie = request.cookies.get('access_token_cookie')
    if not access_token_cookie:
        return redirect(url_for('login_page'))

    try:
        from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
        verify_jwt_in_request(locations=["cookies"])
        user_id = int(get_jwt_identity())
        return render_template('saved_posts.html', user_id=user_id)
    except Exception as e:
        print(f"Error verifying JWT cookie for /saved_posts: {e}")
        return redirect(url_for('login_page'))


# --- API Endpoints for Mobile and Web ---


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
        # Generate a real JWT token, ensuring identity is a string
        access_token = create_access_token(identity=str(user['user_id']))

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
            'token': access_token # Send the generated token
        }), 200)

        # Set the JWT token as an HTTP-only cookie for web authentication
        response.set_cookie('access_token_cookie', access_token, httponly=True, samesite='Lax')

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
        # Generate a real JWT token, ensuring identity is a string
        access_token = create_access_token(identity=str(user_id))

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
            'token': access_token # Send the generated token
        }), 201)

        # Removed the user_id cookie as web frontend will use JWT
        # response.set_cookie('user_id', str(user_id), httponly=True, samesite='Lax') # Add samesite='Lax')

        return response
    else:
        # This assumes create_user returns None on failure (e.g., duplicate user)
        return jsonify({'success': False, 'message': 'Username or email already exists'}), 409

# --- Post Endpoints ---

@app.route('/api/posts', methods=['POST'])
@jwt_required()
def api_create_post():
    # --- Get User ID ---
    jwt_user_id_str = get_jwt_identity()
    user_id = int(jwt_user_id_str) # Convert to int for DB operations
    # No need to check if not user_id, @jwt_required handles it
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

    post_id = create_post(user_id, content_text, image_url) # Use authenticated user_id (now int)

    if post_id:
        # Fetch the created post to return it (optional but good practice)
        # new_post = get_post_by_id(post_id) # Requires get_post_by_id in db_utils
        return jsonify({'success': True, 'message': 'Post created successfully', 'post_id': post_id}), 201
    else:
        return jsonify({'success': False, 'message': 'Failed to create post'}), 500

@app.route('/api/posts', methods=['GET'])
@jwt_required()
def api_get_home_feed_posts():
    # --- Get User ID ---
    jwt_user_id_str = get_jwt_identity()
    user_id = int(jwt_user_id_str) # Convert to int for DB operations
    # No need to check if not user_id, @jwt_required handles it
    # --- End Get User ID ---

    # user_id is now obtained from get_jwt_identity(), remove from query param expectation
    # user_id = request.args.get('user_id')
    # if not user_id:
    #     return jsonify({"error": "Missing user_id query parameter for home feed"}), 400
    # try:
    #     user_id = int(user_id)
    # except ValueError:
    #     return jsonify({"error": "Invalid user_id query parameter"}), 400
    # --- End Old User ID Handling ---

    # Use the new function to get the personalized feed
    posts = get_home_feed_posts(user_id) # user_id is now int

    # TODO: Enhance get_home_feed_posts or process here to add 'is_liked' and 'is_saved' status for the requesting user (user_id)
    # Example (if added to get_home_feed_posts):
    # for post in posts:
    #     post['is_liked'] = post.pop('is_liked_by_current_user', False) # Rename/default
    #     post['is_saved'] = post.pop('is_saved_by_current_user', False) # Rename/default

    return jsonify(posts), 200

# --- User Endpoints (General) ---

@app.route('/api/users', methods=['GET'])
def api_get_all_users():
    print("--- Entering api_get_all_users route handler ---") # Added logging
    # --- Get User ID (Optional, depending on if user list is public) ---
    # If you want to exclude the current user from the list, get their ID
    requesting_user_id = get_current_user_id()
    print(f"--- api_get_all_users: requesting_user_id = {requesting_user_id} ---") # Added logging
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
            print(f"!!! api_get_all_users: Invalid exclude_user_id query parameter: {exclude_user_id_str} ---") # Added logging
            return jsonify({"error": "Invalid exclude_user_id query parameter"}), 400

    # If no exclude_user_id is provided in query params, but user is authenticated,
    # exclude the current user by default.
    if exclude_user_id is None and requesting_user_id is not None:
        exclude_user_id = requesting_user_id

    # Assuming get_all_users exists in db_utils and can take exclude_user_id
    # Get the exclude_user_id from query parameters
    # NOTE: This block seems redundant as exclude_user_id is already determined above.
    # Keeping it for now but might need refactoring.
    exclude_user_id_str = request.args.get('exclude_user_id')
    exclude_user_id = None
    if exclude_user_id_str:
        try:
            exclude_user_id = int(exclude_user_id_str)
        except ValueError:
            # This case is already handled above, but keeping for safety
            print(f"!!! api_get_all_users: Redundant check - Invalid exclude_user_id query parameter: {exclude_user_id_str} ---") # Added logging
            return jsonify({"error": "Invalid exclude_user_id query parameter"}), 400

    # Use the determined exclude_user_id
    # print(f"--- Attempting to fetch all users (exclude_user_id: {exclude_user_id}) ---") # Moved logging to db_utils
    try:
        # Use the actual get_all_users function from db_utils
        users = get_all_users(current_user_id=exclude_user_id) # Pass exclude_user_id as current_user_id
        print(f"--- api_get_all_users: Successfully fetched {len(users)} users from db_utils ---") # Added logging
        return jsonify(users), 200
    except Exception as e:
        print(f"!!! Error in api_get_all_users while calling get_all_users: {e}") # More specific logging
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
    print(f"--- api_search_users: Received search_query = '{search_query}' ---") # Added logging
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

# --- User Endpoints (By ID) ---
@app.route('/api/users/<int:user_id>', methods=['GET'])
@jwt_required() # Require authentication
def api_get_user_by_id_endpoint(user_id):
    # --- Get User ID from JWT ---
    jwt_user_id_str = get_jwt_identity()
    requesting_user_id = int(jwt_user_id_str) # Convert to int
    # --- End Get User ID ---

    # Optional: Add authorization check if a user can only fetch their own data
    # if requesting_user_id != user_id:
    #     return jsonify({"error": "Unauthorized to view this user's data"}), 403

    user = get_user_by_id(user_id) # user_id is int from path

    if user:
        # Format created_at and updated_at timestamps to ISO 8601 strings
        if 'created_at' in user and isinstance(user['created_at'], datetime):
            user['created_at'] = user['created_at'].isoformat()
        if 'updated_at' in user and isinstance(user['updated_at'], datetime):
            user['updated_at'] = user['updated_at'].isoformat()

        # Include is_private status
        user['is_private'] = user.get('is_private', False)

        return jsonify(user), 200
    else:
        return jsonify({"error": "User not found"}), 404 # Not Found

@app.route('/api/posts/<int:post_id>', methods=['GET'])
@jwt_required() # Require authentication to get current_user_id for like/save status
def api_get_post(post_id):
    # --- Get User ID ---
    jwt_current_user_id_str = get_jwt_identity()
    current_user_id = int(jwt_current_user_id_str) # Convert to int
    # --- End Get User ID ---

    # Use the new function to get the post by ID
    post = get_post_by_id(post_id, current_user_id) # Pass current_user_id

    if post:
        # Format created_at and updated_at timestamps to ISO 8601 strings
        if 'created_at' in post and isinstance(post['created_at'], datetime):
            post['created_at'] = post['created_at'].isoformat()
        if 'updated_at' in post and isinstance(post['updated_at'], datetime):
            post['updated_at'] = post['updated_at'].isoformat()

        return jsonify(post), 200
    else:
        return jsonify({"error": "Post not found"}), 404 # Not Found

@app.route('/api/users/<int:user_id>/posts', methods=['GET'])
def api_get_user_posts(user_id):
    # This endpoint gets posts specifically for a user's profile
    current_user_id = get_current_user_id() # Get the ID of the currently logged-in user
    posts = get_posts_by_user_id(user_id, current_user_id) # Pass current_user_id to get like/save status
    return jsonify(posts), 200

# --- Like Endpoints ---

@app.route('/api/posts/<int:post_id>/likes', methods=['POST'])
@jwt_required()
def api_like_post(post_id):
    # --- Get User ID ---
    jwt_user_id_str = get_jwt_identity()
    user_id = int(jwt_user_id_str) # Convert to int
    # --- End Get User ID ---

    # user_id is now obtained from get_jwt_identity(), remove from body expectation
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
        like_id = create_like(user_id, post_id) # user_id is now int
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
@jwt_required()
def api_unlike_post(post_id):
    # --- Get User ID ---
    jwt_user_id_str = get_jwt_identity()
    user_id = int(jwt_user_id_str) # Convert to int
    # --- End Get User ID ---

    # user_id is now obtained from get_jwt_identity(), remove from query param expectation
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
        success = delete_like(user_id, post_id) # user_id is now int
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
@jwt_required() # Require authentication to get current_user_id for like status
def api_get_post_comments(post_id):
    # --- Get User ID ---
    jwt_current_user_id_str = get_jwt_identity()
    current_user_id = int(jwt_current_user_id_str) # Convert to int
    # --- End Get User ID ---

    comments = get_comments_for_post(post_id, current_user_id) # Pass current_user_id
    return jsonify(comments), 200

@app.route('/api/comments', methods=['POST'])
@jwt_required()
def api_create_comment():
    # --- Get User ID ---
    jwt_user_id_str = get_jwt_identity()
    user_id = int(jwt_user_id_str) # Convert to int
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

    post_id_from_req = data.get('post_id') # Renamed to avoid conflict
    comment_text = data.get('comment_text')

    if not post_id_from_req or not comment_text:
        return jsonify({'success': False, 'message': 'Missing post_id or comment_text'}), 400
    try:
        post_id_int = int(post_id_from_req) # Convert to int
    except ValueError:
         return jsonify({'success': False, 'message': 'Invalid post_id'}), 400


    comment_id = create_comment(user_id, post_id_int, comment_text) # Use authenticated user_id (int) and post_id_int

    if comment_id:
        # Optionally, fetch the created comment to return it
        # comment = get_comment_by_id(comment_id) # Need this function in db_utils
        return jsonify({'success': True, 'message': 'Comment created successfully', 'comment_id': comment_id}), 201
    else:
        return jsonify({'success': False, 'message': 'Failed to create comment'}), 500

# --- Comment Like Endpoints ---

@app.route('/api/comments/<int:comment_id>/likes', methods=['POST', 'DELETE'])
@jwt_required()
def api_comment_likes(comment_id): # Renamed function for clarity
    # --- Get User ID ---
    jwt_user_id_str = get_jwt_identity()
    user_id = int(jwt_user_id_str) # Convert to int
    # --- End Get User ID ---

    if request.method == 'POST':
        try:
            # Call the create_comment_like function from db_utils
            like_id = create_comment_like(user_id, comment_id)   # user_id is now int
            if like_id:
                # Fetch the updated like count for the comment
                updated_like_count = get_comment_like_count(comment_id) # Use the new function
                return jsonify({'success': True, 'message': 'Comment liked', 'like_id': like_id, 'likes_count': updated_like_count}), 201
            else:
                # Could be duplicate like (UniqueViolation) or other error
                return jsonify({'success': False, 'message': 'Failed to like comment (maybe already liked?)'}), 409 # Conflict or 500
        except Exception as e:
            print(f"!!! Unexpected error in api_comment_likes (POST): {e}")
            import traceback
            print(traceback.format_exc())
            return jsonify({'success': False, 'message': 'An internal error occurred'}), 500

    elif request.method == 'DELETE':
        try:
            # Call the delete_comment_like function from db_utils
            success = delete_comment_like(user_id, comment_id) # user_id is now int
            if success:
                # Fetch the updated like count for the comment
                updated_like_count = get_comment_like_count(comment_id) # Use the new function
                return jsonify({'success': True, 'message': 'Comment unliked', 'likes_count': updated_like_count}), 200
            else:
                # Could be like not found or other deletion error
                return jsonify({'success': False, 'message': 'Failed to unlike comment (like not found?)'}), 404 # Not Found or 500
        except Exception as e:
            print(f"!!! Unexpected error in api_comment_likes (DELETE): {e}")
            import traceback
            print(traceback.format_exc())
            return jsonify({'success': False, 'message': 'An internal error occurred'}), 500

    # Should not reach here if methods are only POST and DELETE
    return jsonify({'success': False, 'message': 'Method not allowed'}), 405

# --- Follow Endpoints ---

@app.route('/api/follow', methods=['POST'])
@jwt_required()
def api_create_follow():
    # --- Get User ID ---
    jwt_follower_user_id_str = get_jwt_identity() # The user performing the action
    follower_user_id = int(jwt_follower_user_id_str) # Convert to int
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

    followed_user_id_from_req = data.get('followed_user_id') # The user being followed

    if not followed_user_id_from_req:
        return jsonify({'success': False, 'message': 'Missing followed_user_id'}), 400
    try:
        followed_user_id = int(followed_user_id_from_req) # Convert to int
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid followed_user_id'}), 400

    if follower_user_id == followed_user_id: # Both are now int
         return jsonify({'success': False, 'message': 'User cannot follow themselves'}), 400

    try:
        follow_id, result_type = create_follow(follower_user_id, followed_user_id) # Both are int

        if result_type == 'follow_created':
            return jsonify({'success': True, 'message': 'Follow relationship created', 'follow_id': follow_id, 'result_type': result_type}), 201
        elif result_type == 'request_created':
             return jsonify({'success': True, 'message': 'Follow request sent', 'request_id': follow_id, 'result_type': result_type}), 200 # Use 200 for success but not resource creation
        elif result_type == 'follow_exists':
             return jsonify({'success': False, 'message': 'Follow relationship already exists', 'result_type': result_type}), 409 # Conflict
        elif result_type == 'request_exists':
             return jsonify({'success': False, 'message': 'Follow request already pending', 'result_type': result_type}), 409 # Conflict
        else:
            # This case should ideally not be reached if create_follow raises exceptions on error
            return jsonify({'success': False, 'message': 'Failed to create follow relationship or request', 'result_type': result_type}), 500
    except psycopg2.errors.UniqueViolation:
        # Catch UniqueViolation specifically for duplicate follow attempts or pending requests
        return jsonify({'success': False, 'message': 'Follow relationship or request already exists'}), 409 # Conflict
    except Exception as e:
        print(f"!!! Error in api_create_follow: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': 'An internal error occurred while processing follow request'}), 500


@app.route('/api/follow', methods=['DELETE'])
@jwt_required()
def api_delete_follow():
    # --- Get User ID ---
    jwt_follower_user_id_str = get_jwt_identity() # The user performing the action
    follower_user_id = int(jwt_follower_user_id_str) # Convert to int
    # --- End Get User ID ---

    # follower_user_id is now obtained from get_jwt_identity(), remove from query param expectation
    # follower_user_id = request.args.get('follower_user_id') # Expecting user_id in query params for DELETE
    # if not follower_user_id:
    #     return jsonify({'success': False, 'message': 'Missing follower_user_id query parameter'}), 400
    # try:
    #     user_id = int(user_id)
    # except ValueError:
    #     return jsonify({'success': False, 'message': 'Invalid user_id query parameter'}), 400
    # --- End Old User ID Handling ---

    followed_user_id_from_req = request.args.get('followed_user_id') # The user being unfollowed

    if not followed_user_id_from_req:
        return jsonify({'success': False, 'message': 'Missing followed_user_id query parameter'}), 400
    try:
        followed_user_id = int(followed_user_id_from_req) # Convert to int
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid followed_user_id query parameter'}), 400

    success = delete_follow(follower_user_id, followed_user_id) # Both are int

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

# --- Follow Request Endpoints ---

@app.route('/api/users/me/follow_requests', methods=['GET'])
@jwt_required()
def api_get_my_follow_requests():
    current_user_id = int(get_jwt_identity())
    try:
        from db_utils import get_follow_requests_for_user # Import the function
        requests = get_follow_requests_for_user(current_user_id)
        # Format created_at timestamps
        for req in requests:
             if 'created_at' in req and isinstance(req['created_at'], datetime):
                req['created_at'] = req['created_at'].isoformat()
        return jsonify(requests), 200
    except Exception as e:
        print(f"!!! Error in api_get_my_follow_requests: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({"error": "Failed to fetch follow requests"}), 500

@app.route('/api/follow_requests/<int:request_id>/accept', methods=['PUT'])
@jwt_required()
def api_accept_follow_request(request_id):
    current_user_id = int(get_jwt_identity())
    try:
        from db_utils import accept_follow_request # Import the function
        # TODO: Add a check to ensure the current user is the recipient of the request
        # You might need a db_utils function like get_follow_request_recipient(request_id)
        # from db_utils import get_follow_request_recipient
        # recipient_id = get_follow_request_recipient(request_id)
        # if recipient_id != current_user_id:
        #     return jsonify({'success': False, 'message': 'Unauthorized to accept this request'}), 403

        success = accept_follow_request(request_id)
        if success:
            return jsonify({'success': True, 'message': 'Follow request accepted'}), 200
        else:
            return jsonify({'success': False, 'message': 'Failed to accept follow request (not found or already accepted)'}), 400 # Or 404
    except Exception as e:
        print(f"!!! Error in api_accept_follow_request: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': 'An internal error occurred'}), 500

@app.route('/api/follow_requests/<int:request_id>/reject', methods=['PUT'])
@jwt_required()
def api_reject_follow_request(request_id):
    current_user_id = int(get_jwt_identity())
    try:
        from db_utils import reject_follow_request # Import the function
        # TODO: Add a check to ensure the current user is the recipient of the request
        # from db_utils import get_follow_request_recipient
        # recipient_id = get_follow_request_recipient(request_id)
        # if recipient_id != current_user_id:
        #     return jsonify({'success': False, 'message': 'Unauthorized to reject this request'}), 403

        success = reject_follow_request(request_id)
        if success:
            return jsonify({'success': True, 'message': 'Follow request rejected'}), 200
        else:
            return jsonify({'success': False, 'message': 'Failed to reject follow request (not found or already rejected)'}), 400 # Or 404
    except Exception as e:
        print(f"!!! Error in api_reject_follow_request: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': 'An internal error occurred'}), 500


# --- Suggested Users Endpoint ---
@app.route('/api/suggested_users', methods=['GET'])
@jwt_required()
def api_get_suggested_users():
    # --- Get User ID ---
    jwt_current_user_id_str = get_jwt_identity()
    current_user_id = int(jwt_current_user_id_str) # Convert to int
    # --- End Get User ID ---

    # Explicitly import here for debugging NameError
    from db_utils import get_suggested_users, is_following_user

    suggested_users = get_suggested_users(current_user_id) # current_user_id is int

    # Check follow status for each suggested user
    for user in suggested_users: # user['user_id'] is int from DB
        user['is_following'] = is_following_user(current_user_id, user['user_id']) # Both are int
        print(f"--- Suggested user: {user.get('username')}, Profile Picture URL: {user.get('profile_picture_url')} ---") # Added logging

    return jsonify(suggested_users), 200


# --- Saved Post (Bookmark) Endpoints ---

@app.route('/api/posts/<int:post_id>/saved', methods=['POST'])
@jwt_required()
def api_save_post(post_id):
    # --- Get User ID ---
    jwt_user_id_str = get_jwt_identity()
    user_id = int(jwt_user_id_str) # Convert to int
    # --- End Get User ID ---

    # user_id is now obtained from get_jwt_identity(), remove from body expectation
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
        saved_post_id = create_saved_post(user_id, post_id) # user_id is int
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
@jwt_required()
def api_unsave_post(post_id):
    # --- Get User ID ---
    jwt_user_id_str = get_jwt_identity()
    user_id = int(jwt_user_id_str) # Convert to int
    # --- End Get User ID ---

    # user_id is now obtained from get_jwt_identity(), remove from query param expectation
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
        success = delete_saved_post(user_id, post_id) # user_id is now int
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
@jwt_required()
def api_get_saved_posts(user_id): # Changed user_id_from_url back to user_id
    # --- Auth Check (Important!) ---
    jwt_requesting_user_id_str = get_jwt_identity()
    requesting_user_id = int(jwt_requesting_user_id_str) # Convert to int
    if requesting_user_id != user_id: # user_id is int from path
        # Allow fetching only own saved posts
        return jsonify({"error": "Unauthorized to view saved posts for this user"}), 403
    # --- End Auth Check ---

    try:
        # Pass both the user whose saved posts are being fetched (user_id from URL)
        # and the user making the request (requesting_user_id from JWT) for like/save status context.
        # In this specific route, they are the same due to the auth check above.
        saved_posts = get_saved_posts_for_user(user_id_of_saver=user_id, requesting_user_id=requesting_user_id)
        return jsonify(saved_posts), 200
    except Exception as e:
        print(f"!!! Error in api_get_saved_posts for user {user_id}: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({"error": "Failed to fetch saved posts due to an internal server error"}), 500

# --- Message Endpoints ---

@app.route('/api/messages', methods=['POST'])
@jwt_required()
def api_create_message():
     # --- Get User ID ---
    jwt_sender_user_id_str = get_jwt_identity()
    sender_user_id = int(jwt_sender_user_id_str) # Convert to int
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

    receiver_user_id_from_req = data.get('receiver_id')
    message_text = data.get('message_text')

    if not receiver_user_id_from_req or not message_text:
        return jsonify({'success': False, 'message': 'Missing receiver_id or message_text'}), 400
    try:
        receiver_user_id = int(receiver_user_id_from_req) # Convert to int
    except ValueError:
         return jsonify({'success': False, 'message': 'Invalid receiver_id'}), 400

    message_id = create_message(sender_user_id, receiver_user_id, message_text) # Both sender and receiver are int
    if message_id:
        # TODO: Create notification for receiver_user_id
        # create_notification(receiver_user_id, sender_user_id, 'message', message_id=message_id)
        # Return the created message details for the frontend
        return jsonify({
            'success': True,
            'message': 'Message sent',
            'message_id': message_id,
            'sender_user_id': sender_user_id, # Add sender_user_id
            'receiver_user_id': receiver_user_id, # Optionally add receiver_id
            'message_text': message_text # Add message_text
        }), 201
    else:
        return jsonify({'success': False, 'message': 'Failed to send message'}), 500


@app.route('/api/messages/<int:user1_id>/<int:user2_id>', methods=['GET'])
@jwt_required()
def api_get_messages(user1_id, user2_id):
    # --- Auth Check (Important!) ---
    jwt_requesting_user_id_str = get_jwt_identity()
    requesting_user_id = int(jwt_requesting_user_id_str) # Convert to int
    # user1_id and user2_id are ints from path
    if requesting_user_id != user1_id and requesting_user_id != user2_id:
        return jsonify({"error": "Unauthorized to view these messages"}), 403
    # --- End Auth Check ---

    messages = get_messages_between_users(user1_id, user2_id) # Both are int
    return jsonify(messages), 200

@app.route('/api/users/<int:user_id>/chats', methods=['GET'])
@jwt_required()
def api_get_user_chats(user_id): # Changed user_id_from_url to user_id
    # --- Auth Check ---
    jwt_requesting_user_id_str = get_jwt_identity()
    requesting_user_id = int(jwt_requesting_user_id_str) # Convert to int
    if requesting_user_id != user_id: # user_id is int from path
        return jsonify({"error": "Unauthorized to view chats for this user"}), 403
    # --- End Auth Check ---

    chat_summaries = get_chat_summaries_for_user(user_id) # user_id is int
    return jsonify(chat_summaries), 200

# Add a new route for '/api/users/me/chats'
@app.route('/api/users/me/chats', methods=['GET'])
@jwt_required()
def api_get_my_chats():
    # --- Auth Check ---
    jwt_user_id_str = get_jwt_identity()
    user_id = int(jwt_user_id_str) # Convert to int
    # --- End Auth Check ---

    chat_summaries = get_chat_summaries_for_user(user_id) # user_id is int
    return jsonify(chat_summaries), 200

# --- Notification Endpoints ---

@app.route('/api/users/<int:user_id>/notifications', methods=['GET'])
@jwt_required()
def api_get_user_notifications(user_id): # Changed argument name to match route decorator
     # --- Auth Check ---
    jwt_requesting_user_id_str = get_jwt_identity()
    requesting_user_id = int(jwt_requesting_user_id_str) # Convert to int
    if requesting_user_id != user_id: # user_id is int from path
        return jsonify({"error": "Unauthorized to view notifications for this user"}), 403
    # --- End Auth Check ---

    notifications = get_notifications_for_user(user_id) # user_id is int

    # Format created_at timestamps to ISO 8601 strings for the mobile app
    for notification in notifications:
        if 'created_at' in notification and isinstance(notification['created_at'], datetime):
            notification['created_at'] = notification['created_at'].isoformat()

    return jsonify(notifications), 200

@app.route('/api/notifications/<int:notification_id>', methods=['DELETE'])
@jwt_required()
def api_delete_notification(notification_id):
    print(f"--- api_delete_notification called for notification_id: {notification_id} ---") # Added logging
    # --- Auth Check (Important: ensure user owns the notification) ---
    jwt_requesting_user_id_str = get_jwt_identity()
    requesting_user_id = int(jwt_requesting_user_id_str) # Convert to int
    # TODO: Add a check here to ensure the notification_id belongs to requesting_user_id
    # You might need a db_utils function like get_notification_recipient(notification_id)
    # from db_utils import get_notification_recipient # Assuming this function exists
    # recipient_id = get_notification_recipient(notification_id) # notification_id is int from path
    # if recipient_id != requesting_user_id:
    #     print(f"--- api_delete_notification: Unauthorized attempt to delete notification {notification_id} by user {requesting_user_id} ---") # Added logging
    #     return jsonify({'success': False, 'message': 'Unauthorized to delete this notification'}), 403
    # --- End Auth Check ---

    try:
        from db_utils import mark_notification_as_deleted # Import the function
        print(f"--- api_delete_notification: Calling mark_notification_as_deleted with notification_id: {notification_id} ---") # Added logging
        success = mark_notification_as_deleted(notification_id) # notification_id is int
        print(f"--- api_delete_notification: mark_notification_as_deleted returned: {success} ---") # Added logging
        if success:
            return jsonify({'success': True, 'message': 'Bildirim başarıyla silindi olarak işaretlendi.'}), 200
        else:
            print(f"--- api_delete_notification: mark_notification_as_deleted failed for notification_id: {notification_id} ---") # Added logging
            return jsonify({'success': False, 'message': 'Bildirim bulunamadı veya silinirken bir hata oluştu.'}), 404 # Not Found
    except Exception as e:
        print(f"!!! Error in api_delete_notification: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': f'Dahili bir hata oluştu: {e}'}), 500


@app.route('/api/notifications/<int:notification_id>/read', methods=['PUT'])
@jwt_required()
def api_mark_notification_read(notification_id):
    # --- Auth Check (Important: ensure user owns the notification) ---
    jwt_requesting_user_id_str = get_jwt_identity()
    requesting_user_id = int(jwt_requesting_user_id_str) # Convert to int
    # TODO: Add a check here to ensure the notification_id belongs to requesting_user_id
    # You might need a db_utils function like get_notification_recipient(notification_id)
    # from db_utils import get_notification_recipient # Assuming this function exists
    # recipient_id = get_notification_recipient(notification_id) # notification_id is int from path
    # if recipient_id != requesting_user_id:
    #     return jsonify({'success': False, 'message': 'Unauthorized to mark this notification as read'}), 403
    # --- End Auth Check ---

    success = mark_notification_as_read(notification_id) # notification_id is int
    if success:
        return jsonify({'success': True, 'message': 'Notification marked as read'}), 200
    else:
        return jsonify({'success': False, 'message': 'Notification not found or failed to update'}), 404 # Not Found

# --- User Settings Endpoint ---

@app.route('/api/users/<int:user_id>/settings', methods=['GET'])
@jwt_required()
def api_get_user_settings(user_id_from_url): # Renamed
     # --- Auth Check ---
    jwt_requesting_user_id_str = get_jwt_identity()
    requesting_user_id = int(jwt_requesting_user_id_str) # Convert to int
    if requesting_user_id != user_id_from_url: # user_id_from_url is int from path
        return jsonify({"error": "Unauthorized to view settings for this user"}), 403
    # --- End Auth Check ---

    settings = get_user_settings(user_id_from_url) # user_id_from_url is int
    if settings:
        return jsonify(settings), 200
    else:
        # User might exist but settings might not have been created yet
        # Optionally create default settings here if not found
        return jsonify({"error": "User settings not found"}), 404

@app.route('/api/users/<int:user_id>/settings', methods=['PUT'])
@jwt_required()
def api_update_user_settings(user_id_from_url): # Renamed
     # --- Auth Check ---
    jwt_requesting_user_id_str = get_jwt_identity()
    requesting_user_id = int(jwt_requesting_user_id_str) # Convert to int
    if requesting_user_id != user_id_from_url: # user_id_from_url is int from path
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
    setting_id = update_user_settings(user_id_from_url, **update_data)

    if setting_id:
        return jsonify({'success': True, 'message': 'Settings updated successfully', 'setting_id': setting_id}), 200
    else:
        return jsonify({'success': False, 'message': 'Failed to update user settings'}), 500

# --- User Profile Endpoint ---

@app.route('/api/users/<string:username>', methods=['GET'])
@jwt_required(optional=True) # Make JWT required, but optional=True allows unauthenticated access for public profiles
def api_get_user_by_username(username):
    # Get the current user's ID from the JWT if available.
    # get_jwt_identity() will return None if no valid token is present (due to optional=True)
    requesting_user_id = None
    try:
        jwt_identity = get_jwt_identity()
        if jwt_identity:
            requesting_user_id = int(jwt_identity) # Convert back to int for comparisons
            print(f"--- api_get_user_by_username: Requesting user ID from JWT: {requesting_user_id} ---")
        else:
             print(f"--- api_get_user_by_username: No valid JWT found. Requesting user ID is None. ---")
    except Exception as e:
        # Log any unexpected errors during identity retrieval
        print(f"!!! Error getting JWT identity in api_get_user_by_username: {e} ---")
        print(traceback.format_exc())
        # Continue with requesting_user_id = None

    # First, get the target user's ID by username or email
    target_user_basic = get_user_by_username_or_email(username)
    if not target_user_basic:
        print(f"--- api_get_user_by_username: Target user '{username}' not found. ---")
        return jsonify({"error": "User not found"}), 404

    target_user_id = target_user_basic['user_id']
    print(f"--- api_get_user_by_username: Target user ID found: {target_user_id} ---")

    # Use the modified get_user_by_id function which handles privacy and follow status
    # Pass both the target user ID and the requesting user ID
    user_data = get_user_by_id(target_user_id, requesting_user_id=requesting_user_id)

    if user_data:
        # Format created_at and updated_at timestamps to ISO 8601 strings
        if 'created_at' in user_data and isinstance(user_data['created_at'], datetime):
            user_data['created_at'] = user_data['created_at'].isoformat()
        if 'updated_at' in user_data and isinstance(user_data['updated_at'], datetime):
            user_data['updated_at'] = user_data['updated_at'].isoformat()

        print(f"--- api_get_user_by_username: Successfully fetched user data for '{username}'. ---")
        return jsonify(user_data), 200
    else:
        # This case should ideally not be reached if target_user_basic was found,
        # unless get_user_by_id failed internally after finding the user.
        print(f"--- api_get_user_by_username: Failed to fetch user data for '{username}' via get_user_by_id. ---")
        return jsonify({"error": "Failed to retrieve user data"}), 500 # Or 404 if get_user_by_id returns None for privacy reasons (though get_user_by_id should return limited data instead of None)

# --- User Privacy Settings Endpoint ---
@app.route('/api/users/me/privacy', methods=['PUT'])
@jwt_required()
def api_update_my_privacy_status():
    current_user_id = int(get_jwt_identity())
    data = request.get_json()
    is_private = data.get('is_private')

    if is_private is None or not isinstance(is_private, bool):
        return jsonify({'success': False, 'message': 'Missing or invalid "is_private" boolean value'}), 400

    try:
        # Assuming update_user_privacy_status function exists in db_utils
        from db_utils import update_user_privacy_status # Import the function
        success = update_user_privacy_status(current_user_id, is_private)
        if success:
            # If the user is becoming private, delete any pending follow requests *from* them
            # to users they were trying to follow privately before. This might be complex
            # and not strictly necessary for the core feature, so let's skip for now.

            # If the user is becoming public, automatically accept all pending follow requests *to* them
            # TODO: Implement accept_all_pending_follow_requests in db_utils.py if this functionality is desired.
            # if not is_private:
            #      from db_utils import accept_all_pending_follow_requests # Need to implement this
            #      accept_all_pending_follow_requests(current_user_id)


            return jsonify({'success': True, 'message': 'Privacy status updated successfully'}), 200
        else:
            return jsonify({'success': False, 'message': 'Failed to update privacy status'}), 500
    except Exception as e:
        print(f"!!! Error in api_update_my_privacy_status: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': 'An internal error occurred during privacy update'}), 500


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
@jwt_required()
def upload_image():
    # --- Get User ID ---
    jwt_user_id_str = get_jwt_identity()
    user_id_for_filename = jwt_user_id_str # String for filename
    # user_id = int(jwt_user_id_str) # Not needed for DB here, only for filename
    # --- End Get User ID ---

    # user_id is now obtained from get_jwt_identity(), remove from form data expectation
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
            filename = f"user_{user_id_for_filename}_{int(time.time())}.{file.filename.rsplit('.', 1)[1].lower()}"
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

# --- User Profile Update Endpoint (for Mobile App) ---
@app.route('/api/users/<int:user_id_from_path>/profile', methods=['PUT'])
@jwt_required()
def api_update_user_profile_details(user_id_from_path):
    current_user_id = int(get_jwt_identity())

    if current_user_id != user_id_from_path:
        return jsonify({'success': False, 'message': 'Unauthorized to update this profile'}), 403

    data = request.get_json()
    if not data:
        return jsonify({'success': False, 'message': 'No data provided'}), 400

    username = data.get('username')
    profile_image_url = data.get('profile_image_url')

    update_payload = {}
    if username is not None: # Allow sending empty string to clear username if desired, but usually validated
        if not isinstance(username, str) or len(username.strip()) < 3 : # Basic validation
             return jsonify({'success': False, 'message': 'Username must be a string and at least 3 characters long'}), 400
        update_payload['username'] = username.strip()
    
    if profile_image_url is not None: # Allow sending empty string to clear profile image URL
        if not isinstance(profile_picture_url, str):
            return jsonify({'success': False, 'message': 'Profile image URL must be a string'}), 400
        update_payload['profile_picture_url'] = profile_picture_url # Ensure db_utils uses this key

    if not update_payload:
        return jsonify({'success': False, 'message': 'No valid fields provided for update'}), 400

    try:
        # Ensure db_utils.update_user_profile can handle these specific keyword arguments
        # It should ideally update only the fields provided.
        success = update_user_profile(user_id_from_path, **update_payload)
        if success:
            # Optionally, fetch and return the updated user object
            updated_user = get_user_by_id(user_id_from_path) # Assumes get_user_by_id returns a serializable dict
            return jsonify({'success': True, 'message': 'Profile updated successfully', 'user': updated_user}), 200
        else:
            # This could be due to various reasons, e.g., username taken (if db_utils handles this)
            return jsonify({'success': False, 'message': 'Failed to update profile (e.g., username might be taken or no changes made)'}), 400 # Or 409 if username conflict
    except Exception as e:
        print(f"!!! Error in api_update_user_profile_details: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': 'An internal error occurred during profile update'}), 500


# --- Account Update Endpoint (Existing, for Web with form-data) ---
@app.route('/update_account', methods=['POST'])
@jwt_required()
def update_account():
    # --- Get User ID ---
    jwt_user_id_str = get_jwt_identity()
    user_id_for_filename = jwt_user_id_str # String for filename
    user_id_for_db = int(jwt_user_id_str)   # Integer for DB operations
    # --- End Get User ID ---

    username = request.form.get('username')
    profile_picture_file = request.files.get('profile_picture')

    profile_picture_url = None
    if profile_picture_file and allowed_file(profile_picture_file.filename):
        # Use similar logic to the image upload endpoint to save the file
        try:
            filename = f"user_{user_id_for_filename}_profile_{int(time.time())}.{profile_picture_file.filename.rsplit('.', 1)[1].lower()}"
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

        if not update_payload:
             return jsonify({'success': False, 'message': 'No update data provided'}), 400

        success = update_user_profile(user_id_for_db, **update_data) # Use int user_id for DB

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
