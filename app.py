from flask import Flask, request, jsonify
import psycopg2
from datetime import datetime

app = Flask(__name__)

# Veritabanı bağlantı ayarları (Kendi bilgilerinizi girin!)
DATABASE_URL = "postgresql://connected_user:güçlü_parola@localhost:5432/connected_db" # Yerel PostgreSQL için örnek URL

def get_db_connection():
    """Veritabanına bağlantı oluşturur."""
    conn = psycopg2.connect(DATABASE_URL)
    return conn

@app.route('/')
def home():
    return "Connected Backend API Çalışıyor!"

# Kullanıcı Kayıt API'si
@app.route('/register', methods=['POST'])
def register_user():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password') # Şifreleri düz metin olarak saklamayın! Güvenlik için hash kullanın! (bcrypt önerilir)

    if not username or not password:
        return jsonify({'message': 'Kullanıcı adı ve parola gerekli'}), 400

    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Kullanıcı adı zaten var mı kontrol et
        cur.execute("SELECT id FROM users WHERE username = %s", (username,))
        if cur.fetchone() is not None:
            cur.close()
            conn.close()
            return jsonify({'message': 'Bu kullanıcı adı zaten alınmış'}), 409 # Conflict (Çakışma)

        # Yeni kullanıcıyı veritabanına ekle (Parolayı hash'leyerek saklamanız GEREKİR!)
        cur.execute("INSERT INTO users (username, password) VALUES (%s, %s) RETURNING id", (username, password)) # GÜVENLİK UYARISI!
        user_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({'message': 'Kullanıcı başarıyla kaydedildi', 'user_id': user_id}), 201 # Created
    except Exception as e:
        cur.close()
        conn.close()
        return jsonify({'message': 'Kullanıcı kaydı sırasında hata oluştu', 'error': str(e)}), 500 # Internal Server Error


# Kullanıcı Giriş API'si (Çok BASİT ve GÜVENLİ DEĞİL, sadece örnek amaçlı!)
@app.route('/login', methods=['POST'])
def login_user():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'message': 'Kullanıcı adı ve parola gerekli'}), 400

    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Kullanıcıyı veritabanından al
        cur.execute("SELECT id, password FROM users WHERE username = %s", (username,))
        user_data = cur.fetchone()
        cur.close()
        conn.close()

        if user_data is None:
            return jsonify({'message': 'Kullanıcı bulunamadı'}), 401 # Unauthorized

        user_id, stored_password = user_data

        # Parola kontrolü (GÜVENLİ DEĞİL! Gerçek uygulamada hash karşılaştırması yapılmalı)
        if password == stored_password: # GÜVENLİK UYARISI!
            return jsonify({'message': 'Giriş başarılı', 'user_id': user_id}), 200 # OK
        else:
            return jsonify({'message': 'Yanlış parola'}), 401 # Unauthorized

    except Exception as e:
        cur.close()
        conn.close()
        return jsonify({'message': 'Giriş sırasında hata oluştu', 'error': str(e)}), 500 # Internal Server Error


# Gönderi Oluşturma API'si
@app.route('/posts', methods=['POST'])
def create_post():
    data = request.get_json()
    user_id = data.get('user_id') # Giriş yapmış kullanıcının ID'si (güvenlik için oturum yönetimi ve doğrulama GEREKLİ)
    content = data.get('content')
    image_url = data.get('image_url') # İsteğe bağlı resim URL'i

    if not user_id or not content:
        return jsonify({'message': 'Kullanıcı ID ve gönderi içeriği gerekli'}), 400

    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Yeni gönderiyi veritabanına ekle
        cur.execute("INSERT INTO posts (user_id, content, image_url) VALUES (%s, %s, %s) RETURNING id, created_at", (user_id, content, image_url))
        post_id, created_at = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()

        # Gönderi oluşturma zamanını (created_at) uygun formata çevir (ISO formatı)
        created_at_iso = created_at.isoformat()

        return jsonify({
            'message': 'Gönderi başarıyla oluşturuldu',
            'post_id': post_id,
            'created_at': created_at_iso # ISO formatında zaman
        }), 201 # Created
    except Exception as e:
        cur.close()
        conn.close()
        return jsonify({'message': 'Gönderi oluşturulurken hata oluştu', 'error': str(e)}), 500 # Internal Server Error


# Gönderi Akışı (Timeline) API'si (Şimdilik BASİT, sadece tüm gönderileri getiriyor)
@app.route('/posts', methods=['GET'])
def get_timeline_posts():
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Tüm gönderileri veritabanından al (Şimdilik basitçe tüm gönderileri getiriyor)
        cur.execute("""
            SELECT posts.id, posts.content, posts.image_url, posts.created_at, users.username, users.profile_image_url
            FROM posts
            JOIN users ON posts.user_id = users.id
            ORDER BY posts.created_at DESC
        """) # Gönderileri oluşturulma zamanına göre (en yeni önce) sırala
        posts = cur.fetchall()
        cur.close()
        conn.close()

        post_list = []
        for post in posts:
            post_data = {
                'post_id': post[0],
                'content': post[1],
                'image_url': post[2],
                'created_at': post[3].isoformat(), # Zamanı ISO formatına çevir
                'author_username': post[4],
                'author_profile_image_url': post[5]
            }
            post_list.append(post_data)

        return jsonify(post_list), 200 # OK
    except Exception as e:
        cur.close()
        conn.close()
        return jsonify({'message': 'Gönderi akışı alınırken hata oluştu', 'error': str(e)}), 500 # Internal Server Error


if __name__ == '__main__':
    app.run(debug=True) # Geliştirme modunda çalıştır (debug=True) - Üretimde debug=False yapın!