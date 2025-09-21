// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/image_service.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  final ImageService _imageService = ImageService();
  UserProfile? _userProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final profile = await _auth.getUserProfile(user.uid);
      setState(() {
        _userProfile = profile;
        _loading = false;
      });
    }
  }

  Future<void> _changeAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && _userProfile != null) {
      // In a real app, you would upload this to Firebase Storage
      // and update the user's photoUrl
      setState(() {
        _userProfile = _userProfile!.copyWith(photoUrl: image.path);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully!')),
      );
    }
  }

  Future<void> _changeAvatarStyle() async {
    final styles = ['adventurer', 'avataaars', 'bottts', 'lorelei', 'micah'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Avatar Style'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: styles.length,
            itemBuilder: (context, index) => ListTile(
              leading: Image.network(
                AvatarService.generateAvatarUrl(
                  'user',
                  style: styles[index],
                  size: 40,
                ),
                width: 40,
                height: 40,
              ),
              title: Text(styles[index]),
              onTap: () {
                if (_userProfile != null) {
                  setState(() {
                    _userProfile = _userProfile!.copyWith(
                      avatarStyle: styles[index],
                    );
                  });
                  _auth.updateUserProfile(_userProfile!);
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final avatarUrl =
        _userProfile?.photoUrl ??
        AvatarService.generateAvatarUrl(
          _userProfile?.email ?? 'user',
          style: _userProfile?.avatarStyle ?? 'adventurer',
          size: 120,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _editProfile),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _changeAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(avatarUrl),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _userProfile?.displayName ?? 'No Name',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(_userProfile?.email ?? ''),

            const SizedBox(height: 20),

            // Settings Options
            _buildSettingsOption(
              icon: Icons.palette,
              title: 'Change Avatar Style',
              onTap: _changeAvatarStyle,
            ),
            _buildSettingsOption(
              icon: Icons.archive,
              title: 'Archived Notes',
              onTap: () => _navigateToSection('archived'),
            ),
            _buildSettingsOption(
              icon: Icons.delete,
              title: 'Trash',
              onTap: () => _navigateToSection('trash'),
            ),
            _buildSettingsOption(
              icon: Icons.settings,
              title: 'App Settings',
              onTap: () {},
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _auth.signOut(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _navigateToSection(String section) {
    // Implement navigation to different sections
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Navigating to $section section')));
  }

  void _editProfile() {
    final _nameController = TextEditingController(
      text: _userProfile?.displayName,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_userProfile != null) {
                  final updatedProfile = _userProfile!.copyWith(
                    displayName: _nameController.text,
                  );

                  await _auth.updateUserProfile(updatedProfile);
                  setState(() {
                    _userProfile = updatedProfile;
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
