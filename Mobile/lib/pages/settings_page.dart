import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solara/pages/account_settings_page.dart'; // Yeni sayfa importu
import 'package:solara/services/theme_service.dart'; // ThemeService importu

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ThemeService'e erişim (hem okuma hem de değiştirme için)
    final themeService = Provider.of<ThemeService>(context);
    // Mevcut tema ayarlarını almak için
    final currentThemeMode = themeService.themeMode;
    // Tema renklerine erişim
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        // Geri butonu otomatik eklenir
      ),
      body: ListView(
        children: [
          // --- Görünüm Ayarları Bölümü ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Görünüm',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Açık'),
            value: ThemeMode.light,
            groupValue: currentThemeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                themeService.setThemeMode(value); // Temayı değiştir
              }
            },
            activeColor: colorScheme.primary, // Seçili radio buton rengi
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Koyu'),
            value: ThemeMode.dark,
            groupValue: currentThemeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                themeService.setThemeMode(value); // Temayı değiştir
              }
            },
            activeColor: colorScheme.primary,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Sistem Varsayılanı'),
            value: ThemeMode.system,
            groupValue: currentThemeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                themeService.setThemeMode(value); // Temayı değiştir
              }
            },
            activeColor: colorScheme.primary,
          ),

          const Divider(height: 20, thickness: 1),

          // --- Diğer Ayarlar (Placeholder) ---
           _buildSettingsItem(
            context: context,
            icon: Icons.person_outline,
            title: 'Hesap',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountSettingsPage()),
              );
            }
          ),
           _buildSettingsItem(
            context: context,
            icon: Icons.notifications_none,
            title: 'Bildirimler',
             onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bildirim ayarları yakında.')),
              );
            }
          ),
           _buildSettingsItem(
            context: context,
            icon: Icons.lock_outline,
            title: 'Gizlilik ve Güvenlik',
             onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gizlilik ayarları yakında.')),
              );
            }
          ),
           _buildSettingsItem(
            context: context,
            icon: Icons.help_outline,
            title: 'Yardım',
             onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yardım bölümü yakında.')),
              );
            }
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.info_outline,
            title: 'Hakkında',
             onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hakkında bölümü yakında.')),
              );
            }
          ),
        ],
      ),
    );
  }

  // Ayar öğesi için yardımcı widget (kod tekrarını önlemek için)
  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.iconTheme.color),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: theme.iconTheme.color?.withOpacity(0.6)),
      onTap: onTap,
    );
  }
}
