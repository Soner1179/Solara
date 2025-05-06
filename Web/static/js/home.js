// This file will contain JavaScript for the home page
// It will fetch posts from the backend and display them, and also fetch and display suggested users.

// This file will contain JavaScript for the home page
// It will fetch posts from the backend and display them, and also fetch and display suggested users.

// This file will contain JavaScript for the home page
// It will fetch posts from the backend and display them, and also fetch and display suggested users.

document.addEventListener('DOMContentLoaded', () => {
    fetchAndDisplayPosts();
    fetchAndDisplaySuggestedUsers(); // Fetch and display suggested users
});

// Removed client-side cookie check for fetching posts to rely on backend authentication


async function fetchAndDisplayPosts() {
    const feedDiv = document.querySelector('.feed');
    // Removed client-side user ID check here to rely on backend authentication

    const apiUrl = `/api/posts`; // Use relative path, backend will handle user ID from session/token

    try {
        // TODO: Implement authentication (e.g., send token in headers)
        const response = await fetch(apiUrl, {
            headers: {
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
            }
        });

        if (response.status === 401) {
            // Handle unauthorized access - display message or redirect
            console.warn('User not logged in. Authentication required for personalized feed.');
            feedDiv.innerHTML = '<p>Please log in to see your personalized feed.</p>';
            // Optionally redirect to login page after a delay
            // setTimeout(() => { window.location.href = '/login'; }, 2000);
            return;
        }


        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const posts = await response.json();

        feedDiv.innerHTML = ''; // Clear existing static posts

        if (posts.length === 0) {
            feedDiv.innerHTML = '<p>No posts available from users you follow.</p>';
            return;
        }

        posts.forEach(post => {
            const postElement = document.createElement('div');
            postElement.classList.add('post');

            const postHeader = `
                <div class="post-header">
                    <img src="${post.profile_picture_url || 'https://randomuser.me/api/portraits/men/' + (post.user_id % 100) + '.jpg'}" alt="Avatar" class="post-avatar">
                    <div class="post-author-info">
                        <div class="post-author">${post.username} <span style="color:#888; font-weight: normal;">@${post.username}</span></div>
                        <div class="post-time">${new Date(post.created_at).toLocaleString()}</div> <!-- Format date -->
                    </div>
                    <div class="post-options">
                        <i class="fas fa-ellipsis-h"></i>
                    </div>
                </div>
            `;

            const postContent = `
                <div class="post-content">
                    ${post.content_text || ''}
                    ${post.image_url ? `<img src="${post.image_url}" alt="Post Image" style="max-width: 100%; height: auto; margin-top: 10px;">` : ''}
                </div>
            `;

            const postActions = `
                <div class="post-actions">
                    <div class="post-actions-item"><i class="far fa-heart"></i> ${post.likes_count || 0}</div>
                    <div class="post-actions-item"><i class="far fa-comment"></i> ${post.comments_count || 0}</div>
                    <div class="post-actions-item"><i class="far fa-eye"></i> ${post.views_count || 0}</div>
                    <div class="post-actions-item"><i class="far fa-bookmark"></i></div>
                </div>
            `;

            postElement.innerHTML = postHeader + postContent + postActions;
            feedDiv.appendChild(postElement);

            // Add event listeners for like, comment, and save
            addPostActionListeners(postElement, post.post_id, post.is_liked_by_current_user, post.is_saved_by_current_user);
        });

    } catch (error) {
        console.error('Error fetching and displaying posts:', error);
        feedDiv.innerHTML = '<p>Error loading posts.</p>';
    }
}

