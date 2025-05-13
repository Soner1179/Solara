from flask import Flask, render_template, request, jsonify, make_response, redirect, url_for, send_from_directory
import os
import time
from flask_cors import CORS
import bcrypt
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity, JWTManager, verify_jwt_in_request
from flask_mail import Mail, Message
import random
import string
from datetime import datetime, timedelta, timezone
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
    mark_notification_as_read,
    get_home_feed_posts,
    get_suggested_users,
    delete_like,
    delete_saved_post,
    get_post_like_count,
    search_users,
    update_user_profile,
    store_verification_code,
    get_user_by_email_for_verification,
    mark_email_as_verified,
    check_if_email_exists,
    is_following_user # Ensure this is imported
    # Add placeholder for new function needed for /api/users/<id>/likes
    # get_liked_post_ids_for_user # Placeholder - needs implementation in db_utils
)

# Tell Flask where to find the templates and static files relative to this script
app = Flask(__name__, template_folder='../Web/templates', static_folder='../Web/static')
CORS(app) # This line allows requests from all origins (for development)

# Configure JWT settings
app.config["JWT_SECRET_KEY"] = "your-super-secret-jwt-key-change-this"  # Change this in your environment!
# Configure JWT to look for tokens in cookies as well (optional, but can be useful)
app.config["JWT_TOKEN_LOCATION"] = ["headers", "cookies"]
jwt = JWTManager(app)

# Flask-Mail configuration
app.config['MAIL_SERVER'] = os.environ.get('MAIL_SERVER', 'smtp.gmail.com')
app.config['MAIL_PORT'] = int(os.environ.get('MAIL_PORT', 587))
app.config['MAIL_USE_TLS'] = os.environ.get('MAIL_USE_TLS', 'True').lower() == 'true'
app.config['MAIL_USE_SSL'] = os.environ.get('MAIL_USE_SSL', 'False').lower() == 'true'
app.config['MAIL_USERNAME'] = os.environ.get('MAIL_USERNAME')
app.config['MAIL_PASSWORD'] = os.environ.get('MAIL_PASSWORD')
app.config['MAIL_DEFAULT_SENDER'] = os.environ.get('MAIL_DEFAULT_SENDER')

mail = Mail(app)

@app.after_request
def add_header(response):
    """
    Add headers to disable caching for static files during development.
    """
    if request.path.startswith('/static/') or request.path.startswith('/api/'):
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
    return response

# --- Web Page Routes ---

@app.route('/')
def index_page():
    return render_template('login.html')

@app.route('/login')
def login_page():
    return render_template('login.html')

@app.route('/forgot_password')
def forgot_password_page():
    return render_template('forgot_password.html')

@app.route('/home')
@jwt_required() # Protect home page
def home_page():
    user_id = int(get_jwt_identity()) # Get user ID from JWT
    # Fetch personalized feed and suggested users
    posts = get_home_feed_posts(user_id)
    suggested_users = get_suggested_users(user_id)
    # Check follow status for suggested_users
    for user in suggested_users:
        user['is_following'] = is_following_user(user_id, user['user_id'])

    return render_template('home.html', posts=posts, suggested_users=suggested_users, user_id=user_id)

@app.route('/messages')
@jwt_required() # Protect messages page
def messages_page():
    user_id = int(get_jwt_identity()) # Get user ID from JWT
    return render_template('messages.html', user_id=user_id) # Pass user_id to the template

@app.route('/profile')
@jwt_required() # Protect profile page
def profile_page():
    user_id = int(get_jwt_identity()) # Get user ID from JWT
    print(f"--- /profile route: Authenticated user_id from JWT: {user_id} ---")

    # Fetch the user data for the profile page
    user = get_user_by_id(user_id)
    print(f"--- /profile route: Result of get_user_by_id({user_id}): {user} ---")
    if not user:
        print(f"--- /profile route: Authenticated user with ID {user_id} not found in DB. ---")
        # This indicates an issue, maybe user deleted after token issued?
        # Redirect to login or show error
        return redirect(url_for('login_page', error='User not found'))

    # Fetch posts for the user's own profile
    # Pass user_id as both the profile owner and the requesting user
    posts = get_posts_by_user_id(user_id, requesting_user_id=user_id)
    # You don't follow yourself
    is_following_profile_user = False

    # Pass user data, posts, and following status to the template
    return render_template('profile.html', user=user, posts=posts, is_following=is_following_profile_user, user_id=user_id)

