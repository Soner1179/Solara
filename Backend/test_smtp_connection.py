import smtplib
import os
from email.mime.text import MIMEText

def test_smtp_connection():
    mail_server = os.environ.get('MAIL_SERVER', 'smtp.gmail.com') # Default to Gmail if not set
    mail_port = int(os.environ.get('MAIL_PORT', 587)) # Default to 587 if not set
    mail_username = os.environ.get('MAIL_USERNAME')
    mail_password = os.environ.get('MAIL_PASSWORD')
    mail_default_sender = os.environ.get('MAIL_DEFAULT_SENDER') # This will be the sender
    test_recipient = mail_default_sender # Send a test email to yourself

    if not all([mail_username, mail_password, mail_default_sender]):
        print("Error: MAIL_USERNAME, MAIL_PASSWORD, and MAIL_DEFAULT_SENDER environment variables must be set.")
        return

    print(f"Attempting to connect to {mail_server}:{mail_port}...")
    try:
        server = smtplib.SMTP(mail_server, mail_port, timeout=10) # Added timeout
        print("Successfully created SMTP object.")
        
        print("Attempting to start TLS...")
        server.starttls()
        print("Successfully started TLS.")
        
        print(f"Attempting to login with username: {mail_username}...")
        server.login(mail_username, mail_password)
        print("Successfully logged in.")
        
        # Send a test email
        msg = MIMEText('This is a test email from test_smtp_connection.py.')
        msg['Subject'] = 'SMTP Connection Test (Python)'
        msg['From'] = mail_default_sender
        msg['To'] = test_recipient
        
        print(f"Attempting to send a test email to {test_recipient}...")
        server.sendmail(mail_default_sender, test_recipient, msg.as_string())
        print("Successfully sent test email.")
        
    except smtplib.SMTPAuthenticationError as e:
        print(f"SMTP Authentication Error: {e}")
    except smtplib.SMTPConnectError as e:
        print(f"SMTP Connect Error: {e}")
    except smtplib.SMTPServerDisconnected as e:
        print(f"SMTP Server Disconnected: {e}")
    except socket.gaierror as e: # Explicitly catch getaddrinfo error
        print(f"Socket getaddrinfo error: {e}")
    except socket.error as e: # Catch other socket errors
        print(f"Socket error: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
    finally:
        if 'server' in locals() and server:
            try:
                print("Attempting to quit server...")
                server.quit()
                print("Successfully quit server.")
            except Exception as e:
                print(f"Error quitting server: {e}")

if __name__ == "__main__":
    # Need to import socket for gaierror and socket.error
    import socket 
    test_smtp_connection()
