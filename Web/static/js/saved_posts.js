// JavaScript for the Saved Posts page
// This file will handle fetching and displaying saved posts.

document.addEventListener('DOMContentLoaded', () => {
    console.log("Saved Posts JS loaded");
    const currentUserId = localStorage.getItem('currentUserId'); // Get user ID from localStorage
    if (currentUserId) {
        fetchSavedPosts(currentUserId); // Pass currentUserId to the function
    } else {
        console.error('User ID not found in localStorage. Cannot fetch saved posts.');
        // Optionally redirect to login or show a message
        const grid = document.getElementById('saved-posts-grid');
        if (grid) {
            grid.innerHTML = '<p>Please log in to see saved posts.</p>';
        }
    }
});

// Function to add event listeners to post action icons (Copied from home.js)
function addPostActionListeners(postElement, postId, isLikedInitially, isSavedInitially) {
    const likeIcon = postElement.querySelector('.post-actions-item .fa-heart');
    const commentIcon = postElement.querySelector('.post-actions-item .fa-comment');
    const saveIcon = postElement.querySelector('.post-actions-item .fa-bookmark');
    const likeCountSpan = likeIcon.parentElement.querySelector('span'); // Assuming count is next to icon

    // Set initial icon state
    if (isLikedInitially) {
        likeIcon.classList.remove('far');
        likeIcon.classList.add('fas');
        likeIcon.style.color = 'red'; // Or your preferred liked color
    }
    if (isSavedInitially) {
        saveIcon.classList.remove('far');
        saveIcon.classList.add('fas');
        saveIcon.style.color = 'blue'; // Or your preferred saved color
    }

    // Like/Unlike functionality
    likeIcon.parentElement.addEventListener('click', async () => {
        const currentUserId = localStorage.getItem('currentUserId');
        if (!currentUserId) {
            alert('You must be logged in to like posts.');
            return;
        }

        const isLiked = likeIcon.classList.contains('fas');
        const method = isLiked ? 'DELETE' : 'POST';
        const url = `/api/posts/${postId}/likes`; // Backend uses cookie for user_id

        try {
            const response = await fetch(url, {
                method: method,
                headers: {
                    'Content-Type': 'application/json',
                    // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
                },
                body: method === 'POST' ? JSON.stringify({}) : null, // Backend uses cookie for user_id
            });

            const result = await response.json();

            if (result.success) {
                // Toggle icon and update count
                if (isLiked) {
                    likeIcon.classList.remove('fas');
                    likeIcon.classList.add('far');
                    likeIcon.style.color = ''; // Reset color
                    likeCountSpan.textContent = parseInt(likeCountSpan.textContent) - 1;
                } else {
                    likeIcon.classList.remove('far');
                    likeIcon.classList.add('fas');
                    likeIcon.style.color = 'red'; // Set liked color
                    likeCountSpan.textContent = parseInt(likeCountSpan.textContent) + 1;
                }
            } else {
                alert('Operation failed: ' + result.message);
            }
        } catch (error) {
            console.error('Error performing like/unlike action:', error);
            alert('An error occurred.');
        }
    });

    // Comment functionality (basic - will likely open a modal or redirect)
    commentIcon.parentElement.addEventListener('click', () => {
        // TODO: Implement comment modal or redirect to single post page
        alert('Comment functionality not fully implemented yet.');
        // Example: window.location.href = `/post/${postId}`; // Redirect to single post page
    });

    // Save/Unsave functionality
    saveIcon.parentElement.addEventListener('click', async () => {
        const currentUserId = localStorage.getItem('currentUserId');
        if (!currentUserId) {
            alert('You must be logged in to save posts.');
            return;
        }

        const isSaved = saveIcon.classList.contains('fas');
        const method = isSaved ? 'DELETE' : 'POST';
        const url = `/api/posts/${postId}/saved`; // Backend uses cookie for user_id

        try {
            const response = await fetch(url, {
                method: method,
                headers: {
                    'Content-Type': 'application/json',
                    // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
                },
                 body: method === 'POST' ? JSON.stringify({}) : null, // Backend uses cookie for user_id
            });

            const result = await response.json();

            if (result.success) {
                // Toggle icon
                if (isSaved) {
                    saveIcon.classList.remove('fas');
                    saveIcon.classList.add('far');
                    saveIcon.style.color = ''; // Reset color
                    // Optionally remove the post element from the DOM if unsaved on this page
                    const postElementToRemove = saveIcon.closest('.post');
                    if (postElementToRemove) {
                        postElementToRemove.remove();
                        // If the grid becomes empty, display a message
                        const grid = document.getElementById('saved-posts-grid');
                        if (grid && grid.children.length === 0) {
                             grid.innerHTML = '<p>No posts saved yet.</p>';
                        }
                    }
                } else {
                    saveIcon.classList.remove('far');
                    saveIcon.classList.add('fas');
                    saveIcon.style.color = 'blue'; // Set saved color
                }
            } else {
                alert('Operation failed: ' + result.message);
            }
        } catch (error) {
            console.error('Error performing save/unsave action:', error);
            alert('An error occurred.');
        }
    });
}