# Route for viewing other users' profiles (requires username in URL)
@app.route('/profile/<string:username>')
@jwt_required(optional=True) # Allow viewing profiles without login
def view_profile_page(username):
    requesting_user_id = None
    try:
        requesting_user_id = int(get_jwt_identity())
    except Exception:
        pass # User not logged in

    # Fetch the profile user's data based on username
    profile_user = get_user_by_username_or_email(username)
    if not profile_user:
        return "User not found", 404 # Simple 404 page or template

    profile_user_id = profile_user['user_id']

    # Fetch posts for the profile user, passing the requesting user ID for like/save status
    posts = get_posts_by_user_id(profile_user_id, requesting_user_id=requesting_user_id)

    # Determine if the requesting user is following the profile user
    is_following_profile_user = False
    if requesting_user_id and requesting_user_id != profile_user_id:
        is_following_profile_user = is_following_user(requesting_user_id, profile_user_id)

    # Pass profile user data, posts, following status, and requesting user ID to the template
    return render_template('profile.html', user=profile_user, posts=posts, is_following=is_following_profile_user, user_id=requesting_user_id)


@app.route('/create_post')
@jwt_required() # Protect create post page
def create_post_page():
    user_id = int(get_jwt_identity())
    return render_template('create_post.html', user_id=user_id)

@app.route('/settings')
@jwt_required() # Protect settings page
def settings_page():
    user_id = int(get_jwt_identity())
    return render_template('settings.html', user_id=user_id)

@app.route('/discover')
@jwt_required(optional=True) # Discover might be public, but use token if available
def discover_page():
    user_id = None
    try:
        user_id = int(get_jwt_identity())
    except Exception:
        pass # User not logged in
    return render_template('discover.html', user_id=user_id)

@app.route('/notifications')
@jwt_required() # Protect notifications page
def notifications_page():
    user_id = int(get_jwt_identity())
    return render_template('notifications.html', user_id=user_id)

@app.route('/saved_posts')
@jwt_required() # Protect saved posts page
def saved_posts_page():
    user_id = int(get_jwt_identity())
    return render_template('saved_posts.html', user_id=user_id)


# --- API Endpoints for Mobile and Web ---

@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.get_json()
    username_or_email = data.get('username_or_email')
    password = data.get('password')

    if not username_or_email or not password:
        return jsonify({'success': False, 'message': 'Missing username/email or password'}), 400

    user = get_user_by_username_or_email(username_or_email)

    if user and bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
        access_token = create_access_token(identity=str(user['user_id']))
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
            'token': access_token
        }), 200)
        # Set JWT as a cookie (optional, useful for web if not using localStorage exclusively)
        response.set_cookie('access_token_cookie', access_token, httponly=True, samesite='Lax')
        return response
    else:
        return jsonify({'success': False, 'message': 'Invalid username/email or password'}), 401

@app.route('/api/send_verification_code', methods=['POST'])
def send_verification_code():
    data = request.get_json()
    email = data.get('email')
    if not email: return jsonify({'success': False, 'message': 'Email is required'}), 400
    if check_if_email_exists(email): return jsonify({'success': False, 'message': 'This email is already registered and verified.'}), 409
    code = ''.join(random.choices(string.digits, k=6))
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)
    if not store_verification_code(email, code, expires_at): return jsonify({'success': False, 'message': 'Failed to store verification code.'}), 500
    try:
        msg = Message('Your Solara Verification Code', recipients=[email])
        msg.body = f'Your verification code for Solara is: {code}\nThis code will expire in 10 minutes.'
        mail.send(msg)
        return jsonify({'success': True, 'message': 'Verification code sent.'}), 200
    except Exception as e:
        print(f"Error sending email: {e}")
        return jsonify({'success': False, 'message': 'Failed to send verification email.'}), 500

