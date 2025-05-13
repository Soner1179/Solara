import socket

def check_hostname_resolution(hostname):
    try:
        ip_address = socket.gethostbyname(hostname)
        print(f"Successfully resolved '{hostname}' to IP address: {ip_address}")
        return True
    except socket.gaierror as e:
        print(f"Failed to resolve '{hostname}'. Error: {e}")
        return False
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return False

if __name__ == "__main__":
    target_hostname = "smtp.office365.com"
    print(f"Attempting to resolve hostname: {target_hostname}")
    check_hostname_resolution(target_hostname)

    # Test with another common hostname
    print(f"\nAttempting to resolve hostname: google.com")
    check_hostname_resolution("google.com")
