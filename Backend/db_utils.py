# --- db_utils.py ---
# Gerekli kütüphaneleri içe aktar
import psycopg2
import psycopg2.extras
import bcrypt
# Veritabanı yapılandırma bilgilerini yerel db_config modülünden al
from db_config import DB_HOST, DB_NAME, DB_USER, DB_PASSWORD
import traceback # Hata detaylarını görmek için eklendi

def connect_db():
    """PostgreSQL veritabanına bir bağlantı kurar."""
    conn = None # Bağlantı nesnesini başlangıçta None olarak ayarla
    print(f"--- Attempting to connect to database: Host={DB_HOST}, DB={DB_NAME}, User={DB_USER} ---")
    try:
        # psycopg2 kullanarak veritabanına bağlanmayı dene
        conn = psycopg2.connect(
            host=DB_HOST,        # Veritabanı sunucu adresi
            database=DB_NAME,    # Veritabanı adı
            user=DB_USER,        # Veritabanı kullanıcı adı
            password=DB_PASSWORD # Veritabanı şifresi
        )
        # Bağlantı başarılıysa logla
        print("--- Database connection established successfully. ---")
        return conn # Sadece bağlantı nesnesini döndür
    except psycopg2.Error as e:
        # Bağlantı sırasında bir hata oluşursa hatayı yazdır
        print(f"!!! Database connection error: {e}")
        print(traceback.format_exc()) # Hatanın tüm detayını yazdır
        return None
    except Exception as e:
        # Beklenmedik başka hatalar için
        print(f"!!! Unexpected database connection error: {e}")
        print(traceback.format_exc())
        return None


