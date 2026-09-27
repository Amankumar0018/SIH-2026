import '../models/emergency_enums.dart';
import 'app_language.dart';

/// Centralized localization dictionary for Pukaar citizen-facing UI.
///
/// Provides type-safe access to localized strings across English, Hindi,
/// and Marathi without embedding ad-hoc conditionals across widgets.
class AppLocalizations {
  final AppLanguage language;

  const AppLocalizations(this.language);

  // --- Startup & Language Selection ---
  String get chooseLanguageTitle {
    switch (language) {
      case AppLanguage.hindi:
        return 'भाषा चुनें';
      case AppLanguage.marathi:
        return 'भाषा निवडा';
      case AppLanguage.english:
        return 'Choose your language';
    }
  }

  String get chooseLanguageSubtitle {
    switch (language) {
      case AppLanguage.hindi:
        return 'आपातकालीन सहायता के लिए अपनी पसंदीदा भाषा चुनें';
      case AppLanguage.marathi:
        return 'आणीबाणी मदतीसाठी आपली पसंतीची भाषा निवडा';
      case AppLanguage.english:
        return 'Select your preferred language for emergency response';
    }
  }

  String get continueBtn {
    switch (language) {
      case AppLanguage.hindi:
        return 'आगे बढ़ें';
      case AppLanguage.marathi:
        return 'पुढे जा';
      case AppLanguage.english:
        return 'Continue';
    }
  }

  String get languageChangedSuccess {
    switch (language) {
      case AppLanguage.hindi:
        return 'भाषा सफलतापूर्वक बदली गई';
      case AppLanguage.marathi:
        return 'भाषा यशस्वीरित्या बदलली';
      case AppLanguage.english:
        return 'Language updated successfully';
    }
  }

  // --- App Identity ---
  String get appName => 'Pukaar';
  String get appTagline {
    switch (language) {
      case AppLanguage.hindi:
        return 'त्वरित सहायता, एकीकृत आपातकालीन प्रतिक्रिया';
      case AppLanguage.marathi:
        return 'तातडीची मदत, एकात्मिक आणीबाणी प्रतिसाद';
      case AppLanguage.english:
        return 'Instant Help, Unified Emergency Response';
    }
  }

  // --- Authentication ---
  String get signIn {
    switch (language) {
      case AppLanguage.hindi:
        return 'साइन इन';
      case AppLanguage.marathi:
        return 'साइन इन';
      case AppLanguage.english:
        return 'Sign In';
    }
  }

  String get signUp {
    switch (language) {
      case AppLanguage.hindi:
        return 'रजिस्टर करें';
      case AppLanguage.marathi:
        return 'नोंदणी करा';
      case AppLanguage.english:
        return 'Sign Up';
    }
  }

  String get triageCategory {
    switch (language) {
      case AppLanguage.hindi:
        return 'ट्राइएज श्रेणी';
      case AppLanguage.marathi:
        return 'ट्राइएज श्रेणी';
      case AppLanguage.english:
        return 'Triage Category';
    }
  }

  String get mobileNumber {
    switch (language) {
      case AppLanguage.hindi:
        return 'मोबाइल नंबर';
      case AppLanguage.marathi:
        return 'मोबाईल नंबर';
      case AppLanguage.english:
        return 'Mobile Number';
    }
  }

  String get password {
    switch (language) {
      case AppLanguage.hindi:
        return 'पासवर्ड';
      case AppLanguage.marathi:
        return 'पासवर्ड';
      case AppLanguage.english:
        return 'Password';
    }
  }

  String get fullName {
    switch (language) {
      case AppLanguage.hindi:
        return 'पूरा नाम';
      case AppLanguage.marathi:
        return 'पूर्ण नाव';
      case AppLanguage.english:
        return 'Full Name';
    }
  }

  String get emergencyContactName {
    switch (language) {
      case AppLanguage.hindi:
        return 'आपातकालीन संपर्क का नाम';
      case AppLanguage.marathi:
        return 'आणीबाणी संपर्काचे नाव';
      case AppLanguage.english:
        return 'Emergency Contact Name';
    }
  }

  String get emergencyContactPhone {
    switch (language) {
      case AppLanguage.hindi:
        return 'आपातकालीन संपर्क नंबर';
      case AppLanguage.marathi:
        return 'आणीबाणी संपर्क नंबर';
      case AppLanguage.english:
        return 'Emergency Contact Number';
    }
  }

