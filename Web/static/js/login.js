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
                // TODO: Store the authentication token securely (e.g., in localStorage or cookies)
                // localStorage.setItem('authToken', result.token); // Assuming token is returned

                alert('Login successful! Redirecting to home page.');
                window.location.href = '/home'; // Redirect to home page
            } else {
                // Display error message from the server response
                errorMessageDiv.textContent = result.message || `Login failed: ${response.status}`;
            }

        } catch (error) {
            // Handle network errors or server unreachable
            console.error('Login error:', error);
            errorMessageDiv.textContent = 'An error occurred while connecting to the server. Please try again.';
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