def create_tables():
    """Veritabanı tablolarını oluşturur."""
    conn = connect_db() # Veritabanına bağlan
    if conn: # Bağlantı başarılıysa devam et
        cursor = None
        try:
            cursor = conn.cursor() # Standart bir cursor oluştur

            # SQL CREATE TABLE komutları
            sql_script = """
            CREATE TABLE IF NOT EXISTS users (
                user_id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                full_name VARCHAR(100),
                profile_picture_url VARCHAR(512),
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                is_private BOOLEAN DEFAULT FALSE
            );

            CREATE TABLE IF NOT EXISTS posts (
                post_id SERIAL PRIMARY KEY,
                user_id INT NOT NULL,
                content_text TEXT,
                image_url VARCHAR(512),
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                CONSTRAINT fk_user
                    FOREIGN KEY (user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE,
                CONSTRAINT check_content
                    CHECK (content_text IS NOT NULL OR image_url IS NOT NULL)
            );

            CREATE TABLE IF NOT EXISTS follows (
                follow_id SERIAL PRIMARY KEY,
                follower_user_id INT NOT NULL,
                followed_user_id INT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                CONSTRAINT fk_follower
                    FOREIGN KEY (follower_user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE,
                CONSTRAINT fk_followed
                    FOREIGN KEY (followed_user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE,
                UNIQUE (follower_user_id, followed_user_id)
            );

            CREATE TABLE IF NOT EXISTS likes (
                like_id SERIAL PRIMARY KEY,
                user_id INT NOT NULL,
                post_id INT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW(), -- TIMESTATZ -> TIMESTAMPTZ olarak düzeltildi
                CONSTRAINT fk_user_like
                    FOREIGN KEY (user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE,
                CONSTRAINT fk_post_like
                    FOREIGN KEY (post_id)
                    REFERENCES posts(post_id) ON DELETE CASCADE,
                UNIQUE (user_id, post_id)
            );

            CREATE TABLE IF NOT EXISTS comments (
                comment_id SERIAL PRIMARY KEY,
                user_id INT NOT NULL,
                post_id INT NOT NULL,
                comment_text TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                CONSTRAINT fk_user_comment
                    FOREIGN KEY (user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE,
                CONSTRAINT fk_post_comment
                    FOREIGN KEY (post_id)
                    REFERENCES posts(post_id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS comment_likes (
                comment_like_id SERIAL PRIMARY KEY,
                user_id INT NOT NULL,
                comment_id INT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                CONSTRAINT fk_user_comment_like
                    FOREIGN KEY (user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE,
                CONSTRAINT fk_comment_like
                    FOREIGN KEY (comment_id)
                    REFERENCES comments(comment_id) ON DELETE CASCADE,
                UNIQUE (user_id, comment_id)
            );

            CREATE TABLE IF NOT EXISTS saved_posts (
                saved_post_id SERIAL PRIMARY KEY,
                user_id INT NOT NULL,
                post_id INT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW(), -- 'saved_at' yerine 'created_at' kullanılıyor
                CONSTRAINT fk_user_saved
                    FOREIGN KEY (user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE,
                CONSTRAINT fk_post_saved
                    FOREIGN KEY (post_id)
                    REFERENCES posts(post_id) ON DELETE CASCADE,
                UNIQUE (user_id, post_id)
            );

            CREATE TABLE IF NOT EXISTS messages (
                message_id BIGSERIAL PRIMARY KEY,
                sender_user_id INT NOT NULL,
                receiver_user_id INT NOT NULL,
                message_text TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                is_read BOOLEAN DEFAULT FALSE,
                CONSTRAINT fk_sender
                    FOREIGN KEY (sender_user_id)
                    REFERENCES users(user_id) ON DELETE SET NULL, -- Kullanıcı silinirse mesaj kalır
                CONSTRAINT fk_receiver
                    FOREIGN KEY (receiver_user_id)
                    REFERENCES users(user_id) ON DELETE SET NULL -- Kullanıcı silinirse mesaj kalır
            );

            -- ENUM type for notification type
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type') THEN
                    CREATE TYPE notification_type AS ENUM ('like', 'comment', 'follow', 'message', 'follow_request');
                END IF;
                -- Add 'follow_request' to notification_type ENUM if it doesn't exist
                IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumtypid = 'notification_type'::regtype AND enumlabel = 'follow_request') THEN
                    ALTER TYPE notification_type ADD VALUE 'follow_request' AFTER 'message';
                END IF;
            END
            $$;

            CREATE TABLE IF NOT EXISTS notifications (
                notification_id SERIAL PRIMARY KEY,
                recipient_user_id INT NOT NULL,
                actor_user_id INT, -- Bildirimi tetikleyen kullanıcı (like, comment, follow yapan)
                type notification_type NOT NULL,
                post_id INT, -- Hangi postla ilgili (like, comment)
                comment_id INT, -- ****** YENİ: Hangi yorumla ilgili (comment_like) ******
                message_id BIGINT, -- Hangi mesajla ilgili
                follow_request_id INT, -- ****** GÜNCELLEME: follow_request_id alanı eklendi ******
                is_read BOOLEAN DEFAULT FALSE,
                is_deleted BOOLEAN DEFAULT FALSE, -- ****** GÜNCELLEME: is_deleted alanı eklendi ******
                created_at TIMESTAMPTZ DEFAULT NOW(),
                CONSTRAINT fk_recipient
                    FOREIGN KEY (recipient_user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE,
                CONSTRAINT fk_actor
                    FOREIGN KEY (actor_user_id)
                    REFERENCES users(user_id) ON DELETE SET NULL, -- Actor silinse bile bildirim kalabilir
                CONSTRAINT fk_post_notification
                    FOREIGN KEY (post_id)
                    REFERENCES posts(post_id) ON DELETE CASCADE, -- Post silinirse ilgili bildirimler de silinsin
                CONSTRAINT fk_message_notification
                    FOREIGN KEY (message_id)
                    REFERENCES messages(message_id) ON DELETE CASCADE, -- Mesaj silinirse ilgili bildirimler de silinsin
                CONSTRAINT fk_follow_request_notification -- ****** GÜNCELLEME: follow_request_id için FOREIGN KEY eklendi ******
                    FOREIGN KEY (follow_request_id)
                    REFERENCES follow_requests(request_id) ON DELETE CASCADE -- Takip isteği silinirse ilgili bildirim de silinsin
            );

            CREATE TABLE IF NOT EXISTS user_settings (
                setting_id SERIAL PRIMARY KEY,
                user_id INT UNIQUE NOT NULL,
                dark_mode_enabled BOOLEAN DEFAULT FALSE,
                email_notifications_enabled BOOLEAN DEFAULT TRUE,
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                CONSTRAINT fk_user_settings
                    FOREIGN KEY (user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS follow_requests (
                request_id SERIAL PRIMARY KEY,
                requester_user_id INT NOT NULL, -- The user sending the request
                recipient_user_id INT NOT NULL, -- The user receiving the request
                created_at TIMESTAMPTZ DEFAULT NOW(),
                CONSTRAINT fk_requester
                    FOREIGN KEY (requester_user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE,
                CONSTRAINT fk_recipient_request
                    FOREIGN KEY (recipient_user_id)
                    REFERENCES users(user_id) ON DELETE CASCADE,
                UNIQUE (requester_user_id, recipient_user_id)
            );
            """

            print("--- SQL betiği çalıştırılıyor... ---")
            cursor.execute(sql_script)
            conn.commit() # Değişiklikleri veritabanına işle (kalıcı hale getir)
            print("--- Tablolar başarıyla oluşturuldu veya zaten mevcut. ---")
        except psycopg2.Error as e:
            # Tablo oluşturma sırasında hata olursa hatayı yazdır
            print(f"!!! Tablolar oluşturulurken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback() # Hata durumunda yapılan değişiklikleri geri al
        except Exception as e:
            print(f"!!! Tablolar oluşturulurken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            # İşlem bittikten sonra (hata olsa da olmasa da) kaynakları serbest bırak
            print("--- create_tables finally bloğu çalışıyor. ---")
            if cursor:
                cursor.close()
            if conn:
                conn.close()
                print("--- Bağlantı kapatıldı (create_tables). ---")

# --- CREATE Fonksiyonları ---

def create_user(username, email, password_hash):
    """Users tablosuna yeni bir kullanıcı ekler."""
    print(f"--- create_user çağrıldı: username={username}, email={email} ---")
    conn = connect_db()
    user_id = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO users (username, email, password_hash) VALUES (%s, %s, %s) RETURNING user_id;",
                (username, email, password_hash)
            )
            result = cursor.fetchone()
            if result:
                 user_id = result[0]
                 conn.commit()
                 print(f"--- Commit başarılı. Kullanıcı ID ile oluşturuldu: {user_id} ---")
            else:
                 print("!!! HATA: INSERT komutu user_id döndürmedi! Commit yapılmayacak. ---")
        except psycopg2.errors.UniqueViolation as e:
            print(f"!!! Kullanıcı oluşturulurken hata (UniqueViolation): Kullanıcı adı veya e-posta zaten mevcut. Rollback yapılıyor...")
            if conn: conn.rollback()
        except psycopg2.Error as e:
            print(f"!!! Kullanıcı oluşturulurken veritabanı hatası: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
             print(f"!!! Kullanıcı oluşturulurken beklenmedik hata: {e}")
             print(traceback.format_exc())
             if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_user: Veritabanı bağlantısı kurulamadı! ---")
    return user_id

def create_post(user_id, content_text=None, image_url=None):
    """Posts tablosuna yeni bir gönderi ekler."""
    print(f"--- create_post çağrıldı: user_id={user_id}, content_text={'Var' if content_text else 'Yok'}, image_url={'Var' if image_url else 'Yok'} ---")
    conn = connect_db()
    post_id = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO posts (user_id, content_text, image_url) VALUES (%s, %s, %s) RETURNING post_id;",
                (user_id, content_text, image_url)
            )
            result = cursor.fetchone()
            if result:
                post_id = result[0]
                conn.commit()
                print(f"--- Gönderi ID ile oluşturuldu: {post_id} ---")
            else:
                print("!!! HATA: INSERT komutu post_id döndürmedi! ---")
        except psycopg2.Error as e:
            print(f"!!! Gönderi oluşturulurken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Gönderi oluşturulurken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_post: Veritabanı bağlantısı kurulamadı! ---")
    return post_id

def create_follow(follower_user_id, followed_user_id):
    """
    Follows tablosuna yeni bir takip ilişkisi ekler veya takip isteği oluşturur
    eğer takip edilen kullanıcı gizli hesaba sahipse.
    """
    print(f"--- create_follow called: follower_user_id={follower_user_id}, followed_user_id={followed_user_id} ---")
    conn = connect_db()
    result_id = None # Can be follow_id or request_id
    result_type = None # 'follow' or 'request'
    cursor = None

    if follower_user_id == followed_user_id:
        print("!!! create_follow: User cannot follow themselves.")
        return None, None # Return None for both ID and type

    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Check if the followed user is private
            cursor.execute("SELECT is_private FROM users WHERE user_id = %s;", (followed_user_id,))
            followed_user = cursor.fetchone()

            if not followed_user:
                print(f"!!! create_follow: Followed user with ID {followed_user_id} not found.")
                return None, None

            is_private = followed_user.get('is_private', False)

            if is_private:
                # Check if a follow request already exists
                cursor.execute(
                    "SELECT request_id FROM follow_requests WHERE requester_user_id = %s AND recipient_user_id = %s;",
                    (follower_user_id, followed_user_id)
                )
                existing_request = cursor.fetchone()

                if existing_request:
                    print(f"--- Follow request already exists from {follower_user_id} to {followed_user_id}. ---")
                    result_id = existing_request['request_id']
                    result_type = 'request_exists' # Indicate that a request already exists
                else:
                    # Create a follow request
                    cursor.execute(
                        "INSERT INTO follow_requests (requester_user_id, recipient_user_id) VALUES (%s, %s) RETURNING request_id;",
                        (follower_user_id, followed_user_id)
                    )
                    request_result = cursor.fetchone()
                    if request_result:
                        result_id = request_result['request_id']
                        result_type = 'request_created'
                        conn.commit()
                        print(f"--- Follow request created (ID: {result_id}) from {follower_user_id} to {followed_user_id}. ---")
                        # Create a notification for the recipient user
                        try:
                            create_notification(
                                recipient_user_id=followed_user_id,
                                actor_user_id=follower_user_id,
                                notification_type='follow_request',
                                follow_request_id=result_id # Pass the created request_id
                            )
                            print(f"--- Notification created successfully for follow request ID: {result_id} ---")
                        except Exception as notification_error:
                            print(f"!!! ERROR creating notification for follow request ID {result_id}: {notification_error}")
                            print(traceback.format_exc())
                            # Continue execution even if notification creation fails,
                            # as the follow request itself was successful.
                            # Consider adding more robust error logging or alerting here.
                    else:
                        print("!!! HATA: INSERT komutu request_id döndürmedi! ---")
                        if conn: conn.rollback()
                        result_id = None
                        result_type = None
            else:
                # User is not private, create a direct follow relationship
                cursor.execute(
                    "INSERT INTO follows (follower_user_id, followed_user_id) VALUES (%s, %s) RETURNING follow_id;",
                    (follower_user_id, followed_user_id)
                )
                follow_result = cursor.fetchone()
                if follow_result:
                    result_id = follow_result['follow_id']
                    result_type = 'follow_created'
                    conn.commit()
                    print(f"--- Follow relationship created (ID: {result_id}) from {follower_user_id} to {followed_user_id}. ---")
                    # Create a notification for the followed user
                    try:
                        create_notification(
                            recipient_user_id=followed_user_id,
                            actor_user_id=follower_user_id,
                            notification_type='follow'
                        )
                        print(f"--- Notification created successfully for follow ID: {result_id} ---")
                    except Exception as notification_error:
                        print(f"!!! ERROR creating notification for follow ID {result_id}: {notification_error}")
                        print(traceback.format_exc())
                        # Continue execution even if notification creation fails
                        # Consider adding more robust error logging or alerting here.
                else:
                    print("!!! HATA: INSERT komutu follow_id döndürmedi! ---")
                    if conn: conn.rollback()
                    result_id = None
                    result_type = None

        except psycopg2.errors.UniqueViolation:
            print(f"!!! Follow relationship or request already exists. ---")
            if conn: conn.rollback()
            # In case of UniqueViolation, check if it's a follow or a request that exists
            if is_following_user(follower_user_id, followed_user_id):
                 print("--- Follow relationship already exists. ---")
                 # You might want to return the existing follow_id here if needed
                 # For now, just indicate it exists
                 result_type = 'follow_exists'
            elif is_follow_request_pending(follower_user_id, followed_user_id):
                 print("--- Follow request already exists. ---")
                 # You might want to return the existing request_id here if needed
                 # For now, just indicate it exists
                 result_type = 'request_exists'
            else:
                 print("!!! Unexpected UniqueViolation in create_follow. ---")
                 result_type = 'error' # Indicate an unexpected error

            result_id = None # No new ID was created
            raise # Re-raise the exception

        except psycopg2.Error as e:
            print(f"!!! Database error during create_follow: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
            result_id = None
            result_type = 'error'
            raise # Re-raise the exception
        except Exception as e:
            print(f"!!! Unexpected error during create_follow: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
            result_id = None
            result_type = 'error'
            raise # Re-raise the exception
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_follow: Database connection could not be established! ---")
        result_id = None
        result_type = 'error'

    return result_id, result_type


def create_like(user_id, post_id):
    """Likes tablosuna yeni bir beğeni ekler."""
    print(f"--- create_like çağrıldı: user_id={user_id}, post_id={post_id} ---")
    conn = connect_db()
    like_id = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO likes (user_id, post_id) VALUES (%s, %s) RETURNING like_id;",
                (user_id, post_id)
            )
            result = cursor.fetchone()
            if result:
                like_id = result[0]
                conn.commit()
                print(f"--- Beğeni ID ile oluşturuldu: {like_id} ---")
                # Get the post owner's user ID
                cursor.execute("SELECT user_id FROM posts WHERE post_id = %s;", (post_id,))
                post_owner_id = cursor.fetchone()[0]
                # Create a notification for the post owner
                create_notification(
                    recipient_user_id=post_owner_id,
                    actor_user_id=user_id,
                    notification_type='like',
                    post_id=post_id
                )
            else:
                print("!!! HATA: INSERT komutu like_id döndürmedi! ---")
        except psycopg2.errors.UniqueViolation:
            print(f"!!! Beğeni oluşturulurken hata (UniqueViolation): Beğeni zaten mevcut. ---")
            if conn: conn.rollback()
        except psycopg2.Error as e:
            print(f"!!! Beğeni oluşturulurken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Beğeni oluşturulurken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_like: Veritabanı bağlantısı kurulamadı! ---")
    return like_id

def create_comment(user_id, post_id, comment_text):
    """Comments tablosuna yeni bir yorum ekler."""
    print(f"--- create_comment çağrıldı: user_id={user_id}, post_id={post_id}, comment_text='{comment_text[:20]}...' ---")
    conn = connect_db()
    comment_id = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO comments (user_id, post_id, comment_text) VALUES (%s, %s, %s) RETURNING comment_id;",
                (user_id, post_id, comment_text)
            )
            result = cursor.fetchone()
            if result:
                comment_id = result[0]
                conn.commit()
                print(f"--- Yorum ID ile oluşturuldu: {comment_id} ---")
                # Get the post owner's user ID
                cursor.execute("SELECT user_id FROM posts WHERE post_id = %s;", (post_id,))
                post_owner_id = cursor.fetchone()[0]
                # Create a notification for the post owner
                create_notification(
                    recipient_user_id=post_owner_id,
                    actor_user_id=user_id,
                    notification_type='comment',
                    post_id=post_id
                )
            else:
                print("!!! HATA: INSERT komutu comment_id döndürmedi! ---")
        except psycopg2.Error as e:
            print(f"!!! Yorum oluşturulurken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Yorum oluşturulurken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_comment: Veritabanı bağlantısı kurulamadı! ---")
    return comment_id

def create_saved_post(user_id, post_id):
    """SavedPosts tablosına yeni bir kaydedilen gönderi ekler."""
    print(f"--- create_saved_post çağrıldı: user_id={user_id}, post_id={post_id} ---")
    conn = connect_db()
    saved_post_id = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO saved_posts (user_id, post_id) VALUES (%s, %s) RETURNING saved_post_id;",
                (user_id, post_id)
            )
            result = cursor.fetchone()
            if result:
                saved_post_id = result[0]
                conn.commit()
                print(f"--- Kaydedilen gönderi ID ile oluşturuldu: {saved_post_id} ---")
            else:
                print("!!! HATA: INSERT komutu saved_post_id döndürmedi! ---")
        except psycopg2.errors.UniqueViolation:
            print(f"!!! Kaydedilen gönderi oluşturulurken hata (UniqueViolation): Kayıt zaten mevcut. ---")
            if conn: conn.rollback()
        except psycopg2.Error as e:
            print(f"!!! Kaydedilen gönderi oluşturulurken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Kaydedilen gönderi oluşturulurken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_saved_post: Veritabanı bağlantısı kurulamadı! ---")
    return saved_post_id

