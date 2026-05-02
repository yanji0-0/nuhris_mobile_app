import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../navigation/app_nav.dart';
import '../providers/api_client_provider.dart';
import '../providers/account_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? employeeType;
  String _displayName = 'Employee';
  String _displayEmail = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isChangingPassword = false;
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _profilePhoto;
  String? _profilePhotoUrl;

  final _employeeIdCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dateHiredCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  ProviderSubscription<AsyncValue<Map<String, dynamic>>>? _accountSubscription;
  ProviderSubscription<AsyncValue<String?>>? _profilePhotoSubscription;

  final List<_EmployeeTypeOption> employeeTypes = const [
    _EmployeeTypeOption(value: 'Faculty', label: 'Faculty'),
    _EmployeeTypeOption(value: 'Security', label: 'Security'),
    _EmployeeTypeOption(value: 'ASP', label: 'Admin Support Personel'),
  ];

  @override
  void initState() {
    super.initState();
    // Listen to account and profile photo providers and populate fields when data arrives.
    _accountSubscription = ref.listenManual<AsyncValue<Map<String, dynamic>>>(
      accountProvider,
      (prev, next) {
        next.when(
          data: (payload) {
            final user =
                (payload['user'] as Map?)?.cast<String, dynamic>() ?? {};
            final employee =
                (payload['employee'] as Map?)?.cast<String, dynamic>() ?? {};
            final department =
                (employee['department'] as Map?)?.cast<String, dynamic>() ?? {};

            _displayName = (user['name'] ?? 'Employee').toString();
            _displayEmail = (user['email'] ?? '').toString();

            _employeeIdCtrl.text = (employee['employee_id'] ?? '').toString();
            _departmentCtrl.text = (department['name'] ?? '').toString();
            _positionCtrl.text = (employee['position'] ?? '').toString();
            _phoneCtrl.text = (employee['phone'] ?? '').toString();
            _dateHiredCtrl.text = _formatDate(
              (employee['hire_date'] ?? '').toString(),
            );
            _addressCtrl.text = (employee['address'] ?? '').toString();
            employeeType = _normalizeEmployeeType(employee['employment_type']);

            if (mounted) setState(() => _isLoading = false);
          },
          loading: () {
            if (mounted) setState(() => _isLoading = true);
          },
          error: (_, __) {
            if (mounted) setState(() => _isLoading = false);
          },
        );
      },
      fireImmediately: true,
    );

    _profilePhotoSubscription = ref.listenManual<AsyncValue<String?>>(
      profilePhotoProvider,
      (prev, next) {
        next.when(
          data: (url) {
            if (url != null && url.trim().isNotEmpty) {
              if (mounted) setState(() => _profilePhotoUrl = url);
            }
          },
          loading: () {},
          error: (_, __) {},
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _accountSubscription?.close();
    _profilePhotoSubscription?.close();
    _employeeIdCtrl.dispose();
    _departmentCtrl.dispose();
    _positionCtrl.dispose();
    _phoneCtrl.dispose();
    _dateHiredCtrl.dispose();
    _addressCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ignore: unused_element
  Future<void> _pickDateHired() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 60),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null) return;

    _dateHiredCtrl.text =
        '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
  }

  void _showImageDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Please choose an option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  Navigator.pop(dialogContext);
                  _getFromCamera();
                },
                child: const Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.camera, color: AppColors.primaryBlue),
                    ),
                    Text(
                      'Camera',
                      style: TextStyle(color: AppColors.primaryBlue),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.pop(dialogContext);
                  _getFromGallery();
                },
                child: const Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.image, color: AppColors.primaryBlue),
                    ),
                    Text(
                      'Gallery',
                      style: TextStyle(color: AppColors.primaryBlue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getFromCamera() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (pickedFile == null) return;
    await _cropImage(pickedFile.path);
  }

  Future<void> _getFromGallery() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (pickedFile == null) return;
    await _cropImage(pickedFile.path);
  }

  Future<void> _cropImage(String filePath) async {
    final croppedImage = await ImageCropper().cropImage(
      sourcePath: filePath,
      maxHeight: 1080,
      maxWidth: 1080,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.primaryBlue,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: AppColors.primaryBlue,
          dimmedLayerColor: Colors.black54,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Profile Photo',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );

    if (!mounted || croppedImage == null) return;

    final croppedFile = File(croppedImage.path);
    // Force Flutter to reload file contents even if the same path is reused.
    await FileImage(croppedFile).evict();

    setState(() {
      _profilePhoto = XFile(croppedFile.path);
    });

    await _uploadProfilePhoto(croppedFile);
  }

  Future<void> _uploadProfilePhoto(File file) async {
    if (_isUploadingPhoto) {
      return;
    }

    setState(() => _isUploadingPhoto = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.uploadProfilePhoto(filePath: file.path);
      final uploadedUrl = (result['url'] ?? '').trim();
      final resolvedUrl = uploadedUrl.isNotEmpty
          ? uploadedUrl
          : (await api.getProfilePhotoUrl() ?? '');

      if (!mounted) {
        return;
      }

      setState(() {
        _profilePhotoUrl = resolvedUrl.isEmpty ? _profilePhotoUrl : resolvedUrl;
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

        final message = error.toString();

      messenger.showSnackBar(
          SnackBar(content: Text('Photo upload failed: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black45),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF0F0F0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFD1D1D1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.2),
      ),
    );
  }

  String? _normalizeEmployeeType(dynamic value) {
    final normalizedValue = value?.toString().trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }

    for (final option in employeeTypes) {
      if (normalizedValue == option.value ||
          normalizedValue.toLowerCase() == option.label.toLowerCase()) {
        return option.value;
      }
    }

    if (normalizedValue.toLowerCase() == 'admin support personel' ||
        normalizedValue.toLowerCase() == 'admin support personnel') {
      return 'ASP';
    }

    return null;
  }

  Future<void> _handleChangePassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final currentPassword = _currentPasswordCtrl.text;
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (currentPassword.trim().isEmpty ||
        newPassword.trim().isEmpty ||
        confirmPassword.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please complete all password fields.')),
      );
      return;
    }

    if (newPassword.trim().length < 6) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 6 characters long.'),
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('New password and confirm password do not match.'),
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted) {
        return;
      }

      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Change password failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? avatarImage = _profilePhoto != null
        ? FileImage(File(_profilePhoto!.path))
        : (_profilePhotoUrl != null && _profilePhotoUrl!.trim().isNotEmpty
              ? NetworkImage(_profilePhotoUrl!.trim())
              : null);

    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.account,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
        onSignOut: widget.onSignOut,
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B66),
        foregroundColor: Colors.white,
        surfaceTintColor: const Color(0xFF0A1B66),
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Account'),
        actions: [
          IconButton(
            onPressed: () => widget.onNavigate(AppNavItem.notifications),
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 18),
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Container(
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showImageDialog,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 31,
                                backgroundColor: const Color(0xFFE9EEF3),
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 38,
                                        color: Color(0xFF7B8794),
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: _isUploadingPhoto
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _displayEmail,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Information',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FBFF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE1E8F4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'READ ONLY DETAILS',
                          style: TextStyle(
                            color: Color(0xFF657A99),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _ReadOnlyDetailField(
                          label: 'DEPARTMENT',
                          value: _departmentCtrl.text,
                        ),
                        const SizedBox(height: 18),
                        _ReadOnlyDetailField(
                          label: 'POSITION',
                          value: _positionCtrl.text,
                        ),
                        const SizedBox(height: 18),
                        _ReadOnlyDetailField(
                          label: 'EMPLOYEE TYPE',
                          value: _displayEmployeeType(),
                        ),
                        const SizedBox(height: 18),
                        _ReadOnlyDetailField(
                          label: 'EMPLOYEE ID',
                          value: _employeeIdCtrl.text,
                        ),
                        const SizedBox(height: 18),
                        _ReadOnlyDetailField(
                          label: 'DATE HIRED',
                          value: _dateHiredCtrl.text,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Phone'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(hintText: 'e.g., 09171234567'),
                  ),
                  const SizedBox(height: 10),
                  const _FieldLabel('Address'),
                  TextField(
                    controller: _addressCtrl,
                    decoration: _inputDecoration(hintText: 'Home Address'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _isSaving = true);
                                try {
                                  final api = ref.read(apiClientProvider);
                                  await api.updateAccount({
                                    'phone': _phoneCtrl.text.trim(),
                                    'address': _addressCtrl.text.trim(),
                                  });
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Account updated successfully.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Save failed: $error'),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isSaving = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF014A8D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Update your account password. Use your current password before setting a new one.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Current Password'),
                  TextField(
                    controller: _currentPasswordCtrl,
                    obscureText: _obscureCurrentPassword,
                    decoration:
                        _inputDecoration(
                          hintText: 'Enter current password',
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _obscureCurrentPassword =
                                    !_obscureCurrentPassword,
                              );
                            },
                            icon: Icon(
                              _obscureCurrentPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 10),
                  const _FieldLabel('New Password'),
                  TextField(
                    controller: _newPasswordCtrl,
                    obscureText: _obscureNewPassword,
                    decoration: _inputDecoration(hintText: 'Min 6 characters')
                        .copyWith(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () =>
                                    _obscureNewPassword = !_obscureNewPassword,
                              );
                            },
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 10),
                  const _FieldLabel('Confirm New Password'),
                  TextField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscureConfirmPassword,
                    decoration:
                        _inputDecoration(
                          hintText: 'Re-enter new password',
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              );
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _isChangingPassword
                            ? null
                            : _handleChangePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF014A8D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: _isChangingPassword
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_reset, size: 18),
                        label: Text(
                          _isChangingPassword
                              ? 'Changing...'
                              : 'Change Password',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    if (value.length < 10) {
      return value;
    }
    final date = value.substring(0, 10).split('-');
    if (date.length != 3) {
      return value;
    }
    return '${date[1]}/${date[2]}/${date[0]}';
  }

  String _displayEmployeeType() {
    final value = employeeType;
    if (value == null || value.isEmpty) {
      return '';
    }

    for (final option in employeeTypes) {
      if (option.value == value) {
        return option.label;
      }
    }

    return value;
  }
}

class _EmployeeTypeOption {
  const _EmployeeTypeOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _ReadOnlyDetailField extends StatelessWidget {
  const _ReadOnlyDetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF657A99),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
