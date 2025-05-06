// This file will contain JavaScript for the messages page
// It will fetch chat summaries and messages and display them.

// Removed client-side cookie check function


document.addEventListener('DOMContentLoaded', async () => { // Made async to await fetchAndDisplayChatSummaries

    // Check if user is authenticated before fetching chat summaries
    const currentUserId = getCookie('user_id');

    // Rely on backend redirect for unauthenticated users.
    // Only proceed with fetching chat summaries if user ID is available.
    if (currentUserId) {
        console.log(`[DOMContentLoaded] User authenticated with ID: ${currentUserId}. Attempting to fetch chat summaries.`);
        await fetchAndDisplayChatSummaries(); // Call with user ID, backend will handle authentication
    } else {
         console.log("[DOMContentLoaded] User not authenticated. Chat summaries will not be fetched. Backend should redirect if necessary.");
         // Optionally clear the user list area or show a different message if needed,
         // but the backend redirect is the primary authentication gate for the page.
         const userListContentDiv = document.querySelector('.user-list-content');
         userListContentDiv.innerHTML = ''; // Clear content if user is not authenticated
         const chatArea = document.getElementById('chatArea');
         chatArea.style.display = 'none'; // Hide chat area if not authenticated
    }


    // Add event listener for sending messages
    const sendButton = document.getElementById('sendButton');
    const messageInput = document.getElementById('messageInput');
    if (sendButton && messageInput) { // Check if elements exist
        sendButton.addEventListener('click', sendMessage);
        messageInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) { // Send on Enter (not Shift+Enter)
                e.preventDefault(); // Prevent newline
                sendMessage();
            }
        });
    }

    // Add event listener for the new message button
    const newMessageButton = document.querySelector('.new-message-btn');
    if (newMessageButton) {
        newMessageButton.addEventListener('click', () => {
            // Removed the authentication check for opening the modal
            // const currentUserId = getCookie('user_id');
            // if (!currentUserId) {
            //      console.log("[New Message Button] User not authenticated. Cannot open modal.");
            //      // Optionally show a message to the user
            //      return;
            // }
            console.log('New message button clicked. Opening new message modal.');
            newMessageModal.style.display = 'block'; // Show the modal
            // Pass the current user ID to the fetch function, it will handle auth check for the API call
            const currentUserId = getCookie('user_id');
            fetchAndDisplayUsersForNewMessage(null, currentUserId); // Fetch and display users when modal opens, pass currentUserId
        });
    }

    // --- New Message Modal Functionality ---
    const newMessageModal = document.getElementById('newMessageModal');
    const closeButton = newMessageModal.querySelector('.close-button');
    const userListForNewMessageDiv = document.getElementById('userListForNewMessage');
    const userSearchInput = document.getElementById('userSearchInput');

    // Close the modal when the close button is clicked
    closeButton.addEventListener('click', () => {
        newMessageModal.style.display = 'none';
        userSearchInput.value = ''; // Clear search input
        userListForNewMessageDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Kullanıcılar yükleniyor...</p>'; // Reset user list area
    });

    // Close the modal when clicking outside of it
    window.addEventListener('click', (event) => {
        if (event.target === newMessageModal) {
            newMessageModal.style.display = 'none';
            userSearchInput.value = ''; // Clear search input
            userListForNewMessageDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Kullanıcılar yükleniyor...</p>'; // Reset user list area
        }
    });

    // Implement user search functionality - Call the backend API on input
    // Removed the client-side filtering listener that used the undefined 'allUsers' variable.
    userSearchInput.addEventListener('input', () => {
        const searchTerm = userSearchInput.value.trim(); // Use trim() to handle whitespace
        const currentUserId = getCookie('user_id'); // Get current user ID for the search
        fetchAndDisplayUsersForNewMessage(searchTerm, currentUserId); // Call with the search term and current user ID
    });

}); // End of DOMContentLoaded