@app.route('/api/signup', methods=['POST'])
def api_signup():
    data = request.get_json()
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')
    verification_code_input = data.get('verification_code')
    full_name = data.get('full_name')
    profile_picture_url = data.get('profile_picture_url')

    if not all([username, email, password, verification_code_input]):
        return jsonify({'success': False, 'message': 'Missing required fields'}), 400

    user_verification_data = get_user_by_email_for_verification(email)
    if not user_verification_data: return jsonify({'success': False, 'message': 'Email not found or verification not started.'}), 404
    stored_code = user_verification_data.get('verification_code')
    code_expires_at = user_verification_data.get('code_expires_at')
    is_verified = user_verification_data.get('is_email_verified')

    if is_verified: return jsonify({'success': False, 'message': 'Email already verified.'}), 409
    if not stored_code or not code_expires_at: return jsonify({'success': False, 'message': 'Verification data missing.'}), 400
    if code_expires_at.tzinfo is None: code_expires_at = code_expires_at.replace(tzinfo=timezone.utc)
    if stored_code != verification_code_input: return jsonify({'success': False, 'message': 'Invalid verification code.'}), 400
    if datetime.now(timezone.utc) > code_expires_at: return jsonify({'success': False, 'message': 'Verification code expired.'}), 400

    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
    existing_user = get_user_by_username_or_email(username)
    if existing_user and existing_user['email'] != email: return jsonify({'success': False, 'message': 'Username already exists.'}), 409

    user_id = create_user(username, email, hashed_password.decode('utf-8'), full_name=full_name, profile_picture_url=profile_picture_url)
    if user_id:
        if not mark_email_as_verified(email):
            print(f"CRITICAL: Failed to mark email {email} as verified for user_id {user_id}")
            return jsonify({'success': False, 'message': 'Account created, but failed email verification step.'}), 500
        access_token = create_access_token(identity=str(user_id))
        update_user_settings(user_id) # Create default settings
        response = make_response(jsonify({
            'success': True, 'message': 'Account created successfully',
            'user': {'user_id': user_id, 'username': username, 'email': email, 'full_name': full_name, 'profile_picture_url': profile_picture_url},
            'token': access_token
        }), 201)
        response.set_cookie('access_token_cookie', access_token, httponly=True, samesite='Lax')
        return response
    else:
        return jsonify({'success': False, 'message': 'Failed to create account.'}), 409

# --- Post Endpoints ---

@app.route('/api/posts', methods=['POST'])
@jwt_required()
def api_create_post():
    user_id = int(get_jwt_identity())
    data = request.get_json()
    content_text = data.get('content_text')
    image_url = data.get('image_url')
    if not content_text and not image_url: return jsonify({'success': False, 'message': 'Post must have content text or an image'}), 400
    post_id = create_post(user_id, content_text, image_url)
    if post_id: return jsonify({'success': True, 'message': 'Post created', 'post_id': post_id}), 201
    else: return jsonify({'success': False, 'message': 'Failed to create post'}), 500

@app.route('/api/posts', methods=['GET'])
@jwt_required()
def api_get_home_feed_posts():
    user_id = int(get_jwt_identity())
    posts = get_home_feed_posts(user_id)
    # Add like/save status (assuming get_home_feed_posts includes this)
    # If not, fetch liked/saved IDs and merge here
    return jsonify(posts), 200

# --- User Endpoints (General) ---

@app.route('/api/users', methods=['GET'])
@jwt_required(optional=True) # Allow fetching users without login
def api_get_all_users():
    requesting_user_id = None
    try: requesting_user_id = int(get_jwt_identity())
    except Exception: pass

    exclude_user_id_str = request.args.get('exclude_user_id')
    exclude_user_id = None
    if exclude_user_id_str:
        try: exclude_user_id = int(exclude_user_id_str)
        except ValueError: return jsonify({"error": "Invalid exclude_user_id"}), 400
    elif requesting_user_id:
        exclude_user_id = requesting_user_id # Exclude self if logged in

    try:
        users = get_all_users(current_user_id=exclude_user_id)
        return jsonify(users), 200
    except Exception as e:
        print(f"Error in api_get_all_users: {e}")
        return jsonify({"error": "Failed to fetch users"}), 500

# --- User Search Endpoint ---
@app.route('/api/users/search', methods=['GET'])
@jwt_required(optional=True) # Allow searching without login
def api_search_users():
    requesting_user_id = None
    try: requesting_user_id = int(get_jwt_identity())
    except Exception: pass

    search_query = request.args.get('query')
    if not search_query: return jsonify({"error": "Missing 'query' parameter"}), 400

    exclude_user_id_str = request.args.get('exclude_user_id')
    exclude_user_id = None
    if exclude_user_id_str:
        try: exclude_user_id = int(exclude_user_id_str)
        except ValueError: return jsonify({"error": "Invalid exclude_user_id"}), 400
    elif requesting_user_id:
        exclude_user_id = requesting_user_id # Exclude self if logged in

    try:
        users = search_users(search_query, current_user_id=exclude_user_id)
        return jsonify(users), 200
    except Exception as e:
        print(f"Error searching users: {e}")
        return jsonify({"error": "Failed to search users"}), 500