def create_message(sender_user_id, receiver_user_id, message_text):
    """Messages tablosuna yeni bir mesaj ekler."""
    print(f"--- create_message çağrıldı: sender_user_id={sender_user_id}, receiver_user_id={receiver_user_id} ---")
    conn = connect_db()
    message_id = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO messages (sender_user_id, receiver_user_id, message_text) VALUES (%s, %s, %s) RETURNING message_id;",
                (sender_user_id, receiver_user_id, message_text)
            )
            result = cursor.fetchone()
            if result:
                message_id = result[0]
                conn.commit()
                print(f"--- Mesaj ID ile oluşturuldu: {message_id} ---")
                # TODO: Create notification for receiver_user_id
                create_notification(receiver_user_id, sender_user_id, 'message', message_id=message_id)
            else:
                print("!!! HATA: INSERT komutu message_id döndürmedi! ---")
        except psycopg2.Error as e:
            print(f"!!! Mesaj oluşturulurken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Mesaj oluşturulurken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_message: Veritabanı bağlantısı kurulamadı! ---")
    return message_id

def create_comment_like(user_id, comment_id):
    """Inserts a new like for a comment into the comment_likes table."""
    print(f"--- create_comment_like called: user_id={user_id}, comment_id={comment_id} ---")
    conn = connect_db()
    comment_like_id = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO comment_likes (user_id, comment_id) VALUES (%s, %s) RETURNING id;",
                (user_id, comment_id)
            )
            result = cursor.fetchone()
            if result:
                comment_like_id = result[0]
                conn.commit()
                print(f"--- Comment like created with ID: {comment_like_id} ---")
                # Get the comment owner's user ID
                cursor.execute("SELECT user_id FROM comments WHERE comment_id = %s;", (comment_id,))
                comment_owner_id = cursor.fetchone()[0]
                # Create a notification for the comment owner
                create_notification(
                    recipient_user_id=comment_owner_id,
                    actor_user_id=user_id,
                    notification_type='comment_like', # Assuming 'comment_like' is a valid notification type
                    comment_id=comment_id # Pass the comment_id
                )
            else:
                print("!!! HATA: INSERT command did not return id! ---")
        except psycopg2.errors.UniqueViolation:
            print(f"--- Comment like creation error (UniqueViolation): Like already exists. Returning None. ---")
            if conn: conn.rollback()
            return None # Explicitly return None on unique violation
        except psycopg2.Error as e:
            print(f"!!! Database error during comment like creation: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Unexpected error during comment like creation: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_comment_like: Database connection could not be established! ---")
    return comment_like_id

def delete_comment_like(user_id, comment_id):
    """Deletes a like for a comment from the comment_likes table."""
    print(f"--- delete_comment_like called: user_id={user_id}, comment_id={comment_id} ---")
    conn = connect_db()
    rows_deleted = 0
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "DELETE FROM comment_likes WHERE user_id = %s AND comment_id = %s;",
                (user_id, comment_id)
            )
            rows_deleted = cursor.rowcount
            conn.commit()
            if rows_deleted > 0:
                 print(f"--- Comment like successfully deleted. user_id={user_id}, comment_id={comment_id} ---")
            else:
                 print(f"--- No comment like found to delete. user_id={user_id}, comment_id={comment_id} ---")
        except psycopg2.Error as e:
            print(f"!!! Database error during comment like deletion: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Unexpected error during comment like deletion: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! delete_comment_like: Database connection could not be established! ---")
    return rows_deleted > 0


def create_notification(recipient_user_id, actor_user_id, notification_type, post_id=None, message_id=None, follow_request_id=None, comment_id=None):
    """notifications tablosuna yeni bir bildirim ekler."""
    print(f"--- create_notification called: recipient={recipient_user_id}, actor={actor_user_id}, type={notification_type} ---")
    conn = connect_db()
    notification_id = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            # Determine which ID to include based on notification type
            if notification_type in ['like', 'comment']:
                related_id_column = 'post_id'
                related_id_value = post_id
            elif notification_type == 'message':
                related_id_column = 'message_id'
                related_id_value = message_id
            elif notification_type == 'follow_request':
                 related_id_column = 'follow_request_id'
                 related_id_value = follow_request_id
            else: # 'follow' type or others without specific related ID
                related_id_column = None
                related_id_value = None

            if related_id_column:
                 cursor.execute(
                    f"""INSERT INTO notifications
                       (recipient_user_id, actor_user_id, type, {related_id_column})
                       VALUES (%s, %s, %s, %s) RETURNING notification_id;""",
                    (recipient_user_id, actor_user_id, notification_type, related_id_value)
                 )
            else:
                 cursor.execute(
                    """INSERT INTO notifications
                       (recipient_user_id, actor_user_id, type)
                       VALUES (%s, %s, %s) RETURNING notification_id;""",
                    (recipient_user_id, actor_user_id, notification_type)
                 )


            result = cursor.fetchone()
            if result:
                notification_id = result[0]
                conn.commit()
                print(f"--- Notification created with ID: {notification_id} ---")
            else:
                print("!!! ERROR: INSERT command did not return notification_id! ---")
        except psycopg2.Error as e:
            print(f"!!! Database error during create_notification: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Unexpected error during create_notification: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_notification: Database connection could not be established! ---")
    return notification_id

# --- GET Fonksiyonları ---

def get_user_by_username_or_email(username_or_email):
    """Kullanıcı adı veya e-posta adresine göre bir kullanıcıyı getirir."""
    print(f"--- get_user_by_username_or_email çağrıldı: user={username_or_email} ---")
    conn = connect_db()
    user = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) # Sözlük olarak almak için
            cursor.execute(
                "SELECT * FROM users WHERE username = %s OR email = %s;",
                (username_or_email, username_or_email)
            )
            user = cursor.fetchone()
        except psycopg2.Error as e:
            print(f"!!! Kullanıcı alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Kullanıcı alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_user_by_username_or_email: Veritabanı bağlantısı kurulamadı! ---")
    return user

