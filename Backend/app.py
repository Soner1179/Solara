from flask import Flask, render_template, request, jsonify
import os
from flask_cors import CORS
import bcrypt
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
    delete_saved_post # <-- Kaydedileni kaldırmak için (varsayımsal)
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
CORS(app) # Bu satır, tüm origin'lerden gelen isteklere izin verir (geliştirme için)

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
    # TODO: Web için de kullanıcı oturumunu kontrol et ve ona göre feed getir.
    # Şimdilik hala tüm gönderileri gösteriyor.
    # Flask session veya benzeri bir mekanizma kullanarak user_id alınmalı.
    # user_id = session.get('user_id')
    # if user_id:
    #    posts = get_home_feed_posts(user_id)
    # else:
    #    posts = get_all_posts() # Veya login sayfasına yönlendir
    posts = get_all_posts()
    return render_template('home.html', posts=posts)

@app.route('/messages')
def messages_page():
    # TODO: Web mesajları için kullanıcı oturumu gerektirir.
    return render_template('messages.html')

@app.route('/profile')
def profile_page():
    # TODO: Web profili için kullanıcı oturumu veya URL'den username alınmalı.
    return render_template('profile.html')

@app.route('/create_post')
def create_post_page():
    # TODO: Web için kullanıcı oturumu kontrolü ekle
    return render_template('create_post.html')

@app.route('/settings')
def settings_page():
    # TODO: Web için kullanıcı oturumu kontrolü ekle
    return render_template('settings.html')

# --- API Endpoints for Mobile and Web ---

# Helper function (placeholder) for getting user ID from token
def get_user_id_from_token(auth_header):
    # In a real app, validate the token (e.g., JWT) and extract user_id
    # For now, return None or a dummy ID based on a simple scheme if needed
    # Example: if auth_header == "Bearer valid_token_for_user_1": return 1
    return None # Replace with real implementation

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
        return jsonify({
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
        }), 200
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

        return jsonify({
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
        }), 201
    else:
        # This assumes create_user returns None on failure (e.g., duplicate user)
        return jsonify({'success': False, 'message': 'Username or email already exists'}), 409

# --- Post Endpoints ---

@app.route('/api/posts', methods=['POST'])
def api_create_post():
    # --- Production Auth ---
    # auth_header = request.headers.get('Authorization')
    # user_id = get_user_id_from_token(auth_header)
    # if not user_id:
    #    return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- Temp Auth ---
    data = request.get_json()
    user_id = data.get('user_id')
    if not user_id:
        return jsonify({'success': False, 'message': 'Missing user_id in request body'}), 400
    try:
        user_id = int(user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid user_id in request body'}), 400
    # --- End Temp Auth ---

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
    # --- Production Auth ---
    # auth_header = request.headers.get('Authorization')
    # user_id = get_user_id_from_token(auth_header)
    # if not user_id:
    #    return jsonify({"error": "Authentication required"}), 401
    # --- Temp Auth ---
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"error": "Missing user_id query parameter for home feed"}), 400
    try:
        user_id = int(user_id)
    except ValueError:
        return jsonify({"error": "Invalid user_id query parameter"}), 400
    # --- End Temp Auth ---

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
    # --- Production Auth (Optional, depending on if user list is public) ---
    # auth_header = request.headers.get('Authorization')
    # requesting_user_id = get_user_id_from_token(auth_header)
    # if not requesting_user_id:
    #    # If user list requires authentication
    #    return jsonify({"error": "Authentication required"}), 401
    # --- End Production Auth ---

    # Get the exclude_user_id from query parameters
    exclude_user_id_str = request.args.get('exclude_user_id')
    exclude_user_id = None
    if exclude_user_id_str:
        try:
            exclude_user_id = int(exclude_user_id_str)
        except ValueError:
            return jsonify({"error": "Invalid exclude_user_id query parameter"}), 400

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


@app.route('/api/posts/<int:post_id>', methods=['GET'])
def api_get_post(post_id):
    # TODO: Implement get_post_by_id(post_id) in db_utils
    # For now, returning a placeholder or error
    return jsonify({"error": "Get post by ID endpoint not fully implemented yet"}), 501 # Not Implemented

@app.route('/api/users/<int:user_id>/posts', methods=['GET'])
def api_get_user_posts(user_id):
    # This endpoint gets posts specifically for a user's profile
    posts = get_posts_by_user_id(user_id)
    # Optionally add like/comment counts if not already included by the db_utils function
    return jsonify(posts), 200

# --- Like Endpoints ---

