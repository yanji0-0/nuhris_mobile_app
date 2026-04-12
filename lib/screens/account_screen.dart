import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../navigation/app_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String? employeeType;
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _profilePhoto;

  final _employeeIdCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dateHiredCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final List<String> employeeTypes = const [
    'Faculty',
    'Security',
    'ASP',
  ];

  @override
  void dispose() {
    _employeeIdCtrl.dispose();
    _departmentCtrl.dispose();
    _positionCtrl.dispose();
    _phoneCtrl.dispose();
    _dateHiredCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

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
                      child: Icon(
                        Icons.camera,
                        color: AppColors.primaryBlue,
                      ),
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
                      child: Icon(
                        Icons.image,
                        color: AppColors.primaryBlue,
                      ),
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

    setState(() {
      _profilePhoto = XFile(croppedImage.path);
    });
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

  @override
  Widget build(BuildContext context) {
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
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Container(
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
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
                                backgroundImage: _profilePhoto != null ? FileImage(File(_profilePhoto!.path)) : null,
                                child: _profilePhoto == null ? const Icon(Icons.person, size: 38, color: Color(0xFF7B8794)) : null,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Ian Isaac Martinez', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
                      const SizedBox(height: 2),
                      const Text('martinezian@gmail.com', style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Profile Information', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  const _FieldLabel('Employee Type'),
                  DropdownButtonFormField<String>(
                    initialValue: employeeType,
                    isExpanded: true,
                    decoration: _inputDecoration(hintText: 'Select type'),
                    items: employeeTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => employeeType = v),
                  ),
                  const SizedBox(height: 10),
                  const _FieldLabel('Employee ID'),
                  TextField(controller: _employeeIdCtrl, decoration: _inputDecoration(hintText: 'e.g., NU-2025-001')),
                  const SizedBox(height: 10),
                  const _FieldLabel('Department'),
                  TextField(controller: _departmentCtrl, decoration: _inputDecoration(hintText: 'e.g., SACE')),
                  const SizedBox(height: 10),
                  const _FieldLabel('Position'),
                  TextField(controller: _positionCtrl, decoration: _inputDecoration(hintText: 'e.g., Instructor I')),
                  const SizedBox(height: 10),
                  const _FieldLabel('Phone'),
                  TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: _inputDecoration(hintText: 'e.g., 09171234567')),
                  const SizedBox(height: 10),
                  const _FieldLabel('Date Hired'),
                  TextField(controller: _dateHiredCtrl, readOnly: true, onTap: _pickDateHired, decoration: _inputDecoration(hintText: 'mm/dd/yyyy')),
                  const SizedBox(height: 10),
                  const _FieldLabel('Address'),
                  TextField(controller: _addressCtrl, decoration: _inputDecoration(hintText: 'Home Address')),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved (UI only)')));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF014A8D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
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