def get_user_by_id(user_id, requesting_user_id=None):
    """
    Kullanıcı ID'sine göre bir kullanıcıyı getirir.
    requesting_user_id sağlanırsa, gizli hesaplar için erişim kontrolü yapar.
    """
    print(f"--- get_user_by_id called: user_id={user_id}, requesting_user_id={requesting_user_id} ---")
    conn = connect_db()
    user = None
    cursor = None
    if not conn:
        print("!!! get_user_by_id: Database connection could not be established! ---")
        return None

    try:
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        # First, get the basic user info and privacy status
        cursor.execute("SELECT user_id, username, full_name, profile_picture_url, is_private FROM users WHERE user_id = %s;", (user_id,))
        user_basic = cursor.fetchone()

        if not user_basic:
            print(f"--- get_user_by_id: User with ID {user_id} not found. ---")
            return None

        is_private = user_basic.get('is_private', False)
        print(f"--- get_user_by_id: User {user_id} is_private: {is_private} ---")

        # Check if the requesting user is the target user
        is_self = (requesting_user_id is not None and requesting_user_id == user_id)

        # Check if the requesting user is following the target user (only relevant if target is private and not self)
        is_following = False
        if is_private and not is_self and requesting_user_id is not None:
             is_following = is_following_user(requesting_user_id, user_id) # Use the existing helper
             print(f"--- get_user_by_id: Requesting user {requesting_user_id} following user {user_id}: {is_following} ---")

        # Check if there's a pending follow request (only relevant if target is private and not self)
        has_pending_request = False
        if is_private and not is_self and requesting_user_id is not None:
             has_pending_request = is_follow_request_pending(requesting_user_id, user_id) # Use the existing helper
             print(f"--- get_user_by_id: Requesting user {requesting_user_id} has pending request to user {user_id}: {has_pending_request} ---")


        # Determine what data to return based on privacy and follow status
        if not is_private or is_self or is_following:
            # Return full user data if not private, or if it's the user's own profile, or if the requesting user is following
            print(f"--- get_user_by_id: Returning full data for user {user_id}. ---")
            cursor.execute(
                """
                SELECT
                    u.*,
                    (SELECT COUNT(*) FROM follows f WHERE f.followed_user_id = u.user_id) AS followers_count,
                    (SELECT COUNT(*) FROM follows f WHERE f.follower_user_id = u.user_id) AS following_count,
                    (SELECT COUNT(*) FROM posts p WHERE p.user_id = u.user_id) AS post_count,
                    CASE WHEN %(requesting_user_id)s IS NOT NULL THEN EXISTS(SELECT 1 FROM follows f WHERE f.follower_user_id = %(requesting_user_id)s AND f.followed_user_id = u.user_id) ELSE FALSE END AS is_following,
                    CASE WHEN %(requesting_user_id)s IS NOT NULL THEN EXISTS(SELECT 1 FROM follow_requests fr WHERE fr.requester_user_id = %(requesting_user_id)s AND fr.recipient_user_id = u.user_id) ELSE FALSE END AS has_pending_request
                FROM users u
                WHERE u.user_id = %(user_id)s;
                """,
                {'user_id': user_id, 'requesting_user_id': requesting_user_id}
            )
            user = cursor.fetchone()
            # Ensure counts are integers, not strings or None
            if user:
                 user['followers_count'] = user.get('followers_count', 0) or 0
                 user['following_count'] = user.get('following_count', 0) or 0
                 user['post_count'] = user.get('post_count', 0) or 0

        else:
            # Return limited data for private accounts if not followed and not self
            print(f"--- get_user_by_id: Returning limited data for private user {user_id}. ---")
            user = {
                'user_id': user_basic['user_id'],
                'username': user_basic['username'],
                'full_name': user_basic.get('full_name'),
                'profile_picture_url': user_basic.get('profile_picture_url'),
                'is_private': True,
                'is_following': False, # Not following
                'has_pending_request': has_pending_request, # Still show if a request is pending
                # Initialize counts to 0 for other users viewing a private profile they don't follow
                'followers_count': 0,
                'following_count': 0,
                'post_count': 0,
                # Exclude sensitive fields like email, password_hash, created_at, updated_at, bio etc.
            }

            # If the requesting user is the profile owner, fetch and include the actual counts
            if is_self:
                 print(f"--- get_user_by_id: Requesting user is self ({requesting_user_id}), fetching actual counts for private profile {user_id}. ---") # Added requesting_user_id to log
                 cursor.execute(
                     """
                     SELECT
                         (SELECT COUNT(*) FROM follows f WHERE f.followed_user_id = u.user_id) AS followers_count,
                         (SELECT COUNT(*) FROM follows f WHERE f.follower_user_id = u.user_id) AS following_count,
                         (SELECT COUNT(*) FROM posts p WHERE p.user_id = u.user_id) AS post_count
                     FROM users u
                     WHERE u.user_id = %(user_id)s;
                     """,
                     {'user_id': user_id}
                 )
                 counts_data = cursor.fetchone()
                 print(f"--- get_user_by_id: Raw counts data fetched for self-viewing private profile {user_id}: {counts_data} ---") # Added log for raw data
                 if counts_data:
                     user['followers_count'] = counts_data.get('followers_count', 0) or 0
                     user['following_count'] = counts_data.get('following_count', 0) or 0
                     user['post_count'] = counts_data.get('post_count', 0) or 0
                     print(f"--- get_user_by_id: Fetched counts for self-viewing private profile {user_id}: {user['followers_count']} followers, {user['following_count']} following, {user['post_count']} posts. ---") # Added user_id to log
                 else:
                     print(f"!!! get_user_by_id: Failed to fetch counts for self-viewing private profile {user_id}. ---")


        if user:
            print(f"--- get_user_by_id: Successfully fetched user {user_id}. ---")
        else:
            print(f"--- get_user_by_id: User {user_id} not found after privacy check (should not happen if user_basic was found). ---")


    except psycopg2.Error as e:
        print(f"!!! Database error in get_user_by_id: {e}")
        print(traceback.format_exc())
        user = None # Ensure user is None on error
    except Exception as e:
         print(f"!!! Unexpected error in get_user_by_id: {e}")
         print(traceback.format_exc())
         user = None # Ensure user is None on error
    finally:
        if cursor: cursor.close()
        if conn: conn.close()

    return user

def get_all_users(current_user_id=None):
    """
    Tüm kullanıcıları getirir, isteğe bağlı olarak belirli bir kullanıcıyı hariç tutar
    ve mevcut kullanıcının her bir kullanıcıyı takip edip etmediğini belirtir.
    """
    print(f"--- get_all_users called: current_user_id={current_user_id} ---")
    conn = connect_db()
    users = []
    cursor = None
    if not conn: # Check if connection failed
        print("!!! get_all_users: Database connection could not be established! Returning empty list. ---")
        return users # Return empty list immediately if connection fails

    try:
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        query = """
            SELECT
                u.user_id,
                u.username,
                u.full_name,
                u.profile_picture_url,
                CASE
                    WHEN %(current_user_id)s IS NOT NULL AND f.follower_user_id IS NOT NULL THEN TRUE
                    ELSE FALSE
                END AS is_following
            FROM users u
            LEFT JOIN follows f ON u.user_id = f.followed_user_id AND f.follower_user_id = %(current_user_id)s
        """
        params = {'current_user_id': current_user_id}

        if current_user_id is not None:
            query += " WHERE u.user_id != %(current_user_id)s"

        query += " ORDER BY u.username ASC;" # Kullanıcıları kullanıcı adına göre sırala

        print(f"--- Executing query in get_all_users: {query} with params: {params} ---") # More specific logging
        cursor.execute(query, params) # Pass params dictionary directly
        print("--- get_all_users: Query executed. Attempting to fetch results. ---")
        users = cursor.fetchall()
        print(f"--- Query executed successfully in get_all_users. Fetched {len(users)} users. ---") # More specific logging
    except psycopg2.Error as e:
        print(f"!!! Error fetching all users during query execution: {e}") # More specific logging
        print(traceback.format_exc())
    except Exception as e:
         print(f"!!! Unexpected error fetching all users: {e}")
         print(traceback.format_exc())
    finally:
        if cursor: cursor.close()
        if conn: conn.close()
    return users

def search_users(query, current_user_id=None):
    """
    Searches for users by username (case-insensitive, partial match).
    Optionally excludes a specific user ID from the results and
    indicates if the current user is following each result.
    """
    print(f"--- search_users called: query='{query}', current_user_id={current_user_id} ---")
    conn = connect_db()
    users = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            sql_query = """
                SELECT
                    u.user_id,
                    u.username,
                    u.full_name,
                    u.profile_picture_url,
                     CASE
                        WHEN %(current_user_id)s IS NOT NULL AND f.follower_user_id IS NOT NULL THEN TRUE
                        ELSE FALSE
                    END AS is_following
                FROM users u
                LEFT JOIN follows f ON u.user_id = f.followed_user_id AND f.follower_user_id = %(current_user_id)s
                WHERE u.username ILIKE %(query)s
            """
            # Changed the query pattern to match usernames that START WITH the term
            params = {'query': f"{query}%", 'current_user_id': current_user_id}

            if current_user_id is not None:
                sql_query += " AND u.user_id != %(current_user_id)s"

            sql_query += " ORDER BY u.username ASC;"

            print(f"--- Executing query: {sql_query} ---")
            print(f"--- Parameters for search_users query: {params} ---")
            cursor.execute(sql_query, params) # Pass params dictionary directly
            users = cursor.fetchall()
            print(f"--- Raw results from search_users query: {users} ---")
            print(f"--- Query executed successfully in search_users. Found {len(users)} users. ---")
            # Added logging to show fetched usernames and follow status
            if users:
                print("--- Found users: ---")
                for user in users:
                    print(f"    - {user.get('username')} (ID: {user.get('user_id')}), Following: {user.get('is_following')}")
                print("---------------------")

        except psycopg2.Error as e:
            print(f"!!! Error searching users: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Unexpected error searching users: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! search_users: Database connection could not be established! ---")
    return users