@app.route('/api/posts/<int:post_id>/likes', methods=['POST'])
def api_like_post(post_id):
    # --- Production Auth ---
    # auth_header = request.headers.get('Authorization')
    # user_id = get_user_id_from_token(auth_header)
    # if not user_id:
    #    return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- Temp Auth ---
    data = request.get_json()
    user_id = data.get('user_id') # Expecting user_id in body for POST
    if not user_id:
        return jsonify({'success': False, 'message': 'Missing user_id in request body'}), 400
    try:
        user_id = int(user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid user_id in request body'}), 400
    # --- End Temp Auth ---

    like_id = create_like(user_id, post_id)
    if like_id:
        return jsonify({'success': True, 'message': 'Post liked', 'like_id': like_id}), 201
    else:
        # Could be duplicate like (UniqueViolation) or other error
        return jsonify({'success': False, 'message': 'Failed to like post (maybe already liked?)'}), 409 # Conflict or 500

@app.route('/api/posts/<int:post_id>/likes', methods=['DELETE'])
def api_unlike_post(post_id):
    # --- Production Auth ---
    # auth_header = request.headers.get('Authorization')
    # user_id = get_user_id_from_token(auth_header)
    # if not user_id:
    #    return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- Temp Auth ---
    user_id = request.args.get('user_id') # Expecting user_id in query params for DELETE
    if not user_id:
        return jsonify({'success': False, 'message': 'Missing user_id query parameter'}), 400
    try:
        user_id = int(user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid user_id query parameter'}), 400
    # --- End Temp Auth ---

    # Assumes db_utils.delete_like(user_id, post_id) exists
    success = delete_like(user_id, post_id)
    if success:
        return jsonify({'success': True, 'message': 'Post unliked'}), 200
    else:
        return jsonify({'success': False, 'message': 'Failed to unlike post (like not found?)'}), 404 # Not Found or 500

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
    # --- Production Auth ---
    # auth_header = request.headers.get('Authorization')
    # user_id = get_user_id_from_token(auth_header)
    # if not user_id:
    #    return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- Temp Auth ---
    data = request.get_json()
    user_id = data.get('user_id') # Expecting user_id in body
    if not user_id:
        return jsonify({'success': False, 'message': 'Missing user_id in request body'}), 400
    try:
        user_id = int(user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid user_id in request body'}), 400
    # --- End Temp Auth ---

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
    # --- Production Auth ---
    # auth_header = request.headers.get('Authorization')
    # follower_user_id = get_user_id_from_token(auth_header) # The user performing the action
    # if not follower_user_id:
    #    return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- Temp Auth ---
    data = request.get_json()
    follower_user_id = data.get('follower_user_id') # Expect follower_user_id in body
    if not follower_user_id:
        return jsonify({'success': False, 'message': 'Missing follower_user_id in request body'}), 400
    try:
        follower_user_id = int(follower_user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid follower_user_id in request body'}), 400
    # --- End Temp Auth ---

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
    # --- Production Auth ---
    # auth_header = request.headers.get('Authorization')
    # follower_user_id = get_user_id_from_token(auth_header) # The user performing the action
    # if not follower_user_id:
    #    return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- Temp Auth ---
    follower_user_id = request.args.get('follower_user_id') # Expect follower_user_id in query params
    if not follower_user_id:
        return jsonify({'success': False, 'message': 'Missing follower_user_id query parameter'}), 400
    try:
        follower_user_id = int(follower_user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid follower_user_id query parameter'}), 400
    # --- End Temp Auth ---

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


# --- Saved Post (Bookmark) Endpoints ---

@app.route('/api/posts/<int:post_id>/saved', methods=['POST'])
def api_save_post(post_id):
    # --- Production Auth ---
    # auth_header = request.headers.get('Authorization')
    # user_id = get_user_id_from_token(auth_header)
    # if not user_id:
    #    return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- Temp Auth ---
    data = request.get_json()
    user_id = data.get('user_id') # Expecting user_id in body for POST
    if not user_id:
        return jsonify({'success': False, 'message': 'Missing user_id in request body'}), 400
    try:
        user_id = int(user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid user_id in request body'}), 400
    # --- End Temp Auth ---

    saved_post_id = create_saved_post(user_id, post_id)
    if saved_post_id:
        return jsonify({'success': True, 'message': 'Post saved', 'saved_post_id': saved_post_id}), 201
    else:
        return jsonify({'success': False, 'message': 'Failed to save post (maybe already saved?)'}), 409 # Conflict or 500


@app.route('/api/posts/<int:post_id>/saved', methods=['DELETE'])
def api_unsave_post(post_id):
    # --- Production Auth ---
    # auth_header = request.headers.get('Authorization')
    # user_id = get_user_id_from_token(auth_header)
    # if not user_id:
    #    return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- Temp Auth ---
    user_id = request.args.get('user_id') # Expecting user_id in query params for DELETE
    if not user_id:
        return jsonify({'success': False, 'message': 'Missing user_id query parameter'}), 400
    try:
        user_id = int(user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid user_id query parameter'}), 400
    # --- End Temp Auth ---

    # Assumes db_utils.delete_saved_post(user_id, post_id) exists
    success = delete_saved_post(user_id, post_id)
    if success:
        return jsonify({'success': True, 'message': 'Post unsaved'}), 200
    else:
        return jsonify({'success': False, 'message': 'Failed to unsave post (save record not found?)'}), 404 # Not Found or 500


@app.route('/api/users/<int:user_id>/saved-posts', methods=['GET'])
def api_get_saved_posts(user_id):
    # --- Auth Check (Optional but recommended) ---
    # auth_header = request.headers.get('Authorization')
    # requesting_user_id = get_user_id_from_token(auth_header)
    # if not requesting_user_id or requesting_user_id != user_id:
    #     # Allow fetching only own saved posts unless admin/specific logic
    #     return jsonify({"error": "Unauthorized to view saved posts for this user"}), 403
    # --- End Auth Check ---

    saved_posts = get_saved_posts_for_user(user_id)
    return jsonify(saved_posts), 200

# --- Message Endpoints ---

@app.route('/api/messages', methods=['POST'])
def api_create_message():
     # --- Production Auth ---
    # auth_header = request.headers.get('Authorization')
    # sender_user_id = get_user_id_from_token(auth_header)
    # if not sender_user_id:
    #    return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- Temp Auth ---
    data = request.get_json()
    sender_user_id = data.get('sender_id') # Use 'sender_id' to match api_service.dart
    if not sender_user_id:
        return jsonify({'success': False, 'message': 'Missing sender_id in request body'}), 400
    try:
        sender_user_id = int(sender_user_id)
    except ValueError:
        return jsonify({'success': False, 'message': 'Invalid sender_id in request body'}), 400
    # --- End Temp Auth ---

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
    # auth_header = request.headers.get('Authorization')
    # requesting_user_id = get_user_id_from_token(auth_header)
    # if not requesting_user_id or (requesting_user_id != user1_id and requesting_user_id != user2_id):
    #     return jsonify({"error": "Unauthorized to view these messages"}), 403
    # --- End Auth Check ---

    messages = get_messages_between_users(user1_id, user2_id)
    return jsonify(messages), 200

@app.route('/api/users/<int:user_id>/chats', methods=['GET'])
def api_get_user_chats(user_id):
    # --- Auth Check ---
    # auth_header = request.headers.get('Authorization')
    # requesting_user_id = get_user_id_from_token(auth_header)
    # if not requesting_user_id or requesting_user_id != user_id:
    #     return jsonify({"error": "Unauthorized to view chats for this user"}), 403
    # --- End Auth Check ---

    chat_summaries = get_chat_summaries_for_user(user_id)
    return jsonify(chat_summaries), 200


# --- Notification Endpoints ---

@app.route('/api/users/<int:user_id>/notifications', methods=['GET'])
def api_get_user_notifications(user_id):
     # --- Auth Check ---
    # auth_header = request.headers.get('Authorization')
    # requesting_user_id = get_user_id_from_token(auth_header)
    # if not requesting_user_id or requesting_user_id != user_id:
    #     return jsonify({"error": "Unauthorized to view notifications for this user"}), 403
    # --- End Auth Check ---

    notifications = get_notifications_for_user(user_id)
    return jsonify(notifications), 200

@app.route('/api/notifications/<int:notification_id>/read', methods=['PUT'])
def api_mark_notification_read(notification_id):
    # --- Auth Check (Optional but good: ensure user owns the notification) ---
    # auth_header = request.headers.get('Authorization')
    # requesting_user_id = get_user_id_from_token(auth_header)
    # if not requesting_user_id: return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # Check if notification belongs to requesting_user_id before marking as read
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
    # auth_header = request.headers.get('Authorization')
    # requesting_user_id = get_user_id_from_token(auth_header)
    # if not requesting_user_id or requesting_user_id != user_id:
    #     return jsonify({"error": "Unauthorized to view settings for this user"}), 403
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
    # auth_header = request.headers.get('Authorization')
    # requesting_user_id = get_user_id_from_token(auth_header)
    # if not requesting_user_id or requesting_user_id != user_id:
    #     return jsonify({"error": "Unauthorized to update settings for this user"}), 403
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
    # --- Auth Check ---
    # auth_header = request.headers.get('Authorization')
    # user_id = get_user_id_from_token(auth_header)
    # if not user_id:
    #    return jsonify({'success': False, 'message': 'Authentication required'}), 401
    # --- End Auth Check ---

    # --- Temp User ID from form data ---
    user_id = request.form.get('user_id')
    if not user_id:
        # If user_id is not provided in form data, use 'unknown' for filename
        user_id = 'unknown'
    else:
        try:
            user_id = int(user_id)
        except ValueError:
            user_id = 'invalid_id' # Handle invalid user_id format

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

# Configure static file serving for uploads
from flask import send_from_directory
@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


if __name__ == '__main__':
    import time # Needed for temporary filename generation
    # In production, use a production-ready WSGI server like Gunicorn or uWSGI
    # And set debug=False
    app.run(debug=True, host='0.0.0.0', port=5000)