// Function to fetch and display users for starting a new message
// Accepts an optional search term and the current user ID
async function fetchAndDisplayUsersForNewMessage(searchTerm = null, currentUserId) { // Added currentUserId parameter
    const userListForNewMessageDiv = document.getElementById('userListForNewMessage');
    userListForNewMessageDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Kullanıcılar yükleniyor...</p>'; // Show loading

    // Construct the API URL
    let apiUrl = '/api/users/search_for_message';
    const params = new URLSearchParams();
    if (searchTerm) {
        params.append('username', searchTerm); // Add search term
    }
    // Always add current_user_id for backend filtering/auth
    if (currentUserId) {
         params.append('current_user_id', currentUserId); // Add current user ID
    }


    if (params.toString()) {
        apiUrl += `?${params.toString()}`;
    }

    console.log(`[fetchAndDisplayUsersForNewMessage] Fetching users from: ${apiUrl}`); // Added logging

    try {
        const response = await fetch(apiUrl, {
            headers: {
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN' // TODO: Add actual token
            }
        });

        console.log(`[fetchAndDisplayUsersForNewMessage] Fetch response status: ${response.status}`); // Added logging

        if (response.status === 401 || response.status === 403) {
             userListForNewMessageDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Kullanıcıları görmek için giriş yapmalısınız.</p>';
             console.error('Authentication required to fetch users for new message.');
             // Do NOT return here, allow displaying the message
        } else if (!response.ok) {
            const errorText = await response.text();
            console.error(`[fetchAndDisplayUsersForNewMessage] HTTP error! status: ${response.status}, response text: ${errorText}`);
            userListForNewMessageDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Kullanıcılar yüklenirken bir hata oluştu.</p>';
            // Do NOT throw error, handle display in the catch block
        } else {
             const users = await response.json();
             console.log(`[fetchAndDisplayUsersForNewMessage] Fetched ${users.length} users.`); // Added logging
             displayUsersForNewMessage(users); // Display the fetched users
        }


    } catch (error) {
        console.error('Error fetching users for new message:', error);
        userListForNewMessageDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Kullanıcılar yüklenirken bir hata oluştu.</p>';
    }
}

// Function to display users in the new message modal
function displayUsersForNewMessage(usersToDisplay) {
    const userListForNewMessageDiv = document.getElementById('userListForNewMessage');
    userListForNewMessageDiv.innerHTML = ''; // Clear previous content

    if (usersToDisplay.length === 0) {
        userListForNewMessageDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Kullanıcı bulunamadı.</p>';
        return;
    }

    usersToDisplay.forEach(user => {
        const userItemElement = document.createElement('div');
        userItemElement.classList.add('user-item'); // Reuse existing user-item styling
        userItemElement.setAttribute('data-user-id', user.user_id); // Assuming user object has user_id
        userItemElement.setAttribute('data-username', user.username); // Assuming user object has username
        userItemElement.setAttribute('data-avatar-url', user.profile_picture_url); // Use profile_picture_url from backend

        // Determine the avatar URL, using a fallback if the provided URL is invalid or missing
        const avatarSrc = user.profile_picture_url && isValidUrl(user.profile_picture_url)
            ? user.profile_picture_url
            : 'https://randomuser.me/api/portraits/men/' + (user.user_id % 100) + '.jpg'; // Fallback image

        console.log(`[displayUsersForNewMessage] User: ${user.username}, Avatar URL: ${user.profile_picture_url}, Using src: ${avatarSrc}`); // Log the URLs

        userItemElement.innerHTML = `
            <img src="${avatarSrc}" alt="Avatar" class="user-avatar">
            <div class="user-details">
                <div class="user-name">${user.username}</div>
                <!-- Could add other user info here if available -->
            </div>
        `;

        // Add click listener to select a user and start a chat
        userItemElement.addEventListener('click', () => {
            const selectedUserId = userItemElement.getAttribute('data-user-id');
            const selectedUsername = userItemElement.getAttribute('data-username');
            const selectedAvatarUrl = userItemElement.getAttribute('data-avatar-url');

            console.log('User selected for new message:', selectedUsername, selectedUserId);

            // TODO: Implement logic to start a new chat with the selected user on the backend if it doesn't exist.
            // For now, we directly open the chat view.
            const newMessageModal = document.getElementById('newMessageModal');
            const userSearchInput = document.getElementById('userSearchInput');
            const userListForNewMessageDiv = document.getElementById('userListForNewMessage');

            newMessageModal.style.display = 'none'; // Hide the modal
            userSearchInput.value = ''; // Clear search input
            userListForNewMessageDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Kullanıcılar yükleniyor...</p>'; // Reset user list area

            // Open chat with the selected user
            openChat(selectedUserId, selectedUsername, selectedAvatarUrl, ''); // Status is unknown for new chats
        });

        userListForNewMessageDiv.appendChild(userItemElement);
    });
}

