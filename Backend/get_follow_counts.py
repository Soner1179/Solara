import psycopg2
from db_config import DB_HOST, DB_NAME, DB_USER, DB_PASSWORD

def get_follow_counts(user_id):
    conn = None
    followers_count = 0
    following_count = 0
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        cursor = conn.cursor()

        # Get followers count
        cursor.execute("SELECT COUNT(*) FROM follows WHERE followed_user_id = %s;", (user_id,))
        followers_count = cursor.fetchone()[0]

        # Get following count
        cursor.execute("SELECT COUNT(*) FROM follows WHERE follower_user_id = %s;", (user_id,))
        following_count = cursor.fetchone()[0]

        cursor.close()
        conn.close()
    except psycopg2.Error as e:
        print(f"Database error: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")
    return followers_count, following_count

if __name__ == "__main__":
    # Replace with the actual user ID you want to check
    user_id_to_check = 8
    followers, following = get_follow_counts(user_id_to_check)
    print(f"User ID: {user_id_to_check}")
    print(f"Followers: {followers}")
    print(f"Following: {following}")
