document.addEventListener('DOMContentLoaded', () => {
    // Logo Etkileşimi
    const logo = document.querySelector('.sidebar-left .logo');
    if (logo) {
        logo.addEventListener('click', () => {
            alert('Connected Logo Tıklandı!');
        });
    }

    // Sol Sidebar Link Etkileşimleri
    const sidebarLinks = document.querySelectorAll('.sidebar-left nav ul li a');
    sidebarLinks.forEach(link => {
        link.addEventListener('click', (event) => {
            event.preventDefault(); // Sayfa yenilemesini engelle
            alert(`${link.textContent.trim()} Linkine Tıklandı!`);
            // İsteğe bağlı: Aktif linki vurgulama (CSS sınıfı ekleyerek)
            sidebarLinks.forEach(l => l.classList.remove('active-link')); // Önce tüm aktif sınıfları kaldır
            link.classList.add('active-link'); // Tıklanan linke aktif sınıfı ekle
        });
    });

    // Arama Barı Etkileşimi (Odaklanma)
    const searchInput = document.querySelector('.search-bar input[type="text"]');
    if (searchInput) {
        searchInput.addEventListener('focus', () => {
            console.log('Arama barına odaklanıldı.');
            // İsteğe bağlı: Arama barını vurgulama (CSS sınıfı ekleyerek)
            searchInput.classList.add('focused-input');
        });
        searchInput.addEventListener('blur', () => {
            searchInput.classList.remove('focused-input'); // Odak kaybında vurgulamayı kaldır
        });
    }

    // Bildirimler ve Mesajlar İkonları Etkileşimi
    const notificationsIcon = document.querySelector('.user-profile .notifications');
    const messagesIcon = document.querySelector('.user-profile .messages');

    if (notificationsIcon) {
        notificationsIcon.addEventListener('click', () => {
            alert('Bildirimler İkonuna Tıklandı!');
        });
    }

    if (messagesIcon) {
        messagesIcon.addEventListener('click', () => {
            alert('Mesajlar İkonuna Tıklandı!');
        });
    }

    // Profil Bilgisi Etkileşimi
    const profileInfo = document.querySelector('.user-profile .profile-info');
    if (profileInfo) {
        profileInfo.addEventListener('click', () => {
            alert('Profil Bilgisine Tıklandı!');
        });
    }

    // Gönderi Girişi Alanı Etkileşimi
    const postInput = document.querySelector('.post-input-header input[type="text"]');
    if (postInput) {
        postInput.addEventListener('click', () => {
            postInput.focus(); // Input alanına odaklan
        });
    }

    // Gönderi Girişi Eylemleri (Fotoğraf, Duygu/Aktivite, Gönder)
    const photoButton = document.querySelector('.post-input-actions .actions-left button:nth-child(1)');
    const feelingActivityButton = document.querySelector('.post-input-actions .actions-left button:nth-child(2)');
    const postButton = document.querySelector('.post-input-actions .actions-right button');

    if (photoButton) {
        photoButton.addEventListener('click', () => {
            alert('Fotoğraf Ekle Butonuna Tıklandı!');
        });
    }

    if (feelingActivityButton) {
        feelingActivityButton.addEventListener('click', () => {
            alert('Duygu/Aktivite Ekle Butonuna Tıklandı!');
        });
    }

    if (postButton) {
        postButton.addEventListener('click', () => {
            alert('Gönder Butonuna Tıklandı!');
        });
    }

    // Feed Post Eylemleri (Beğen, Yorum, Paylaş) - İlk gönderi için
    const feedPostActions = document.querySelectorAll('.feed-post .post-actions');
    feedPostActions.forEach(postAction => {
        const likeButton = postAction.querySelector('.actions-left button:nth-child(1)');
        const commentButton = postAction.querySelector('.actions-left button:nth-child(2)');
        const shareButton = postAction.querySelector('.actions-right button');

        if (likeButton) {
            likeButton.addEventListener('click', () => {
                const likeCountSpan = likeButton.querySelector('span');
                let likeCount = parseInt(likeCountSpan ? likeCountSpan.textContent : 0);
                const isLiked = likeButton.classList.contains('liked');

                if (isLiked) {
                    likeButton.classList.remove('liked');
                    likeButton.innerHTML = '<i class="far fa-thumbs-up"></i> Like' + (likeCountSpan ? ` <span style="color: #6c757d;">${likeCountSpan.textContent}</span>` : '');
                    alert('Beğenmekten Vazgeçildi!');
                } else {
                    likeButton.classList.add('liked');
                    likeButton.innerHTML = '<i class="fas fa-thumbs-up"></i> Liked' + (likeCountSpan ? ` <span style="color: #6c757d;">${likeCountSpan.textContent}</span>` : '');
                    alert('Beğenildi!');
                }
            });
        }

        if (commentButton) {
            commentButton.addEventListener('click', () => {
                alert('Yorum Yap Butonuna Tıklandı!');
            });
        }

        if (shareButton) {
            shareButton.addEventListener('click', () => {
                alert('Paylaş Butonuna Tıklandı!');
            });
        }
    });


    // Sağ Sidebar Link Etkileşimleri (Etkinlikler, Doğum Günleri, Sohbetler, Online Kişiler)
    const rightSidebarLinks = document.querySelectorAll('.sidebar-right .sidebar-right-section ul li a');
    rightSidebarLinks.forEach(link => {
        link.addEventListener('click', (event) => {
            event.preventDefault(); // Sayfa yenilemesini engelle
            alert(`${link.textContent.trim()} Linkine Tıklandı! (Sağ Sidebar)`);
            // İsteğe bağlı: Aktif linki vurgulama (CSS sınıfı ekleyerek - sağ sidebar için farklı sınıf kullanabilirsiniz)
            rightSidebarLinks.forEach(l => l.classList.remove('active-right-link')); // Önce tüm aktif sınıfları kaldır
            link.classList.add('active-right-link'); // Tıklanan linke aktif sınıfı ekle
        });
    });


});