@app.route('/api/posts/<int:post_id>', methods=['GET'])
@jwt_required(optional=True) # Allow viewing single post without login
def api_get_post(post_id):
    # TODO: Implement get_post_by_id(post_id) in db_utils
    # Should also fetch like/save status if user is logged in
    return jsonify({"error": "Get post by ID not fully implemented"}), 501

@app.route('/api/users/<int:user_id>/posts', methods=['GET'])
@jwt_required(optional=True) # Allow viewing user posts without login
def api_get_user_posts(user_id):
    requesting_user_id = None
    try: requesting_user_id = int(get_jwt_identity())
    except Exception: pass
    posts = get_posts_by_user_id(user_id, requesting_user_id) # Pass requesting user for like/save status
    return jsonify(posts), 200

# --- Like Endpoints ---

@app.route('/api/posts/<int:post_id>/likes', methods=['POST'])
@jwt_required()
def api_like_post(post_id):
    user_id = int(get_jwt_identity())
    try:
        like_id = create_like(user_id, post_id)
        if like_id:
            updated_like_count = get_post_like_count(post_id)
            return jsonify({'success': True, 'message': 'Post liked', 'like_id': like_id, 'likes_count': updated_like_count}), 201
        else: return jsonify({'success': False, 'message': 'Already liked?'}), 409
    except Exception as e:
        print(f"Error liking post: {e}")
        return jsonify({'success': False, 'message': 'Internal error'}), 500

@app.route('/api/posts/<int:post_id>/likes', methods=['DELETE'])
@jwt_required()
def api_unlike_post(post_id):
    user_id = int(get_jwt_identity())
    try:
        success = delete_like(user_id, post_id)
        if success:
            updated_like_count = get_post_like_count(post_id)
            return jsonify({'success': True, 'message': 'Post unliked', 'likes_count': updated_like_count}), 200
        else: return jsonify({'success': False, 'message': 'Like not found?'}), 404
    except Exception as e:
        print(f"Error unliking post: {e}")
        return jsonify({'success': False, 'message': 'Internal error'}), 500

@app.route('/api/posts/<int:post_id>/likes', methods=['GET'])
@jwt_required(optional=True) # Allow getting likers without login
def api_get_post_likes(post_id):
    likes = get_likes_for_post(post_id) # Returns list of user dicts
    return jsonify(likes), 200

# --- Comment Endpoints ---

@app.route('/api/posts/<int:post_id>/comments', methods=['GET'])
@jwt_required(optional=True) # Allow getting comments without login
def api_get_post_comments(post_id):
    comments = get_comments_for_post(post_id)
    return jsonify(comments), 200

@app.route('/api/comments', methods=['POST'])
@jwt_required()
def api_create_comment():
    user_id = int(get_jwt_identity())
    data = request.get_json()
    post_id_from_req = data.get('post_id')
    comment_text = data.get('comment_text')
    if not post_id_from_req or not comment_text: return jsonify({'success': False, 'message': 'Missing post_id or comment_text'}), 400
    try: post_id_int = int(post_id_from_req)
    except ValueError: return jsonify({'success': False, 'message': 'Invalid post_id'}), 400
    comment_id = create_comment(user_id, post_id_int, comment_text)
    if comment_id: return jsonify({'success': True, 'message': 'Comment created', 'comment_id': comment_id}), 201
    else: return jsonify({'success': False, 'message': 'Failed to create comment'}), 500

# --- Follow Endpoints ---

@app.route('/api/follow', methods=['POST'])
@jwt_required()
def api_create_follow():
    follower_user_id = int(get_jwt_identity())
    data = request.get_json()
    followed_user_id_from_req = data.get('followed_user_id')
    if not followed_user_id_from_req: return jsonify({'success': False, 'message': 'Missing followed_user_id'}), 400
    try: followed_user_id = int(followed_user_id_from_req)
    except ValueError: return jsonify({'success': False, 'message': 'Invalid followed_user_id'}), 400
    if follower_user_id == followed_user_id: return jsonify({'success': False, 'message': 'Cannot follow self'}), 400
    follow_id = create_follow(follower_user_id, followed_user_id)
    if follow_id: return jsonify({'success': True, 'message': 'Follow created', 'follow_id': follow_id}), 201
    else: return jsonify({'success': False, 'message': 'Already following?'}), 409

