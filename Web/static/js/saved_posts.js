// This file will contain JavaScript for the saved posts page
// It will fetch and display saved posts for the current user.

document.addEventListener('DOMContentLoaded', () => {
    const currentUserId = 1; // TODO: Replace with actual logic to get current user ID
    fetchAndDisplaySavedPosts(currentUserId);
});

async function fetchAndDisplaySavedPosts(userId) {
    const savedPostsListDiv = document.getElementById('saved-posts-list');
    const apiUrl = `/api/users/${userId}/saved-posts`;

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

        const posts = await response.json();

        savedPostsListDiv.innerHTML = ''; // Clear existing content

        if (posts.length === 0) {
            savedPostsListDiv.innerHTML = '<p>No saved posts found.</p>';
            return;
        }

        posts.forEach(post => {
            const postElement = document.createElement('div');
            postElement.classList.add('post'); // Reuse post styling from home page

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
                    <div class="post-actions-item"><i class="fas fa-bookmark"></i></div> <!-- Use solid bookmark icon for saved -->
                </div>
            `;

            postElement.innerHTML = postHeader + postContent + postActions;
            savedPostsListDiv.appendChild(postElement);
        });

    } catch (error) {
        console.error('Error fetching and displaying saved posts:', error);
        savedPostsListDiv.innerHTML = '<p>Error loading saved posts.</p>';
    }
}