async function fetchSavedPosts(userId) { // Accept userId as a parameter
    const grid = document.getElementById('saved-posts-grid');
    if (!grid) {
        console.error('Saved posts grid element not found.');
        return;
    }
    grid.innerHTML = '<p>Loading saved posts...</p>'; // Loading indicator

    const apiUrl = `/api/users/${userId}/saved-posts`; // Construct URL with userId

    try {
        const response = await fetch(apiUrl, {
            // Add authentication headers if needed
            // headers: { 'Authorization': `Bearer YOUR_TOKEN` }
        });

        if (!response.ok) {
            if (response.status === 401 || response.status === 403) {
                grid.innerHTML = '<p>Please log in to see saved posts.</p>';
            } else {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return;
        }

        const posts = await response.json();

        grid.innerHTML = ''; // Clear loading/placeholder

        if (posts && posts.length > 0) {
            // Use the same post structure as home.js and profile.js
            posts.forEach(post => {
                const postElement = document.createElement('div');
                postElement.classList.add('post', 'contest-entry'); // Use the same class for styling, added 'contest-entry'

                const postHeader = `
                    <div class="post-header">
                        <img src="${post.post_author_avatar || 'https://randomuser.me/api/portraits/men/' + (post.user_id % 100) + '.jpg'}" alt="Avatar" class="post-avatar">
                        <div class="post-author-info">
                            <div class="post-author">${post.post_author_username} <span style="color:#888; font-weight: normal;">@${post.post_author_username}</span></div>
                            <div class="post-time">${new Date(post.created_at).toLocaleString()}</div> <!-- Post creation date -->
                        </div>
                        {# Removed post-options div #}
                    </div>
                `;

                let postImageHTML = '';
                if (post.image_url) {
                    postImageHTML = `
                    <div class="post-image-container">
                        <img src="${post.image_url}" alt="Post Image">
                    </div>`;
                }

                const postContentText = `
                    <div class="post-content">
                        ${post.content_text || ''}
                    </div>
                `;

                // Removed postActions for saved posts page
                postElement.innerHTML = postHeader + postContentText + postImageHTML; // Header, content text, then image container
                grid.appendChild(postElement);

                // Removed call to addPostActionListeners as it's for the old action items.
                // Voting functionality for saved posts would need a new implementation if required.
            });
        } else {
            grid.innerHTML = '<p>No posts saved yet.</p>';
        }

    } catch (error) {
        console.error('Error fetching saved posts:', error);
        grid.innerHTML = '<p>Could not load saved posts. Please try again later.</p>';
    }
}

// Call the function
// fetchSavedPosts(); // Called in DOMContentLoaded
