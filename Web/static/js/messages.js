// This file will contain JavaScript for the messages page
// It will fetch chat summaries and messages and display them.

// Removed client-side cookie check function

// Helper to get user ID, prioritizing server-provided values
function getAuthenticatedUserId() {
    // Check window global variable
    if (window.APPLICATION_USER_ID !== undefined && window.APPLICATION_USER_ID !== null) {
        // Ensure it's not an empty string if that's considered invalid
        const idVal = String(window.APPLICATION_USER_ID).trim();
        if (idVal !== "") {
            console.log("[getAuthenticatedUserId] Using user ID from window.APPLICATION_USER_ID:", window.APPLICATION_USER_ID);
            return window.APPLICATION_USER_ID; // Return raw value (could be number or string)
        }
    }

    // Check body data attribute
    const bodyElement = document.querySelector('body[data-user-id]');
    if (bodyElement && bodyElement.dataset.userId !== undefined && bodyElement.dataset.userId !== null) {
        const idVal = String(bodyElement.dataset.userId).trim();
        if (idVal !== "") {
            console.log("[getAuthenticatedUserId] Using user ID from body[data-user-id]:", bodyElement.dataset.userId);
            return bodyElement.dataset.userId; // Data attributes are strings
        }
    }

    // Fallback to cookie
    const cookieUserId = getCookie('user_id'); // getCookie returns the value or null
    if (cookieUserId !== null) {
        const idVal = String(cookieUserId).trim();
        if (idVal !== "") {
            console.warn("[getAuthenticatedUserId] Fallback: Using user ID from cookie. Value:", cookieUserId);
            return cookieUserId;
        }
    }

    console.error("[getAuthenticatedUserId] Critical: User ID not found or is empty via window, data attribute, or cookie. Chat functionality will likely fail.");
    return null; // Explicitly return null if no valid ID found
}


document.addEventListener('DOMContentLoaded', async () => { // Made async to await fetchAndDisplayChatSummaries

    // Check if user is authenticated before fetching chat summaries
    const currentUserId = getAuthenticatedUserId();

    // Rely on backend redirect for unauthenticated users.
    // Only proceed with fetching chat summaries if user ID is available.
    if (currentUserId !== null) {
        console.log(`[DOMContentLoaded] User authenticated with ID: ${currentUserId}. Attempting to fetch chat summaries.`);
        await fetchAndDisplayChatSummaries(); // Call with user ID, backend will handle authentication
    } else {
         console.log("[DOMContentLoaded] User not authenticated or ID not found. Chat summaries will not be fetched. Backend should redirect if necessary.");
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
            const currentUserId = getAuthenticatedUserId();
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
        const currentUserId = getAuthenticatedUserId(); // Get current user ID for the search
        fetchAndDisplayUsersForNewMessage(searchTerm, currentUserId); // Call with the search term and current user ID
    });

    // --- Event Delegation for User List Clicks ---
    const userListContentDiv = document.querySelector('.user-list-content');
    if (userListContentDiv) {
        userListContentDiv.addEventListener('click', (event) => {
            const clickedItem = event.target.closest('.user-item'); // Find the closest user-item ancestor
            if (!clickedItem) {
                return; // Click wasn't on a user item or its descendant
            }

            // Check authentication
            const currentUserId = getAuthenticatedUserId();
            if (currentUserId === null) {
                console.log("[User List Click] User not authenticated or ID not found. Cannot open chat.");
                return;
            }

            // Remove active class from all items
            document.querySelectorAll('.user-item.active').forEach(item => item.classList.remove('active'));
            // Add active class to the clicked item
            clickedItem.classList.add('active');

            // Get data and open chat
            const otherUserId = clickedItem.getAttribute('data-other-user-id');
            const username = clickedItem.getAttribute('data-username');
            const avatarUrl = clickedItem.getAttribute('data-avatar-url');
            const status = clickedItem.getAttribute('data-status');

            // Add detailed logging before calling openChat
            console.log(`[User List Click Delegated] Data retrieved:`, { otherUserId, username, avatarUrl, status });
            console.log(`[User List Click Delegated] Calling openChat...`);

            openChat(otherUserId, username, avatarUrl, status);
        });
    }
    // --- End Event Delegation ---


}); // End of DOMContentLoaded

