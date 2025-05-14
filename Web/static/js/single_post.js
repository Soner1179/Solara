// This file will contain JavaScript for the single post page
// It will fetch and display a single post and its comments.

document.addEventListener('DOMContentLoaded', () => {
    const postId = getPostIdFromUrl(); // TODO: Implement function to get post ID from URL
    if (postId) {
        fetchAndDisplayPost(postId);
        fetchAndDisplayComments(postId);
    } else {
        document.getElementById('post-container').innerHTML = '<p>Post ID not found in URL.</p>';
        document.getElementById('comments-list').innerHTML = '';
    }
});

function getPostIdFromUrl() {
    // TODO: Implement logic to extract post ID from the URL
    // Example: If URL is /post/123, extract 123
    const pathSegments = window.location.pathname.split('/');
    const postId = pathSegments[pathSegments.length - 1]; // Assuming ID is the last segment
    return parseInt(postId) || null; // Convert to integer, return null if not a valid number
}

async function fetchAndDisplayPost(postId) {
    const postContainerDiv = document.getElementById('post-container');
    const apiUrl = `/api/posts/${postId}`; // Assuming endpoint for single post

    try {
        // TODO: Implement authentication if needed for viewing single posts
        const response = await fetch(apiUrl, {
             headers: {
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const post = await response.json();

        postContainerDiv.innerHTML = ''; // Clear existing content

        if (!post) {
            postContainerDiv.innerHTML = '<p>Post not found.</p>';
            return;
        }

        // Reuse post rendering logic (adapted from home.js)
        const postElement = document.createElement('div');
        postElement.classList.add('post', 'contest-entry'); // Reuse post styling, added 'contest-entry'

        const postHeader = `
            <div class="post-header">
                <img src="${post.profile_picture_url || 'https://randomuser.me/api/portraits/men/' + (post.user_id % 100) + '.jpg'}" alt="Avatar" class="post-avatar">
                <div class="post-author-info">
                    <div class="post-author">${post.username} <span style="color:#888; font-weight: normal;">@${post.username}</span></div>
                    <div class="post-time">${new Date(post.created_at).toLocaleString()}</div> <!-- Format date -->
                </div>
                {# Removed post-options div #}
            </div>
        `;

        const postContent = `
            <div class="post-content">
                ${post.content_text || ''}
                ${post.image_url ? `<img src="${post.image_url}" alt="Post Image" style="max-width: 100%; height: auto; margin-top: 10px; border-radius: 8px;">` : ''}
                 </div>
             `;

             // Removed postActions for single post page
             postElement.innerHTML = postHeader + postContent; // Only header and content
             postContainerDiv.appendChild(postElement);


    } catch (error) {
        console.error('Error fetching and displaying post:', error);
        postContainerDiv.innerHTML = '<p>Error loading post.</p>';
    }
}

async function fetchAndDisplayComments(postId) {
    const commentsListDiv = document.getElementById('comments-list');
    const apiUrl = `/api/posts/${postId}/comments`;

    try {
        // TODO: Implement authentication if needed for viewing comments
        const response = await fetch(apiUrl, {
             headers: {
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const comments = await response.json();

        commentsListDiv.innerHTML = '<h2>Comments</h2>'; // Clear existing comments and add a heading

        if (comments.length === 0) {
            commentsListDiv.innerHTML += '<p>No comments yet.</p>';
            return;
        }

        comments.forEach(comment => {
            const commentElement = document.createElement('div');
            commentElement.classList.add('comment'); // Add a class for styling comments

            commentElement.innerHTML = `
                <div style="display: flex; align-items: center; margin-bottom: 5px;">
                    <img src="${comment.author_profile_picture_url || 'https://randomuser.me/api/portraits/men/' + (comment.user_id % 100) + '.jpg'}" alt="Avatar" style="width: 30px; height: 30px; border-radius: 50%; margin-right: 10px;">
                    <div style="font-weight: bold; margin-right: 5px;">${comment.author_username}</div>
                    <div style="color: #888; font-size: 0.9em;">${new Date(comment.created_at).toLocaleString()}</div>
                </div>
                <div style="margin-left: 40px;">${comment.comment_text}</div> <!-- Indent comment text -->
            `; // Basic comment structure, style as needed

            commentsListDiv.appendChild(commentElement);
        });

    } catch (error) {
        console.error('Error fetching and displaying comments:', error);
        commentsListDiv.innerHTML += '<p>Error loading comments.</p>';
    }
}
