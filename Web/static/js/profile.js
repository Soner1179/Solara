// Helper function to get authentication headers
function getAuthHeaders() {
    const token = localStorage.getItem('token');
    const headers = {
        'Content-Type': 'application/json', // Default content type
    };
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    } else {
        console.warn('Authentication token not found in localStorage.');
        // Maybe redirect to login if token is strictly required for profile view?
        // window.location.href = '/login';
    }
    return headers;
}

// Helper function to update suggestion button state if profile follow state changes
function updateSuggestionButtonState(targetUserId, isNowFollowing) {
    const suggestionButton = document.querySelector(`.suggestion-follow-button[data-user-id="${targetUserId}"]`);
    if (suggestionButton) {
        if (isNowFollowing) {
            suggestionButton.textContent = 'Takip Ediliyor';
            suggestionButton.classList.add('following');
        } else {
            suggestionButton.textContent = 'Takip Et';
            suggestionButton.classList.remove('following');
        }
    }
}


document.addEventListener('DOMContentLoaded', async () => {
    const mainContentDiv = document.querySelector('.main-content');
    const body = document.querySelector('body');
    const loggedInUserId = parseInt(body.getAttribute('data-user-id')); // Might be NaN
    const loggedInUsername = body.getAttribute('data-user-username'); // Assuming base.html adds this

    console.log('[ProfilePage] DOMContentLoaded: loggedInUserId =', loggedInUserId, ', loggedInUsername =', loggedInUsername);

    try {
        // --- ADD LISTENERS FOR EXISTING BUTTONS (SERVER-RENDERED) ---
        const editButton = document.querySelector('.profile-edit-button');
        const followButton = document.querySelector('.profile-follow-button');
        const profileHeader = document.querySelector('.profile-header'); // Find the header to get profile user ID

        let profileUserId = null;
        if (followButton) {
            profileUserId = parseInt(followButton.getAttribute('data-user-id'));
        } else if (profileHeader) {
            // Fallback: Try to find it elsewhere if follow button isn't reliable (e.g., hidden on own profile)
            // This depends heavily on your HTML structure. Let's assume follow button is the primary source for now.
            console.warn('[ProfilePage] Could not find follow button to get profile user ID reliably.');
        }

        console.log('[ProfilePage] Profile User ID found in HTML:', profileUserId);

        // Edit Button Logic
        if (editButton) {
            // Show/Hide based on whether it's the user's own profile
            if (!isNaN(loggedInUserId) && !isNaN(profileUserId) && loggedInUserId === profileUserId) {
                 console.log('[ProfilePage] Adding edit button listener for own profile.');
                 editButton.style.display = ''; // Ensure it's visible
                 editButton.addEventListener('click', function() {
                     window.location.href = '/settings'; // Redirect to settings/edit page
                 });
            } else {
                 console.log('[ProfilePage] Not own profile or user not logged in, hiding edit button.');
                 editButton.style.display = 'none'; // Hide edit button if not own profile
            }
        }

        // Follow Button Logic
        if (followButton) {
             // Hide follow button if it's the user's own profile
             if (!isNaN(loggedInUserId) && !isNaN(profileUserId) && loggedInUserId === profileUserId) {
                 console.log('[ProfilePage] Hiding follow button for own profile.');
                 followButton.style.display = 'none';
             }
             // Only add listener if logged in AND it's not the user's own profile
             else if (!isNaN(loggedInUserId) && !isNaN(profileUserId)) {
                 console.log('[ProfilePage] Adding follow button listener.');
                 followButton.style.display = ''; // Ensure it's visible

                 // Determine initial state FROM SERVER RENDERED HTML (Crucial: Server needs to add 'following' class if applicable)
                 let isInitiallyFollowing = followButton.classList.contains('following');
                 // Update button text based on initial state
                 if (isInitiallyFollowing) {
                     followButton.textContent = 'Takip Ediliyor';
                 } else {
                     followButton.textContent = 'Takip Et';
                 }

                 followButton.addEventListener('click', async function() {
                     const targetUserId = this.getAttribute('data-user-id'); // Should be profileUserId

                     // Re-check loggedInUserId just in case state changed? Unlikely but safe.
                     const currentLoggedInUserId = parseInt(document.querySelector('body').getAttribute('data-user-id'));
                     if (!currentLoggedInUserId || isNaN(currentLoggedInUserId)) {
                         alert('Takip etmek için giriş yapmalısınız.'); // You must be logged in to follow users.
                         return;
                     }

                     // Determine current state *at time of click*
                     const isCurrentlyFollowing = this.classList.contains('following');
                     const method = isCurrentlyFollowing ? 'DELETE' : 'POST';
                     const url = '/api/follow';
                     // Body only needed for POST, follower ID (current user) comes from token server-side
                     const bodyData = isCurrentlyFollowing ? null : JSON.stringify({ followed_user_id: parseInt(targetUserId) });
                     // Query params only needed for DELETE (based on current backend)
                     const queryParams = isCurrentlyFollowing ? `?followed_user_id=${targetUserId}` : '';

                     try {
                         const response = await fetch(`${url}${queryParams}`, {
                             method: method,
                             headers: getAuthHeaders(), // Use helper function
                             body: bodyData
                         });

                         if (response.status === 401 || response.status === 403) {
                              alert('Authentication failed. Please log in again to follow users.');
                              return;
                         }
                         // Check for other errors before parsing JSON
                         if (!response.ok) {
                             const errorData = await response.json().catch(() => ({ message: 'Unknown error' }));
                             alert(`Failed to update follow status: ${errorData.message || response.statusText}`);
                             return;
                         }

                         const result = await response.json(); // Should be successful now

                         if (result.success) {
                             // Find follower count span (assuming ID or specific structure)
                             const followersCountSpan = document.getElementById('followers-count') || document.querySelector('.profile-stats-item:nth-child(2) .profile-stats-number'); // Adjust selector if needed
                             let currentCount = followersCountSpan ? parseInt(followersCountSpan.textContent) || 0 : 0;

                             // Update button text, class, and follower count
                             if (isCurrentlyFollowing) {
                                 this.textContent = 'Takip Et';
                                 this.classList.remove('following');
                                 if (followersCountSpan) followersCountSpan.textContent = Math.max(0, currentCount - 1);
                             } else {
                                 this.textContent = 'Takip Ediliyor';
                                 this.classList.add('following');
                                 if (followersCountSpan) followersCountSpan.textContent = currentCount + 1;
                             }
                             // Sync with suggestion button if present
                             updateSuggestionButtonState(targetUserId, !isCurrentlyFollowing);

                         } else {
                              alert('Failed to update follow status: ' + result.message);
                         }
                     } catch (error) {
                         console.error('Error updating follow status:', error);
                         alert('An error occurred while updating follow status.');
                     }
                 });
             } else {
                 // Not logged in or profileUserId missing/invalid
                 console.log('[ProfilePage] Follow button listener not added (not logged in, viewing own profile, or target user ID missing/invalid).');
                 // Hide button if not logged in (server should ideally handle this too)
                 if (isNaN(loggedInUserId)) {
                     followButton.style.display = 'none';
                 }
             }
        }

        // --- SETUP LISTENERS FOR POST ACTIONS (if server renders posts with actions) ---
        const postListDiv = document.querySelector('.post-list');
        if (postListDiv) {
            // Use event delegation for like/save/comment actions on posts loaded by the server
            postListDiv.addEventListener('click', async (event) => {
                const likeButton = event.target.closest('.post-actions-item:nth-child(1)'); // Target the container div
                const commentButton = event.target.closest('.post-actions-item:nth-child(2)');
                const saveButton = event.target.closest('.post-actions-item:nth-child(3)'); // Assuming save is 3rd
                const postElement = event.target.closest('.post');

                if (!postElement) return; // Click wasn't inside a post

                const postId = postElement.getAttribute('data-post-id'); // SERVER MUST ADD data-post-id to each post div
                if (!postId) {
                    console.warn('Post element missing data-post-id attribute.');
                    return;
                }

                 // Re-check loggedInUserId for actions
                 const currentLoggedInUserId = parseInt(document.querySelector('body').getAttribute('data-user-id'));
                 if (isNaN(currentLoggedInUserId)) {
                     // Allow comment clicks to redirect, but block like/save
                     if (likeButton || saveButton) {
                         alert('You must be logged in to like or save posts.');
                         return;
                     }
                 }

                // Like Action
                if (likeButton) {
                    const likeIcon = likeButton.querySelector('i.fa-heart');
                    const likeCountSpan = likeButton.querySelector('span');
                    if (!likeIcon || !likeCountSpan) return;

                    const isLiked = likeIcon.classList.contains('fas'); // Check if already liked
                    const method = isLiked ? 'DELETE' : 'POST';
                    const url = `/api/posts/${postId}/likes`;

                    try {
                        const response = await fetch(url, {
                            method: method,
                            headers: getAuthHeaders(),
                            body: method === 'POST' ? JSON.stringify({ user_id: currentLoggedInUserId }) : null,
                        });
                        if (response.status === 401 || response.status === 403) { alert('Authentication failed.'); return; }
                        if (!response.ok) { const err = await response.json().catch(()=>({})); alert(`Like failed: ${err.message || response.statusText}`); return; }

                        const result = await response.json();
                        if (result.success) {
                            let count = parseInt(likeCountSpan.textContent) || 0;
                            if (isLiked) {
                                likeIcon.classList.replace('fas', 'far');
                                likeIcon.classList.remove('liked');
                                likeIcon.style.color = '';
                                likeCountSpan.textContent = Math.max(0, count - 1);
                            } else {
                                likeIcon.classList.replace('far', 'fas');
                                likeIcon.classList.add('liked');
                                likeIcon.style.color = 'red';
                                likeCountSpan.textContent = count + 1;
                            }
                        } else { alert('Like failed: ' + result.message); }
                    } catch (error) { console.error('Like error:', error); alert('An error occurred.'); }
                }

                // Comment Action
                if (commentButton) {
                    window.location.href = `/post/${postId}`; // Redirect to single post page
                }

                // Save Action
                if (saveButton) {
                    const saveIcon = saveButton.querySelector('i.fa-bookmark');
                    if (!saveIcon) return;

                    const isSaved = saveIcon.classList.contains('fas'); // Check if already saved
                    const method = isSaved ? 'DELETE' : 'POST';
                    const url = `/api/posts/${postId}/saved`;

                    try {
                        const response = await fetch(url, {
                            method: method,
                            headers: getAuthHeaders(),
                            body: method === 'POST' ? JSON.stringify({ user_id: currentLoggedInUserId }) : null,
                        });
                        if (response.status === 401 || response.status === 403) { alert('Authentication failed.'); return; }
                        if (!response.ok) { const err = await response.json().catch(()=>({})); alert(`Save failed: ${err.message || response.statusText}`); return; }

                        const result = await response.json();
                        if (result.success) {
                            if (isSaved) {
                                saveIcon.classList.replace('fas', 'far');
                                saveIcon.classList.remove('saved');
                                saveIcon.style.color = '';
                            } else {
                                saveIcon.classList.replace('far', 'fas');
                                saveIcon.classList.add('saved');
                                saveIcon.style.color = 'blue';
                            }
                        } else { alert('Save failed: ' + result.message); }
                    } catch (error) { console.error('Save error:', error); alert('An error occurred.'); }
                }
            });
        }


        // --- FETCH AND DISPLAY SUGGESTED USERS ---
        // This can run independently
        await fetchAndDisplaySuggestedUsers();

    } catch (error) {
        console.error('[ProfilePage] General error in DOMContentLoaded:', error);
        if (mainContentDiv && !mainContentDiv.textContent.includes('Error')) { // Avoid overwriting specific errors
            // Display a generic error if the main content area is empty or hasn't shown an error yet
             if (!mainContentDiv.innerHTML.trim()) {
                mainContentDiv.innerHTML = '<p>An unexpected error occurred while initializing the profile page script.</p>';
             }
        }
    }
});

