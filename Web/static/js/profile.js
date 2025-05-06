// This file will contain JavaScript for the profile page
// It will fetch user profile data and their posts and display them.

// This file will contain JavaScript for the profile page
// It will fetch user profile data and their posts and display them.

document.addEventListener('DOMContentLoaded', () => {
    const username = getUsernameFromUrl(); // Get username from URL
    const body = document.querySelector('body');
    const currentUserId = parseInt(body.getAttribute('data-current-user-id'));

    if (username) {
        // If username is in URL, fetch and display that user's profile
        fetchAndDisplayProfile(username);
    } else if (currentUserId) {
        // If no username in URL but current user is logged in, fetch and display current user's profile
        // We need the username for the fetchAndDisplayProfile function, so we might need a different approach
        // or fetch the username first using the currentUserId.
        // Let's modify fetchAndDisplayProfile to accept either username or user ID.
        // For now, let's fetch the current user's username first if only currentUserId is available.
        fetch(`/api/users/${currentUserId}`)
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.json();
            })
            .then(userData => {
                if (userData && userData.username) {
                    fetchAndDisplayProfile(userData.username);
                } else {
                    console.error('Could not fetch current user data or username.');
                    document.querySelector('.main-content').innerHTML = '<p>Error loading profile.</p>';
                }
            })
            .catch(error => {
                console.error('Error fetching current user data:', error);
                document.querySelector('.main-content').innerHTML = '<p>Error loading profile.</p>';
            });

    } else {
        // If no username in URL and no current user is logged in
        console.error('Username not found in URL and user is not logged in.');
        document.querySelector('.main-content').innerHTML = '<p>User not found or not logged in.</p>';
    }

    fetchAndDisplaySuggestedUsers(); // Fetch and display suggested users on load
});

function getUsernameFromUrl() {
    // Assuming the URL is like /profile?username=someuser
    const params = new URLSearchParams(window.location.search);
    return params.get('username');
}

