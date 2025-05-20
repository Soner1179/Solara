document.addEventListener('DOMContentLoaded', function() {
    console.log('notifications.js loaded');

    // Function to get user ID from cookie (similar to other web scripts)
    function getUserIdFromCookie() {
        const name = "user_id=";
        const decodedCookie = decodeURIComponent(document.cookie);
        const ca = decodedCookie.split(';');
        for(let i = 0; i < ca.length; i++) {
            let c = ca[i];
            while (c.charAt(0) === ' ') {
                c = c.substring(1);
            }
            if (c.indexOf(name) === 0) {
                return c.substring(name.length, c.length);
            }
        }
        return "";
    }

    const userId = getUserIdFromCookie();
    const notificationsList = document.getElementById('notifications-list'); // Assuming an element with this ID exists

    if (!userId) {
        console.error('User ID not found in cookie. Cannot fetch notifications.');
        if (notificationsList) {
            notificationsList.innerHTML = '<p>Bildirimleri görmek için giriş yapın.</p>';
        }
        return;
    }

    console.log('Fetching notifications and follow requests for user ID:', userId);

    // Function to fetch notifications and follow requests
    async function fetchNotificationsAndRequests() {
        if (!notificationsList) return;

        notificationsList.innerHTML = '<p>Bildirimler yükleniyor...</p>'; // Loading indicator

        try {
            // Fetch regular notifications
            const notificationsResponse = await fetch(`/api/users/${userId}/notifications`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    // Include JWT token if web uses it for auth
                    // 'Authorization': 'Bearer YOUR_JWT_TOKEN'
                },
            });

            if (!notificationsResponse.ok) {
                 console.error('Failed to fetch notifications:', notificationsResponse.status, notificationsResponse.statusText);
                 // Don't return, try to fetch requests even if notifications fail
            }
            const notifications = notificationsResponse.ok ? await notificationsResponse.json() : [];
            console.log('Fetched notifications:', notifications);

            // Fetch follow requests
            const followRequestsResponse = await fetch(`/api/users/me/follow_requests`, {
                 method: 'GET',
                 headers: {
                     'Content-Type': 'application/json',
                     // Include JWT token if web uses it for auth
                     // 'Authorization': 'Bearer YOUR_JWT_TOKEN'
                 },
            });

            if (!followRequestsResponse.ok) {
                 console.error('Failed to fetch follow requests:', followRequestsResponse.status, followRequestsResponse.statusText);
                 // Don't return, display whatever data we have
            }
            const followRequests = followRequestsResponse.ok ? await followRequestsResponse.json() : [];
            console.log('Fetched follow requests:', followRequests);


            // Combine and sort all items by creation date (newest first)
            const allItems = [...notifications, ...followRequests];
            allItems.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));


            displayNotifications(allItems); // Display combined list

        } catch (error) {
            console.error('Error fetching notifications and requests:', error);
            if (notificationsList) {
                 notificationsList.innerHTML = '<p>Bildirimler yüklenirken bir hata oluştu.</p>';
            }
        }
    }

    // Function to display notifications and follow requests
    function displayNotifications(items) {
        if (!notificationsList) return;

        notificationsList.innerHTML = ''; // Clear previous content

        if (items.length === 0) {
            notificationsList.innerHTML = '<p>Henüz bildiriminiz veya takip isteğiniz yok.</p>';
            return;
        }

        items.forEach(item => {
            const itemElement = document.createElement('div');
            itemElement.classList.add('notification-item'); // Use a common class

            const createdAt = new Date(item.created_at);
            const timeAgoText = timeAgo(createdAt);

            if (item.type === 'follow_request') {
                 // Handle Follow Request display
                 const requesterUsername = item.requester_username || 'Birisi';
                 const requesterAvatarUrl = item.requester_profile_picture_url || '/static/images/default-avatar.png'; // Use default avatar

                 itemElement.innerHTML = `
                     <div class="notification-avatar">
                         <img src="${requesterAvatarUrl}" alt="${requesterUsername}'s avatar">
                     </div>
                     <div class="notification-content">
                         <strong>${requesterUsername}</strong> sizi takip etmek istiyor.
                         <div class="notification-timestamp">${timeAgoText}</div>
                     </div>
                     <div class="follow-request-actions">
                         <button class="accept-request-btn" data-request-id="${item.request_id}">Kabul Et</button>
                         <button class="reject-request-btn" data-request-id="${item.request_id}">Reddet</button>
                     </div>
                 `;

                 // Add event listeners for buttons
                 itemElement.querySelector('.accept-request-btn').addEventListener('click', function() {
                     const requestId = this.dataset.requestId;
                     acceptFollowRequest(requestId, itemElement);
                 });

                 itemElement.querySelector('.reject-request-btn').addEventListener('click', function() {
                     const requestId = this.dataset.requestId;
                     rejectFollowRequest(requestId, itemElement);
                 });

                 // Optional: Add click listener to navigate to requester's profile
                 itemElement.querySelector('.notification-content').addEventListener('click', function() {
                     if (item.requester_username) {
                         window.location.href = `/profile/${item.requester_username}`; // Navigate to profile page
                     }
                 });


            } else {
                // Handle other notification types (existing logic adapted)
                if (!item.is_read) {
                    itemElement.classList.add('unread'); // Add class for unread notifications
                }

                let notificationText = 'Yeni bildirim.';
                const actorUsername = item.actor_username || 'Birisi';
                const messagePreview = item.message_preview || '';
                const actorAvatarUrl = item.actor_profile_picture_url || '/static/images/default-avatar.png'; // Use default avatar


                switch (item.type) {
                    case 'like':
                        notificationText = `<strong>${actorUsername}</strong> gönderinizi beğendi.`;
                        break;
                    case 'comment':
                        notificationText = `<strong>${actorUsername}</strong> gönderinize yorum yaptı: "${messagePreview}..."`;
                        break;
                    case 'follow':
                        notificationText = `<strong>${actorUsername}</strong> sizi takip etmeye başladı.`;
                        break;
                    case 'message':
                        notificationText = `<strong>${actorUsername}</strong> size mesaj gönderdi: "${messagePreview}..."`;
                        break;
                    default:
                        notificationText = 'Yeni bildirim.';
                }

                itemElement.innerHTML = `
                    <div class="notification-avatar">
                        <img src="${actorAvatarUrl}" alt="${actorUsername}'s avatar">
                    </div>
                    <div class="notification-content">${notificationText}
                        <div class="notification-timestamp">${timeAgoText}</div>
                    </div>
                    ${item.is_read ? '<div class="read-indicator">✓</div>' : ''}
                    <button class="delete-notification-btn" data-notification-id="${item.notification_id}">X</button>
                `;

                // Add click listener to mark as read and navigate
                // Prevent event propagation from the delete button
                itemElement.addEventListener('click', function(event) {
                    // Check if the clicked element or its parent is the delete button
                    if (event.target.classList.contains('delete-notification-btn')) {
                        return; // Do nothing if the delete button was clicked
                    }

                    if (!item.is_read) {
                        markNotificationAsRead(item.notification_id, itemElement);
                    }
                    // Navigate to the relevant page based on notification type
                    if (item.type === 'like' || item.type === 'comment') {
                        if (item.post_id) {
                            window.location.href = `/post/${item.post_id}`; // Navigate to single post page
                        }
                    } else if (item.type === 'follow') {
                         if (item.actor_username) {
                             window.location.href = `/profile/${item.actor_username}`; // Navigate to profile page
                         }
                    } else if (item.type === 'message') {
                         // For messages, navigate to the chat page with the sender
                         // Need to determine the chat partner's username.
                         // Assuming the actor_username is the sender in a message notification
                         if (item.actor_username) {
                             window.location.href = `/messages?chat_partner=${item.actor_username}`; // Navigate to messages page
                         }
                    }
                });

                // Add event listener for the delete button
                itemElement.querySelector('.delete-notification-btn').addEventListener('click', function() {
                    const notificationId = this.dataset.notificationId;
                    deleteNotification(notificationId, itemElement);
                });

            }

            notificationsList.appendChild(itemElement);
        });
    }

    // Function to mark notification as read
    async function markNotificationAsRead(notificationId, element) {
         try {
            const response = await fetch(`/api/notifications/${notificationId}/read`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    // Include JWT token if web uses it for auth
                    // 'Authorization': 'Bearer YOUR_JWT_TOKEN'
                },
            });

            if (response.ok) {
                console.log(`Notification ${notificationId} marked as read.`);
                if (element) {
                    element.classList.remove('unread'); // Remove unread class from UI
                    // Optionally add a read indicator
                    let readIndicator = element.querySelector('.read-indicator');
                    if (!readIndicator) {
                         readIndicator = document.createElement('div');
                         readIndicator.classList.add('read-indicator');
                         readIndicator.textContent = '✓';
                         element.appendChild(readIndicator);
                    }
                }
            } else {
                 console.error(`Failed to mark notification ${notificationId} as read:`, response.status, response.statusText);
            }
         } catch (error) {
             console.error(`Error marking notification ${notificationId} as read:`, error);
         }
    }

    // Function to delete a notification
    async function deleteNotification(notificationId, element) {
        if (confirm('Bu bildirimi silmek istediğinizden emin misiniz?')) { // Confirmation dialog
            try {
                const response = await fetch(`/api/notifications/${notificationId}`, {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json',
                        // Include JWT token if web uses it for auth
                        // 'Authorization': 'Bearer YOUR_JWT_TOKEN'
                    },
                });

                if (response.ok) {
                    console.log(`Notification ${notificationId} deleted.`);
                    // Remove the notification element from the UI
                    if (element) {
                        element.remove();
                    }
                    // Optionally show a success message
                    // alert('Bildirim silindi.'); // Simple alert for now
                    // No need to refetch, as the item is removed from the UI
                } else {
                    console.error(`Failed to delete notification ${notificationId}:`, response.status, response.statusText);
                    alert('Bildirim silinemedi.'); // Simple alert for now
                }
            } catch (error) {
                console.error(`Error deleting notification ${notificationId}:`, error);
                alert('Bildirim silinirken bir hata oluştu.'); // Simple alert for now
            }
        }
    }


    // Function to accept a follow request
    async function acceptFollowRequest(requestId, element) {
        try {
            const response = await fetch(`/api/follow_requests/${requestId}/accept`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    // Include JWT token if web uses it for auth
                    // 'Authorization': 'Bearer YOUR_JWT_TOKEN'
                },
            });

            if (response.ok) {
                console.log(`Follow request ${requestId} accepted.`);
                // Remove the request element from the UI
                if (element) {
                    element.remove();
                }
                // Optionally show a success message
                alert('Takip isteği kabul edildi.'); // Simple alert for now
                // Refresh the list to show the new follow notification (optional)
                fetchNotificationsAndRequests();
            } else {
                console.error(`Failed to accept follow request ${requestId}:`, response.status, response.statusText);
                alert('Takip isteği kabul edilemedi.'); // Simple alert for now
            }
        } catch (error) {
            console.error(`Error accepting follow request ${requestId}:`, error);
            alert('Takip isteği kabul edilirken bir hata oluştu.'); // Simple alert for now
        }
    }

    // Function to reject a follow request
    async function rejectFollowRequest(requestId, element) {
        try {
            const response = await fetch(`/api/follow_requests/${requestId}/reject`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    // Include JWT token if web uses it for auth
                    // 'Authorization': 'Bearer YOUR_JWT_TOKEN'
                },
            });

            if (response.ok) {
                console.log(`Follow request ${requestId} rejected.`);
                // Remove the request element from the UI
                if (element) {
                    element.remove();
                }
                // Optionally show a success message
                alert('Takip isteği reddedildi.'); // Simple alert for now
            } else {
                console.error(`Failed to reject follow request ${requestId}:`, response.status, response.statusText);
                alert('Takip isteği reddedilemedi.'); // Simple alert for now
            }
        } catch (error) {
            console.error(`Error rejecting follow request ${requestId}:`, error);
            alert('Takip isteği reddedilirken bir hata oluştu.'); // Simple alert for now
        }
    }


    // Basic time ago function (can be replaced with a library)
    function timeAgo(date) {
        const seconds = Math.floor((new Date() - date) / 1000);
        let interval = Math.floor(seconds / 31536000);
        if (interval > 1) return interval + " yıl önce";
        interval = Math.floor(seconds / 2592000);
        if (interval > 1) return interval + " ay önce";
        interval = Math.floor(seconds / 86400);
        if (interval > 1) return interval + " gün önce";
        interval = Math.floor(seconds / 3600);
        if (interval > 1) return interval + " saat önce";
        interval = Math.floor(seconds / 60);
        if (interval > 1) return interval + " dakika önce";
        return Math.floor(seconds) + " saniye önce";
    }


    // Fetch notifications and requests when the page loads
    fetchNotificationsAndRequests();
});