@app.route('/api/follow', methods=['DELETE'])
@jwt_required()
def api_delete_follow():
    follower_user_id = int(get_jwt_identity())
    followed_user_id_from_req = request.args.get('followed_user_id')
    if not followed_user_id_from_req: return jsonify({'success': False, 'message': 'Missing followed_user_id query parameter'}), 400
    try: followed_user_id = int(followed_user_id_from_req)
    except ValueError: return jsonify({'success': False, 'message': 'Invalid followed_user_id'}), 400
    success = delete_follow(follower_user_id, followed_user_id)
    if success: return jsonify({'success': True, 'message': 'Follow deleted'}), 200
    else: return jsonify({'success': False, 'message': 'Follow not found?'}), 404

@app.route('/api/users/<int:user_id>/followers', methods=['GET'])
@jwt_required(optional=True) # Allow viewing followers without login
def api_get_followers(user_id):
    followers = get_followers_for_user(user_id)
    return jsonify(followers), 200

@app.route('/api/users/<int:user_id>/following', methods=['GET'])
@jwt_required(optional=True) # Allow viewing following without login
def api_get_following(user_id):
    following = get_following_for_user(user_id)
    return jsonify(following), 200

# --- Suggested Users Endpoint ---
@app.route('/api/suggested_users', methods=['GET'])
@jwt_required()
def api_get_suggested_users():
    current_user_id = int(get_jwt_identity())
    suggested_users = get_suggested_users(current_user_id)
    for user in suggested_users:
        user['is_following'] = is_following_user(current_user_id, user['user_id'])
    return jsonify(suggested_users), 200

# --- Saved Post (Bookmark) Endpoints ---

@app.route('/api/posts/<int:post_id>/saved', methods=['POST'])
@jwt_required()
def api_save_post(post_id):
    user_id = int(get_jwt_identity())
    try:
        saved_post_id = create_saved_post(user_id, post_id)
        if saved_post_id: return jsonify({'success': True, 'message': 'Post saved', 'saved_post_id': saved_post_id}), 201
        else: return jsonify({'success': False, 'message': 'Already saved?'}), 409
    except Exception as e:
        print(f"Error saving post: {e}")
        return jsonify({'success': False, 'message': 'Internal error'}), 500

@app.route('/api/posts/<int:post_id>/saved', methods=['DELETE'])
@jwt_required()
def api_unsave_post(post_id):
    user_id = int(get_jwt_identity())
    try:
        success = delete_saved_post(user_id, post_id)
        if success: return jsonify({'success': True, 'message': 'Post unsaved'}), 200
        else: return jsonify({'success': False, 'message': 'Save record not found?'}), 404
    except Exception as e:
        print(f"Error unsaving post: {e}")
        return jsonify({'success': False, 'message': 'Internal error'}), 500

# Endpoint used by profile.js to get *list* of saved posts for the logged-in user
@app.route('/api/users/<int:user_id>/saved-posts', methods=['GET'])
@jwt_required()
def api_get_saved_posts_list_for_user(user_id): # Renamed to avoid conflict
    requesting_user_id = int(get_jwt_identity())
    if requesting_user_id != user_id: return jsonify({"error": "Unauthorized"}), 403
    try:
        saved_posts = get_saved_posts_for_user(user_id_of_saver=user_id, requesting_user_id=requesting_user_id)
        return jsonify(saved_posts), 200
    except Exception as e:
        print(f"Error fetching saved posts for user {user_id}: {e}")
        return jsonify({"error": "Failed to fetch saved posts"}), 500

# --- Message Endpoints ---

@app.route('/api/messages', methods=['POST'])
@jwt_required()
def api_create_message():
    sender_user_id = int(get_jwt_identity())
    data = request.get_json()
    receiver_user_id_from_req = data.get('receiver_id')
    message_text = data.get('message_text')
    if not receiver_user_id_from_req or not message_text: return jsonify({'success': False, 'message': 'Missing receiver_id or message_text'}), 400
    try: receiver_user_id = int(receiver_user_id_from_req)
    except ValueError: return jsonify({'success': False, 'message': 'Invalid receiver_id'}), 400
    message_id = create_message(sender_user_id, receiver_user_id, message_text)
    if message_id:
        return jsonify({
            'success': True, 'message': 'Message sent', 'message_id': message_id,
            'sender_user_id': sender_user_id, 'receiver_user_id': receiver_user_id, 'message_text': message_text
        }), 201
    else: return jsonify({'success': False, 'message': 'Failed to send message'}), 500