def get_all_posts():
    """Tüm gönderileri getirir (Genellikle test veya admin için kullanılır)."""
    print("--- get_all_posts çağrıldı ---")
    conn = connect_db()
    posts = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT
                    p.*,
                    u.username,
                    u.profile_picture_url,
                    (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.post_id) AS likes_count,
                    (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comments_count,
                    p.created_at::TEXT AS created_at, -- Explicitly cast to TEXT (ISO 8601)
                    p.updated_at::TEXT AS updated_at -- Explicitly cast to TEXT (ISO 8601)
                FROM posts p
                JOIN users u ON p.user_id = u.user_id
                ORDER BY p.created_at DESC;
                """
            )
            posts = cursor.fetchall()
            print(f"--- Toplam gönderi sayısı: {len(posts)} ---")
        except psycopg2.Error as e:
            print(f"!!! Tüm gönderiler alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Tüm gönderiler alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_all_posts: Veritabanı bağlantısı kurulamadı! ---")
    return posts

def get_home_feed_posts(user_id):
    """Belirli bir kullanıcının takip ettiği kişilerin gönderilerini getirir."""
    print(f"--- get_home_feed_posts çağrıldı: user_id={user_id} ---")
    conn = connect_db()
    posts = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            # Takip edilen kullanıcıların gönderilerini ve kendi gönderilerini çek
            # Ayrıca mevcut kullanıcının beğenme ve kaydetme durumunu da ekle
            cursor.execute(
                """
                SELECT
                    p.*,
                    u.username,
                    u.profile_picture_url,
                    (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.post_id) AS likes_count,
                    (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comments_count,
                    EXISTS(SELECT 1 FROM likes lk WHERE lk.post_id = p.post_id AND lk.user_id = %(current_user_id)s) AS is_liked_by_current_user,
                    EXISTS(SELECT 1 FROM saved_posts sp WHERE sp.post_id = p.post_id AND sp.user_id = %(current_user_id)s) AS is_saved_by_current_user,
                    p.created_at::TEXT AS created_at, -- Explicitly cast to TEXT (ISO 8601)
                    p.updated_at::TEXT AS updated_at -- Explicitly cast to TEXT (ISO 8601)
                FROM posts p
                JOIN users u ON p.user_id = u.user_id
                -- Sadece takip edilenlerin gönderilerini al
                WHERE p.user_id IN (
                    SELECT followed_user_id FROM follows WHERE follower_user_id = %(current_user_id)s
                )
                ORDER BY p.created_at DESC;
                """,
                {'current_user_id': user_id} # Named placeholder kullanımı
            )
            posts = cursor.fetchall()
            print(f"--- Kullanıcı {user_id} için ana sayfa gönderi sayısı: {len(posts)} ---")
        except psycopg2.Error as e:
            print(f"!!! Ana sayfa gönderileri alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Ana sayfa gönderileri alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_home_feed_posts: Veritabanı bağlantısı kurulamadı! ---")
    return posts


def get_posts_by_user_id(user_id, current_user_id=None):
    """Belirli bir kullanıcıya ait gönderileri getirir (Profil sayfası için)."""
    print(f"--- get_posts_by_user_id çağrıldı: user_id={user_id}, current_user_id={current_user_id} ---")
    conn = connect_db()
    posts = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            # Include like/comment counts and current user's like/save status
            cursor.execute(
                 """
                 SELECT
                     p.*,
                     u.username,
                     u.profile_picture_url,
                     (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.post_id) AS likes_count,
                     (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comments_count,
                     EXISTS(SELECT 1 FROM likes lk WHERE lk.post_id = p.post_id AND lk.user_id = %(current_user_id)s) AS is_liked_by_current_user,
                     EXISTS(SELECT 1 FROM saved_posts sp WHERE sp.post_id = p.post_id AND sp.user_id = %(current_user_id)s) AS is_saved_by_current_user,
                     p.created_at::TEXT AS created_at, -- Explicitly cast to TEXT (ISO 8601)
                     p.updated_at::TEXT AS updated_at -- Explicitly cast to TEXT (ISO 8601)
                 FROM posts p
                 JOIN users u ON p.user_id = u.user_id
                 WHERE p.user_id = %(user_id)s
                 ORDER BY p.created_at DESC;
                 """,
                {'user_id': user_id, 'current_user_id': current_user_id} # Use named placeholders
            )
            posts = cursor.fetchall()
            print(f"--- Kullanıcı {user_id} için gönderi sayısı: {len(posts)} ---")
        except psycopg2.Error as e:
            print(f"!!! Kullanıcı gönderileri alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Kullanıcı gönderileri alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_posts_by_user_id: Veritabanı bağlantısı kurulamadı! ---")
    return posts

def get_likes_for_post(post_id):
    """Belirli bir gönderiye ait beğenileri (kullanıcıları) getirir."""
    print(f"--- get_likes_for_post çağrıldı: post_id={post_id} ---")
    conn = connect_db()
    likes = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """SELECT l.like_id, l.user_id, l.created_at, u.username, u.profile_picture_url
                   FROM likes l
                   JOIN users u ON l.user_id = u.user_id
                   WHERE l.post_id = %s ORDER BY l.created_at DESC;""",
                (post_id,)
            )
            likes = cursor.fetchall()
        except psycopg2.Error as e:
            print(f"!!! Beğeniler alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Beğeniler alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_likes_for_post: Veritabanı bağlantısı kurulamadı! ---")
    return likes

def get_post_like_count(post_id):
    """Belirli bir gönderiye ait beğeni sayısını getirir."""
    print(f"--- get_post_like_count çağrıldı: post_id={post_id} ---")
    conn = connect_db()
    like_count = 0
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT COUNT(*) FROM likes WHERE post_id = %s;",
                (post_id,)
            )
            result = cursor.fetchone()
            if result:
                like_count = result[0]
                print(f"--- Gönderi {post_id} için beğeni sayısı: {like_count} ---")
        except psycopg2.Error as e:
            print(f"!!! Beğeni sayısı alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Beğeni sayısı alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_post_like_count: Veritabanı bağlantısı kurulamadı! ---")
    return like_count

def get_comment_like_count(comment_id):
    """Belirli bir yoruma ait beğeni sayısını getirir."""
    print(f"--- get_comment_like_count called: comment_id={comment_id} ---")
    conn = connect_db()
    like_count = 0
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT COUNT(*) FROM comment_likes WHERE comment_id = %s;",
                (comment_id,)
            )
            result = cursor.fetchone()
            if result:
                like_count = result[0]
                print(f"--- Comment {comment_id} için beğeni sayısı: {like_count} ---")
        except psycopg2.Error as e:
            print(f"!!! Comment beğeni sayısı alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Comment beğeni sayısı alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_comment_like_count: Veritabanı bağlantısı kurulamadı! ---")
    return like_count


def get_comments_for_post(post_id, current_user_id=None):
    """Belirli bir gönderiye ait yorumları getirir ve mevcut kullanıcının beğenip beğenmediğini belirtir."""
    print(f"--- get_comments_for_post called: post_id={post_id}, current_user_id={current_user_id} ---")
    conn = connect_db()
    comments = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT
                    c.*,
                    u.username,
                    u.profile_picture_url,
                    (SELECT COUNT(*) FROM comment_likes cl WHERE cl.comment_id = c.comment_id) AS like_count,
                    CASE
                        WHEN %(current_user_id)s IS NOT NULL THEN EXISTS(SELECT 1 FROM comment_likes clk WHERE clk.comment_id = c.comment_id AND clk.user_id = %(current_user_id)s)
                        ELSE FALSE
                    END AS is_liked
                FROM comments c
                JOIN users u ON c.user_id = u.user_id
                WHERE c.post_id = %(post_id)s
                ORDER BY c.created_at ASC;
                """,
                {'post_id': post_id, 'current_user_id': current_user_id} # Use named placeholders
            )
            comments = cursor.fetchall()
            print(f"--- Comments fetched for post {post_id}: {len(comments)} ---")
        except psycopg2.Error as e:
            print(f"!!! Error fetching comments: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Unexpected error fetching comments: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_comments_for_post: Database connection could not be established! ---")
    return comments

def get_messages_between_users(user1_id, user2_id):
    """İki kullanıcı arasındaki mesajları getirir."""
    print(f"--- get_messages_between_users çağrıldı: user1_id={user1_id}, user2_id={user2_id} ---")
    conn = connect_db()
    messages = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT * FROM messages
                WHERE (sender_user_id = %s AND receiver_user_id = %s)
                   OR (sender_user_id = %s AND receiver_user_id = %s)
                ORDER BY created_at ASC;
                """,
                (user1_id, user2_id, user2_id, user1_id)
            )
            messages = cursor.fetchall()
        except psycopg2.Error as e:
            print(f"!!! Mesajlar alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Mesajlar alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_messages_between_users: Veritabanı bağlantısı kurulamadı! ---")
    return messages

def get_post_by_id(post_id, current_user_id=None):
    """Belirli bir gönderiyi ID'sine göre getirir."""
    print(f"--- get_post_by_id çağrıldı: post_id={post_id}, current_user_id={current_user_id} ---")
    conn = connect_db()
    post = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            # Include like/comment counts and current user's like/save status
            cursor.execute(
                 """
                 SELECT
                     p.*,
                     u.username,
                     u.profile_picture_url,
                     (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.post_id) AS likes_count,
                     (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comments_count,
                     EXISTS(SELECT 1 FROM likes lk WHERE lk.post_id = p.post_id AND lk.user_id = %(current_user_id)s) AS is_liked_by_current_user,
                     EXISTS(SELECT 1 FROM saved_posts sp WHERE sp.post_id = p.post_id AND sp.user_id = %(current_user_id)s) AS is_saved_by_current_user,
                     p.created_at::TEXT AS created_at, -- Explicitly cast to TEXT (ISO 8601)
                     p.updated_at::TEXT AS updated_at -- Explicitly cast to TEXT (ISO 8601)
                 FROM posts p
                 JOIN users u ON p.user_id = u.user_id
                 WHERE p.post_id = %(post_id)s
                 """,
                {'post_id': post_id, 'current_user_id': current_user_id} # Use named placeholders
            )
            post = cursor.fetchone()
            if post:
                print(f"--- Gönderi {post_id} başarıyla alındı. ---")
            else:
                print(f"--- Gönderi {post_id} bulunamadı. ---")
        except psycopg2.Error as e:
            print(f"!!! Gönderi alınırken hata (ID): {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Gönderi alınırken beklenmedik hata (ID): {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_post_by_id: Veritabanı bağlantısı kurulamadı! ---")
    return post


def get_saved_posts_for_user(user_id_of_saver, requesting_user_id):
    """Belirli bir kullanıcı tarafından kaydedilen gönderileri getirir.
    requesting_user_id, gönderilerin bu kullanıcı tarafından beğenilip beğenilmediğini kontrol etmek için kullanılır.
    """
    print(f"--- get_saved_posts_for_user çağrıldı: user_id_of_saver={user_id_of_saver}, requesting_user_id={requesting_user_id} ---")
    conn = connect_db()
    if not conn: # Check connection failure early
        print("!!! get_saved_posts_for_user: Veritabanı bağlantısı kurulamadı! ---")
        raise Exception("Database connection failed in get_saved_posts_for_user")

    saved_posts_details = []
    cursor = None
    try:
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cursor.execute(
            """
            SELECT
                sp.saved_post_id, sp.created_at AS saved_at,
                p.post_id, p.user_id, p.content_text, p.image_url,
                p.created_at::TEXT AS created_at, -- Explicitly cast to TEXT (ISO 8601)
                p.updated_at::TEXT AS updated_at, -- Explicitly cast to TEXT (ISO 8601)
                u.username AS post_author_username,
                u.profile_picture_url AS post_author_avatar,
                (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.post_id) AS likes_count,
                (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comments_count,
                EXISTS(SELECT 1 FROM likes lk WHERE lk.post_id = p.post_id AND lk.user_id = %(requesting_user_id_param)s) AS is_liked_by_current_user,
                TRUE AS is_saved_by_current_user -- Bu sorgu zaten kaydedilmiş postları getirdiği için bu her zaman true olacak
            FROM saved_posts sp
            JOIN posts p ON sp.post_id = p.post_id
            JOIN users u ON p.user_id = u.user_id -- Postu atan kullanıcı
            WHERE sp.user_id = %(user_id_of_saver_param)s -- Kimin kaydettiği postlar
            ORDER BY sp.created_at DESC; -- En son kaydedilenler üstte
            """,
            {
                'user_id_of_saver_param': user_id_of_saver,
                'requesting_user_id_param': requesting_user_id
            }
        )
        saved_posts_details = cursor.fetchall()
        print(f"--- Kullanıcı {user_id_of_saver} için kaydedilen gönderi sayısı: {len(saved_posts_details)} ---")
    except psycopg2.Error as e:
        print(f"!!! Kaydedilen gönderiler alınırken psycopg2.Error: {e}")
        print(traceback.format_exc())
        raise 
    except Exception as e:
        print(f"!!! Kaydedilen gönderiler alınırken beklenmedik Exception: {e}")
        print(traceback.format_exc())
        raise
    finally:
        if cursor: cursor.close()
        if conn: conn.close()
    
    return saved_posts_details

def get_followers_for_user(user_id):
    """Belirli bir kullanıcıyı takip eden kullanıcıları getirir."""
    print(f"--- get_followers_for_user çağrıldı: user_id={user_id} ---")
    conn = connect_db()
    followers = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT f.follow_id, f.created_at, u.user_id, u.username, u.full_name, u.profile_picture_url
                FROM follows f
                JOIN users u ON f.follower_user_id = u.user_id -- Takip eden kullanıcı bilgileri
                WHERE f.followed_user_id = %s -- Takip edilen kişi bu user_id
                ORDER BY f.created_at DESC;
                """,
                (user_id,)
            )
            followers = cursor.fetchall()
        except psycopg2.Error as e:
            print(f"!!! Takipçiler alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Takipçiler alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_followers_for_user: Veritabanı bağlantısı kurulamadı! ---")
    return followers

def get_following_for_user(user_id):
    """Belirli bir kullanıcının takip ettiği kullanıcıları getirir."""
    print(f"--- get_following_for_user çağrıldı: user_id={user_id} ---")
    conn = connect_db()
    following = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT f.follow_id, f.created_at, u.user_id, u.username, u.full_name, u.profile_picture_url
                FROM follows f
                JOIN users u ON f.followed_user_id = u.user_id -- Takip edilen kullanıcı bilgileri
                WHERE f.follower_user_id = %s -- Takip eden kişi bu user_id
                ORDER BY f.created_at DESC;
                """,
                (user_id,)
            )
            following = cursor.fetchall()
        except psycopg2.Error as e:
            print(f"!!! Takip edilenler alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Takip edilenler alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_following_for_user: Veritabanı bağlantısı kurulamadı! ---")
    return following

def is_following_user(follower_user_id, followed_user_id):
    """Checks if a user is following another user."""
    print(f"--- is_following_user called: follower_user_id={follower_user_id}, followed_user_id={followed_user_id} ---")
    conn = connect_db()
    is_following = False
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT 1 FROM follows WHERE follower_user_id = %s AND followed_user_id = %s;",
                (follower_user_id, followed_user_id)
            )
            # If fetchone returns a row, it means the relationship exists
            is_following = cursor.fetchone() is not None
            print(f"--- is_following_user result: {is_following} ---")
        except psycopg2.Error as e:
            print(f"!!! Error checking follow status: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Unexpected error checking follow status: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! is_following_user: Database connection could not be established! ---")
    return is_following

