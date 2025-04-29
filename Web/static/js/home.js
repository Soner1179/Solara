// This file will contain JavaScript for the home page
// It will fetch posts from the backend and display them.

document.addEventListener('DOMContentLoaded', () => {
    fetchAndDisplayPosts();
});

async function fetchAndDisplayPosts() {
    const feedDiv = document.querySelector('.feed');
    const currentUserId = 1; // TODO: Replace with actual logic to get current user ID
    const apiUrl = `/api/posts?user_id=${currentUserId}`; // Use relative path

    try {
        // TODO: Implement authentication (e.g., send token in headers)
        const response = await fetch(apiUrl, {
            headers: {
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const posts = await response.json();

        feedDiv.innerHTML = ''; // Clear existing static posts

        if (posts.length === 0) {
            feedDiv.innerHTML = '<p>No posts available.</p>';
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
        });

    } catch (error) {
        console.error('Error fetching and displaying posts:', error);
        feedDiv.innerHTML = '<p>Error loading posts.</p>';
    }
}
