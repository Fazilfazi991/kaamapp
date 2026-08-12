import 'package:url_launcher/url_launcher.dart';

const kaamPrivacyPolicyUrl =
    'https://www.fusionventuresglobal.com/kaam/privacy-policy';

Future<bool> openKaamPrivacyPolicy() {
  return launchUrl(
    Uri.parse(kaamPrivacyPolicyUrl),
    mode: LaunchMode.externalApplication,
  );
}
