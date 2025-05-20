import psycopg2
from db_config import DB_HOST, DB_NAME, DB_USER, DB_PASSWORD

def add_column_if_not_exists(table_name, column_name, column_definition):
    """Adds a column to a table if it does not already exist."""
    conn = None
    cursor = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        cursor = conn.cursor()

        # Check if the column already exists
        cursor.execute(
            """
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = %s AND column_name = %s;
            """,
            (table_name, column_name)
        )
        column_exists = cursor.fetchone() is not None

        if not column_exists:
            # Add the column
            alter_table_sql = f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_definition};"
            cursor.execute(alter_table_sql)
            conn.commit()
            print(f"Column '{column_name}' added to table '{table_name}'.")
        else:
            print(f"Column '{column_name}' already exists in table '{table_name}'.")

    except psycopg2.Error as e:
        print(f"Database error: {e}")
        if conn:
            conn.rollback()
    except Exception as e:
        print(f"Unexpected error: {e}")
        if conn:
            conn.rollback()
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

if __name__ == '__main__':
    # Add the 'is_private' column to the 'users' table
    add_column_if_not_exists('users', 'is_private', 'BOOLEAN DEFAULT FALSE')