@app.route('/api/messages/<int:user1_id>/<int:user2_id>', methods=['GET'])
@jwt_required()
def api_get_messages(user1_id, user2_id):
    requesting_user_id = int(get_jwt_identity())
    if requesting_user_id != user1_id and requesting_user_id != user2_id: return jsonify({"error": "Unauthorized"}), 403
    messages = get_messages_between_users(user1_id, user2_id)
    return jsonify(messages), 200

@app.route('/api/users/<int:user_id>/chats', methods=['GET'])
@jwt_required()
def api_get_user_chats(user_id):
    requesting_user_id = int(get_jwt_identity())
    if requesting_user_id != user_id: return jsonify({"error": "Unauthorized"}), 403
    chat_summaries = get_chat_summaries_for_user(user_id)
    return jsonify(chat_summaries), 200

@app.route('/api/users/me/chats', methods=['GET'])
@jwt_required()
def api_get_my_chats():
    user_id = int(get_jwt_identity())
    chat_summaries = get_chat_summaries_for_user(user_id)
    return jsonify(chat_summaries), 200

# --- Notification Endpoints ---

@app.route('/api/users/<int:user_id>/notifications', methods=['GET'])
@jwt_required()
def api_get_user_notifications(user_id): # Renamed param
    requesting_user_id = int(get_jwt_identity())
    if requesting_user_id != user_id: return jsonify({"error": "Unauthorized"}), 403
    notifications = get_notifications_for_user(user_id)
    return jsonify(notifications), 200

@app.route('/api/notifications/<int:notification_id>/read', methods=['PUT'])
@jwt_required()
def api_mark_notification_read(notification_id):
    requesting_user_id = int(get_jwt_identity())
    # TODO: Add auth check: ensure notification belongs to requesting_user_id
    success = mark_notification_as_read(notification_id)
    if success: return jsonify({'success': True, 'message': 'Notification marked read'}), 200
    else: return jsonify({'success': False, 'message': 'Notification not found?'}), 404

# --- User Settings Endpoint ---

@app.route('/api/users/<int:user_id>/settings', methods=['GET'])
@jwt_required()
def api_get_user_settings(user_id): # Renamed param
    requesting_user_id = int(get_jwt_identity())
    if requesting_user_id != user_id: return jsonify({"error": "Unauthorized"}), 403
    settings = get_user_settings(user_id)
    if settings: return jsonify(settings), 200
    else: return jsonify({"error": "User settings not found"}), 404

@app.route('/api/users/<int:user_id>/settings', methods=['PUT'])
@jwt_required()
def api_update_user_settings(user_id): # Renamed param
    requesting_user_id = int(get_jwt_identity())
    if requesting_user_id != user_id: return jsonify({"error": "Unauthorized"}), 403
    data = request.get_json()
    update_data = {}
    if data.get('dark_mode_enabled') is not None: update_data['dark_mode_enabled'] = data['dark_mode_enabled']
    if data.get('email_notifications_enabled') is not None: update_data['email_notifications_enabled'] = data['email_notifications_enabled']
    if not update_data: return jsonify({'success': False, 'message': 'No settings provided'}), 400
    setting_id = update_user_settings(user_id, **update_data)
    if setting_id: return jsonify({'success': True, 'message': 'Settings updated', 'setting_id': setting_id}), 200
    else: return jsonify({'success': False, 'message': 'Failed to update settings'}), 500

# --- User Profile Endpoint (by username) ---
@app.route('/api/users/<string:username>', methods=['GET'])
@jwt_required(optional=True) # Allow viewing profiles without login
def api_get_user_by_username(username):
    requesting_user_id = None
    try: requesting_user_id = int(get_jwt_identity())
    except Exception: pass

    user = get_user_by_username_or_email(username)
    if user:
        followers_count = len(get_followers_for_user(user['user_id']))
        following_count = len(get_following_for_user(user['user_id']))
        post_count = len(get_posts_by_user_id(user['user_id'])) # Assuming this returns count or list
        is_currently_following = False
        if requesting_user_id and requesting_user_id != user['user_id']:
            is_currently_following = is_following_user(requesting_user_id, user['user_id'])
        user_data = {
            'user_id': user['user_id'], 'username': user['username'], 'email': user['email'],
            'full_name': user.get('full_name'), 'profile_picture_url': user.get('profile_picture_url'),
            'created_at': user['created_at'], 'updated_at': user['updated_at'],
            'followers_count': followers_count, 'following_count': following_count,
            'post_count': post_count, 'is_following': is_currently_following
        }
        return jsonify(user_data), 200
    else: return jsonify({"error": "User not found"}), 404

