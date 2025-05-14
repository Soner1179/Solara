// This file will contain JavaScript for the login page
// It will handle form submission and send login data to the backend.

document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('login-form');
    const usernameOrEmailInput = document.getElementById('username_or_email');
    const passwordInput = document.getElementById('password');
    const errorMessageDiv = document.getElementById('error-message');
    const submitButton = document.getElementById('submit-button');

    loginForm.addEventListener('submit', async function(event) {
        event.preventDefault(); // Prevent default form submission
        errorMessageDiv.textContent = ''; // Clear previous errors
        submitButton.disabled = true; // Disable button during submission
        submitButton.textContent = 'Logging in...'; // Change button text

        const usernameOrEmail = usernameOrEmailInput.value.trim();
        const password = passwordInput.value;

        // Basic client-side validation
        if (!usernameOrEmail || !password) {
            errorMessageDiv.textContent = 'Please fill in all fields.';
            submitButton.disabled = false;
            submitButton.textContent = 'Giriş Yap';
            return;
        }

        // Data to send to the API
        const data = {
            username_or_email: usernameOrEmail,
            password: password
        };

        try {
            // Send POST request to the login endpoint
            const response = await fetch('/api/login', { // Use relative path
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data), // Convert data to JSON string
            });

            const result = await response.json(); // Read the response as JSON

            if (response.ok && result.success) { // Check for success based on HTTP status and response body
                console.log('Login successful:', result);
                // Store the user ID in localStorage for client-side access
                if (result.user && result.user.user_id) {
                    localStorage.setItem('currentUserId', result.user.user_id);
                    console.log('User ID stored in localStorage:', result.user.user_id);
                    console.log('localStorage currentUserId after set:', localStorage.getItem('currentUserId')); // Added log
                } else {
                    console.warn('Login successful, but user ID not found in response.');
                    // Handle this case - maybe show an error or redirect to a generic page
                }

                // Store the authentication token in localStorage
                if (result.token) {
                    localStorage.setItem('token', result.token); // Use 'token' key and store the token
                    console.log('Auth token stored in localStorage.');
                    console.log('localStorage token after set:', localStorage.getItem('token')); // Added log
                } else {
                     console.warn('Login successful, but auth token not found in response.');
                     // Handle this case - maybe show an error or prevent redirect
                }


                console.log('Login API response status:', response.status); // Added log
                console.log('Login API response result:', result); // Added log
                window.location.href = '/home'; // Redirect to home page
            } else {
                // Display error message from the server response
                const serverMessage = result && result.message ? result.message : 'Bilinmeyen sunucu hatası.';
                const statusText = response.statusText || 'Durum metni yok.';
                errorMessageDiv.textContent = `${serverMessage} (HTTP ${response.status} ${statusText})`;
                console.error('Login failed. Server response:', result);
                console.error('Login failed. HTTP status:', response.status);
                console.error('Login failed. Response ok:', response.ok);
                console.error('Login failed. Result success:', result ? result.success : 'result undefined');
            }

        } catch (error) {
            // Handle network errors or server unreachable
            console.error('Login error (catch block):', error);
            console.error('Error name:', error.name);
            console.error('Error message:', error.message);
            console.error('Error stack:', error.stack);
            errorMessageDiv.textContent = 'Sunucuya bağlanırken bir hata oluştu. Lütfen tekrar deneyin.';
        } finally {
            // Re-enable the button after the process is complete
            submitButton.disabled = false;
            submitButton.textContent = 'Giriş Yap';
        }
    });

    // Google login button functionality (placeholder)
    document.querySelector('.google-button').addEventListener('click', function() {
        alert('Google login is not yet implemented!');
    });
});
