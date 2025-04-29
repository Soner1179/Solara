// This file will contain JavaScript for the signup page
// It will handle form submission and send registration data to the backend.

document.addEventListener('DOMContentLoaded', () => {
    const signupForm = document.getElementById('signup-form');
    const usernameInput = document.getElementById('username');
    const emailInput = document.getElementById('email');
    const passwordInput = document.getElementById('password');
    const confirmPasswordInput = document.getElementById('confirmPassword');
    const errorMessageDiv = document.getElementById('error-message');
    const submitButton = document.getElementById('submit-button');

    signupForm.addEventListener('submit', async function(event) {
        event.preventDefault(); // Prevent default form submission
        errorMessageDiv.textContent = ''; // Clear previous errors
        submitButton.disabled = true; // Disable button during submission
        submitButton.textContent = 'Signing up...'; // Change button text

        const username = usernameInput.value.trim();
        const email = emailInput.value.trim();
        const password = passwordInput.value;
        const confirmPassword = confirmPasswordInput.value;

        // Basic client-side validation
        if (!username || !email || !password || !confirmPassword) {
            errorMessageDiv.textContent = 'Please fill in all fields.';
            submitButton.disabled = false;
            submitButton.textContent = 'Kayıt ol';
            return;
        }

        if (password !== confirmPassword) {
            errorMessageDiv.textContent = 'Passwords do not match.';
            submitButton.disabled = false;
            submitButton.textContent = 'Kayıt ol';
            return;
        }

        // Data to send to the API
        const data = {
            username: username,
            email: email,
            password: password
        };

        try {
            // Send POST request to the signup endpoint
            const response = await fetch('/api/signup', { // Use relative path
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data), // Convert data to JSON string
            });

            const result = await response.json(); // Read the response as JSON

            if (response.ok && result.success) { // Check for success based on HTTP status and response body
                console.log('Signup successful:', result);
                alert('Signup successful! You can now log in.');
                window.location.href = '/login'; // Redirect to login page
            } else {
                // Display error message from the server response
                errorMessageDiv.textContent = result.message || `Signup failed: ${response.status}`;
            }

        } catch (error) {
            // Handle network errors or server unreachable
            console.error('Signup error:', error);
            errorMessageDiv.textContent = 'An error occurred while connecting to the server. Please try again.';
        } finally {
            // Re-enable the button after the process is complete
            submitButton.disabled = false;
            submitButton.textContent = 'Kayıt ol';
        }
    });

    // Google signup button functionality (placeholder)
    document.querySelector('.google-button').addEventListener('click', function() {
        alert('Google signup is not yet implemented!');
    });
});