# --- User Profile Endpoint (by ID) --- Added NEW
@app.route('/api/users/<int:user_id>', methods=['GET'])
@jwt_required(optional=True) # Allow viewing profiles without login
def api_get_user_by_id_route(user_id):
    requesting_user_id = None
    try: requesting_user_id = int(get_jwt_identity())
    except Exception: pass

    user = get_user_by_id(user_id) # Fetch by ID
    if user:
        # Re-use the enrichment logic from the username route
        followers_count = len(get_followers_for_user(user['user_id']))
        following_count = len(get_following_for_user(user['user_id']))
        post_count = len(get_posts_by_user_id(user['user_id']))
        is_currently_following = False
        if requesting_user_id and requesting_user_id != user['user_id']:
            is_currently_following = is_following_user(requesting_user_id, user['user_id'])
        user_data = {
            'user_id': user['user_id'], 'username': user['username'], 'email': user['email'],
            'full_name': user.get('full_name'), 'profile_picture_url': user.get('profile_picture_url'),
            'created_at': user['created_at'], 'updated_at': user['updated_at'],
            'followers_count': followers_count, 'following_count': following_count,
            'post_count': post_count, 'is_following': is_currently_following
        }
        return jsonify(user_data), 200
    else: return jsonify({"error": "User not found"}), 404