// Function to fetch and display users for starting a new message
// Accepts an optional search term and the current user ID
async function fetchAndDisplayUsersForNewMessage(searchTerm = null, currentUserId) { // Added currentUserId parameter
    const userListForNewMessageDiv = document.getElementById('userListForNewMessage');
    userListForNewMessageDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Kullanıcılar yükleniyor...</p>'; // Show loading

    // Construct the API URL
    // The currentUserId parameter is passed from the click handler (where getCookie was called).
    // We will still attempt to use it for exclude_user_id if available,
    // but we won't block the API call based on it here.
    // The server will handle authentication.
    let apiUrl = '/api/users/search'; // Corrected endpoint
    const params = new URLSearchParams();
    // Always append the 'query' parameter, even if searchTerm is null or empty
    params.append('query', searchTerm || ''); // Use empty string if searchTerm is null/empty
    // Always add current_user_id for backend filtering/auth, as exclude_user_id
    if (currentUserId) {
         params.append('exclude_user_id', currentUserId); // Changed 'current_user_id' to 'exclude_user_id'
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
            <img src="${avatarSrc}" alt="Avatar" class="user-item-avatar">
            <div class="user-item-details">
                <div class="user-item-name">${user.username}</div>
                <!-- Could add other user info here if available -->
            </div>
        `;

        // REMOVED the complex logic from here.
        // Add a simple click listener just to close the modal and trigger the main logic
        userItemElement.addEventListener('click', () => {
            const selectedUserId = userItemElement.getAttribute('data-user-id');
            const selectedUsername = userItemElement.getAttribute('data-username');
            const selectedAvatarUrl = userItemElement.getAttribute('data-avatar-url');

            // Close modal
            const newMessageModal = document.getElementById('newMessageModal');
            const userSearchInput = document.getElementById('userSearchInput');
            const userListForNewMessageDiv = document.getElementById('userListForNewMessage');
            newMessageModal.style.display = 'none';
            userSearchInput.value = '';
            userListForNewMessageDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Kullanıcılar yükleniyor...</p>';

            // Call the function to handle adding/selecting the user in the main list
            handleUserSelectionFromModal(selectedUserId, selectedUsername, selectedAvatarUrl);
        });

        userListForNewMessageDiv.appendChild(userItemElement);
    });
}

// New function to handle user selection logic after modal closes
function handleUserSelectionFromModal(selectedUserId, selectedUsername, selectedAvatarUrl) {
    console.log('[handleUserSelectionFromModal] Handling selection for:', selectedUsername, 'ID:', selectedUserId);

    const userListContentDiv = document.querySelector('.user-list-content');
    let targetUserItem = userListContentDiv.querySelector(`.user-item[data-other-user-id="${selectedUserId}"]`);

    if (!targetUserItem) {
        // User not in the list, create and add it
        console.log(`[handleUserSelectionFromModal] User ${selectedUsername} not in list. Creating new item.`);
        targetUserItem = document.createElement('div'); // Assign to targetUserItem
        targetUserItem.classList.add('user-item');
        targetUserItem.setAttribute('data-other-user-id', selectedUserId);
        targetUserItem.setAttribute('data-username', selectedUsername);
        targetUserItem.setAttribute('data-avatar-url', selectedAvatarUrl);
        targetUserItem.setAttribute('data-status', ''); // Status unknown

        const newAvatarSrc = selectedAvatarUrl && isValidUrl(selectedAvatarUrl)
            ? selectedAvatarUrl
            : 'https://randomuser.me/api/portraits/men/' + (selectedUserId % 100) + '.jpg'; // Fallback

        targetUserItem.innerHTML = `
            <img src="${newAvatarSrc}" alt="Avatar" class="user-item-avatar">
            <div class="user-item-details">
                <div class="user-item-name">${selectedUsername}</div>
                <div class="user-item-last-message"></div> <!-- No last message yet -->
            </div>
            <div class="user-item-meta">
                <span class="user-item-time"></span> <!-- No time yet -->
            </div>
        `;
        // Add the new item to the top of the list
        // Ensure the placeholder is removed if it exists
        const placeholder = userListContentDiv.querySelector('p');
        if (placeholder && placeholder.textContent.includes('No chats available')) {
            userListContentDiv.innerHTML = ''; // Clear placeholder
        }
        userListContentDiv.prepend(targetUserItem);
    } else {
         console.log(`[handleUserSelectionFromModal] User ${selectedUsername} found in list.`);
    }

    // Manually set the active state on the target item (new or existing)
    document.querySelectorAll('.user-item.active').forEach(item => item.classList.remove('active'));
    targetUserItem.classList.add('active');

    // Directly open the chat using data from the target item
    const userId = targetUserItem.getAttribute('data-other-user-id');
    const username = targetUserItem.getAttribute('data-username');
    const avatarUrl = targetUserItem.getAttribute('data-avatar-url');
    const status = targetUserItem.getAttribute('data-status');
    console.log(`[handleUserSelectionFromModal] Directly calling openChat for user ${username}.`);
    openChat(userId, username, avatarUrl, status);
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

    const currentUserId = getAuthenticatedUserId();
    if (currentUserId === null) {
        console.error("[fetchAndDisplayChatSummaries] User ID not found or invalid. Cannot fetch chat summaries. Backend should have redirected.");
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
                <img src="${chatAvatarSrc}" alt="Avatar" class="user-item-avatar">
                <div class="user-item-details">
                    <div class="user-item-name">${chat.partner_username}</div>
                    <div class="user-item-last-message">${chat.message_text || 'No messages yet'}</div> <!-- Use message_text from summary -->
                </div>
                <div class="user-item-meta">
                    <span class="user-item-time">${chat.last_message_timestamp ? new Date(chat.last_message_timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}</span>
                    <!-- Optionally, add unread count here if available from backend -->
                    <!-- <span class="user-item-unread">3</span> -->
                </div>
            `;

            // REMOVED direct event listener - delegation handles this now.

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
    console.log(`[openChat] START - Opening chat for ${username} (ID: ${otherUserId})`);

    const messageListDiv = document.getElementById('messageList');
    const chatHeaderAvatar = document.getElementById('chatHeaderAvatar');
    const chatHeaderName = document.getElementById('chatHeaderName');
    const chatHeaderStatus = document.getElementById('chatHeaderStatus');
    const chatArea = document.getElementById('chatArea');
    const messageInput = document.getElementById('messageInput');

    if (!chatArea || !messageListDiv || !chatHeaderAvatar || !chatHeaderName || !chatHeaderStatus || !messageInput) {
        console.error("[openChat] One or more critical chat UI elements are missing from the DOM!");
        return;
    }

    // Initial UI setup for opening a chat
    const chatHeaderAvatarSrc = avatarUrl && isValidUrl(avatarUrl)
        ? avatarUrl
        : 'https://randomuser.me/api/portraits/men/' + (otherUserId % 100) + '.jpg'; // Fallback image
    chatHeaderAvatar.src = chatHeaderAvatarSrc;
    chatHeaderName.textContent = username;
    // Set initial status; will be cleared if currentUserId is null and user wants no loading text
    chatHeaderStatus.textContent = status || 'Yükleniyor...'; 
    chatArea.style.display = 'flex';
    // Set initial message list content; will be cleared if currentUserId is null
    messageListDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Loading messages...</p>'; 

    const currentUserId = getAuthenticatedUserId();
    console.log(`[openChat] Attempting to use currentUserID: ${currentUserId}`);


    if (currentUserId === null) {
        console.error("[openChat] CRITICAL: currentUserId is null. Cannot fetch messages. Check logs from getAuthenticatedUserId() to see why it failed to retrieve a valid user ID. Ensure backend correctly provides user_id via window.APPLICATION_USER_ID or data-user-id on the body tag in messages.html.");
        // User requested to remove loading/error UI texts if ID is missing.
        chatHeaderStatus.textContent = status || ''; // Use provided status or clear if it was 'Yükleniyor...'
        messageListDiv.innerHTML = ''; // Clear "Loading messages..."
        return; // Stop further execution
    }

    // If currentUserId is valid, and we have otherUserId from the function parameter,
    // set the recipient ID on the message input field.
    // This allows sendMessage to work even if fetching previous messages fails.
    if (otherUserId) {
        messageInput.setAttribute('data-other-user-id', String(otherUserId));
        console.log(`[openChat] Set data-other-user-id to: ${otherUserId} on messageInput.`);
    } else {
        console.error("[openChat] otherUserId is null or undefined. Cannot set data-other-user-id for sending messages.");
        messageInput.removeAttribute('data-other-user-id'); // Clear any old attribute
    }

    // If currentUserId is valid, proceed to fetch messages
    // The "Loading messages..." and "Yükleniyor..." texts set above will be replaced by actual content or error messages from the fetch attempt.
    console.log(`[openChat] Valid currentUserID: ${currentUserId}. Proceeding to fetch messages.`);
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
                messageElement.classList.add('message-bubble');
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

         // Focus the input field after loading messages
         messageInput.focus();

        console.log('[openChat] Chat opened successfully.');

    } catch (error) {
        console.error('[openChat] CATCH BLOCK: Error fetching and displaying messages:', error); // Log in catch block
        messageListDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Error loading messages.</p>';
    }
    console.log(`[openChat] END - Finished opening chat for ${username}`); // Log end
}

