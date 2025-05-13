import 'package:flutter/material.dart';
import 'package:solara/pages/edit_profile_page.dart'; // EditProfilePage importu

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesap Ayarları'),
      ),
      body: ListView(
        children: [
          // --- Profil Ayarları Bölümü ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Profil',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.edit_outlined,
            title: 'Profili Düzenle',
            subtitle: 'Kullanıcı adı, profil resmi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfilePage()),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildSettingsItem(
            context: context,
            icon: Icons.email_outlined,
            title: 'E-posta Adresini Değiştir',
            onTap: () {
              // Şimdilik statik
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('E-posta değiştirme (statik).')),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildSettingsItem(
            context: context,
            icon: Icons.phone_outlined,
            title: 'Telefon Numarası Yönetimi',
            onTap: () {
              // Şimdilik statik
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Telefon numarası yönetimi (statik).')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.iconTheme.color),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7))) : null,
      trailing: Icon(Icons.chevron_right, color: theme.iconTheme.color?.withOpacity(0.6)),
      onTap: onTap,
    );
  }
}
