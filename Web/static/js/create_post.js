// This file will contain JavaScript for the create post page
// It will handle form submission for creating a new post.

document.addEventListener('DOMContentLoaded', () => {
    const createPostForm = document.getElementById('create-post-form');
    const postTextInput = document.getElementById('post-text');
    const postImageInput = document.getElementById('post-image');
    const errorMessageDiv = document.getElementById('error-message');

    createPostForm.addEventListener('submit', async function(event) {
        event.preventDefault(); // Prevent default form submission
        errorMessageDiv.textContent = ''; // Clear previous errors

        const postText = postTextInput.value.trim();
        const postImage = postImageInput.files[0]; // Get the selected file

        if (!postText && !postImage) {
            errorMessageDiv.textContent = 'Please enter some text or select an image.';
            return;
        }

        const currentUserId = 1; // TODO: Replace with actual logic to get current user ID
        let imageUrl = null;

        // TODO: Implement authentication (e.g., get token)
        const authToken = 'YOUR_AUTH_TOKEN'; // Replace with actual token

        // 1. Upload Image if selected
        if (postImage) {
            const uploadUrl = '/api/upload/image'; // Use relative path
            const formData = new FormData();
            formData.append('image', postImage);
            formData.append('user_id', currentUserId); // Include user_id for backend

            try {
                const uploadResponse = await fetch(uploadUrl, {
                    method: 'POST',
                    headers: {
                        // 'Authorization': `Bearer ${authToken}` // TODO: Add actual token
                    },
                    body: formData,
                });

                const uploadResult = await uploadResponse.json();

                if (uploadResponse.ok && uploadResult.imageUrl) {
                    imageUrl = uploadResult.imageUrl; // Get the image URL from the response
                } else {
                    throw new Error(uploadResult.message || `Image upload failed: ${uploadResponse.status}`);
                }
            } catch (error) {
                console.error('Image upload error:', error);
                errorMessageDiv.textContent = `Image upload failed: ${error.message}`;
                return; // Stop if image upload fails
            }
        }

        // 2. Create Post
        const createPostUrl = '/api/posts'; // Use relative path
        const postData = {
            user_id: currentUserId,
            content_text: postText,
            image_url: imageUrl, // Will be null if no image was uploaded
        };

        try {
            const createPostResponse = await fetch(createPostUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    // 'Authorization': `Bearer ${authToken}` // TODO: Add actual token
                },
                body: JSON.stringify(postData),
            });

            const createPostResult = await createPostResponse.json();

            if (createPostResponse.ok && createPostResult.success) {
                console.log('Post created successfully:', createPostResult);
                alert('Post created successfully!');
                // TODO: Redirect to home page or the new post's page
                // window.location.href = '/home';
            } else {
                errorMessageDiv.textContent = createPostResult.message || `Failed to create post: ${createPostResponse.status}`;
            }

        } catch (error) {
            console.error('Create post error:', error);
            errorMessageDiv.textContent = 'An error occurred while creating the post. Please try again.';
        }
    });
});
