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
                updated_at TIMESTAMPTZ DEFAULT NOW()
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
                created_at TIMESTAMPTZ DEFAULT NOW(),
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
                    CREATE TYPE notification_type AS ENUM ('like', 'comment', 'follow', 'message');
                END IF;
            END
            $$;

            CREATE TABLE IF NOT EXISTS notifications (
                notification_id SERIAL PRIMARY KEY,
                recipient_user_id INT NOT NULL,
                actor_user_id INT, -- Bildirimi tetikleyen kullanıcı (like, comment, follow yapan)
                type notification_type NOT NULL,
                post_id INT, -- Hangi postla ilgili (like, comment)
                message_id BIGINT, -- Hangi mesajla ilgili
                is_read BOOLEAN DEFAULT FALSE,
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
                    REFERENCES messages(message_id) ON DELETE CASCADE -- Mesaj silinirse ilgili bildirimler de silinsin
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
    """Follows tablosuna yeni bir takip ilişkisi ekler."""
    print(f"--- create_follow çağrıldı: follower_user_id={follower_user_id}, followed_user_id={followed_user_id} ---")
    conn = connect_db()
    follow_id = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO follows (follower_user_id, followed_user_id) VALUES (%s, %s) RETURNING follow_id;",
                (follower_user_id, followed_user_id)
            )
            result = cursor.fetchone()
            if result:
                follow_id = result[0]
                conn.commit()
                print(f"--- Takip ilişkisi ID ile oluşturuldu: {follow_id} ---")
            else:
                print("!!! HATA: INSERT komutu follow_id döndürmedi! ---")
        except psycopg2.errors.UniqueViolation:
            print(f"!!! Takip ilişkisi oluşturulurken hata (UniqueViolation): İlişki zaten mevcut. ---")
            if conn: conn.rollback()
            # Zaten var olan ilişki için ID döndürme (veya istersen var olanı sorgula)
        except psycopg2.Error as e:
            print(f"!!! Takip ilişkisi oluşturulurken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Takip ilişkisi oluşturulurken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_follow: Veritabanı bağlantısı kurulamadı! ---")
    return follow_id

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
    """SavedPosts tablosuna yeni bir kaydedilen gönderi ekler."""
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

def create_notification(recipient_user_id, actor_user_id, notification_type, post_id=None, message_id=None):
    """Notifications tablosuna yeni bir bildirim ekler."""
    print(f"--- create_notification çağrıldı: recipient={recipient_user_id}, actor={actor_user_id}, type={notification_type} ---")
    conn = connect_db()
    notification_id = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute(
                """INSERT INTO notifications
                   (recipient_user_id, actor_user_id, type, post_id, message_id)
                   VALUES (%s, %s, %s, %s, %s) RETURNING notification_id;""",
                (recipient_user_id, actor_user_id, notification_type, post_id, message_id)
            )
            result = cursor.fetchone()
            if result:
                notification_id = result[0]
                conn.commit()
                print(f"--- Bildirim ID ile oluşturuldu: {notification_id} ---")
            else:
                print("!!! HATA: INSERT komutu notification_id döndürmedi! ---")
        except psycopg2.Error as e:
            print(f"!!! Bildirim oluşturulurken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Bildirim oluşturulurken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! create_notification: Veritabanı bağlantısı kurulamadı! ---")
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

def get_user_by_id(user_id):
    """Kullanıcı ID'sine göre bir kullanıcıyı getirir."""
    print(f"--- get_user_by_id çağrıldı: user_id={user_id} ---")
    conn = connect_db()
    user = None
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute( "SELECT * FROM users WHERE user_id = %s;", (user_id,) )
            user = cursor.fetchone()
        except psycopg2.Error as e:
            print(f"!!! Kullanıcı alınırken hata (ID): {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Kullanıcı alınırken beklenmedik hata (ID): {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_user_by_id: Veritabanı bağlantısı kurulamadı! ---")
    return user

