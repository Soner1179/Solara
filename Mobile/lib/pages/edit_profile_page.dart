import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:solara/services/user_state.dart';
import 'package:solara/services/api_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  String _currentProfileImageUrl = '';
  String _currentUsername = '';

  @override
  void initState() {
    super.initState();
    try {
      final userState = Provider.of<UserState>(context, listen: false);
      _currentUsername = userState.currentUser?['username'] as String? ?? 'Kullanıcı Adı';
      _currentProfileImageUrl = userState.currentUser?['profile_picture_url'] as String? ?? '';
      _usernameController = TextEditingController(text: _currentUsername);
    } catch (e) {
      print("[EditProfilePage initState] Error accessing UserState: $e");
      _usernameController = TextEditingController(text: 'Hata');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          _profileImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resim seçilemedi: $e')),
        );
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamerayla Çek'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    print('****************************************************************');
    print('[EditProfilePage] _saveProfile: Method Entered.');
    print('****************************************************************');

    if (!_formKey.currentState!.validate()) {
      print('[EditProfilePage] _saveProfile: Form validation failed.');
      return;
    }
    print('[EditProfilePage] _saveProfile: Form validation successful.');

    if (mounted) {
      setState(() {
        _isLoading = true;
        print('[EditProfilePage] _saveProfile: _isLoading set to true.');
      });
    } else {
      print('[EditProfilePage] _saveProfile: WARNING - Component not mounted when trying to set _isLoading to true.');
      return;
    }

    ApiService apiService;
    UserState userState;

    try {
      print('[EditProfilePage] _saveProfile: Attempting to get ApiService from Provider.');
      apiService = Provider.of<ApiService>(context, listen: false);
      print('[EditProfilePage] _saveProfile: ApiService obtained.');

      print('[EditProfilePage] _saveProfile: Attempting to get UserState from Provider.');
      userState = Provider.of<UserState>(context, listen: false);
      print('[EditProfilePage] _saveProfile: UserState obtained.');
    } catch (e, stackTrace) {
      print('[EditProfilePage] _saveProfile: ERROR obtaining Provider: $e');
      print('[EditProfilePage] _saveProfile: Provider StackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: Servislere ulaşılamadı - $e')),
        );
        setState(() { _isLoading = false; });
      }
      return;
    }
    
    if (userState.currentUser == null || userState.currentUser!['user_id'] == null) {
      print('[EditProfilePage] _saveProfile: User data or user_id is null. Aborting. currentUser: ${userState.currentUser}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı bilgileri bulunamadı. Lütfen tekrar giriş yapın.')),
        );
        setState(() { _isLoading = false; });
      }
      return;
    }

    final int userId = userState.currentUser!['user_id'] as int;
    print('[EditProfilePage] _saveProfile: Starting profile save for userId: $userId, username: ${_usernameController.text}');

    try {
      print('[EditProfilePage] _saveProfile: Calling apiService.updateUserProfile...');
      final updatedProfileData = await apiService.updateUserProfile(
        userId: userId,
        username: _usernameController.text,
        profileImageFile: _profileImageFile,
        currentProfileImageUrl: _currentProfileImageUrl,
      );
      print('[EditProfilePage] _saveProfile: apiService.updateUserProfile call completed. Response: $updatedProfileData');

      if (mounted) {
        print('[EditProfilePage] _saveProfile: Component is mounted. Processing response.');
        // Start with a fresh copy of the existing user data to preserve other fields
        Map<String, dynamic> updatedUserForState = Map.from(userState.currentUser ?? {});

        // Determine the new username
        String newUsername = _usernameController.text;
        if (updatedProfileData.containsKey('user') && 
            updatedProfileData['user'] is Map &&
            (updatedProfileData['user'] as Map).containsKey('username')) {
          newUsername = (updatedProfileData['user'] as Map)['username'] ?? newUsername;
        }
        updatedUserForState['username'] = newUsername;

        // Determine the new profile picture URL
        String newProfilePicUrl = _currentProfileImageUrl; // Default to current

        if (updatedProfileData.containsKey('user') && 
            updatedProfileData['user'] is Map &&
            (updatedProfileData['user'] as Map).containsKey('profile_picture_url')) {
          // Priority 1: URL from the 'user' object in the PUT response
          newProfilePicUrl = (updatedProfileData['user'] as Map)['profile_picture_url'] ?? newProfilePicUrl;
        } else if (_profileImageFile != null && updatedProfileData.containsKey('profile_image_url')) {
          // Priority 2: URL from the image upload response (if a new file was uploaded)
          // This key 'profile_image_url' comes from the apiService.updateUserProfile's own structure
          // if it directly returns the uploaded image URL when the main PUT response doesn't nest it.
          newProfilePicUrl = updatedProfileData['profile_image_url'] ?? newProfilePicUrl;
        }
        // Ensure we use 'profile_picture_url' as the key in UserState
        updatedUserForState['profile_picture_url'] = newProfilePicUrl;
        
        // Remove the potentially problematic 'profile_image_url' key if it exists from old logic
        updatedUserForState.remove('profile_image_url'); 

        print('[EditProfilePage] _saveProfile: Updating UserState with: $updatedUserForState');
        await userState.setCurrentUser(updatedUserForState); // This will notify listeners

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla güncellendi!')),
        );
        Navigator.of(context).pop(); // This should trigger a rebuild of ProfilePage if it's listening to UserState
      } else {
        print('[EditProfilePage] _saveProfile: Component is NOT mounted after API call.');
      }
    } catch (e, stackTrace) {
      print('[EditProfilePage] _saveProfile: ERROR during profile save: $e');
      print('[EditProfilePage] _saveProfile: StackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil güncellenirken bir hata oluştu: $e')),
        );
      }
    } finally {
      print('[EditProfilePage] _saveProfile: Finally block. Setting _isLoading to false.');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveProfile,
              tooltip: 'Kaydet',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _showImageSourceActionSheet(context),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: colorScheme.surfaceVariant,
                  backgroundImage: _profileImageFile != null
                      ? FileImage(_profileImageFile!)
                      : (_currentProfileImageUrl.isNotEmpty
                          ? NetworkImage(_currentProfileImageUrl)
                          : null) as ImageProvider?,
                  child: _profileImageFile == null && _currentProfileImageUrl.isEmpty
                      ? Icon(Icons.person_outline, size: 60, color: colorScheme.onSurfaceVariant)
                      : null,
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.camera_alt_outlined, color: colorScheme.primary),
                label: Text('Profil Resmini Değiştir', style: TextStyle(color: colorScheme.primary)),
                onPressed: () => _showImageSourceActionSheet(context),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kullanıcı adı boş bırakılamaz.';
                  }
                  if (value.length < 3) {
                    return 'Kullanıcı adı en az 3 karakter olmalıdır.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.save_alt_outlined),
                label: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Değişiklikleri Kaydet'),
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
