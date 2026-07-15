import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_stepper.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../profile/candidate_display_formatters.dart';

class BasicDetailsScreen extends StatefulWidget {
  const BasicDetailsScreen({super.key});

  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen> {
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final whatsappController = TextEditingController();
  final nationalityController = TextEditingController();
  final currentLocationController = TextEditingController();
  final preferredLocationController = TextEditingController();
  final dobController = TextEditingController();
  final genderController = TextEditingController();
  final passportNumberController = TextEditingController();
  final passportExpiryController = TextEditingController();
  final repository = const CandidateProfileRepository();
  bool saving = false;
  bool loading = true;

  static const nationalities = [
    'Indian',
    'Pakistani',
    'Bangladeshi',
    'Nepali',
    'Filipino',
    'Sri Lankan',
    'African',
    'Other',
  ];

  static const countries = ['UAE', 'India'];
  static const uaeEmirates = ['Abu Dhabi', 'Dubai', 'Sharjah', 'Ajman', 'Umm Al Quwain', 'Ras Al Khaimah', 'Fujairah'];
  static const indianStates = ['Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Puducherry', 'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu', 'Lakshadweep', 'Andaman and Nicobar Islands'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    whatsappController.dispose();
    nationalityController.dispose();
    currentLocationController.dispose();
    preferredLocationController.dispose();
    dobController.dispose();
    genderController.dispose();
    passportNumberController.dispose();
    passportExpiryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await repository.loadCurrentProfile();
      final identity = await repository.loadIdentityDocuments();
      if (!mounted) return;
      fullNameController.text =
          profile.fullName.isNotEmpty ? profile.fullName : identity.fullName;
      phoneController.text = profile.phone;
      nationalityController.text =
          profile.nationality.isNotEmpty ? profile.nationality : identity.nationality;
      final savedCountry = profile.currentCountry.isNotEmpty ? profile.currentCountry : profile.preferredCountry;
      preferredLocationController.text = countries.contains(savedCountry) ? savedCountry : '';
      currentLocationController.text = preferredLocationController.text.isEmpty ? '' : profile.currentCity;
      dobController.text = identity.dob;
      genderController.text = identity.gender;
      passportNumberController.text = identity.passportNumber;
      passportExpiryController.text = identity.passportExpiryDate;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _continue() async {
    final missing = <String>[];
    if (fullNameController.text.trim().isEmpty) missing.add('full name');
    if (phoneController.text.trim().isEmpty) missing.add('mobile number');
    if (nationalityController.text.trim().isEmpty) missing.add('nationality');
    if (preferredLocationController.text.trim().isEmpty) {
      missing.add('country');
    }
    if (currentLocationController.text.trim().isEmpty) {
      missing.add(preferredLocationController.text == 'India' ? 'state' : 'emirate');
    }
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add ${missing.join(', ')}.')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      await repository.upsertBasicProfile(
        fullName: titleCase(fullNameController.text),
        phone: phoneController.text,
        nationality: titleCase(nationalityController.text),
        currentLocation: preferredLocationController.text.trim(),
        preferredLocation: titleCase(currentLocationController.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
      Navigator.of(context).pushNamed(AppRoutes.workPreferences);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required TextEditingController controller,
  }) async {
    final search = TextEditingController();
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(child: StatefulBuilder(builder: (context, setSheetState) {
        final query = search.text.toLowerCase(); final visible = options.where((item) => item.toLowerCase().contains(query)).toList();
        return Padding(padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 24), child: SizedBox(height: MediaQuery.sizeOf(context).height * .7, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.title), const SizedBox(height: 12), if (options.length > 10) AppTextField(controller: search, label: 'Search', hint: 'Search', onChanged: (_) => setSheetState(() {})), Expanded(child: ListView(children: [for (final option in visible) ListTile(title: Text(option), trailing: controller.text == option ? const Icon(Icons.check) : null, onTap: () => Navigator.of(context).pop(option))]))])));
      })),
    );
    if (value == null) return;
    controller.text = value;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Basic Details',
      showBack: true,
      children: [
        const ProgressStepper(current: 2, total: 5),
        const SizedBox(height: 22),
        const Text('Check Your Details', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        const Text('We filled what we could from your passport. You can edit anything.',
            style: AppTextStyles.body),
        const SizedBox(height: 18),
        if (loading) const LinearProgressIndicator(),
        if (loading) const SizedBox(height: 12),
        AppTextField(controller: fullNameController, label: 'Full name', hint: 'Your full name'),
        const SizedBox(height: 12),
        AppTextField(
          controller: dobController,
          label: 'Date of birth',
          hint: 'YYYY-MM-DD',
          readOnly: true,
          suffixIcon: const Icon(Icons.lock_outline_rounded),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: nationalityController,
          label: 'Nationality',
          hint: 'Select nationality',
          readOnly: true,
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          onTap: () => _pickOption(
            title: 'Select nationality',
            options: nationalities,
            controller: nationalityController,
          ),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: genderController,
          label: 'Gender',
          hint: 'From passport',
          readOnly: true,
          suffixIcon: const Icon(Icons.lock_outline_rounded),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: passportNumberController,
          label: 'Passport number',
          hint: 'From passport',
          readOnly: true,
          suffixIcon: const Icon(Icons.lock_outline_rounded),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: passportExpiryController,
          label: 'Passport expiry',
          hint: 'YYYY-MM-DD',
          readOnly: true,
          suffixIcon: const Icon(Icons.lock_outline_rounded),
        ),
        const SizedBox(height: 20),
        const Text('Contact Details', style: AppTextStyles.title),
        const SizedBox(height: 12),
        AppTextField(
          controller: phoneController,
          label: 'Mobile number *',
          hint: '+971 50 000 0000',
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: whatsappController,
          label: 'WhatsApp number',
          hint: 'Optional if different',
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Location', style: AppTextStyles.title),
        const SizedBox(height: 8),
        const Text('Select your country, then your emirate or state.', style: AppTextStyles.body),
        const SizedBox(height: 12),
        AppTextField(
          controller: preferredLocationController,
          label: 'Country *',
          hint: 'Select country',
          readOnly: true,
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          onTap: () async {
            final previous = preferredLocationController.text;
            await _pickOption(
              title: 'Select country',
              options: countries,
              controller: preferredLocationController,
            );
            if (preferredLocationController.text != previous) {
              setState(() => currentLocationController.clear());
            }
          },
        ),
        if (preferredLocationController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppTextField(
          controller: currentLocationController,
          label: preferredLocationController.text == 'India' ? 'State *' : 'Emirate *',
          hint: preferredLocationController.text == 'India' ? 'Select state' : 'Select emirate',
          readOnly: true,
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          onTap: () => _pickOption(
            title: preferredLocationController.text == 'India' ? 'Select state' : 'Select emirate',
            options: preferredLocationController.text == 'India' ? indianStates : uaeEmirates,
            controller: currentLocationController,
          ),
          ),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: saving ? 'Saving...' : 'Continue',
          onPressed: saving ? null : _continue,
        ),
      ],
    );
  }
}