def is_follow_request_pending(requester_user_id, recipient_user_id):
    """Checks if a follow request is pending from requester to recipient."""
    print(f"--- is_follow_request_pending called: requester_user_id={requester_user_id}, recipient_user_id={recipient_user_id} ---")
    conn = connect_db()
    is_pending = False
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT 1 FROM follow_requests WHERE requester_user_id = %s AND recipient_user_id = %s;",
                (requester_user_id, recipient_user_id)
            )
            is_pending = cursor.fetchone() is not None
            print(f"--- is_follow_request_pending result: {is_pending} ---")
        except psycopg2.Error as e:
            print(f"!!! Error checking follow request status: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Unexpected error checking follow request status: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! is_follow_request_pending: Database connection could not be established! ---")
    return is_pending


def get_suggested_users(user_id, limit=10):
    """Belirli bir kullanıcının takip etmediği kullanıcıları öneri olarak getirir."""
    print(f"--- get_suggested_users called: user_id={user_id}, limit={limit} ---")
    conn = connect_db()
    suggested_users = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            # Kullanıcının takip etmediği ve kendisi olmayan kullanıcıları seç
            cursor.execute(
                """
                SELECT user_id, username, full_name, profile_picture_url
                FROM users
                WHERE user_id != %s -- Kendisini önerme
                AND user_id NOT IN (
                    SELECT followed_user_id FROM follows WHERE follower_user_id = %s
                )
                ORDER BY random() -- Basit bir öneri için rastgele sıralama
                LIMIT %s;
                """,
                (user_id, user_id, limit)
            )
            suggested_users = cursor.fetchall()
            print(f"--- Kullanıcı {user_id} için önerilen kullanıcı sayısı: {len(suggested_users)} ---")
        except psycopg2.Error as e:
            print(f"!!! Önerilen kullanıcılar alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Önerilen kullanıcılar alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_suggested_users: Veritabanı bağlantısı kurulamadı! ---")
    if suggested_users:
        print(f"--- Kullanıcı {user_id} için önerilen kullanıcı sayısı: {len(suggested_users)} ---")
        return suggested_users
    else:
        # Eğer dinamik öneri yoksa, tüm diğer kullanıcıları öner (kendisi hariç)
        print(f"--- Kullanıcı {user_id} için dinamik öneri bulunamadı. Tüm diğer kullanıcılar öneriliyor. ---")
        # get_all_users fonksiyonunu kullanarak tüm kullanıcıları getir ve kendisini hariç tut
        all_other_users = get_all_users(current_user_id=user_id) # Use current_user_id parameter
        print(f"--- Kullanıcı {user_id} için toplam diğer kullanıcı sayısı: {len(all_other_users)} ---")
        return all_other_users


def get_user_settings(user_id):
    """Belirli bir kullanıcının ayarlarını getirir."""
    print(f"--- get_user_settings çağrıldı: user_id={user_id} ---")
    conn = connect_db()
    settings = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute( "SELECT * FROM user_settings WHERE user_id = %s;", (user_id,) )
            settings = cursor.fetchone()
        except psycopg2.Error as e:
            print(f"!!! Kullanıcı ayarları alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Kullanıcı ayarları alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_user_settings: Veritabanı bağlantısı kurulamadı! ---")
    return settings

def get_chat_summaries_for_user(user_id):
    """Belirli bir kullanıcı için sohbet özetlerini (son mesajlar) getirir."""
    print(f"--- get_chat_summaries_for_user çağrıldı: user_id={user_id} ---")
    conn = connect_db()
    chat_summaries = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                WITH latest_messages AS (
                    SELECT
                        LEAST(sender_user_id, receiver_user_id) as user_a_id,
                        GREATEST(sender_user_id, receiver_user_id) as user_b_id,
                        MAX(message_id) as last_message_id -- Son mesaj ID'sini al
                    FROM messages
                    WHERE sender_user_id = %(current_user_id)s OR receiver_user_id = %(current_user_id)s
                    GROUP BY user_a_id, user_b_id
                )
                SELECT
                    m.message_id, m.message_text, m.created_at as last_message_timestamp, m.is_read,
                    m.sender_user_id, -- Son mesajı kimin attığını bilmek için
                    CASE
                        WHEN m.sender_user_id = %(current_user_id)s THEN m.receiver_user_id
                        ELSE m.sender_user_id
                    END as partner_user_id,
                    -- Partner bilgilerini users tablosından al
                    partner.username as partner_username,
                    partner.full_name as partner_name,
                    partner.profile_picture_url as partner_avatar_url
                FROM latest_messages lm
                JOIN messages m ON m.message_id = lm.last_message_id -- En son mesajı ID ile eşleştir
                -- Partner kullanıcının bilgilerini almak için users tablosuna JOIN yap
                JOIN users partner ON partner.user_id = (
                     CASE
                        WHEN m.sender_user_id = %(current_user_id)s THEN m.receiver_user_id
                        ELSE m.sender_user_id
                    END
                )
                -- Sadece mevcut kullanıcıyı içeren sohbetleri filtrele (WHERE zaten latest_messages CTE'sinde yapıldı)
                ORDER BY m.created_at DESC; -- En yeni sohbetler üstte
                """,
                 {'current_user_id': user_id}
            )
            chat_summaries = cursor.fetchall()
            print(f"--- Kullanıcı {user_id} için sohbet özeti sayısı: {len(chat_summaries)} ---")
        except psycopg2.Error as e:
            print(f"!!! Sohbet özetleri alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Sohbet özetleri alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_chat_summaries_for_user: Veritabanı bağlantısı kurulamadı! ---")
    return chat_summaries


def get_notifications_for_user(user_id):
    """Belirli bir kullanıcı için bildirimleri getirir (silinmemiş olanları)."""
    print(f"--- get_notifications_for_user çağrıldı: user_id={user_id} ---")
    conn = connect_db()
    notifications = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT
                    n.notification_id,
                    n.recipient_user_id,
                    n.actor_user_id,
                    n.type,
                    n.post_id,
                    n.message_id,
                    n.follow_request_id, -- Include follow_request_id
                    n.created_at,
                    n.is_read,
                    n.is_deleted, -- ****** GÜNCELLEME: is_deleted alanı SELECT sorgusuna eklendi ******
                    a.username as actor_username,
                    a.profile_picture_url as actor_profile_picture_url,
                    p.image_url as post_thumbnail_url,
                    CASE
                        WHEN n.type = 'comment' THEN LEFT(c.comment_text, 50)
                        WHEN n.type = 'message' THEN LEFT(m.message_text, 50)
                        ELSE NULL
                    END as message_preview,
                    req_u.username as requester_username, -- Include requester username for follow requests
                    req_u.profile_picture_url as requester_profile_picture_url -- Include requester profile picture for follow requests
                FROM notifications n
                LEFT JOIN users a ON n.actor_user_id = a.user_id
                LEFT JOIN posts p ON n.post_id = p.post_id
                LEFT JOIN comments c ON n.post_id = c.post_id AND n.type = 'comment'
                LEFT JOIN messages m ON n.message_id = m.message_id AND n.type = 'message'
                -- Add joins for follow requests and the requester's user info
                LEFT JOIN follow_requests fr ON n.follow_request_id = fr.request_id AND n.type = 'follow_request'
                LEFT JOIN users req_u ON fr.requester_user_id = req_u.user_id AND n.type = 'follow_request'
                WHERE n.recipient_user_id = %s AND n.is_deleted = FALSE -- ****** GÜNCELLEME: Sadece silinmemişler getiriliyor ******
                ORDER BY n.created_at DESC;
                """,
                (user_id,)
            )
            notifications = cursor.fetchall()
        except psycopg2.Error as e:
            print(f"!!! Bildirimler alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Bildirimler alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_notifications_for_user: Veritabanı bağlantısı kurulamadı! ---")
    return notifications

