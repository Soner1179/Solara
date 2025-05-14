document.addEventListener('DOMContentLoaded', () => {
    const signupForm = document.getElementById('signup-form');
    const emailStage = document.getElementById('email-stage');
    const detailsStage = document.getElementById('details-stage');

    const emailInput = document.getElementById('email');
    const sendCodeButton = document.getElementById('send-code-button');

    const verificationCodeInput = document.getElementById('verificationCode');
    const usernameInput = document.getElementById('username');
    const passwordInput = document.getElementById('password');
    const confirmPasswordInput = document.getElementById('confirmPassword');
    const signupButton = document.getElementById('signup-button');

    const errorMessageDiv = document.getElementById('error-message');
    const successMessageDiv = document.getElementById('success-message');
    const changeEmailLinkDiv = document.getElementById('change-email-link');
    const backToEmailStageLink = document.getElementById('back-to-email-stage');

    // --- Stage 1: Send Verification Code ---
    sendCodeButton.addEventListener('click', async () => {
        errorMessageDiv.textContent = '';
        successMessageDiv.textContent = '';
        sendCodeButton.disabled = true;
        sendCodeButton.textContent = 'Gönderiliyor...';

        const email = emailInput.value.trim();
        if (!email) {
            errorMessageDiv.textContent = 'Lütfen e-posta adresinizi girin.';
            sendCodeButton.disabled = false;
            sendCodeButton.textContent = 'Doğrulama Kodu Gönder';
            return;
        }

        try {
            const response = await fetch('/api/send_verification_code', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email: email }),
            });
            const result = await response.json();

            if (response.ok && result.success) {
                successMessageDiv.textContent = result.message || 'Doğrulama kodu e-postanıza gönderildi.';
                emailStage.style.display = 'none';
                detailsStage.style.display = 'block';
                changeEmailLinkDiv.style.display = 'block'; // E-posta değiştir linkini göster
                emailInput.readOnly = true; // E-postayı ikinci aşamada değiştirilemez yap
            } else {
                errorMessageDiv.textContent = result.message || `Bir hata oluştu: ${response.status}`;
            }
        } catch (error) {
            console.error('Kod gönderme hatası:', error);
            errorMessageDiv.textContent = 'Sunucuya bağlanırken bir hata oluştu.';
        } finally {
            sendCodeButton.disabled = false;
            sendCodeButton.textContent = 'Doğrulama Kodu Gönder';
        }
    });

    // --- Stage 2: Sign Up with Verification Code ---
    signupForm.addEventListener('submit', async function(event) {
        event.preventDefault();
        // Sadece detailsStage görünürken bu submit işlemini yap
        if (detailsStage.style.display !== 'block') {
            return;
        }

        errorMessageDiv.textContent = '';
        successMessageDiv.textContent = ''; // Önceki başarı mesajlarını temizle
        signupButton.disabled = true;
        signupButton.textContent = 'Kayıt Olunuyor...';

        const email = emailInput.value.trim(); // E-posta hala gerekli
        const verificationCode = verificationCodeInput.value.trim();
        const username = usernameInput.value.trim();
        const password = passwordInput.value;
        const confirmPassword = confirmPasswordInput.value;

        if (!email || !verificationCode || !username || !password || !confirmPassword) {
            errorMessageDiv.textContent = 'Lütfen tüm alanları doldurun.';
            signupButton.disabled = false;
            signupButton.textContent = 'Kayıt Ol';
            return;
        }

        if (password !== confirmPassword) {
            errorMessageDiv.textContent = 'Şifreler eşleşmiyor.';
            signupButton.disabled = false;
            signupButton.textContent = 'Kayıt Ol';
            return;
        }

        const data = {
            email: email,
            username: username,
            password: password,
            verification_code: verificationCode,
        };

        try {
            const response = await fetch('/api/signup', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data),
            });
            const result = await response.json();

            if (response.ok && result.success) {
                alert('Kayıt başarılı ve e-posta doğrulandı! Giriş yapabilirsiniz.');
                window.location.href = '/login';
            } else {
                errorMessageDiv.textContent = result.message || `Bir hata oluştu: ${response.status}`;
            }
        } catch (error) {
            console.error('Kayıt hatası:', error);
            errorMessageDiv.textContent = 'Sunucuya bağlanırken bir hata oluştu.';
        } finally {
            signupButton.disabled = false;
            signupButton.textContent = 'Kayıt Ol';
        }
    });

    // --- Link to go back to email stage ---
    backToEmailStageLink.addEventListener('click', (e) => {
        e.preventDefault();
        emailStage.style.display = 'block';
        detailsStage.style.display = 'none';
        changeEmailLinkDiv.style.display = 'none';
        errorMessageDiv.textContent = '';
        successMessageDiv.textContent = '';
        emailInput.readOnly = false; // E-postayı tekrar düzenlenebilir yap
        // İsteğe bağlı olarak ikinci aşamadaki alanları temizleyebilirsiniz
        // verificationCodeInput.value = '';
        // usernameInput.value = '';
        // passwordInput.value = '';
        // confirmPasswordInput.value = '';
    });


    // Google signup button functionality (placeholder)
    document.querySelector('.google-button').addEventListener('click', function() {
        alert('Google ile kayıt henüz uygulanmadı!');
    });
});
