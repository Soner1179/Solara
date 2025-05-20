import psycopg2
from db_config import DB_HOST, DB_NAME, DB_USER, DB_PASSWORD

def check_column_exists(table_name, column_name):
    """Checks if a column exists in a given table."""
    conn = None
    cursor = None
    column_exists = False
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = %s AND column_name = %s;
            """,
            (table_name, column_name)
        )
        column_exists = cursor.fetchone() is not None
        print(f"Column '{column_name}' in table '{table_name}' exists: {column_exists}")
    except psycopg2.Error as e:
        print(f"Database error: {e}")
    except Exception as e:
        print(f"Unexpected error: {e}")
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
    return column_exists

if __name__ == '__main__':
    check_column_exists('users', 'is_private')