# NOTE: The mobile app now fetches follow requests as part of the general notifications
# using get_notifications_for_user. This separate function might still be useful
# for other purposes, but the mobile app's NotificationsPage no longer calls it directly.
# Keeping it for now, but consider if it's still needed.
def get_follow_requests_for_user(user_id):
    """Belirli bir kullanıcıya gelen takip isteklerini getirir."""
    print(f"--- get_follow_requests_for_user called: user_id={user_id} ---")
    conn = connect_db()
    requests = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT fr.*, u.username as requester_username, u.profile_picture_url as requester_profile_picture_url
                FROM follow_requests fr
                JOIN users u ON fr.requester_user_id = u.user_id
                WHERE fr.recipient_user_id = %s
                ORDER BY fr.created_at DESC;
                """,
                (user_id,)
            )
            requests = cursor.fetchall()
            print(f"--- Kullanıcı {user_id} için takip isteği sayısı: {len(requests)} ---")
        except psycopg2.Error as e:
            print(f"!!! Takip istekleri alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Takip istekleri alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_follow_requests_for_user: Veritabanı bağlantısı kurulamadı! ---")
    return requests


# --- UPDATE Fonksiyonları ---

def update_user_settings(user_id, **kwargs):
    """Kullanıcı ayarlarını günceller veya oluşturur. kwargs: dark_mode_enabled=bool, email_notifications_enabled=bool"""
    print(f"--- update_user_settings çağrıldı: user_id={user_id}, settings={kwargs} ---")
    conn = connect_db()
    setting_id = None
    cursor = None
    if not kwargs: # Eğer güncellenecek bir şey yoksa
        print("--- update_user_settings: Güncellenecek ayar belirtilmedi. ---")
        return None

    if conn:
        try:
            cursor = conn.cursor()
            # Mevcut ayarları kontrol et
            cursor.execute("SELECT setting_id FROM user_settings WHERE user_id = %s;", (user_id,))
            existing_setting = cursor.fetchone()

            set_clauses = []
            params = []
            for key, value in kwargs.items():
                 # Sadece izin verilen alanları güncelle
                 if key in ['dark_mode_enabled', 'email_notifications_enabled']:
                    set_clauses.append(f"{key} = %s")
                    params.append(value)

            if not set_clauses: # Güncellenecek geçerli alan yoksa
                 print("--- update_user_settings: Geçerli ayar alanı bulunamadı. ---")
                 return None

            if existing_setting:
                # Var olanı güncelle
                query = f"UPDATE user_settings SET {', '.join(set_clauses)}, updated_at = NOW() WHERE user_id = %s RETURNING setting_id;"
                params.append(user_id)
                cursor.execute(query, tuple(params))
                result = cursor.fetchone()
                if result:
                    setting_id = result[0]
                    conn.commit()
                    print(f"--- Kullanıcı ayarları güncellendi: {setting_id} ---")
                else:
                    print("!!! HATA: UPDATE komutu setting_id döndürmedi! ---")
            else:
                # Yeni kayıt oluştur (varsayılanlarla birleştirerek)
                # Önce varsayılan değerleri al (False, True)
                defaults = {'dark_mode_enabled': False, 'email_notifications_enabled': True}
                # Gelen ayarlarla varsayılanları birleştir (gelenler öncelikli)
                final_settings = {**defaults, **kwargs}

                cursor.execute(
                    """INSERT INTO user_settings
                       (user_id, dark_mode_enabled, email_notifications_enabled)
                       VALUES (%s, %s, %s) RETURNING setting_id;""",
                    (user_id, final_settings['dark_mode_enabled'], final_settings['email_notifications_enabled'])
                )
                result = cursor.fetchone()
                if result:
                    setting_id = result[0]
                    conn.commit()
                    print(f"--- Kullanıcı ayarları oluşturuldu: {setting_id} ---")
                else:
                    print("!!! HATA: INSERT komutu setting_id döndürmedi! ---")

        except psycopg2.Error as e:
            print(f"!!! Kullanıcı ayarları güncellenirken/oluşturulurken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Kullanıcı ayarları güncellenirken/oluşturulurken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! update_user_settings: Veritabanı bağlantısı kurulamadı! ---")
    return setting_id

def update_user_privacy_status(user_id, is_private):
    """Updates a user's privacy status."""
    print(f"--- update_user_privacy_status called: user_id={user_id}, is_private={is_private} ---")
    conn = connect_db()
    success = False
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "UPDATE users SET is_private = %s, updated_at = NOW() WHERE user_id = %s;",
                (is_private, user_id)
            )
            rows_updated = cursor.rowcount
            conn.commit()
            if rows_updated > 0:
                print(f"--- User {user_id} privacy status updated to {is_private}. ---")
                success = True
            else:
                print(f"--- User {user_id} not found or privacy status already {is_private}. ---")
        except psycopg2.Error as e:
            print(f"!!! Database error during update_user_privacy_status: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Unexpected error during update_user_privacy_status: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! update_user_privacy_status: Database connection could not be established! ---")
    return success


def mark_notification_as_read(notification_id):
    """Belirli bir bildirimi okundu olarak işaretler."""
    print(f"--- mark_notification_as_read çağrıldı: notification_id={notification_id} ---")
    conn = connect_db()
    rows_updated = 0
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "UPDATE notifications SET is_read = TRUE WHERE notification_id = %s AND is_read = FALSE;",
                (notification_id,)
            )
            rows_updated = cursor.rowcount
            print(f"--- UPDATE notifications SET is_deleted = TRUE WHERE notification_id = {notification_id} executed. Rows updated: {rows_updated} ---") # Added logging
            conn.commit()
            if rows_updated > 0:
                 print(f"--- Bildirim {notification_id} silindi olarak işaretlendi. ---")
            else:
                 print(f"--- Bildirim {notification_id} zaten silindi veya bulunamadı. ---")
        except psycopg2.Error as e:
            print(f"!!! Bildirim silindi olarak işaretlenirken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Bildirim silindi olarak işaretlenirken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! mark_notification_as_deleted: Database connection could not be established! ---")
    return rows_updated > 0

def mark_notification_as_deleted(notification_id):
    """Marks a specific notification as deleted."""
    print(f"--- mark_notification_as_deleted called: notification_id={notification_id} ---")
    conn = None
    cursor = None
    success = False
    try:
        conn = connect_db()
        if conn:
            cursor = conn.cursor()
            print(f"--- Executing UPDATE for notification_id: {notification_id} ---")
            cursor.execute(
                "UPDATE notifications SET is_deleted = TRUE WHERE notification_id = %s AND is_deleted = FALSE;",
                (notification_id,)
            )
            rows_updated = cursor.rowcount
            conn.commit()
            print(f"--- UPDATE executed. Rows updated: {rows_updated} ---")
            if rows_updated > 0:
                 print(f"--- Notification {notification_id} marked as deleted. ---")
                 success = True
            else:
                 print(f"--- Notification {notification_id} not found or already marked as deleted. ---")
        else:
            print("!!! mark_notification_as_deleted: Database connection could not be established! ---")
    except psycopg2.Error as e:
        print(f"!!! Database error during mark_notification_as_deleted: {e}")
        print(traceback.format_exc())
        if conn: conn.rollback()
        success = False
    except Exception as e:
        print(f"!!! Unexpected error during mark_notification_as_deleted: {e}")
        print(traceback.format_exc())
        if conn: conn.rollback()
        success = False
    finally:
        if cursor: cursor.close()
        if conn: conn.close()
    return success


# --- Follow Request Actions ---