  String get roleCitizen {
    switch (language) {
      case AppLanguage.hindi:
        return 'नागरिक';
      case AppLanguage.marathi:
        return 'नागरिक';
      case AppLanguage.english:
        return 'Citizen';
    }
  }

  String get roleResponder {
    switch (language) {
      case AppLanguage.hindi:
        return 'बचावकर्मी';
      case AppLanguage.marathi:
        return 'बचावकर्ता';
      case AppLanguage.english:
        return 'Emergency Responder';
    }
  }

  // --- Home Screen & SOS ---
  String get immediateEmergencyBroadcast {
    switch (language) {
      case AppLanguage.hindi:
        return 'त्वरित आपातकालीन प्रसारण';
      case AppLanguage.marathi:
        return 'तातडीचे आणीबाणी प्रसारण';
      case AppLanguage.english:
        return 'IMMEDIATE EMERGENCY BROADCAST';
    }
  }

  String get triggerSos {
    switch (language) {
      case AppLanguage.hindi:
        return 'एसओएस';
      case AppLanguage.marathi:
        return 'SOS';
      case AppLanguage.english:
        return 'SOS';
    }
  }

  String get sosInstruction {
    switch (language) {
      case AppLanguage.hindi:
        return 'सभी स्थानीय आपातकालीन बचाव दलों को सूचित करने के लिए एसओएस दबाएं या दबाकर रखें।';
      case AppLanguage.marathi:
        return 'सर्व स्थानिक बचाव पथकांना त्वरित सूचित करण्यासाठी SOS दाबा किंवा दाबून ठेवा.';
      case AppLanguage.english:
        return 'Tap and hold/press SOS to notify all local emergency rescue teams immediately.';
    }
  }

  String get broadcastingIn {
    switch (language) {
      case AppLanguage.hindi:
        return 'प्रसारण हो रहा है...';
      case AppLanguage.marathi:
        return 'प्रसारण होत आहे...';
      case AppLanguage.english:
        return 'BROADCASTING IN...';
    }
  }

  String get cancelDispatch {
    switch (language) {
      case AppLanguage.hindi:
        return 'अलर्ट रद्द करें';
      case AppLanguage.marathi:
        return 'अलर्ट रद्द करा';
      case AppLanguage.english:
        return 'CANCEL DISPATCH';
    }
  }

  String get sosBroadcastActive {
    switch (language) {
      case AppLanguage.hindi:
        return 'एसओएस अलर्ट सक्रिय है';
      case AppLanguage.marathi:
        return 'SOS अलर्ट सक्रिय आहे';
      case AppLanguage.english:
        return 'SOS BROADCAST ACTIVE';
    }
  }

  String get liveLocationTracking {
    switch (language) {
      case AppLanguage.hindi:
        return 'आपका स्थान लाइव अपडेट हो रहा है।';
      case AppLanguage.marathi:
        return 'आपले स्थान थेट अपडेट केले जात आहे.';
      case AppLanguage.english:
        return 'Your location is being updated live.';
    }
  }

  String get deactivateSos {
    switch (language) {
      case AppLanguage.hindi:
        return 'एसओएस अलर्ट बंद करें';
      case AppLanguage.marathi:
        return 'SOS अलर्ट बंद करा';
      case AppLanguage.english:
        return 'DEACTIVATE SOS ALERT';
    }
  }

  String get gpsActive {
    switch (language) {
      case AppLanguage.hindi:
        return 'जीपीएस सक्रिय • उच्च सटीकता';
      case AppLanguage.marathi:
        return 'GPS सक्रिय • उच्च अचूकता';
      case AppLanguage.english:
        return 'GPS Active • High Accuracy';
    }
  }

  String get locationCaptured {
    switch (language) {
      case AppLanguage.hindi:
        return 'स्थान प्राप्त किया गया';
      case AppLanguage.marathi:
        return 'स्थान प्राप्त झाले';
      case AppLanguage.english:
        return 'Location Captured';
    }
  }

  // --- Emergency Categories ---
  String get selectEmergencyCategory {
    switch (language) {
      case AppLanguage.hindi:
        return 'आपातकालीन श्रेणी चुनें';
      case AppLanguage.marathi:
        return 'आणीबाणी श्रेणी निवडा';
      case AppLanguage.english:
        return 'Select Emergency Category';
    }
  }