async function sendMessage() {
    const messageInput = document.getElementById('messageInput');
    const messageText = messageInput.value.trim();
    const currentUserId = getAuthenticatedUserId(); // Get user ID from HTML/global var or fallback to cookie
    const otherUserId = messageInput.getAttribute('data-other-user-id'); // Get the recipient's ID

    console.log(`[sendMessage] Attempting to send message. Text: "${messageText}", Current User ID: ${currentUserId}, Other User ID: ${otherUserId}`);

     if (currentUserId === null) {
        console.error("User ID not found or invalid for sending message.");
        // Handle this case, maybe show an error to the user
        return;
    }

    if (!messageText || !otherUserId) {
        if (!messageText) {
            console.log("[sendMessage] Message text is empty. Not sending.");
        }
        if (!otherUserId) {
            console.error("[sendMessage] Cannot send message: otherUserId is missing. The 'data-other-user-id' attribute on messageInput might not be set correctly by the openChat function, possibly due to an earlier error in openChat (e.g., failure to get currentUserId or an issue when initially trying to load the chat).");
        }
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
            if (response.status === 401 || response.status === 403) {
                console.error('Authentication failed. Cannot send message. Status:', response.status);
                alert('Mesaj gönderilemedi: Kimlik doğrulama hatası. Lütfen tekrar giriş yapmayı deneyin veya yöneticiyle iletişime geçin.');
            } else {
                const errorText = await response.text().catch(() => "Ayrıntı yok"); // Get more error details, with a fallback
                console.error(`HTTP error! status: ${response.status}, response text: ${errorText}`);
                alert(`Mesaj gönderilemedi: Sunucu hatası (${response.status}). Lütfen daha sonra tekrar deneyin. Detaylar konsolda bulunabilir.`);
            }
            return; // Stop if there was an error
        }

        const sentMessage = await response.json(); // Assuming backend returns the sent message

        // Add the sent message to the UI
        const messageElement = document.createElement('div');
        messageElement.classList.add('message-bubble', 'sent');
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
