// This file will contain JavaScript for the profile page
// It will fetch user profile data and their posts and display them.

document.addEventListener('DOMContentLoaded', () => {
    const username = 'sonereski1179'; // TODO: Get username from URL or other source
    fetchAndDisplayProfile(username);
});

async function fetchAndDisplayProfile(username) {
    const profileHeaderDiv = document.querySelector('.profile-header');
    const postListDiv = document.querySelector('.post-list');

    const profileApiUrl = `/api/users/${username}`;
    // Need user ID for fetching posts, will get it from profile data
    let userId = null;

    try {
        // Fetch profile data
        const profileResponse = await fetch(profileApiUrl);

        if (!profileResponse.ok) {
            throw new Error(`HTTP error! status: ${profileResponse.status}`);
        }

        const profileData = await profileResponse.json();
        userId = profileData.user_id; // Assuming the response includes user_id

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
                        <span class="profile-stats-number">${profileData.followers_count || 0}</span> <span class="profile-stats-label">Takipçi</span>
                    </div>
                    <div class="profile-stats-item">
                        <span class="profile-stats-number">${profileData.following_count || 0}</span> <span class="profile-stats-label">Takip</span>
                    </div>
                </div>
                <div class="profile-bio">
                    ${profileData.bio || ''}
                </div>
                <button class="profile-edit-button">Profili Düzenle</button>
            </div>
        `;

        // Add event listener to the dynamically created edit button
        profileHeaderDiv.querySelector('.profile-edit-button').addEventListener('click', function() {
            alert('Profil düzenleme sayfasına yönlendiriliyor!'); // TODO: Implement actual navigation
        });


        // Fetch and display user posts if userId is available
        if (userId) {
            fetchAndDisplayUserPosts(userId, postListDiv);
        }

    } catch (error) {
        console.error('Error fetching and displaying profile:', error);
        profileHeaderDiv.innerHTML = '<p>Error loading profile.</p>';
        postListDiv.innerHTML = ''; // Clear any static posts
    }
}

async function fetchAndDisplayUserPosts(userId, postListDiv) {
     const postsApiUrl = `/api/users/${userId}/posts`;

     try {
         const postsResponse = await fetch(postsApiUrl);

         if (!postsResponse.ok) {
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
         });

     } catch (error) {
         console.error('Error fetching and displaying user posts:', error);
         postListDiv.innerHTML += '<p>Error loading posts.</p>'; // Add error below header
     }
}
