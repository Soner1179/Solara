import psycopg2
from db_config import DB_HOST, DB_NAME, DB_USER, DB_PASSWORD

def get_user():
    conn = None
    user = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        cursor = conn.cursor()
        cursor.execute("SELECT user_id, username FROM users LIMIT 2;")
        users = cursor.fetchall()
        user = users if users else None
        cursor.close()
        conn.close()
    except psycopg2.Error as e:
        print(f"Database error: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")
    return user

if __name__ == "__main__":
    user_data = get_user()
    if user_data:
        print(f"User ID: {user_data[0]}, Username: {user_data[1]}")
    else:
        print("No users found or failed to connect.")