def accept_follow_request(request_id):
    """Accepts a follow request, creates a follow relationship, and deletes the request."""
    print(f"--- accept_follow_request called: request_id={request_id} ---")
    conn = connect_db()
    success = False
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            # Get the request details
            cursor.execute(
                "SELECT requester_user_id, recipient_user_id FROM follow_requests WHERE request_id = %s;",
                (request_id,)
            )
            request_details = cursor.fetchone()
            print(f"--- accept_follow_request: Fetched request details for request_id {request_id}: {request_details} ---") # Added logging

            if request_details:
                requester_user_id = request_details['requester_user_id']
                recipient_user_id = request_details['recipient_user_id']

                # Create the follow relationship directly
                cursor.execute(
                    "INSERT INTO follows (follower_user_id, followed_user_id) VALUES (%s, %s) RETURNING follow_id;",
                    (requester_user_id, recipient_user_id)
                )
                follow_result = cursor.fetchone()
                print(f"--- accept_follow_request: Follow creation result for request_id {request_id}: {follow_result} ---") # Added logging


                if follow_result:
                    follow_id = follow_result[0]
                    # Delete the follow request
                    cursor.execute("DELETE FROM follow_requests WHERE request_id = %s;", (request_id,))
                    rows_deleted = cursor.rowcount
                    print(f"--- accept_follow_request: Rows deleted from follow_requests for request_id {request_id}: {rows_deleted} ---") # Added logging


                    if rows_deleted > 0:
                        conn.commit()
                        print(f"--- Follow request {request_id} accepted. Follow relationship created (ID: {follow_id}). ---")
                        success = True
                        # Create a notification for the requester that their request was accepted
                        try: # Added try-except block
                            create_notification(
                                recipient_user_id=requester_user_id,
                                actor_user_id=recipient_user_id,
                                notification_type='follow' # Use 'follow' type for acceptance notification
                            )
                            print(f"--- Notification created successfully for accepted follow request ID: {request_id} ---") # Added logging
                        except Exception as notification_error:
                            print(f"!!! ERROR creating notification for accepted follow request ID {request_id}: {notification_error}")
                            print(traceback.format_exc())
                            # Continue execution even if notification creation fails,
                            # as the follow request itself was successfully accepted.
                            # Consider adding more robust error logging or alerting here.

                    else:
                        print(f"!!! HATA: Follow request {request_id} not found during deletion after follow creation. Rollback initiated. ---")
                        if conn: conn.rollback() # Rollback follow creation if request deletion fails
                else:
                    print(f"!!! HATA: Failed to create follow relationship for request {request_id}. Rollback initiated. ---")
                    if conn: conn.rollback() # Rollback if follow creation fails
            else:
                print(f"--- Follow request {request_id} not found. ---")

        except psycopg2.errors.UniqueViolation:
             print(f"!!! Follow relationship already exists when accepting request {request_id}. Deleting request.")
             # If the follow relationship already exists, just delete the request
             try:
                 cursor = conn.cursor() # Need a new cursor if the previous one is in a bad state
                 cursor.execute("DELETE FROM follow_requests WHERE request_id = %s;", (request_id,))
                 rows_deleted = cursor.rowcount
                 conn.commit()
                 if rows_deleted > 0:
                     print(f"--- Follow request {request_id} deleted because follow relationship already existed. ---")
                     success = True # Consider this a success as the request is handled
                 else:
                     print(f"!!! HATA: Follow request {request_id} not found during deletion after UniqueViolation. ---")
             except Exception as e:
                 print(f"!!! Error deleting request after UniqueViolation: {e}")
                 print(traceback.format_exc())
                 if conn: conn.rollback()
                 success = False
        except psycopg2.Error as e:
            print(f"!!! Database error during accept_follow_request: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Unexpected error during accept_follow_request: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! accept_follow_request: Database connection could not be established! ---")
    return success

def reject_follow_request(request_id):
    """Rejects (deletes) a follow request."""
    print(f"--- reject_follow_request called: request_id={request_id} ---")
    conn = connect_db()
    success = False
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "DELETE FROM follow_requests WHERE request_id = %s;",
                (request_id,)
            )
            rows_deleted = cursor.rowcount
            conn.commit()
            if rows_deleted > 0:
                print(f"--- Follow request {request_id} rejected (deleted). ---")
                success = True
            else:
                print(f"--- Follow request {request_id} not found or already deleted. ---")
        except psycopg2.Error as e:
            print(f"!!! Database error during reject_follow_request: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Unexpected error during reject_follow_request: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! reject_follow_request: Database connection could not be established! ---")
    return success


# --- DELETE Fonksiyonları ---

def delete_follow(follower_user_id, followed_user_id):
    """Follows tablosından bir takip ilişkisini siler."""
    print(f"--- delete_follow çağrıldı: follower_user_id={follower_user_id}, followed_user_id={followed_user_id} ---")
    conn = connect_db()
    rows_deleted = 0
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "DELETE FROM follows WHERE follower_user_id = %s AND followed_user_id = %s;",
                (follower_user_id, followed_user_id)
            )
            rows_deleted = cursor.rowcount # Etkilenen satır sayısını al
            conn.commit()
            if rows_deleted > 0:
                print(f"--- Takip ilişkisi silindi: {follower_user_id} -> {followed_user_id} ---")
            else:
                 print(f"--- Silinecek takip ilişkisi bulunamadı: {follower_user_id} -> {followed_user_id} ---")
        except psycopg2.Error as e:
            print(f"!!! Takip ilişkisi silinirken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Takip ilişkisi silinirken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! delete_follow: Veritabanı bağlantısı kurulamadı! ---")
    return rows_deleted > 0 # Silme işlemi başarılıysa True döndür


def delete_like(user_id, post_id):
    """Likes tablosından bir beğeniyi siler."""
    print(f"--- delete_like çağrıldı: user_id={user_id}, post_id={post_id} ---")
    conn = connect_db()
    rows_deleted = 0
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "DELETE FROM likes WHERE user_id = %s AND post_id = %s;",
                (user_id, post_id)
            )
            rows_deleted = cursor.rowcount # Etkilenen (silinen) satır sayısını al
            conn.commit()
            if rows_deleted > 0:
                 print(f"--- Beğeni başarıyla silindi. user_id={user_id}, post_id={post_id} ---")
            else:
                 print(f"--- Silinecek beğeni bulunamadı. user_id={user_id}, post_id={post_id} ---")
        except psycopg2.Error as e:
            print(f"!!! Beğeni silinirken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Beğeni silinirken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! delete_like: Veritabanı bağlantısı kurulamadı! ---")
    # Silme işlemi başarılıysa (en az 1 satır etkilendiyse) True döndür
    return rows_deleted > 0

def delete_saved_post(user_id, post_id):
    """SavedPosts tablosından kaydedilmiş bir gönderiyi siler."""
    print(f"--- delete_saved_post çağrıldı: user_id={user_id}, post_id={post_id} ---")
    conn = connect_db()
    rows_deleted = 0
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "DELETE FROM saved_posts WHERE user_id = %s AND post_id = %s;",
                (user_id, post_id)
            )
            rows_deleted = cursor.rowcount
            conn.commit()
            if rows_deleted > 0:
                 print(f"--- Kaydedilen gönderi başarıyla silindi. user_id={user_id}, post_id={post_id} ---")
            else:
                 print(f"--- Silinecek kaydedilen gönderi bulunamadı. user_id={user_id}, post_id={post_id} ---")
        except psycopg2.Error as e:
            print(f"!!! Kaydedilen gönderi silinirken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Kaydedilen gönderi silinirken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! delete_saved_post: Veritabanı bağlantısı kurulamadı! ---")
    # Silme işlemi başarılıysa True döndür
    return rows_deleted > 0

def update_user_profile(user_id, username=None, profile_picture_url=None):
    """Updates a user's profile information (username, profile_picture_url)."""
    print(f"--- update_user_profile called: user_id={user_id}, username={username}, profile_picture_url={profile_picture_url} ---")
    conn = connect_db()
    success = False
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            set_clauses = []
            params = []

            if username is not None:
                set_clauses.append("username = %s")
                params.append(username)
            if profile_picture_url is not None:
                set_clauses.append("profile_picture_url = %s")
                params.append(profile_picture_url)

            if not set_clauses:
                print("--- update_user_profile: No fields to update. ---")
                return False

            query = f"UPDATE users SET {', '.join(set_clauses)}, updated_at = NOW() WHERE user_id = %s;"
            params.append(user_id)

            cursor.execute(query, tuple(params))
            rows_updated = cursor.rowcount
            conn.commit()

            if rows_updated > 0:
                print(f"--- User {user_id} profile updated successfully. ---")
                success = True
            else:
                print(f"--- User {user_id} not found or no changes made. ---")

        except psycopg2.errors.UniqueViolation:
            print(f"!!! User profile update failed (UniqueViolation): Username might be taken. Rollback initiated.")
            if conn: conn.rollback()
            success = False # Ensure success is False on unique violation
        except psycopg2.Error as e:
            print(f"!!! Database error during user profile update: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
            success = False
        except Exception as e:
            print(f"!!! Unexpected error during user profile update: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
            success = False
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! update_user_profile: Database connection could not be established! ---")
        success = False
    return success

def search_users_for_message(current_user_id, search_term=None):
    """
    Searches for users for the new message feature.
    If search_term is None, returns users the current user is following.
    If search_term is provided, searches for users by username.
    """
    print(f"--- search_users_for_message called: current_user_id={current_user_id}, search_term='{search_term}' ---") # Added quotes around search_term for clarity
    conn = connect_db()
    users = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            if search_term is None or search_term == "":
                # Return users the current user is following
                query = """
                    SELECT u.user_id, u.username, u.full_name, u.profile_picture_url
                    FROM users u
                    JOIN follows f ON u.user_id = f.followed_user_id
                    WHERE f.follower_user_id = %s
                    ORDER BY u.username ASC;
                """
                params = (current_user_id,)
                print(f"--- search_users_for_message: No search term, fetching following users for user_id={current_user_id} ---") # Added logging
            else:
                # Search for users by username (case-insensitive, partial match)
                # Exclude the current user from search results
                query = """
                    SELECT user_id, username, full_name, profile_picture_url
                    FROM users
                    WHERE username ILIKE %s AND user_id != %s
                    ORDER BY username ASC;
                """
                params = (f"%{search_term}%", current_user_id)
                print(f"--- search_users_for_message: Searching for username ILIKE '%{search_term}%' excluding user_id={current_user_id} ---") # Added logging

            print(f"--- Executing query: {query} with params: {params} ---")
            cursor.execute(query, params)
            users = cursor.fetchall()
            print(f"--- Query executed successfully. Fetched {len(users)} users. ---")
            # Added logging to show fetched usernames
            if users:
                print("--- Fetched users: ---")
                for user in users:
                    print(f"    - {user.get('username')} (ID: {user.get('user_id')})")
                print("---------------------")


        except psycopg2.Error as e:
            print(f"!!! Error searching users for message: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Unexpected error searching users for message: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! search_users_for_message: Database connection could not be established! ---")
    return users


# Bu blok, dosya doğrudan çalıştırıldığında yürütülür.
if __name__ == '__main__':
    print("--- db_utils.py doğrudan çalıştırıldı. Tablolar oluşturuluyor/kontrol ediliyor... ---")
    create_tables()
    print("--- Tablo oluşturma işlemi tamamlandı. ---")
    # İsteğe bağlı olarak test fonksiyonları buraya eklenebilir.
    # Örneğin: test_user = create_user('testuser', 'test@example.com', bcrypt.hashpw(b'password', bcrypt.gensalt()).decode())
    # print(f"Test kullanıcısı oluşturuldu: {test_user}")
