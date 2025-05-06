// This file will contain JavaScript for the discover page
// It will fetch and display users.

document.addEventListener('DOMContentLoaded', () => {
    console.log("Discover JS loaded"); // Get user ID from localStorage
    const currentUserId = localStorage.getItem('currentUserId'); // Get user ID from localStorage
    if (currentUserId) {
        fetchAndDisplayUsers(currentUserId);
    } else {
        console.error('User ID not found in localStorage. Cannot fetch users for Discover.');
        // Optionally redirect to login or show a message
        const userListDiv = document.getElementById('user-list');
        if (userListDiv) {
            userListDiv.innerHTML = '<p>Please log in to see suggested users.</p>';
        }
    }
});

async function fetchAndDisplayUsers(currentUserId) {
    const userListDiv = document.getElementById('user-list');
    const apiUrl = `/api/users?exclude_user_id=${currentUserId}`;

    try {
        // TODO: Implement authentication
        const response = await fetch(apiUrl, {
            headers: {
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const users = await response.json();

        userListDiv.innerHTML = ''; // Clear existing content

        if (users.length === 0) {
            userListDiv.innerHTML = '<p>No users found.</p>';
            return;
        }

        users.forEach(user => {
            const userElement = document.createElement('div');
            userElement.classList.add('user-item'); // You might want to add specific styling for discover user items

            userElement.innerHTML = `
                <img src="${user.profile_picture_url || 'https://randomuser.me/api/portraits/men/' + (user.user_id % 100) + '.jpg'}" alt="Avatar" style="width: 50px; height: 50px; border-radius: 50%; margin-right: 10px;">
                <div>
                    <div style="font-weight: bold;">${user.username}</div>
                    <div style="color: #888;">${user.full_name || ''}</div>
                </div>
                <button class="follow-button" data-user-id="${user.user_id}">Follow</button>
            `; // Basic structure, style as needed

            // TODO: Add event listener for follow button

            userListDiv.appendChild(userElement);
        });

    } catch (error) {
        console.error('Error fetching and displaying users:', error);
        userListDiv.innerHTML = '<p>Error loading users.</p>';
    }
}