// Function to add event listeners to post action icons
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
        const url = `/api/posts/${postId}/likes${isLiked ? `?user_id=${currentUserId}` : ''}`; // Add user_id for DELETE in query params

        try {
            const response = await fetch(url, {
                method: method,
                headers: {
                    'Content-Type': 'application/json',
                    // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
                },
                body: method === 'POST' ? JSON.stringify({ user_id: parseInt(currentUserId) }) : null, // Send user_id in body for POST
            });

            const result = await response.json();

            if (result.success) {
                // Toggle icon and update count
                if (isLiked) {
                    likeIcon.classList.remove('fas');
                    likeIcon.classList.add('far');
                    likeIcon.style.color = ''; // Reset color
                } else {
                    likeIcon.classList.remove('far');
                    likeIcon.classList.add('fas');
                    likeIcon.style.color = 'red'; // Set liked color
                }
                // Update the like count from the backend response
                likeCountSpan.textContent = result.likes_count;
            } else {
                alert('Operation failed: ' + result.message);
            }
        } catch (error) {
            console.error('Error performing like/unlike action:', error);
            // Removed generic alert, backend response should provide specific message
            // alert('An error occurred.');
        }
    });

    // Comment functionality - Open Comment Modal
    commentIcon.parentElement.addEventListener('click', () => {
        openCommentModal(postId);
    });

    // Save/Unsave functionality
    saveIcon.parentElement.addEventListener('click', async () => {
        const currentUserId = localStorage.getItem('currentUserId'); // Assuming user ID is stored here for now
        if (!currentUserId) {
            alert('You must be logged in to save posts.'); // Or redirect to login
            return;
        }

        const isSaved = saveIcon.classList.contains('fas');
        const method = isSaved ? 'DELETE' : 'POST';
        const url = `/api/posts/${postId}/saved${isSaved ? `?user_id=${currentUserId}` : ''}`; // Add user_id for DELETE in query params

        try {
            const response = await fetch(url, {
                method: method,
                headers: {
                    'Content-Type': 'application/json',
                    // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
                },
                 body: method === 'POST' ? JSON.stringify({ user_id: parseInt(currentUserId) }) : null, // Send user_id in body for POST
            });

            const result = await response.json();

            if (result.success) {
                // Toggle icon
                if (isSaved) {
                    saveIcon.classList.remove('fas');
                    saveIcon.classList.add('far');
                    saveIcon.style.color = ''; // Reset color
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

async function fetchAndDisplaySuggestedUsers() {
    const suggestedUsersListDiv = document.getElementById('suggested-users-list');
    // Removed client-side user ID check here to rely on backend authentication

    const apiUrl = `/api/suggested_users`; // Use relative path, backend will handle user ID from session/token

    try {
        const response = await fetch(apiUrl, {
             headers: {
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
            }
        });

        if (response.status === 401) {
            // Handle unauthorized access - display message
            console.warn('User not logged in. Authentication required for suggested users.');
            suggestedUsersListDiv.innerHTML = '<p>Log in to see suggestions.</p>';
            return;
        }

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const suggestedUsers = await response.json();

        suggestedUsersListDiv.innerHTML = ''; // Clear existing content

        if (suggestedUsers.length === 0) {
            suggestedUsersListDiv.innerHTML = '<p>No suggestions at this time.</p>';
            return;
        }

        suggestedUsers.forEach(user => {
            const suggestionItem = document.createElement('div');
            suggestionItem.classList.add('suggestion-item');

            // Determine initial button text and class based on follow status
            const isFollowing = user.is_following; // Get follow status from backend response
            const buttonText = isFollowing ? 'Takipten Çık' : 'Takip Et';
            const buttonClass = isFollowing ? 'suggestion-follow-button following' : 'suggestion-follow-button';

            suggestionItem.innerHTML = `
                <img src="${user.profile_picture_url || 'https://randomuser.me/api/portraits/men/' + (user.user_id % 100) + '.jpg'}" alt="Avatar" class="suggestion-avatar">
                <div class="suggestion-username">${user.username}</div>
                <button class="${buttonClass}" data-user-id="${user.user_id}" data-is-following="${isFollowing}">${buttonText}</button>
            `;
            suggestedUsersListDiv.appendChild(suggestionItem);

            // Add event listener to the follow/unfollow button
            const followButton = suggestionItem.querySelector('.suggestion-follow-button');
            followButton.addEventListener('click', async function() {
                const targetUserId = this.getAttribute('data-user-id');
                let currentIsFollowing = this.getAttribute('data-is-following') === 'true'; // Get current status

                const currentUserId = localStorage.getItem('currentUserId');

                 if (!currentUserId) {
                    alert('You must be logged in to follow or unfollow users.'); // Or redirect to login
                    return;
                }

                const method = currentIsFollowing ? 'DELETE' : 'POST';
                const url = currentIsFollowing ? `/api/follow?follower_user_id=${currentUserId}&followed_user_id=${targetUserId}` : '/api/follow';
                const body = currentIsFollowing ? null : JSON.stringify({ follower_user_id: parseInt(currentUserId), followed_user_id: parseInt(targetUserId) });


                try {
                    const response = await fetch(url, {
                        method: method,
                        headers: {
                            'Content-Type': 'application/json',
                            // Include authorization header if using tokens
                            // 'Authorization': `Bearer ${yourAuthToken}`
                        },
                        body: body
                    });

                    const result = await response.json();

                    if (result.success) {
                        // Toggle the button state
                        currentIsFollowing = !currentIsFollowing;
                        this.setAttribute('data-is-following', currentIsFollowing);
                        this.textContent = currentIsFollowing ? 'Takipten Çık' : 'Takip Et';
                        this.classList.toggle('following', currentIsFollowing); // Add/remove 'following' class
                        alert(result.message); // Show success message
                        // Optionally refresh the list or remove the item if unfollowed
                        // fetchAndDisplaySuggestedUsers(); // Refresh the list
                    } else {
                        alert('Operation failed: ' + result.message);
                    }
                } catch (error) {
                    console.error('Error performing follow/unfollow action:', error);
                    alert('An error occurred.');
                }
            });
        });

    } catch (error) {
        console.error('Error fetching and displaying suggested users:', error);
        suggestedUsersListDiv.innerHTML = '<p>Error loading suggestions.</p>';
    }
}

// Removed the getCurrentUserIdFromCookie function as user ID is now from localStorage

// --- Comment Modal Functionality ---
let currentCommentPostId = null; // To keep track of which post is being commented on

function openCommentModal(postId) {
    currentCommentPostId = postId;
    const modal = document.getElementById('commentModal');
    if (modal) {
        modal.style.display = 'block';
        // Optional: Fetch existing comments for this post and display them in the modal
        // fetchAndDisplayComments(postId); // Needs implementation
    }
}

function closeCommentModal() {
    const modal = document.getElementById('commentModal');
    const commentInput = document.getElementById('commentInput');
    if (modal) {
        modal.style.display = 'none';
        if (commentInput) {
            commentInput.value = ''; // Clear input field
        }
    }
    currentCommentPostId = null; // Reset post ID
}

async function submitComment() {
    const commentInput = document.getElementById('commentInput');
    const commentText = commentInput ? commentInput.value.trim() : '';
    const currentUserId = localStorage.getItem('currentUserId'); // Assuming user ID is stored here

    if (!currentUserId) {
        alert('You must be logged in to comment.'); // Or redirect to login
        return;
    }

    if (!commentText) {
        alert('Comment cannot be empty.');
        return;
    }

    if (currentCommentPostId === null) {
        console.error('No post ID associated with the comment modal.');
        alert('An error occurred. Please try again.');
        return;
    }

    const apiUrl = '/api/comments';

    try {
        const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
            },
            body: JSON.stringify({
                user_id: parseInt(currentUserId), // Backend expects user_id in body for this endpoint
                post_id: currentCommentPostId,
                comment_text: commentText
            }),
        });

        const result = await response.json();

        if (result.success) {
            alert('Comment added successfully!');
            closeCommentModal();
            // Optional: Update comment count on the post element without refreshing
            // Or refetch and display comments for the specific post
            // For now, user might need to refresh to see the new comment count/comment
        } else {
            alert('Failed to add comment: ' + result.message);
        }
    } catch (error) {
        console.error('Error submitting comment:', error);
        alert('An error occurred while submitting your comment.');
    }
}

// Close the modal if the user clicks outside of it
window.onclick = function(event) {
    const modal = document.getElementById('commentModal');
    if (event.target === modal) {
        closeCommentModal();
    }
}