  String get selectEmergencyCategorySubtitle {
    switch (language) {
      case AppLanguage.hindi:
        return 'विशिष्ट आपातकालीन सेवा के लिए श्रेणी चुनें';
      case AppLanguage.marathi:
        return 'विशिष्ट आणीबाणी सेवेसाठी श्रेणी निवडा';
      case AppLanguage.english:
        return 'Directly open specific triage incident routing';
    }
  }

  String get medicalEmergency {
    switch (language) {
      case AppLanguage.hindi:
        return 'चिकित्सा आपातकाल';
      case AppLanguage.marathi:
        return 'वैद्यकीय आणीबाणी';
      case AppLanguage.english:
        return 'Medical Emergency';
    }
  }

  String get medicalEmergencyDesc {
    switch (language) {
      case AppLanguage.hindi:
        return 'एम्बुलेंस, प्राथमिक उपचार और आपातकालीन स्वास्थ्य सेवा';
      case AppLanguage.marathi:
        return 'रुग्णवाहिका, प्रथमोपचार आणि वैद्यकीय मदत';
      case AppLanguage.english:
        return 'Ambulance, first aid, & critical healthcare support';
    }
  }

  String get womenSafety {
    switch (language) {
      case AppLanguage.hindi:
        return "महिला सुरक्षा";
      case AppLanguage.marathi:
        return "महिला सुरक्षा";
      case AppLanguage.english:
        return "Women's Safety";
    }
  }

  String get womenSafetyDesc {
    switch (language) {
      case AppLanguage.hindi:
        return 'सुरक्षा अलर्ट, एसओएस सहायता और सुरक्षित क्षेत्र मार्गदर्शन';
      case AppLanguage.marathi:
        return 'तातडीची मदत, SOS अलर्ट आणि सुरक्षित मार्ग';
      case AppLanguage.english:
        return 'Urgent assistance, SOS alerts, & safe zone routing';
    }
  }

  String get disasterManagement {
    switch (language) {
      case AppLanguage.hindi:
        return 'आपदा प्रबंधन';
      case AppLanguage.marathi:
        return 'आपत्ती व्यवस्थापन';
      case AppLanguage.english:
        return 'Disaster Management';
    }
  }

  String get disasterManagementDesc {
    switch (language) {
      case AppLanguage.hindi:
        return 'बाढ़, आग, भूकंप अलर्ट और बचाव अभियान';
      case AppLanguage.marathi:
        return 'पूर, आग, भूकंप अलर्ट आणि बचाव कार्य';
      case AppLanguage.english:
        return 'Flood, fire, earthquake alerts & rescue operations';
    }
  }

  String get campusEmergency {
    switch (language) {
      case AppLanguage.hindi:
        return 'परिसर आपातकाल';
      case AppLanguage.marathi:
        return 'कॅम्पस आणीबाणी';
      case AppLanguage.english:
        return 'Campus Emergency';
    }
  }

  String get campusEmergencyDesc {
    switch (language) {
      case AppLanguage.hindi:
        return 'सुरक्षा दल, त्वरित अलर्ट और विश्वविद्यालय घटना प्रतिक्रिया';
      case AppLanguage.marathi:
        return 'सुरक्षा, त्वरित सूचना आणि महाविद्यालयीन मदत';
      case AppLanguage.english:
        return 'Security, quick alert, & university incident response';
    }
  }

  String get reportIncident {
    switch (language) {
      case AppLanguage.hindi:
        return 'रिपोर्ट करें';
      case AppLanguage.marathi:
        return 'नोंदवा';
      case AppLanguage.english:
        return 'Report Incident';
    }
  }

  // --- Voice-to-Text & Incident Description ---
  String get describeEmergencyTitle {
    switch (language) {
      case AppLanguage.hindi:
        return 'घटना का विवरण दें';
      case AppLanguage.marathi:
        return 'घटनेचे वर्णन करा';
      case AppLanguage.english:
        return 'Describe what is happening';
    }
  }

  String get describeEmergencySubtitle {
    switch (language) {
      case AppLanguage.hindi:
        return 'एआई ट्राइएज के लिए बोलकर या लिखकर विवरण दें';
      case AppLanguage.marathi:
        return 'AI ट्राइएजसाठी माहिती बोला किंवा लिहा';
      case AppLanguage.english:
        return 'Speak or type incident details for AI triage';
    }
  }

