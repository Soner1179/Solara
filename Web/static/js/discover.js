// This file will contain JavaScript for the discover page
// It will fetch and display users based on search input or show all users.

document.addEventListener('DOMContentLoaded', () => {
    console.log("Discover JS loaded");
    const currentUserId = localStorage.getItem('currentUserId');

    if (!currentUserId) {
        console.error('User ID not found in localStorage. Cannot search users for Discover.');
        const searchResultsDiv = document.getElementById('search-results');
        if (searchResultsDiv) {
            searchResultsDiv.innerHTML = '<p>Please log in to search for users.</p>';
        }
        return;
    }

    const searchInput = document.getElementById('user-search-input');
    const userListDiv = document.getElementById('user-list');
    const searchResultsDiv = document.getElementById('search-results');

    // Hide the initial user list div on load
    userListDiv.style.display = 'none';

    let debounceTimer;
    searchInput.addEventListener('input', (event) => {
        clearTimeout(debounceTimer);
        const searchTerm = event.target.value.trim();

        debounceTimer = setTimeout(() => {
            if (searchTerm.length > 0) {
                searchResultsDiv.style.display = 'block';
                searchUsers(currentUserId, searchTerm);
            } else {
                searchResultsDiv.style.display = 'none';
                searchResultsDiv.innerHTML = ''; // Clear search results when search is cleared
            }
        }, 300); // Debounce for 300ms
    });
});

async function fetchAndDisplayUsers(currentUserId) {
    // This function is no longer used for initial load, but kept in case it's needed elsewhere or for future features.
    console.log("fetchAndDisplayUsers called, but not used for initial load.");
    const userListDiv = document.getElementById('user-list');
    const apiUrl = `/api/users?exclude_user_id=${currentUserId}`;

    try {
        const authToken = localStorage.getItem('authToken');
        const headers = {
            'Content-Type': 'application/json',
        };
        if (authToken) {
            headers['Authorization'] = `Bearer ${authToken}`;
        }

        const response = await fetch(apiUrl, {
            headers: headers
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

        displayUsers(users, userListDiv);

    } catch (error) {
        console.error('Error fetching and displaying users:', error);
        userListDiv.innerHTML = '<p>Error loading users.</p>';
    }
}

async function searchUsers(currentUserId, searchTerm) {
    const searchResultsDiv = document.getElementById('search-results');
    // Corrected the API endpoint URL
    const apiUrl = `/api/users/search?query=${encodeURIComponent(searchTerm)}&exclude_user_id=${currentUserId}`;

    try {
        const authToken = localStorage.getItem('authToken');
        const headers = {
            'Content-Type': 'application/json',
        };
        if (authToken) {
            headers['Authorization'] = `Bearer ${authToken}`;
        }

        const response = await fetch(apiUrl, {
            headers: headers
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const users = await response.json();

        searchResultsDiv.innerHTML = ''; // Clear existing content

        if (users.length === 0) {
            searchResultsDiv.innerHTML = '<p>No users found.</p>';
            return;
        }

        displayUsers(users, searchResultsDiv);

    } catch (error) {
        console.error('Error searching users:', error);
        searchResultsDiv.innerHTML = '<p>Error searching users.</p>';
    }
}

function displayUsers(users, containerElement) {
    containerElement.innerHTML = ''; // Clear existing content before displaying new results
    users.forEach(user => {
        const userElement = document.createElement('div');
        userElement.classList.add('user-item');

        // Determine follow button text and class
        const isFollowing = user.is_following; // Assuming backend provides this
        const buttonText = isFollowing ? 'Takipten Çık' : 'Takip Et';
        const buttonClass = isFollowing ? 'unfollow-button' : 'follow-button';

        userElement.innerHTML = `
            <img src="${user.profile_picture_url || 'https://randomuser.me/api/portraits/men/' + (user.user_id % 100) + '.jpg'}" alt="Avatar">
            <div>
                <div>${user.username}</div>
                <div>${user.full_name || ''}</div>
            </div>
            <button class="${buttonClass}" data-user-id="${user.user_id}">${buttonText}</button>
        `;

        // TODO: Add event listener for follow/unfollow button

        containerElement.appendChild(userElement);
    });
}