def get_all_users(exclude_user_id=None):
    """Tüm kullanıcıları getirir, isteğe bağlı olarak belirli bir kullanıcıyı hariç tutar."""
    print(f"--- get_all_users called: exclude_user_id={exclude_user_id} ---")
    conn = connect_db()
    users = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            query = "SELECT user_id, username, full_name, profile_picture_url FROM users"
            params = []

            if exclude_user_id is not None:
                query += " WHERE user_id != %s"
                params.append(exclude_user_id)

            query += " ORDER BY username ASC;" # Kullanıcıları kullanıcı adına göre sırala

            print(f"--- Executing query: {query} with params: {params} ---")
            cursor.execute(query, tuple(params))
            users = cursor.fetchall()
            print(f"--- Query executed successfully. Fetched {len(users)} users. ---")
        except psycopg2.Error as e:
            print(f"!!! Error fetching all users: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Unexpected error fetching all users: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_all_users: Database connection could not be established! ---")
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
                    (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comments_count
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
                    EXISTS(SELECT 1 FROM saved_posts sp WHERE sp.post_id = p.post_id AND sp.user_id = %(current_user_id)s) AS is_saved_by_current_user
                FROM posts p
                JOIN users u ON p.user_id = u.user_id
                -- Kendi gönderilerini veya takip ettiklerinin gönderilerini al
                WHERE p.user_id = %(current_user_id)s OR p.user_id IN (
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


def get_posts_by_user_id(user_id):
    """Belirli bir kullanıcıya ait gönderileri getirir (Profil sayfası için)."""
    print(f"--- get_posts_by_user_id çağrıldı: user_id={user_id} ---")
    conn = connect_db()
    posts = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
             # İsteğe bağlı olarak like/comment count eklenebilir
            cursor.execute(
                 """
                 SELECT
                     p.*,
                     u.username,
                     u.profile_picture_url,
                     (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.post_id) AS likes_count,
                     (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comments_count
                 FROM posts p
                 JOIN users u ON p.user_id = u.user_id
                 WHERE p.user_id = %s
                 ORDER BY p.created_at DESC;
                 """,
                (user_id,)
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

def get_comments_for_post(post_id):
    """Belirli bir gönderiye ait yorumları getirir."""
    print(f"--- get_comments_for_post çağrıldı: post_id={post_id} ---")
    conn = connect_db()
    comments = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """SELECT c.*, u.username, u.profile_picture_url
                   FROM comments c
                   JOIN users u ON c.user_id = u.user_id
                   WHERE c.post_id = %s ORDER BY c.created_at ASC;""", # Genellikle eskiden yeniye sıralanır
                (post_id,)
            )
            comments = cursor.fetchall()
        except psycopg2.Error as e:
            print(f"!!! Yorumlar alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Yorumlar alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_comments_for_post: Veritabanı bağlantısı kurulamadı! ---")
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

def get_saved_posts_for_user(user_id):
    """Belirli bir kullanıcı tarafından kaydedilen gönderileri getirir."""
    print(f"--- get_saved_posts_for_user çağrıldı: user_id={user_id} ---")
    conn = connect_db()
    saved_posts_details = []
    cursor = None
    if conn:
        try:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
             # JOIN ile post detaylarını da alalım
            cursor.execute(
                """
                SELECT
                    sp.saved_post_id, sp.created_at AS saved_at, -- saved_posts.created_at is when it was saved
                    p.*, -- Tüm post detayları
                    u.username AS post_author_username,
                    u.profile_picture_url AS post_author_avatar
                    -- İsteğe bağlı: Kaydedilen postun like/comment sayıları
                    ,(SELECT COUNT(*) FROM likes l WHERE l.post_id = p.post_id) AS likes_count
                    ,(SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comments_count
                    -- İsteğe bağlı: Mevcut kullanıcının bu postu beğenip beğenmediği (zaten kaydedilmiş ama yine de)
                    ,EXISTS(SELECT 1 FROM likes lk WHERE lk.post_id = p.post_id AND lk.user_id = sp.user_id) AS is_liked_by_saver
                FROM saved_posts sp
                JOIN posts p ON sp.post_id = p.post_id
                JOIN users u ON p.user_id = u.user_id -- Postu atan kullanıcı
                WHERE sp.user_id = %s
                ORDER BY sp.created_at DESC; -- En son kaydedilenler üstte
                """,
                (user_id,)
            )
            saved_posts_details = cursor.fetchall()
            print(f"--- Kullanıcı {user_id} için kaydedilen gönderi sayısı: {len(saved_posts_details)} ---")
        except psycopg2.Error as e:
            print(f"!!! Kaydedilen gönderiler alınırken hata: {e}")
            print(traceback.format_exc())
        except Exception as e:
             print(f"!!! Kaydedilen gönderiler alınırken beklenmedik hata: {e}")
             print(traceback.format_exc())
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! get_saved_posts_for_user: Veritabanı bağlantısı kurulamadı! ---")
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
                    -- Partner bilgilerini users tablosundan al
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
    """Belirli bir kullanıcı için bildirimleri getirir."""
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
                    n.*,
                    -- Aktör kullanıcı bilgileri (varsa)
                    a.username as actor_username,
                    a.profile_picture_url as actor_profile_picture_url,
                    -- İlgili post bilgileri (varsa)
                    p.image_url as post_thumbnail_url, -- Sadece küçük resim yeterli olabilir
                    -- İlgili mesaj önizlemesi (varsa)
                    LEFT(m.message_text, 50) as message_preview -- Mesajın ilk 50 karakteri
                FROM notifications n
                LEFT JOIN users a ON n.actor_user_id = a.user_id
                LEFT JOIN posts p ON n.post_id = p.post_id
                LEFT JOIN messages m ON n.message_id = m.message_id
                WHERE n.recipient_user_id = %s
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
                "UPDATE notifications SET is_read = TRUE WHERE notification_id = %s AND is_read = FALSE;", # Sadece okunmamışları güncelle
                (notification_id,)
            )
            rows_updated = cursor.rowcount
            conn.commit()
            if rows_updated > 0:
                 print(f"--- Bildirim {notification_id} okundu olarak işaretlendi. ---")
            else:
                 print(f"--- Bildirim {notification_id} zaten okundu veya bulunamadı. ---")
        except psycopg2.Error as e:
            print(f"!!! Bildirim okundu olarak işaretlenirken hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        except Exception as e:
            print(f"!!! Bildirim okundu olarak işaretlenirken beklenmedik hata: {e}")
            print(traceback.format_exc())
            if conn: conn.rollback()
        finally:
            if cursor: cursor.close()
            if conn: conn.close()
    else:
        print("!!! mark_notification_as_read: Veritabanı bağlantısı kurulamadı! ---")
    return rows_updated > 0

# --- DELETE Fonksiyonları ---

def delete_follow(follower_user_id, followed_user_id):
    """Follows tablosundan bir takip ilişkisini siler."""
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
    """Likes tablosundan bir beğeniyi siler."""
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
    """SavedPosts tablosundan kaydedilmiş bir gönderiyi siler."""
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


# Bu blok, dosya doğrudan çalıştırıldığında yürütülür.
if __name__ == '__main__':
    print("--- db_utils.py doğrudan çalıştırıldı. Tablolar oluşturuluyor/kontrol ediliyor... ---")
    create_tables()
    print("--- Tablo oluşturma işlemi tamamlandı. ---")
    # İsteğe bağlı olarak test fonksiyonları buraya eklenebilir.
    # Örneğin: test_user = create_user('testuser', 'test@example.com', bcrypt.hashpw(b'password', bcrypt.gensalt()).decode())
    # print(f"Test kullanıcısı oluşturuldu: {test_user}")