  String get voiceInputHint {
    switch (language) {
      case AppLanguage.hindi:
        return 'माइक दबाएं या विवरण लिखें (उदा. बेहोश व्यक्ति, स्थान, खतरा)...';
      case AppLanguage.marathi:
        return 'माइक दाबा किंवा माहिती लिहा (उदा. बेशुद्ध व्यक्ती, ठिकाण, धोका)...';
      case AppLanguage.english:
        return 'Tap mic or type details (e.g. person unconscious, location, hazards)...';
    }
  }

  String get voiceConnecting {
    switch (language) {
      case AppLanguage.hindi:
        return 'माइक कनेक्ट हो रहा है...';
      case AppLanguage.marathi:
        return 'माइक जोडला जात आहे...';
      case AppLanguage.english:
        return 'Connecting microphone...';
    }
  }

  String get voiceListening {
    switch (language) {
      case AppLanguage.hindi:
        return 'सुन रहे हैं... कृपया स्पष्ट बोलें';
      case AppLanguage.marathi:
        return 'ऐकत आहे... कृपया स्पष्ट बोला';
      case AppLanguage.english:
        return 'Listening... Speak clearly now';
    }
  }

  String get voiceTranscriptCaptured {
    switch (language) {
      case AppLanguage.hindi:
        return 'विवरण दर्ज हो गया (संपादन योग्य)';
      case AppLanguage.marathi:
        return 'माहिती नोंदवली (संपादन योग्य)';
      case AppLanguage.english:
        return 'Transcript captured (editable)';
    }
  }

  String get voicePermissionDenied {
    switch (language) {
      case AppLanguage.hindi:
        return 'आवाज इनपुट के लिए माइक्रोफ़ोन अनुमति आवश्यक है।';
      case AppLanguage.marathi:
        return 'व्हॉइस इनपुटसाठी मायक्रोफोन परवानगी आवश्यक आहे.';
      case AppLanguage.english:
        return 'Microphone permission is required for voice input.';
    }
  }

  String get voiceRecognitionError {
    switch (language) {
      case AppLanguage.hindi:
        return 'आवाज पहचान में समस्या। आप लिखकर दर्ज कर सकते हैं।';
      case AppLanguage.marathi:
        return 'आवाज ओळखण्यात समस्या. आपण लिहून नोंदवू शकता.';
      case AppLanguage.english:
        return 'Voice recognition error. You can type manually.';
    }
  }

  String get voiceUnavailable {
    switch (language) {
      case AppLanguage.hindi:
        return 'स्पीच रिकॉग्निशन उपलब्ध नहीं है। कृपया मैन्युअल लिखें।';
      case AppLanguage.marathi:
        return 'स्पीच रेकग्निशन उपलब्ध नाही. कृपया स्वतः लिहा.';
      case AppLanguage.english:
        return 'Could not access speech recognizer. Manual input available.';
    }
  }

  String get readyBadge {
    switch (language) {
      case AppLanguage.hindi:
        return 'तैयार';
      case AppLanguage.marathi:
        return 'तयार';
      case AppLanguage.english:
        return 'READY';
    }
  }

  String get clearInput {
    switch (language) {
      case AppLanguage.hindi:
        return 'हटाएं';
      case AppLanguage.marathi:
        return 'काढून टाका';
      case AppLanguage.english:
        return 'Clear';
    }
  }

  String get broadcastWithVoiceNotes {
    switch (language) {
      case AppLanguage.hindi:
        return 'वॉयस विवरण के साथ आपातकाल भेजें';
      case AppLanguage.marathi:
        return 'व्हॉइस माहितीसह आणीबाणी पाठवा';
      case AppLanguage.english:
        return 'Broadcast Emergency with Voice Notes';
    }
  }

  String get sendSos {
    switch (language) {
      case AppLanguage.hindi:
        return 'एसओएस भेजें';
      case AppLanguage.marathi:
        return 'SOS पाठवा';
      case AppLanguage.english:
        return 'Send SOS';
    }
  }

  String get cancelSos {
    switch (language) {
      case AppLanguage.hindi:
        return 'आपातकाल रद्द करें';
      case AppLanguage.marathi:
        return 'आणीबाणी रद्द करा';
      case AppLanguage.english:
        return 'Cancel SOS';
    }
  }

  // --- Emergency Tracking & Timeline ---
  String get emergencyStatus {
    switch (language) {
      case AppLanguage.hindi:
        return 'आपातकाल स्थिति';
      case AppLanguage.marathi:
        return 'आणीबाणी स्थिती';
      case AppLanguage.english:
        return 'Emergency Status';
    }
  }