// --- Chat Switching ---
// Keep existing openChat function, it will be reused to open the new chat

// --- Message Sending ---
// Keep existing sendMessage function

// --- Sidebar Navigation (Keep this function if needed) ---
// Keep existing navigateTo function

// Helper function to get cookie value (still used for openChat and sendMessage for now)
function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split(';').shift();
    return null;
}

async function fetchAndDisplayChatSummaries() {
    console.log("[fetchAndDisplayChatSummaries] Called.");
    const userListContentDiv = document.querySelector('.user-list-content');
    const chatArea = document.getElementById('chatArea'); // Get chat area element

    const currentUserId = getCookie('user_id');
    if (!currentUserId) {
        console.error("[fetchAndDisplayChatSummaries] User ID not found. Cannot fetch chat summaries. Backend should have redirected.");
        // No need to display an error message here, as the backend should handle the redirect.
        // Keep the return to prevent API call.
        return; // Stop if not authenticated
    }
    console.log(`[fetchAndDisplayChatSummaries] Current user ID: ${currentUserId}. Fetching chats.`);


    // Use the user ID obtained from the cookie/auth
    const apiUrl = `/api/users/me/chats`; // Assuming a '/api/users/me' endpoint or similar

    try {
        // TODO: Implement authentication (e.g., send token in headers)
        const response = await fetch(apiUrl, {
            headers: {
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN' // TODO: Add actual token
            }
        });

        console.log(`[fetchAndDisplayChatSummaries] Fetch response status: ${response.status}`);

        if (response.status === 401 || response.status === 403) {
             userListContentDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Please log in to view messages.</p>';
             chatArea.style.display = 'none'; // Hide chat area
             console.error('[fetchAndDisplayChatSummaries] Authentication required for chat summaries.');
             return; // Stop if not authenticated
        }


        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[fetchAndDisplayChatSummaries] HTTP error! status: ${response.status}, response text: ${errorText}`);
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const chatSummaries = await response.json();
        console.log(`[fetchAndDisplayChatSummaries] Fetched ${chatSummaries.length} chat summaries.`);


        userListContentDiv.innerHTML = ''; // Clear existing static user items

        if (chatSummaries.length === 0) {
            userListContentDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">No chats available.</p>';
            chatArea.style.display = 'none'; // Hide chat area if no chats
            return;
        }

        chatSummaries.forEach(chat => {
            const userItemElement = document.createElement('div');
            userItemElement.classList.add('user-item');
            // Use 'partner_user_id' from the backend response
            userItemElement.setAttribute('data-other-user-id', chat.partner_user_id);
            userItemElement.setAttribute('data-username', chat.partner_username);
            userItemElement.setAttribute('data-avatar-url', chat.partner_avatar_url);
            // The backend query doesn't provide partner status, so this will be empty for now
            userItemElement.setAttribute('data-status', ''); // chat.other_user_status || ''

            // Determine the avatar URL for chat summaries, using a fallback if the provided URL is invalid or missing
            const chatAvatarSrc = chat.partner_avatar_url && isValidUrl(chat.partner_avatar_url)
                ? chat.partner_avatar_url
                : 'https://randomuser.me/api/portraits/men/' + (chat.partner_user_id % 100) + '.jpg'; // Fallback image

            console.log(`[fetchAndDisplayChatSummaries] Chat Partner: ${chat.partner_username}, Avatar URL: ${chat.partner_avatar_url}, Using src: ${chatAvatarSrc}`); // Log the URLs

            userItemElement.innerHTML = `
                <img src="${chatAvatarSrc}" alt="Avatar" class="user-avatar">
                <div class="user-details">
                    <div class="user-name">${chat.partner_username}</div>
                    <div class="last-message">${chat.message_text || 'No messages yet'}</div> <!-- Use message_text from summary -->
                </div>
                <div class="user-meta">
                    <span class="last-message-time">${chat.last_message_timestamp ? new Date(chat.last_message_timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}</span>
                </div>
            `;

            userItemElement.addEventListener('click', () => {
                // Check authentication again before opening chat
                const currentUserId = getCookie('user_id');
                if (!currentUserId) {
                    console.log("[Chat Item Click] User not authenticated. Cannot open chat.");
                    // Optionally show a message to the user
                    return;
                }

                // Remove active class from all user items
                document.querySelectorAll('.user-item').forEach(item => item.classList.remove('active'));
                // Add active class to the clicked item
                event.currentTarget.classList.add('active'); // Use event.currentTarget

                // Open the chat for this user
                openChat(
                    event.currentTarget.getAttribute('data-other-user-id'), // Get ID from data attribute
                    event.currentTarget.getAttribute('data-username'),
                    event.currentTarget.getAttribute('data-avatar-url'),
                    event.currentTarget.getAttribute('data-status')
                );
            });

            userListContentDiv.appendChild(userItemElement);
        });

        // Optional: Automatically open the first chat if on desktop
        // Check if chatArea is visible (it might be hidden by the initial check if no user ID)
        // Only auto-open if there are chats and user is authenticated
        if (chatArea.style.display !== 'none' && chatSummaries.length > 0 && currentUserId) {
            const firstUserItem = userListContentDiv.querySelector('.user-item');
            if (firstUserItem) {
                firstUserItem.click();
            }
        }


    } catch (error) {
        console.error('[fetchAndDisplayChatSummaries] Error fetching and displaying chat summaries:', error);
        userListContentDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Error loading chats.</p>';
         chatArea.style.display = 'none'; // Hide chat area on error
    }
}

async function openChat(otherUserId, username, avatarUrl, status) {
    console.log(`[openChat] Called with otherUserId: ${otherUserId}, username: ${username}`);
    const currentUserId = getCookie('user_id'); // Get user ID from cookie

    if (!currentUserId) {
        console.error("[openChat] User ID not found for opening chat. Cannot proceed. Backend should have redirected.");
        // No need to display an error message here, as the backend should handle the redirect.
        // Keep the return to prevent further execution.
        return;
    }
    console.log(`[openChat] Current user ID: ${currentUserId}`);

    const messageListDiv = document.getElementById('messageList');
    const chatHeaderAvatar = document.getElementById('chatHeaderAvatar');
    const chatHeaderName = document.getElementById('chatHeaderName');
    const chatHeaderStatus = document.getElementById('chatHeaderStatus');
    const chatArea = document.getElementById('chatArea');
    const messageInput = document.getElementById('messageInput');

    console.log(`[openChat] Attempting to update chat header for ${username}`); // Log before header update
    // Update chat header
    // Determine the avatar URL for the chat header, using a fallback if the provided URL is invalid or missing
    const chatHeaderAvatarSrc = avatarUrl && isValidUrl(avatarUrl)
        ? avatarUrl
        : 'https://randomuser.me/api/portraits/men/' + (otherUserId % 100) + '.jpg'; // Fallback image

    console.log(`[openChat] Chat Partner: ${username}, Avatar URL: ${avatarUrl}, Using src: ${chatHeaderAvatarSrc}`); // Log the URLs

    chatHeaderAvatar.src = chatHeaderAvatarSrc;
    chatHeaderName.textContent = username;
    chatHeaderStatus.textContent = status; // This status is static from HTML for now

    console.log('[openChat] Attempting to show chat area...'); // Log before showing chat area
    // Show chat area and clear previous messages
    chatArea.style.display = 'flex';
    console.log(`[openChat] chatArea display set to: ${chatArea.style.display}`); // Log after showing chat area
    messageListDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Loading messages...</p>'; // Show loading indicator

    // Use the actual user ID and the other user's ID
    const messagesApiUrl = `/api/messages/${currentUserId}/${otherUserId}`;
    console.log(`[openChat] Fetching messages from: ${messagesApiUrl}`);

    try {
        console.log('[openChat] Entering fetch try block...'); // Log entering try block
        // TODO: Implement authentication (e.g., send token in headers)
        const response = await fetch(messagesApiUrl, {
             headers: {
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN' // TODO: Add actual token
            }
        });

        console.log(`[openChat] Fetch response status: ${response.status}`);

        if (!response.ok) {
             // Handle specific HTTP errors, e.g., 401 Unauthorized
            if (response.status === 401 || response.status === 403) {
                 messageListDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Authentication failed. Cannot load messages.</p>';
                 console.error('[openChat] Authentication required for messages.');
            } else {
                // Log the full response for debugging
                const errorText = await response.text();
                console.error(`[openChat] HTTP error! status: ${response.status}, response text: ${errorText}`);
                messageListDiv.innerHTML = `<p style="text-align: center; padding: 20px; color: #888;">Error loading messages: ${response.status} ${response.statusText}</p>`;
            }
             return; // Stop if there was an error
        }

        const messages = await response.json();
        console.log(`[openChat] Fetched ${messages.length} messages.`);

        messageListDiv.innerHTML = ''; // Clear loading indicator

        if (messages.length === 0) {
            messageListDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Start a conversation!</p>';
        } else {
            messages.forEach(message => {
                const messageElement = document.createElement('div');
                messageElement.classList.add('message');
                // Determine if the message was sent by the current user
                if (message.sender_user_id == currentUserId) { // Use == for potential type coercion
                    messageElement.classList.add('sent');
                } else {
                    messageElement.classList.add('received');
                }
                messageElement.textContent = message.message_text; // Sanitize in real app
                messageListDiv.appendChild(messageElement);
            });
             // Scroll to the bottom of the message list
            messageListDiv.scrollTop = messageListDiv.scrollHeight;
        }

        // Store the other user's ID in the input area for sending messages
        messageInput.setAttribute('data-other-user-id', otherUserId);

         // Focus the input field after loading messages
         messageInput.focus();

        console.log('[openChat] Chat opened successfully.');

    } catch (error) {
        console.error('[openChat] CATCH BLOCK: Error fetching and displaying messages:', error); // Log in catch block
        messageListDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Error loading messages.</p>';
    }
}

async function sendMessage() {
    const messageInput = document.getElementById('messageInput');
    const messageText = messageInput.value.trim();
    // const currentUserId = 1; // TODO: Replace with actual logic to get current user ID - REMOVED
    const currentUserId = getCookie('user_id'); // Get user ID from cookie
    const otherUserId = messageInput.getAttribute('data-other-user-id'); // Get the recipient's ID

     if (!currentUserId) {
        console.error("User ID not found for sending message.");
        // Handle this case, maybe show an error to the user
        return;
    }

    if (!messageText || !otherUserId) {
        return; // Don't send empty messages or if recipient is unknown
    }

    const messageListDiv = document.getElementById('messageList');
    const apiUrl = `/api/messages`; // Endpoint for sending messages

    try {
        // TODO: Implement authentication (e.g., send token in headers)
        const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN' // TODO: Add actual token
            },
            body: JSON.stringify({
                sender_id: parseInt(currentUserId), // Ensure it's an integer
                receiver_id: parseInt(otherUserId), // Ensure it's an integer
                message_text: messageText
            })
        });

        if (!response.ok) {
             // Handle specific HTTP errors, e.g., 401 Unauthorized
            if (response.status === 401 || response.status === 403) {
                 console.error('Authentication failed. Cannot send message.');
                 // Optionally show an error message to the user in the UI
            } else {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
             return; // Stop if there was an error
        }

        const sentMessage = await response.json(); // Assuming backend returns the sent message

        // Add the sent message to the UI
        const messageElement = document.createElement('div');
        messageElement.classList.add('message', 'sent');
        messageElement.textContent = sentMessage.message_text; // Use response data if available
        messageListDiv.appendChild(messageElement);

        messageInput.value = ''; // Clear input
        messageListDiv.scrollTop = messageListDiv.scrollHeight; // Scroll to bottom

        // TODO: Update the last message preview in the user list for this chat

    } catch (error) {
        console.error('Error sending message:', error);
        // Optionally display an error message to the user
    }
}

// --- Sidebar Navigation (Keep this function if needed) ---
function navigateTo(path) {
    if (path === '/explore' || path === '/contest' || path === '/settings' || path === '/more') {
        alert(path + ' sayfasına yönlendiriliyor! (Demo)');
        // In a real app, update the active state visually if needed without reload
        document.querySelectorAll('.sidebar-menu-item').forEach(item => {
             item.classList.toggle('active', item.getAttribute('onclick') === `navigateTo('${path}')`);
        });

    } else {
        window.location.href = path; // Navigate for known paths
    }
}

// Helper function to get cookie value (still used for openChat and sendMessage for now)
function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split(';').shift();
    return null;
}

// Helper function to check if a string is a valid URL
function isValidUrl(string) {
    try {
        new URL(string);
        return true;
    } catch (e) {
        return false;
    }
}