function getUsernameFromUrl() {
    // Assuming the URL is like /profile/someuser
    const pathParts = window.location.pathname.split('/');
    if (pathParts.length >= 3 && pathParts[1] === 'profile' && pathParts[2]) {
        return pathParts[2]; // Get username from path e.g., /profile/testuser
    }
    // Fallback or alternative: maybe the username is embedded in the page?
    const profileUsernameDiv = document.querySelector('.profile-username');
    if (profileUsernameDiv && profileUsernameDiv.textContent.startsWith('@')) {
        return profileUsernameDiv.textContent.substring(1);
    }
    console.warn('[getUsernameFromUrl] Could not determine username from URL path or profile header.');
    return null; // Return null if not found
}


// --- UNUSED FUNCTIONS (kept in case needed later, but not called from DOMContentLoaded) ---

async function fetchAndDisplayProfile(username) {
    // THIS FUNCTION IS NO LONGER CALLED BY DOMCONTENTLOADED
    console.warn('[fetchAndDisplayProfile] This function is deprecated for initial load. Called for username:', username);
    // ... original function code ...
    // ... it might be useful if you implement dynamic profile updates later ...
    const profileHeaderDiv = document.querySelector('.profile-header');
    const postListDiv = document.querySelector('.post-list');

    if (!profileHeaderDiv || !postListDiv) {
        console.error('[fetchAndDisplayProfile] Profile header or post list div not found in DOM.');
        return;
    }
    if (!username) {
        console.error('[fetchAndDisplayProfile] Username is null or undefined. Cannot fetch profile.');
        profileHeaderDiv.innerHTML = '<p>Cannot load profile: Username not provided.</p>';
        return;
    }

    profileHeaderDiv.innerHTML = '<p>Loading profile...</p>'; // Initial loading state
    postListDiv.innerHTML = ''; // Clear previous posts

    console.log(`[fetchAndDisplayProfile] Fetching profile for username: ${username}`);
    const profileApiUrl = `/api/users/${username}`;
    let userId = null; // User ID of the profile being viewed
        // Get current user ID from the data attribute on the body
        const body = document.querySelector('body');
        // Corrected attribute name to match base.html
        const currentUserId = parseInt(body.getAttribute('data-user-id')); // This might be NaN if not logged in

        try {
        // Fetch profile data
        const profileResponse = await fetch(profileApiUrl, { headers: getAuthHeaders() }); // Added headers

        if (!profileResponse.ok) {
            if (profileResponse.status === 401 || profileResponse.status === 403) {
                 console.error('Authentication failed fetching profile data.');
                 profileHeaderDiv.innerHTML = '<p>Could not load profile. Authentication failed.</p>';
                 return;
            }
            if (profileResponse.status === 404) {
                 profileHeaderDiv.innerHTML = '<p>User not found.</p>';
                 return;
            }
            throw new Error(`HTTP error! status: ${profileResponse.status}`);
        }

        const profileData = await profileResponse.json();
        userId = profileData.user_id; // User ID of the profile being viewed

        // Check if the current user is following this profile
        let isFollowing = false;
        // Only fetch following status if the current user is logged in (currentUserId is a valid number)
        if (currentUserId && !isNaN(currentUserId) && currentUserId !== userId) { // Also check not viewing own profile
             const followingApiUrl = `/api/users/${currentUserId}/following`; // Check if current user follows the profile user
             try {
                 const followingResponse = await fetch(followingApiUrl, { headers: getAuthHeaders() }); // Added headers
                 if (followingResponse.ok) {
                     const followingList = await followingResponse.json();
                     // Check if the profile user's ID is in the list of users the current user follows
                     isFollowing = followingList.some(user => user.user_id === userId);
                 } else {
                     console.error(`Failed to fetch following list for current user ${currentUserId}. Status: ${followingResponse.status}`);
                     // Decide how to handle this - maybe proceed without follow status?
                 }
             } catch (followError) {
                  console.error('Error fetching following status:', followError);
             }
        } else {
             console.log("Current user not logged in, viewing own profile, or ID not available, skipping follow status check.");
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
                ${currentUserId && !isNaN(currentUserId) && currentUserId !== userId ? // Check currentUserId is valid number and not own profile
                    `<button class="profile-follow-button ${isFollowing ? 'following' : ''}" data-user-id="${userId}">${isFollowing ? 'Takip Ediliyor' : 'Takip Et'}</button>`
                    : ''}
                ${currentUserId && !isNaN(currentUserId) && currentUserId === userId ? // Check currentUserId is valid number and is own profile
                    `<button class="profile-edit-button">Profili Düzenle</button>`
                    : ''}
            </div>
        `;

        // Add event listener to the dynamically created edit button (if it exists)
        const editButton = profileHeaderDiv.querySelector('.profile-edit-button');
        if (editButton) {
            editButton.addEventListener('click', function() {
                // Redirect to the actual edit profile page
                window.location.href = '/settings'; // Assuming '/settings' is the route for the page with editing options
            });
        }


        // Add event listener to the dynamically created follow button (if it exists)
        const followButton = profileHeaderDiv.querySelector('.profile-follow-button');
        if (followButton) {
            followButton.addEventListener('click', async function() {
                const targetUserId = this.getAttribute('data-user-id');
                // Determine state from class presence
                const isCurrentlyFollowing = this.classList.contains('following');

                 // Re-check currentUserId just in case, although it should be valid if button exists
                // Corrected attribute name to match base.html
                const loggedInUserId = parseInt(document.querySelector('body').getAttribute('data-user-id'));
                if (!loggedInUserId || isNaN(loggedInUserId)) {
                    alert('You must be logged in to follow users.'); // Or redirect to login
                    return;
                }

                const method = isCurrentlyFollowing ? 'DELETE' : 'POST';
                const url = '/api/follow';
                // Body is only needed for POST
                const bodyData = isCurrentlyFollowing ? null : JSON.stringify({ followed_user_id: parseInt(targetUserId) });
                 // Query params are only needed for DELETE (based on current backend implementation)
                 // Follower ID (current user) should be derived from the token on the backend for both POST and DELETE
                const queryParams = isCurrentlyFollowing ? `?followed_user_id=${targetUserId}` : '';

                try {
                    const response = await fetch(`${url}${queryParams}`, {
                        method: method,
                        headers: getAuthHeaders(), // Use helper function
                        body: bodyData // Pass null for DELETE, JSON string for POST
                    });

                    // Check for auth errors first
                    if (response.status === 401 || response.status === 403) {
                         alert('Authentication failed. Please log in again to follow users.');
                         return; // Stop processing
                    }

                    const result = await response.json();

                    if (result.success) {
                        // Update button text and class
                        if (isCurrentlyFollowing) {
                            this.textContent = 'Takip Et';
                            this.classList.remove('following');
                        } else {
                            this.textContent = 'Takip Ediliyor';
                            this.classList.add('following');
                        }
                        // Update followers count
                        const followersCountSpan = document.getElementById('followers-count');
                        if (followersCountSpan) {
                            let currentCount = parseInt(followersCountSpan.textContent) || 0;
                            followersCountSpan.textContent = isCurrentlyFollowing ? Math.max(0, currentCount - 1) : currentCount + 1;
                        }
                         // Sync with suggestion button if present
                         updateSuggestionButtonState(targetUserId, !isCurrentlyFollowing);

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
            // fetchAndDisplayUserPosts(userId, postListDiv); // NO LONGER CALLED HERE
            console.warn('[fetchAndDisplayProfile] Skipping call to fetchAndDisplayUserPosts.');
        }

    } catch (error) {
        console.error('Error fetching and displaying profile:', error);
         // Avoid overwriting specific auth error messages
         if (!profileHeaderDiv.textContent.includes('Authentication failed')) {
             profileHeaderDiv.innerHTML = `<p>Error loading profile: ${error.message}</p>`;
         }
    }
}

async function fetchAndDisplayUserPosts(userId, postListDiv) {
     // THIS FUNCTION IS NO LONGER CALLED BY DOMCONTENTLOADED
     console.warn('[fetchAndDisplayUserPosts] This function is deprecated for initial load. Called for user ID:', userId);
     // ... original function code ...
     const postsApiUrl = `/api/users/${userId}/posts`;
     postListDiv.innerHTML = '<p>Loading posts...</p>'; // Loading state for posts

     try {
         // Posts might be public, but include header just in case endpoint requires it for personalized data (likes/saves)
         const postsResponse = await fetch(postsApiUrl, { headers: getAuthHeaders() });

         if (!postsResponse.ok) {
             if (postsResponse.status === 401 || postsResponse.status === 403) {
                 console.warn(`Authentication error fetching posts for user ${userId}. Status: ${postsResponse.status}`);
                 postListDiv.innerHTML = '<p>Could not load posts (authentication issue).</p>';
                 return;
             }
             console.error(`HTTP error fetching posts for user ${userId}: status ${postsResponse.status}`);
             throw new Error(`HTTP error! status: ${postsResponse.status}`);
         }

         const posts = await postsResponse.json();
         postListDiv.innerHTML = ''; // Clear loading message

         if (posts.length === 0) {
             postListDiv.innerHTML = '<p>This user hasn\'t posted anything yet.</p>';
             return;
         }

         // Get current user's liked and saved posts for accurate icon state (requires auth)
         let likedPostIds = new Set();
         let savedPostIds = new Set();
         // Corrected attribute name to match base.html
         const loggedInUserId = parseInt(document.querySelector('body').getAttribute('data-user-id'));

         if (loggedInUserId && !isNaN(loggedInUserId)) {
             try {
                 // Use Promise.allSettled to avoid failing if one request fails
                 const results = await Promise.allSettled([
                     fetch(`/api/users/${loggedInUserId}/likes`, { headers: getAuthHeaders() }),
                     fetch(`/api/users/${loggedInUserId}/saved`, { headers: getAuthHeaders() })
                 ]);

                 const likesResult = results[0];
                 const savesResult = results[1];

                 if (likesResult.status === 'fulfilled' && likesResult.value.ok) {
                     const likedPosts = await likesResult.value.json();
                     likedPostIds = new Set(likedPosts.map(p => p.post_id));
                 } else if (likesResult.status === 'rejected' || !likesResult.value.ok) {
                     console.warn(`Failed to fetch liked posts for user ${loggedInUserId}. Status: ${likesResult.value?.status || likesResult.reason}`);
                 }

                 if (savesResult.status === 'fulfilled' && savesResult.value.ok) {
                     const savedPosts = await savesResult.value.json();
                     savedPostIds = new Set(savedPosts.map(p => p.post_id));
                 } else if (savesResult.status === 'rejected' || !savesResult.value.ok) {
                     console.warn(`Failed to fetch saved posts for user ${loggedInUserId}. Status: ${savesResult.value?.status || savesResult.reason}`);
                 }
             } catch (err) {
                 console.error("Error fetching user's liked/saved posts:", err);
             }
         }


         posts.forEach(post => {
             const postElement = document.createElement('div');
             postElement.classList.add('post'); // Standard post class
             postElement.setAttribute('data-post-id', post.post_id); // Add post ID for event delegation

             const postHeader = `
                 <div class="post-header">
                     <img src="${post.profile_picture_url || 'https://randomuser.me/api/portraits/men/' + (post.user_id % 100) + '.jpg'}" alt="Avatar" class="post-avatar">
                     <div class="post-author-info">
                         <a href="/profile/${post.username}" class="post-author">${post.username}</a>
                         <div class="post-time">${new Date(post.created_at).toLocaleString()}</div> <!-- Format date -->
                     </div>
                     <!-- Removed options button -->
                 </div>
             `;

             const postContent = `
                 <div class="post-content">
                     <p>${post.content_text || ''}</p>
                     ${post.image_url ? `<img src="${post.image_url}" alt="Post Image" class="post-image">` : ''}
                 </div>
             `;

             // Add post actions back, similar to home.js
             const postActions = `
                 <div class="post-actions">
                     <div class="post-actions-item">
                         <i class="far fa-heart"></i> <span>${post.like_count || 0}</span>
                     </div>
                     <div class="post-actions-item">
                         <i class="far fa-comment"></i> <span>${post.comment_count || 0}</span>
                     </div>
                     <div class="post-actions-item post-actions-item-right">
                         <i class="far fa-bookmark"></i>
                     </div>
                 </div>
             `;

             postElement.innerHTML = postHeader + postContent + postActions;
             postListDiv.appendChild(postElement);

             // Set initial state for icons based on fetched liked/saved status
             const likeIcon = postElement.querySelector('.fa-heart');
             const saveIcon = postElement.querySelector('.fa-bookmark');
             if (likedPostIds.has(post.post_id)) {
                 likeIcon.classList.replace('far', 'fas');
                 likeIcon.classList.add('liked');
                 likeIcon.style.color = 'red';
             }
             if (savedPostIds.has(post.post_id)) {
                 saveIcon.classList.replace('far', 'fas');
                 saveIcon.classList.add('saved');
                 saveIcon.style.color = 'blue';
             }
             // Event listeners are now handled by delegation in DOMContentLoaded
         });

     } catch (error) {
         console.error('Error fetching and displaying user posts:', error);
         postListDiv.innerHTML = `<p>Error loading posts: ${error.message}</p>`;
     }
}


// --- SUGGESTED USERS FUNCTIONS (Unchanged) ---

async function fetchAndDisplaySuggestedUsers() {
    const suggestionsContainer = document.querySelector('.sidebar-right .sidebar-right-section'); // Target the first section
    if (!suggestionsContainer) {
        console.error('Suggestions container not found.');
        return;
    }

    // Find the title element to preserve it
    const titleElement = suggestionsContainer.querySelector('.sidebar-right-title');

    // Clear existing suggestion items and messages, but keep the title
    suggestionsContainer.querySelectorAll('.suggestion-item, p').forEach(item => item.remove());


    // Get current user ID (needed for API call and logic)
    const body = document.querySelector('body');
    // Corrected attribute name to match base.html
    const currentUserId = parseInt(body.getAttribute('data-user-id'));

    // No need to fetch suggestions if user isn't logged in
    if (isNaN(currentUserId)) { // Check if currentUserId is NaN
        console.log('User not logged in, skipping suggested users.');
        const noLoginMsg = document.createElement('p');
        noLoginMsg.textContent = 'Log in to see suggestions.';
        noLoginMsg.style.padding = '10px';
        suggestionsContainer.appendChild(noLoginMsg);
        return;
    }

    try {
        // Suggested users endpoint likely requires authentication
        const response = await fetch('/api/suggested_users', { headers: getAuthHeaders() }); // Added headers

        if (response.status === 401 || response.status === 403) {
             console.error('Authentication failed fetching suggested users.');
             const authErrorMsg = document.createElement('p');
             authErrorMsg.textContent = 'Could not load suggestions (auth failed).';
             authErrorMsg.style.padding = '10px';
             suggestionsContainer.appendChild(authErrorMsg);
             return;
        }

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const suggestedUsers = await response.json();

        if (suggestedUsers.length === 0) {
            const noSuggestions = document.createElement('p');
            noSuggestions.textContent = 'No new users to suggest right now.';
            noSuggestions.style.padding = '10px';
            suggestionsContainer.appendChild(noSuggestions);
            return;
        }

        suggestedUsers.forEach(user => {
            // Skip suggesting the current user themselves
            if (user.user_id === currentUserId) return;

            const suggestionItem = document.createElement('div');
            suggestionItem.classList.add('suggestion-item');

            // Backend should provide 'is_following' based on the authenticated user
            const buttonText = user.is_following ? 'Takip Ediliyor' : 'Takip Et';
            const buttonClass = user.is_following ? 'suggestion-follow-button following' : 'suggestion-follow-button';

            suggestionItem.innerHTML = `
                <img src="${user.profile_picture_url || 'https://randomuser.me/api/portraits/lego/1.jpg'}" alt="Avatar" class="suggestion-avatar">
                <div class="suggestion-details">
                     <a href="/profile/${user.username}" class="suggestion-username">${user.username}</a>
                     ${user.full_name ? `<div class="suggestion-fullname">${user.full_name}</div>` : ''}
                </div>
                <button class="${buttonClass}" data-user-id="${user.user_id}">${buttonText}</button>
            `;
            suggestionsContainer.appendChild(suggestionItem);
        });

        // Add event listeners after updating the DOM
        addSuggestionButtonListeners();

    } catch (error) {
        console.error('Error fetching or displaying suggested users:', error);
        const errorMsg = document.createElement('p');
        errorMsg.textContent = 'Öneriler yüklenirken hata oluştu.'; // Error loading suggestions.
        errorMsg.style.padding = '10px';
        suggestionsContainer.appendChild(errorMsg);
    }
}

// Function to add listeners for suggestion follow buttons
function addSuggestionButtonListeners() {
    const body = document.querySelector('body');
    // Get current user ID once
    // Corrected attribute name to match base.html
    const currentUserId = parseInt(body.getAttribute('data-user-id'));

    // Use event delegation on the container for dynamically added buttons
    const suggestionsContainer = document.querySelector('.sidebar-right .sidebar-right-section');
    if (!suggestionsContainer) return;

    // Check if listener already exists to avoid duplicates (simple flag method)
    if (suggestionsContainer.dataset.listenerAttached === 'true') {
        console.log('Suggestion button listener already attached.');
        return;
    }
    suggestionsContainer.dataset.listenerAttached = 'true'; // Mark as attached

    suggestionsContainer.addEventListener('click', async function(event) {
        if (!event.target.matches('.suggestion-follow-button')) {
            return; // Click wasn't on a follow button
        }

        const button = event.target;
        const targetUserId = button.getAttribute('data-user-id');
        const isCurrentlyFollowing = button.classList.contains('following');

        if (!currentUserId || isNaN(currentUserId)) {
            alert('Takip etmek için giriş yapmalısınız.'); // You must be logged in to follow.
            return;
        }
        if (!targetUserId) {
             console.error('Target user ID not found on button.');
             return;
        }

        const method = isCurrentlyFollowing ? 'DELETE' : 'POST';
        const url = '/api/follow';
        const bodyData = isCurrentlyFollowing ? null : JSON.stringify({ followed_user_id: parseInt(targetUserId) });
        const queryParams = isCurrentlyFollowing ? `?followed_user_id=${targetUserId}` : '';

        console.log(`Attempting to ${method} follow for user ${targetUserId} from suggestions`);

        try {
            const response = await fetch(`${url}${queryParams}`, {
                method: method,
                headers: getAuthHeaders(), // Use helper function
                body: bodyData
            });

            if (response.status === 401 || response.status === 403) {
                 alert('Authentication failed. Please log in again to follow users.');
                 return;
            }
            if (!response.ok) {
                 const errorData = await response.json().catch(() => ({ message: 'Unknown error' }));
                 alert(`Takip durumu güncellenemedi: ${errorData.message || response.statusText}`); // Failed to update follow status
                 return;
            }

            const result = await response.json();

            if (result.success) {
                // Update button text and class
                if (isCurrentlyFollowing) {
                    button.textContent = 'Takip Et';
                    button.classList.remove('following');
                } else {
                    button.textContent = 'Takip Ediliyor';
                    button.classList.add('following');
                }

                // If the suggested user is the same as the profile being viewed, update the main follow button and count
                const viewedProfileUsername = getUsernameFromUrl(); // Get username of profile being viewed
                const suggestionUsernameLink = button.closest('.suggestion-item')?.querySelector('.suggestion-username');
                const suggestionUsername = suggestionUsernameLink ? suggestionUsernameLink.textContent : null;

                // Check if the followed user from suggestions matches the profile page user
                if (viewedProfileUsername && suggestionUsername && viewedProfileUsername === suggestionUsername) {
                    const mainFollowButton = document.querySelector('.profile-follow-button'); // In profile header
                    if (mainFollowButton) {
                        mainFollowButton.textContent = button.textContent; // Sync text
                        if (isCurrentlyFollowing) {
                            mainFollowButton.classList.remove('following');
                        } else {
                            mainFollowButton.classList.add('following');
                        }
                    }
                    // Update follower count on main profile
                    const followersCountSpan = document.getElementById('followers-count') || document.querySelector('.profile-stats-item:nth-child(2) .profile-stats-number');
                    if (followersCountSpan) {
                        let currentCount = parseInt(followersCountSpan.textContent) || 0;
                        followersCountSpan.textContent = isCurrentlyFollowing ? Math.max(0, currentCount - 1) : currentCount + 1;
                    }
                }

            } else {
                alert('Takip durumu güncellenemedi: ' + result.message); // Failed to update follow status
            }
        } catch (error) {
            console.error('Takip durumu güncellenirken hata:', error); // Error updating follow status
            alert('Takip durumu güncellenirken bir hata oluştu.'); // An error occurred while updating follow status.
        }
    });
}