async function fetchAndDisplayProfile(username) {
    const profileHeaderDiv = document.querySelector('.profile-header');
    const postListDiv = document.querySelector('.post-list');

    const profileApiUrl = `/api/users/${username}`;
    let userId = null; // User ID of the profile being viewed
    // Get current user ID from the data attribute on the body
    const body = document.querySelector('body');
    const currentUserId = parseInt(body.getAttribute('data-current-user-id'));

    try {
        // Fetch profile data
        const profileResponse = await fetch(profileApiUrl);

        if (!profileResponse.ok) {
            if (profileResponse.status === 404) {
                 profileHeaderDiv.innerHTML = '<p>User not found.</p>';
                 postListDiv.innerHTML = '';
                 return;
            }
            throw new Error(`HTTP error! status: ${profileResponse.status}`);
        }

        const profileData = await profileResponse.json();
        userId = profileData.user_id; // User ID of the profile being viewed

        // Check if the current user is following this profile
        let isFollowing = false;
        if (currentUserId) {
             const followingResponse = await fetch(`/api/users/${currentUserId}/following`);
             if (followingResponse.ok) {
                 const followingList = await followingResponse.json();
                 isFollowing = followingList.some(user => user.user_id === userId);
             } else {
                 console.error('Failed to fetch following list for current user');
     }
}

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
    const suggestionsContainer = document.querySelector('.sidebar-right .sidebar-right-section'); // Target the first section
    if (!suggestionsContainer) {
        console.error('Suggestions container not found.');
        return;
    }

    // Find the title element to preserve it
    const titleElement = suggestionsContainer.querySelector('.sidebar-right-title');

    // Clear existing suggestion items, but keep the title
    suggestionsContainer.querySelectorAll('.suggestion-item').forEach(item => item.remove());

    // Get current user ID (needed for API call and logic)
    const body = document.querySelector('body');
    const currentUserId = parseInt(body.getAttribute('data-current-user-id'));

    if (!currentUserId) {
        console.error('Current user ID not found for fetching suggestions.');
        // Optionally display a message in the suggestions area
        return;
    }

    try {
        const response = await fetch('/api/suggested_users'); // Assumes endpoint requires auth via cookie
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const suggestedUsers = await response.json();

        if (suggestedUsers.length === 0) {
            // Optionally display a "No suggestions" message
            const noSuggestions = document.createElement('p');
            noSuggestions.textContent = 'Önerilecek kullanıcı bulunamadı.';
            noSuggestions.style.padding = '10px'; // Add some padding
            suggestionsContainer.appendChild(noSuggestions);
            return;
        }

        suggestedUsers.forEach(user => {
            const suggestionItem = document.createElement('div');
            suggestionItem.classList.add('suggestion-item');

            const buttonText = user.is_following ? 'Takip Ediliyor' : 'Takip Et';
            const buttonClass = user.is_following ? 'suggestion-follow-button following' : 'suggestion-follow-button'; // Add 'following' class if needed for styling

            suggestionItem.innerHTML = `
                <img src="${user.profile_picture_url || 'https://randomuser.me/api/portraits/lego/1.jpg'}" alt="Avatar" class="suggestion-avatar">
                <div class="suggestion-username">${user.username}</div>
                <button class="${buttonClass}" data-user-id="${user.user_id}">${buttonText}</button>
            `;
            suggestionsContainer.appendChild(suggestionItem);
        });

        // Add event listeners after updating the DOM
        addSuggestionButtonListeners();

    } catch (error) {
        console.error('Error fetching or displaying suggested users:', error);
        // Optionally display an error message in the suggestions area
        const errorMsg = document.createElement('p');
        errorMsg.textContent = 'Öneriler yüklenirken hata oluştu.';
        errorMsg.style.padding = '10px';
        suggestionsContainer.appendChild(errorMsg);
    }
}

// Function to add listeners for suggestion follow buttons
function addSuggestionButtonListeners() {
    const body = document.querySelector('body');
    const currentUserId = parseInt(body.getAttribute('data-current-user-id'));

    document.querySelectorAll('.suggestion-follow-button').forEach(button => {
        button.addEventListener('click', async function() {
            const targetUserId = this.getAttribute('data-user-id');
            // Determine current state based on text or class
            const isCurrentlyFollowing = this.textContent.trim() === 'Takip Ediliyor' || this.classList.contains('following');

            if (!currentUserId) {
                alert('Takip etmek için giriş yapmalısınız.'); // Or redirect to login
                return;
            }
            if (!targetUserId) {
                 console.error('Target user ID not found on button.');
                 return;
            }

            const method = isCurrentlyFollowing ? 'DELETE' : 'POST';
            const url = '/api/follow';
            // Body is only needed for POST
            const bodyData = isCurrentlyFollowing ? null : JSON.stringify({ followed_user_id: parseInt(targetUserId) });
            // Query params are only needed for DELETE (based on current backend implementation)
            const queryParams = isCurrentlyFollowing ? `?followed_user_id=${targetUserId}` : ''; // Follower ID comes from auth cookie on backend

            console.log(`Attempting to ${method} follow for user ${targetUserId}`);
            console.log(`URL: ${url}${queryParams}`);
            console.log(`Body: ${bodyData}`);


            try {
                const response = await fetch(`${url}${queryParams}`, {
                    method: method,
                    headers: {
                        'Content-Type': 'application/json',
                        // Auth should be handled by cookies based on backend setup
                    },
                    body: bodyData // Pass null for DELETE, JSON string for POST
                });

                const result = await response.json();

                if (result.success) {
                    // Update button text and class
                    if (isCurrentlyFollowing) {
                        this.textContent = 'Takip Et';
                        this.classList.remove('following');
                        // Optionally disable the button briefly or add visual feedback
                    } else {
                        this.textContent = 'Takip Ediliyor';
                        this.classList.add('following');
                        // Optionally disable the button briefly or add visual feedback
                    }
                    // Note: We are not updating any follower counts here as they aren't displayed in suggestions
                } else {
                    alert('Takip durumu güncellenemedi: ' + result.message);
                }
            } catch (error) {
                console.error('Takip durumu güncellenirken hata:', error);
                alert('Takip durumu güncellenirken bir hata oluştu.');
            }
        });
    });
}


        // Update profile header
        profileHeaderDiv.innerHTML = `
            <img src="${profileData.profile_picture_url || 'https://randomuser.me/api/portraits/men/' + (userId % 100) + '.jpg'}" alt="Profile Avatar" class="profile-avatar-large">
            <div class="profile-info">
                <div class="profile-name">${profileData.full_name || ''}</div>
                <div class="profile-username">@${profileData.username}</div>
                <div class="profile-stats">
                    <div class="profile-stats-item">
                        <span class="profile-stats-number">${profileData.post_count || 0}</span> <span class="profile-stats-label">Gönderi</span>
                    </div>
                    <div class="profile-stats-item">
                        <span class="profile-stats-number" id="followers-count">${profileData.followers_count || 0}</span> <span class="profile-stats-label">Takipçi</span>
                    </div>
                    <div class="profile-stats-item">
                        <span class="profile-stats-number">${profileData.following_count || 0}</span> <span class="profile-stats-label">Takip</span>
                    </div>
                </div>
                <div class="profile-bio">
                    ${profileData.bio || ''}
                </div>
                ${currentUserId && currentUserId !== userId ?
                    `<button class="profile-follow-button" data-user-id="${userId}">${isFollowing ? 'Takip Ediliyor' : 'Takip Et'}</button>`
                    : ''}
                ${currentUserId && currentUserId === userId ?
                    `<button class="profile-edit-button">Profili Düzenle</button>`
                    : ''}
            </div>
        `;

        // Add event listener to the dynamically created edit button (if it exists)
        const editButton = profileHeaderDiv.querySelector('.profile-edit-button');
        if (editButton) {
            editButton.addEventListener('click', function() {
                alert('Profil düzenleme sayfasına yönlendiriliyor!'); // TODO: Implement actual navigation
            });
        }


        // Add event listener to the dynamically created follow button (if it exists)
        const followButton = profileHeaderDiv.querySelector('.profile-follow-button');
        if (followButton) {
            followButton.addEventListener('click', async function() {
                const targetUserId = this.getAttribute('data-user-id');
                const isCurrentlyFollowing = this.textContent.trim() === 'Takip Ediliyor';

                if (!currentUserId) {
                    alert('You must be logged in to follow users.'); // Or redirect to login
                    return;
                }

                const method = isCurrentlyFollowing ? 'DELETE' : 'POST';
                const url = '/api/follow';
                const body = isCurrentlyFollowing ? null : JSON.stringify({ followed_user_id: parseInt(targetUserId) });
                const queryParams = isCurrentlyFollowing ? `?follower_user_id=${currentUserId}&followed_user_id=${targetUserId}` : '';

                try {
                    const response = await fetch(`${url}${queryParams}`, {
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
                        // Update button text and class
                        if (isCurrentlyFollowing) {
                            this.textContent = 'Takip Et';
                            this.classList.remove('following'); // Add a class for styling "Takip Ediliyor"
                        } else {
                            this.textContent = 'Takip Ediliyor';
                            this.classList.add('following'); // Add a class for styling "Takip Ediliyor"
                        }
                        // Update followers count
                        const followersCountSpan = document.getElementById('followers-count');
                        if (followersCountSpan) {
                            let currentCount = parseInt(followersCountSpan.textContent) || 0;
                            followersCountSpan.textContent = isCurrentlyFollowing ? currentCount - 1 : currentCount + 1;
                        }

                    } else {
                        alert('Failed to update follow status: ' + result.message);
                    }
                } catch (error) {
                    console.error('Error updating follow status:', error);
                    alert('An error occurred while updating follow status.');
                }
            });
        }


        // Fetch and display user posts if userId is available
        if (userId) {
            fetchAndDisplayUserPosts(userId, postListDiv);
        }

    } catch (error) {
        console.error('Error fetching and displaying profile:', error);
        profileHeaderDiv.innerHTML = `<p>Error loading profile: ${error.message}</p>`;
        postListDiv.innerHTML = ''; // Clear any static posts
    }
}

async function fetchAndDisplayUserPosts(userId, postListDiv) {
     const postsApiUrl = `/api/users/${userId}/posts`;

     try {
         const postsResponse = await fetch(postsApiUrl);

         if (!postsResponse.ok) {
             // Log the specific HTTP status and message
             console.error(`HTTP error fetching posts for user ${userId}: status ${postsResponse.status}`);
             throw new Error(`HTTP error! status: ${postsResponse.status}`);
         }

         const posts = await postsResponse.json();

         // Clear existing static posts, but keep the profile header
         // Assuming postListDiv is the container for posts below the header
         postListDiv.querySelectorAll('.post').forEach(post => post.remove());


         if (posts.length === 0) {
             postListDiv.innerHTML += '<p>No posts available.</p>'; // Add below header
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
             postListDiv.appendChild(postElement);

             // Add event listeners for like, comment, and save
             addPostActionListeners(postElement, post.post_id, post.is_liked_by_current_user, post.is_saved_by_current_user);
         });

     } catch (error) {
         console.error('Error fetching and displaying user posts:', error);
         postListDiv.innerHTML += `<p>Error loading posts: ${error.message}</p>`; // Add error below header
     }
}
