document.addEventListener('DOMContentLoaded', () => {
    const themeRadios = document.querySelectorAll('input[name="theme"]');
    const htmlElement = document.documentElement; // Target the <html> element
    const messageDiv = document.getElementById('message'); // For feedback

    // Function to apply the theme
    const applyTheme = (theme) => {
        htmlElement.setAttribute('data-theme', theme);
        // Optional: Provide feedback to the user
        if (messageDiv) {
            // messageDiv.textContent = `Tema ${theme} olarak ayarlandı.`;
            // messageDiv.style.display = 'block';
            // setTimeout(() => { messageDiv.style.display = 'none'; }, 3000);
        }
    };

    // Function to save theme preference
    const saveThemePreference = (theme) => {
        localStorage.setItem('solaraTheme', theme);
    };

    // Function to load and apply saved theme or system preference
    const loadAndApplyTheme = () => {
        const savedTheme = localStorage.getItem('solaraTheme');
        let themeToApply = 'light'; // Default theme

        if (savedTheme) {
            themeToApply = savedTheme;
        } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
            // Check system preference if no theme is saved
            themeToApply = 'dark';
            // If system is default, mark the system radio button
             const systemRadio = document.querySelector('input[name="theme"][value="system"]');
             if (systemRadio) systemRadio.checked = true;
        }
         // If system is light and no theme saved, light is default

        applyTheme(themeToApply);

        // Update the radio button selection to match the applied theme
        const activeRadio = document.querySelector(`input[name="theme"][value="${themeToApply}"]`);
        if (activeRadio && !document.querySelector('input[name="theme"][value="system"]:checked')) { // Don't override if system was checked
             activeRadio.checked = true;
        }
         // Handle the 'system' case specifically if it was saved
         if (savedTheme === 'system') {
             const systemRadio = document.querySelector('input[name="theme"][value="system"]');
             if (systemRadio) systemRadio.checked = true;
             // Re-evaluate system preference on load if 'system' was chosen
             const systemPrefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
             applyTheme(systemPrefersDark ? 'dark' : 'light');
         }
    };

    // Add event listeners to radio buttons
    themeRadios.forEach(radio => {
        radio.addEventListener('change', (event) => {
            const selectedTheme = event.target.value;
            saveThemePreference(selectedTheme); // Save the explicit choice ('light', 'dark', or 'system')

            if (selectedTheme === 'system') {
                // If system is chosen, apply the current system preference
                const systemPrefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
                applyTheme(systemPrefersDark ? 'dark' : 'light');
            } else {
                // Apply the explicitly chosen theme
                applyTheme(selectedTheme);
            }
        });
    });

    // Add listener for system preference changes (if 'system' is selected)
     if (window.matchMedia) {
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', event => {
            const systemRadio = document.querySelector('input[name="theme"][value="system"]');
            // Only update if 'system' is the selected preference
            if (systemRadio && systemRadio.checked) {
                applyTheme(event.matches ? "dark" : "light");
            }
        });
    }


    // Load and apply theme on initial page load
    loadAndApplyTheme();

    // --- Logout Button Logic (Example) ---
    const logoutButton = document.getElementById('logout-button');
    if (logoutButton) {
        logoutButton.addEventListener('click', (event) => {
            event.preventDefault(); // Prevent default link behavior
            console.log('Logout clicked');
            // Add actual logout logic here (e.g., clear tokens, redirect)
            // Example: Clear local storage and redirect
            // localStorage.removeItem('authToken');
            // localStorage.removeItem('userId');
            // window.location.href = '/login'; // Redirect to login page
            alert('Çıkış yapma işlemi henüz uygulanmadı.'); // Placeholder alert
        });
    }

});