# --- Endpoints for getting liked/saved post IDs (for profile.js) --- Added NEW
@app.route('/api/users/<int:user_id>/likes', methods=['GET'])
@jwt_required()
def api_get_user_liked_posts(user_id):
    requesting_user_id = int(get_jwt_identity())
    if requesting_user_id != user_id: return jsonify({"error": "Unauthorized"}), 403
    try:
        # Placeholder implementation until get_liked_post_ids_for_user(user_id) is created in db_utils.py
        # This function should return a list of post IDs liked by the given user_id.
        # For now, return an empty list to avoid breaking the frontend.
        print(f"Warning: Missing db_utils function get_liked_post_ids_for_user({user_id}). Returning empty list for liked posts.")
        liked_ids = [] # Return empty list as placeholder
        return jsonify([{'post_id': pid} for pid in liked_ids]), 200
    except Exception as e:
        # Log the specific error
        print(f"!!! Error in api_get_user_liked_posts for user {user_id}: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({"error": "Failed to fetch liked posts"}), 500

@app.route('/api/users/<int:user_id>/saved', methods=['GET']) # Renamed from /saved-posts to match profile.js call
@jwt_required()
def api_get_user_saved_posts_ids(user_id): # Renamed function
    requesting_user_id = int(get_jwt_identity())
    if requesting_user_id != user_id: return jsonify({"error": "Unauthorized"}), 403
    try:
        # Use the existing function that returns full post details
        saved_posts_data = get_saved_posts_for_user(user_id_of_saver=user_id, requesting_user_id=requesting_user_id)
        # Extract just the post_ids
        saved_ids = [post['post_id'] for post in saved_posts_data]
        # Return a simple list of post IDs in the format expected by profile.js
        return jsonify([{'post_id': pid} for pid in saved_ids]), 200
    except Exception as e:
        print(f"Error fetching saved posts for user {user_id}: {e}")
        return jsonify({"error": "Failed to fetch saved posts"}), 500


# --- Image Upload Endpoint ---
UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
if not os.path.exists(UPLOAD_FOLDER): os.makedirs(UPLOAD_FOLDER)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/api/upload/image', methods=['POST'])
@jwt_required()
def upload_image():
    user_id_for_filename = get_jwt_identity() # String identity
    try:
        if 'image' not in request.files: return jsonify({'success': False, 'message': 'No image file part'}), 400
        file = request.files['image']
        if file.filename == '': return jsonify({'success': False, 'message': 'No selected image file'}), 400
        if file and allowed_file(file.filename):
            filename = f"user_{user_id_for_filename}_{int(time.time())}.{file.filename.rsplit('.', 1)[1].lower()}"
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            try:
                file.save(filepath)
                image_url = f"/uploads/{filename}"
                return jsonify({'success': True, 'message': 'Image uploaded', 'imageUrl': image_url}), 201
            except Exception as e:
                 print(f"Error saving uploaded file: {e}")
                 return jsonify({'success': False, 'message': 'Failed to save image'}), 500
        else: return jsonify({'success': False, 'message': 'File type not allowed'}), 400
    except Exception as e:
        print(f"Error in upload_image: {e}")
        return jsonify({'success': False, 'message': 'Internal error during upload'}), 500

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

# --- User Profile Update Endpoint (for Mobile App) ---
@app.route('/api/users/<int:user_id>/profile', methods=['PUT']) # Changed path param name
@jwt_required()
def api_update_user_profile_details(user_id): # Changed param name
    current_user_id = int(get_jwt_identity())
    if current_user_id != user_id: return jsonify({'success': False, 'message': 'Unauthorized'}), 403
    data = request.get_json()
    if not data: return jsonify({'success': False, 'message': 'No data provided'}), 400
    update_payload = {}
    if data.get('username') is not None: update_payload['username'] = data['username'].strip()
    if data.get('profile_image_url') is not None: update_payload['profile_picture_url'] = data['profile_image_url']
    # Add other fields like full_name, bio if needed
    if data.get('full_name') is not None: update_payload['full_name'] = data['full_name'].strip()
    if data.get('bio') is not None: update_payload['bio'] = data['bio'].strip()

    if not update_payload: return jsonify({'success': False, 'message': 'No valid fields provided'}), 400
    # Add validation for fields if necessary
    try:
        success = update_user_profile(user_id, **update_payload)
        if success:
            updated_user = get_user_by_id(user_id)
            return jsonify({'success': True, 'message': 'Profile updated', 'user': updated_user}), 200
        else: return jsonify({'success': False, 'message': 'Failed to update profile'}), 400
    except Exception as e:
        print(f"Error updating profile: {e}")
        return jsonify({'success': False, 'message': 'Internal error'}), 500

# --- Account Update Endpoint (Existing, for Web settings page with form-data) ---
@app.route('/update_account', methods=['POST'])
@jwt_required()
def update_account():
    user_id_str = get_jwt_identity()
    user_id_for_db = int(user_id_str)
    username = request.form.get('username')
    full_name = request.form.get('full_name') # Added
    bio = request.form.get('bio') # Added
    profile_picture_file = request.files.get('profile_picture')
    profile_picture_url = None

    if profile_picture_file and allowed_file(profile_picture_file.filename):
        try:
            filename = f"user_{user_id_str}_profile_{int(time.time())}.{profile_picture_file.filename.rsplit('.', 1)[1].lower()}"
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            profile_picture_file.save(filepath)
            profile_picture_url = f"/uploads/{filename}"
        except Exception as e:
            print(f"Error saving profile picture: {e}")
            # Decide if this is fatal or just continue without updating picture
            # For now, let's return an error
            return jsonify({'success': False, 'message': 'Failed to save profile picture'}), 500
    elif profile_picture_file:
         return jsonify({'success': False, 'message': 'Profile picture file type not allowed'}), 400

    update_data = {}
    if username is not None: update_data['username'] = username.strip()
    if full_name is not None: update_data['full_name'] = full_name.strip() # Added
    if bio is not None: update_data['bio'] = bio.strip() # Added
    if profile_picture_url is not None: update_data['profile_picture_url'] = profile_picture_url

    if not update_data: return jsonify({'success': False, 'message': 'No update data provided'}), 400
    # Add validation if needed

    try:
        success = update_user_profile(user_id_for_db, **update_data)
        if success:
            # Redirect back to settings page or profile page after update
            # Using jsonify for now as frontend might handle redirect
            return jsonify({'success': True, 'message': 'Account updated successfully'}), 200
        else:
            return jsonify({'success': False, 'message': 'Failed to update account (username might be taken)'}), 409
    except Exception as e:
        print(f"Error updating account: {e}")
        return jsonify({'success': False, 'message': 'Internal error during account update'}), 500


if __name__ == '__main__':
    # In production, use a production-ready WSGI server like Gunicorn or uWSGI
    # And set debug=False
    app.run(debug=True, host='0.0.0.0', port=5000)
