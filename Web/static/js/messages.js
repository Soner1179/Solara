// This file will contain JavaScript for the messages page
// It will fetch chat summaries and messages and display them.

document.addEventListener('DOMContentLoaded', () => {
    const currentUserId = 1; // TODO: Replace with actual logic to get current user ID
    fetchAndDisplayChatSummaries(currentUserId);

    // Add event listener for sending messages
    const sendButton = document.getElementById('sendButton');
    const messageInput = document.getElementById('messageInput');
    sendButton.addEventListener('click', sendMessage);
    messageInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter' && !e.shiftKey) { // Send on Enter (not Shift+Enter)
            e.preventDefault(); // Prevent newline
            sendMessage();
        }
    });
});

async function fetchAndDisplayChatSummaries(userId) {
    const userListContentDiv = document.querySelector('.user-list-content');
    const apiUrl = `/api/users/${userId}/chats`;

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

        const chatSummaries = await response.json();

        userListContentDiv.innerHTML = ''; // Clear existing static user items

        if (chatSummaries.length === 0) {
            userListContentDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">No chats available.</p>';
            return;
        }

        chatSummaries.forEach(chat => {
            const userItemElement = document.createElement('div');
            userItemElement.classList.add('user-item');
            userItemElement.setAttribute('data-other-user-id', chat.other_user_id); // Store other user's ID
            userItemElement.setAttribute('data-username', chat.other_username); // Store username
            userItemElement.setAttribute('data-avatar-url', chat.other_user_avatar_url); // Store avatar URL
            userItemElement.setAttribute('data-status', chat.other_user_status || ''); // Store status

            userItemElement.innerHTML = `
                <img src="${chat.other_user_avatar_url || 'https://randomuser.me/api/portraits/men/' + (chat.other_user_id % 100) + '.jpg'}" alt="Avatar" class="user-avatar">
                <div class="user-details">
                    <div class="user-name">${chat.other_username}</div>
                    <div class="last-message">${chat.last_message_text || 'No messages yet'}</div>
                </div>
                <div class="user-meta">
                    <span class="last-message-time">${chat.last_message_time ? new Date(chat.last_message_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}</span>
                </div>
            `;

            userItemElement.addEventListener('click', () => {
                // Remove active class from all user items
                document.querySelectorAll('.user-item').forEach(item => item.classList.remove('active'));
                // Add active class to the clicked item
                userItemElement.classList.add('active');

                // Open the chat for this user
                openChat(
                    userItemElement.getAttribute('data-other-user-id'),
                    userItemElement.getAttribute('data-username'),
                    userItemElement.getAttribute('data-avatar-url'),
                    userItemElement.getAttribute('data-status')
                );
            });

            userListContentDiv.appendChild(userItemElement);
        });

        // Optional: Automatically open the first chat
        const firstUserItem = userListContentDiv.querySelector('.user-item');
        if (firstUserItem) {
            firstUserItem.click();
        }


    } catch (error) {
        console.error('Error fetching and displaying chat summaries:', error);
        userListContentDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Error loading chats.</p>';
    }
}

async function openChat(otherUserId, username, avatarUrl, status) {
    const currentUserId = 1; // TODO: Replace with actual logic to get current user ID
    const messageListDiv = document.getElementById('messageList');
    const chatHeaderAvatar = document.getElementById('chatHeaderAvatar');
    const chatHeaderName = document.getElementById('chatHeaderName');
    const chatHeaderStatus = document.getElementById('chatHeaderStatus');
    const chatArea = document.getElementById('chatArea');
    const messageInput = document.getElementById('messageInput');

    // Update chat header
    chatHeaderAvatar.src = avatarUrl || 'https://randomuser.me/api/portraits/men/' + (otherUserId % 100) + '.jpg';
    chatHeaderName.textContent = username;
    chatHeaderStatus.textContent = status;

    // Show chat area and clear previous messages
    chatArea.style.display = 'flex';
    messageListDiv.innerHTML = '';

    const messagesApiUrl = `/api/messages/${currentUserId}/${otherUserId}`; // Assuming endpoint is user1Id/user2Id

    try {
        // TODO: Implement authentication
        const response = await fetch(messagesApiUrl, {
             headers: {
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const messages = await response.json();

        if (messages.length === 0) {
            messageListDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Start a conversation!</p>';
        } else {
            messages.forEach(message => {
                const messageElement = document.createElement('div');
                messageElement.classList.add('message');
                // Determine if the message was sent by the current user
                if (message.sender_id === currentUserId) {
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


    } catch (error) {
        console.error('Error fetching and displaying messages:', error);
        messageListDiv.innerHTML = '<p style="text-align: center; padding: 20px; color: #888;">Error loading messages.</p>';
    }
}

async function sendMessage() {
    const messageInput = document.getElementById('messageInput');
    const messageText = messageInput.value.trim();
    const currentUserId = 1; // TODO: Replace with actual logic to get current user ID
    const otherUserId = messageInput.getAttribute('data-other-user-id'); // Get the recipient's ID

    if (!messageText || !otherUserId) {
        return; // Don't send empty messages or if recipient is unknown
    }

    const messageListDiv = document.getElementById('messageList');
    const apiUrl = `/api/messages`; // Endpoint for sending messages

    try {
        // TODO: Implement authentication
        const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                // 'Authorization': `Bearer YOUR_AUTH_TOKEN` // TODO: Add actual token
            },
            body: JSON.stringify({
                sender_id: currentUserId,
                receiver_id: parseInt(otherUserId), // Ensure it's an integer
                message_text: messageText
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
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