  String get incidentTimeline {
    switch (language) {
      case AppLanguage.hindi:
        return 'घटना की समयरेखा';
      case AppLanguage.marathi:
        return 'घटनेची टाइमलाइन';
      case AppLanguage.english:
        return 'Incident Timeline';
    }
  }

  String get incidentCreated {
    switch (language) {
      case AppLanguage.hindi:
        return 'घटना दर्ज की गई';
      case AppLanguage.marathi:
        return 'घटना नोंदवली गेली';
      case AppLanguage.english:
        return 'Incident Created';
    }
  }

  String get searchingResponders {
    switch (language) {
      case AppLanguage.hindi:
        return 'निकटतम बचाव दल की खोज';
      case AppLanguage.marathi:
        return 'जवळचे बचाव पथक शोधत आहे';
      case AppLanguage.english:
        return 'Searching Nearest Responders';
    }
  }

  String get responderDispatched {
    switch (language) {
      case AppLanguage.hindi:
        return 'बचाव दल रवाना';
      case AppLanguage.marathi:
        return 'बचाव पथक पाठवले';
      case AppLanguage.english:
        return 'Responder Dispatched';
    }
  }

  String get responderAccepted {
    switch (language) {
      case AppLanguage.hindi:
        return 'बचाव दल ने स्वीकार किया';
      case AppLanguage.marathi:
        return 'बचाव पथकाने स्वीकारले';
      case AppLanguage.english:
        return 'Responder Accepted';
    }
  }

  String get rescueInProgress {
    switch (language) {
      case AppLanguage.hindi:
        return 'बचाव कार्य प्रगति पर';
      case AppLanguage.marathi:
        return 'बचाव कार्य सुरू आहे';
      case AppLanguage.english:
        return 'Rescue In Progress';
    }
  }

  String get resolved {
    switch (language) {
      case AppLanguage.hindi:
        return 'समस्या निवारित';
      case AppLanguage.marathi:
        return 'निवारण झाले';
      case AppLanguage.english:
        return 'Resolved';
    }
  }

  String get cancelEmergency {
    switch (language) {
      case AppLanguage.hindi:
        return 'आपातकाल रद्द करें';
      case AppLanguage.marathi:
        return 'आणीबाणी रद्द करा';
      case AppLanguage.english:
        return 'Cancel Emergency';
    }
  }

  // --- Profile, Settings & Language ---
  String get profile {
    switch (language) {
      case AppLanguage.hindi:
        return 'प्रोफ़ाइल';
      case AppLanguage.marathi:
        return 'प्रोफाइल';
      case AppLanguage.english:
        return 'Profile';
    }
  }

  String get appLanguageLabel {
    switch (language) {
      case AppLanguage.hindi:
        return 'ऐप की भाषा';
      case AppLanguage.marathi:
        return 'अॅपची भाषा';
      case AppLanguage.english:
        return 'App Language';
    }
  }

  String get changeLanguage {
    switch (language) {
      case AppLanguage.hindi:
        return 'भाषा बदलें';
      case AppLanguage.marathi:
        return 'भाषा बदला';
      case AppLanguage.english:
        return 'Change Language';
    }
  }

  String get signOut {
    switch (language) {
      case AppLanguage.hindi:
        return 'लॉग आउट';
      case AppLanguage.marathi:
        return 'लॉग आउट';
      case AppLanguage.english:
        return 'Sign Out';
    }
  }

  String localizedEmergencyStatus(EmergencyStatus status) {
    switch (status) {
      case EmergencyStatus.created:
        return incidentCreated;
      case EmergencyStatus.searching:
        return searchingResponders;
      case EmergencyStatus.dispatched:
        return responderDispatched;
      case EmergencyStatus.accepted:
        return responderAccepted;
      case EmergencyStatus.inProgress:
        return rescueInProgress;
      case EmergencyStatus.resolved:
        return resolved;
      case EmergencyStatus.cancelled:
        return cancelEmergency;
    }
  }

  String localizedEmergencyCategory(EmergencyCategory category) {
    switch (category) {
      case EmergencyCategory.medical:
        return medicalEmergency;
      case EmergencyCategory.womenSafety:
        return womenSafety;
      case EmergencyCategory.disaster:
        return disasterManagement;
      case EmergencyCategory.campus:
        return campusEmergency;
    }
  }
}
