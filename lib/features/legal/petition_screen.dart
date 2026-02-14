import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/petition_model.dart';
import '../../services/pdf_service.dart';
import '../../services/doc_service.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/providers.dart';
import '../../core/payment_config.dart';
import '../../models/user_model.dart';
import '../../models/petition_record_model.dart';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

enum RelationType { sonOf, wifeOf, daughterOf }

class PetitionFormScreen extends ConsumerStatefulWidget {
  final UserModel? currentUser;
  final String? petitionType;
  
  const PetitionFormScreen({super.key, this.currentUser, this.petitionType});

  @override
  ConsumerState<PetitionFormScreen> createState() => _PetitionFormScreenState();
}

class _PetitionFormScreenState extends ConsumerState<PetitionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late final TextEditingController _senderNameController;
  late final TextEditingController _senderDesignationController;
  late final TextEditingController _senderMobileController;
  
  // Detailed Address Controllers
  late final TextEditingController _fatherNameController;
  late final TextEditingController _doorNoController;
  late final TextEditingController _streetController;
  late final TextEditingController _villageController;
  late final TextEditingController _postOfficeController;
  late final TextEditingController _talukController;
  late final TextEditingController _districtController;
  late final TextEditingController _pincodeController;
  
  bool _saveAddress = false;
  bool _isLoading = false;
  bool _isWordLoading = false;
  bool _hasSavedAddress = false;
  RelationType _relationType = RelationType.sonOf;
  List<String> _savedPresets = [];
  
  late final List<TextEditingController> _reqDocumentsControllers;
  late final List<TextEditingController> _attachmentControllers;
  late final List<TextEditingController> _ccControllers;
  late Razorpay _razorpay;
  PetitionModel? _pendingPaymentModel;
  void Function(PetitionModel)? _onPaymentSuccess;

  @override
  void initState() {
    super.initState();
    _loadPresets();
    _initRazorpay();
    _senderNameController = TextEditingController(text: widget.currentUser?.name ?? '');
    _senderDesignationController = TextEditingController(
        text: widget.currentUser?.designation ?? (widget.currentUser?.role == UserRole.admin 
        ? 'மாநில தலைவர் நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கம்' 
        : 'உறுப்பினர் நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கம்')
    );
    _senderMobileController = TextEditingController(text: widget.currentUser?.phone ?? '');
    
    // Initialize address controllers with empty text first
    _fatherNameController = TextEditingController();
    _doorNoController = TextEditingController();
    _streetController = TextEditingController();
    _villageController = TextEditingController();
    _postOfficeController = TextEditingController();
    _talukController = TextEditingController();
    _districtController = TextEditingController();
    _pincodeController = TextEditingController();
    
    // Load initial address data
    _loadAddressFrom(widget.currentUser?.address ?? '');
    
    // Initialize editable date and place
    _placeController = TextEditingController(text: '');
    _dateController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));

    // Initial content setup
    _initializeContentDefaults();

    // Check saved status
    _hasSavedAddress = (widget.currentUser?.address ?? '').isNotEmpty;

    // Add listener for dynamic content update based on designation
    _senderDesignationController.addListener(_updateContentBasedOnDesignation);
    
    // Force initial update to set correct text
    _updateContentBasedOnDesignation();
    debugPrint('Petition Screen Initialized - v2.7 3rd field fix');
  }

  void _initializeContentDefaults() {
    String defaultTitle = 'மனு';
    String defaultSubject = '';
    String defaultContent1 = '';
    String defaultContent2 = '';
    
    // Robust case-insensitive check for Evidence Act (Defined ONCE at the top)
    final String typeLower = (widget.petitionType ?? '').toLowerCase();
    final bool isEvidenceAct = typeLower.contains('evidence') && typeLower.contains('act');
    
    if (isEvidenceAct) {
      defaultTitle = 'பாரதிய சாட்சிய அதினியம், 2023 பிரிவு 74, 75-ன் படி, சான்று நகல் வேண்டி விண்ணப்பம்.';
      defaultSubject = 'பாரதிய சாட்சிய அதினியம் 2023 பிரிவு 54(1)-ன் கீழ் நாட்டில் அமலில் உள்ள சட்டங்கள் அனைத்தையும் நீதிமன்றம், நிர்வாக முறையில் கவனத்தில் கொள்ள வேண்டும் என்பதை கருத்தில் கொண்டு கொடுக்கப்படும் விண்ணப்ப மனு.';
      
      String intro = 'வணக்கம்,\nநான் மேற்கண்ட முகவரியில் வசித்து வருகிறேன். மேலும் நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கத்தின் ';
      final role1 = _senderDesignationController.text.replaceAll('நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கம்', '').trim();
      if (role1.contains('உறுப்பினர்')) {
        intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
      } else if (role1.isNotEmpty) {
        intro += '$role1 ஆகவும் இருந்து வருகிறேன்.';
      } else {
        intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
      }
      defaultContent1 = intro;
      defaultContent2 = 'பாரதிய சாட்சிய அதினியம், 2023 பிரிவு 74 இன் படி அரசு அலுவலகங்களில் உள்ள அனைத்து ஆவணங்களும் பொது ஆவணங்கள் என்பதை தாங்கள் அறிவீர்கள். கீழே என்னால் கோரப்பட்டுள்ள ஆவணங்கள் தங்களது அலுவலகத்தில் இல்லாத பட்சத்தில் உரிய அலுவலகத்திற்கு அனுப்பி தகவல்களை வழங்க கடமைப்பட்டுள்ளீர்கள் என்பதையும் தெரிவித்துக் கொள்கிறேன். பாரதிய சாட்சிய அதினியம், 2023 பிரிவு 75-ன் படி என்னால் கீழே கோரப்படுள்ள ஆவணங்களுக்கு சான்று நகல் தருமாறு கேட்டுக் கொள்கிறேன்.';
    } else if (widget.petitionType == 'Police Complaint') {
      defaultTitle = 'புகார் மனு';
      defaultSubject = 'நீதிமன்ற சாசனமாம் பாரதிய சாக்ஷ்ய அதீனியம் 2023 பிரிவு 54(1)-ன் கீழ் நாட்டில் அமலில் உள்ள சட்டங்கள் அனைத்தையும் நீதிமன்றம், நிர்வாக நீதி முறையில் கவனத்தில் கொள்ள வேண்டும் என்பதை கருத்தில் கொண்டு கொடுக்கப்படும் புகார் மனு';
      
      String intro = 'வணக்கம்,\nநான் மேற்கண்ட முகவரியில் வசித்து வருகிறேன். மேலும் நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கத்தின் ';
      final role2 = _senderDesignationController.text.replaceAll('நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கம்', '').trim();
      if (role2.contains('உறுப்பினர்')) {
        intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
      } else if (role2.isNotEmpty) {
        intro += '$role2 ஆகவும் இருந்து வருகிறேன்.';
      } else {
        intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
      }
      defaultContent1 = intro;
      defaultContent2 = 'எனவே, தாங்கள் இது குறித்து சட்டப்படி நடவடிக்கை எடுத்து நீதி வழங்குமாறு தாழ்மையுடன் கேட்டுக்கொள்கிறேன்.';
      
      if (_recipientDesignationController.text.isEmpty || _recipientDesignationController.text == 'துணைக்காவல் கண்காணிப்பாளர்') {
          _recipientDesignationController.text = 'காவல் ஆய்வாளர் (Inspector of Police)';
          _recipientNameController.text = 'காவல் ஆய்வாளர் அவர்கள்';
          _recipientAddressController.text = 'காவல் நிலையம்,\n.................';
      }
    } else if (widget.petitionType == 'SP Appeal Petition') {
      defaultTitle = 'மேல்முறையீட்டு மனு';
      defaultSubject = 'காவல் ஆய்வாளர் அவர்களிடம் புகார் அளித்தும் நடவடிக்கை எடுக்காததால் மேல்முறையீடு செய்வது தொடர்பாக.';
      
      String intro = 'வணக்கம்,\nநான் மேற்கண்ட முகவரியில் வசித்து வருகிறேன். மேலும் நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கத்தின் ';
      final role3 = _senderDesignationController.text.replaceAll('நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கம்', '').trim();
      if (role3.contains('உறுப்பினர்')) {
        intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
      } else if (role3.isNotEmpty) {
        intro += '$role3 ஆகவும் இருந்து வருகிறேன்.';
      } else {
        intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
      }
      defaultContent1 = '$intro\n\nநான் கடந்த ................................. தேதியன்று ................................. காவல் நிலையத்தில் புகார் அளித்திருந்தேன்.';
      defaultContent2 = 'ஆனால், எனது புகாரின் மீது இதுநாள் வரை எவ்வித நடவடிக்கையும் எடுக்கப்படவில்லை (அல்லது) முதல் தகவல் அறிக்கை (FIR) பதிவு செய்யப்படவில்லை. எனவே, தாங்கள் இது குறித்து உரிய விசாரணை மேற்கொண்டு சட்டப்படி நடவடிக்கை எடுக்குமாறு தாழ்மையுடன் கேட்டுக்கொள்கிறேன்.'; 
      
      if (_recipientDesignationController.text.isEmpty || _recipientDesignationController.text.contains('Inspector') || _recipientDesignationController.text == 'துணைக்காவல் கண்காணிப்பாளர்') {
          _recipientDesignationController.text = 'காவல் கண்காணிப்பாளர் (Superintendent of Police)';
          _recipientNameController.text = 'காவல் கண்காணிப்பாளர் அவர்கள்';
          _recipientAddressController.text = 'மாவட்ட காவல் கண்காணிப்பாளர் அலுவலகம்,\n.................';
      }
    } else if (widget.petitionType == 'Reminder Petition' || widget.petitionType == 'Legal Notice') {
      final isReminder = widget.petitionType == 'Reminder Petition';
      defaultTitle = isReminder ? 'நினைவூட்டல் மனு' : 'சட்டப்பூர்வ அறிவிப்பு';
      defaultSubject = '......................................... அலுவலகத்திற்கு மனுதாரரால் பதிவு அஞ்சல் மூலம் அனுப்பிய மனு. நாள்: 22/05/2024';
      
      final role4 = _senderDesignationController.text.replaceAll('நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கம்', '').trim();
      String intro = 'வணக்கம்,\nநான் மேற்கண்ட முகவரியில் வசித்து வருகிறேன். மேலும் நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கத்தின் ';
      if (role4.contains('உறுப்பினர்')) {
        intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
      } else if (role4.isNotEmpty) {
        intro += '$role4 ஆகவும் இருந்து வருகிறேன்.';
      } else {
        intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
      }

      if (isReminder) {
        defaultContent1 = '$intro\n\nபார்வையில் காணும் கோரிக்கை மனுவினை கடந்த................................. தேதியன்று அனுப்பி இன்றுடன்....................... நாட்கள் முடிவடைந்து விட்டது. நாளது தேதி வரை எனது கோரிக்கை அரசால் நிறைவேற்றுகை செய்யப்படவில்லை. இது தமிழ்நாடு அரசாணை எண்.73/2018 நாள்.11.06.2018 இல் கண்டுள்ள நெறிகளின்படி இது குற்றமுறு நடவடிக்கையாக கருதப்படுகிறது. மேலும் மேற்காணும் அரசாணை விதிகளுக்கு ஆதரவாக ஒவ்வொரு அரசு அலுவலகங்களும் பொது மக்களிடம் பெறுகின்ற கோரிக்கை மனுவினை 30 தினங்களுக்குள் நிறைவேற்றுகை செய்ய வேண்டும் என்பதை உறுதி படுத்தி சென்னை உயர் நீதிமன்றம் வழக்கு எண். W. P. No. 20527 /2014 and M. P. No. 1/2014 நாள்.01.08.2014 என்ற வழக்கு தீர்ப்புரையில் உறுதி செய்து தீரப்பு வழங்கியுள்ளது. மேற்காணும் அரசாணை மற்றும் தீரப்பு ஆகியவை எனது இந்த கோரிக்கை மனுவுக்கும் இந்திய அரசியல் அமைப்பு சட்டம் 1950 இன் 14 வது பிரிவுப்படி பொருந்தும் என மனுதாராகிய என்னால் கருதப்பட்டு நினைவூட்டும் முகமாக தங்களுக்கு பணிந்து அனுப்ப படுகிறது.';
        defaultContent2 = '2) இந்த நினைவூட்டும் விண்ணப்பம் தங்களுக்கு கிடைத்த 15 தினங்களுக்குள் எனது கோரிக்கையை நிறைவேற்றுகை செய்ய தவறும் பட்சத்திலும் அல்லது பதில் வழங்க தவறினாலும் தங்களின் பதில் எனக்கு திருப்தி அளிக்க வில்லை என்றாலும் நீங்கள் உங்களின் கடமையை செய்ய தவறியுள்ளீர்கள் என மனுதாராகிய என்னால் கருதப்பட்டு நீதிமன்ற நடவடிக்கை மேற்கொள்ள இதுவே ஆவணமாகிவிடும் என்பதையும், அதற்க்காகும் வேலையிழப்பு /வீண் செலவினங்கள்/வருமான இழப்பு /மன உளைச்சல் ஆகியவற்றுக்கு தாங்களே தார்மீக பொறுப்பு ஏற்க நேரிடும் என்பதையும் இதன் மூலம் நினைவூட்டப்படுகிறது.';
      } else {
        defaultContent1 = '$intro நான் கடந்த 22/05/2024 தேதியில் கோரிக்கை மனு ஒன்றை தங்களது அலுவலகத்திற்கு அஞ்சல் வழியில் மனு செய்திருந்தேன். மேற்கண்ட எனது மனுவின் மீது இது நாள் வரை எந்த ஒரு நடவடிக்கையும் மேற்கொள்ளவில்லை.\n\nஅம்மனுவினை பெற்றுக் கொண்டதற்கான ஒப்புதல் தமிழ்நாடு அரசாணை எண்.73/2018 - நாள்:11-06-2018 இல் வகுத்துரைக்கப்பட்டவாறு 5 தினங்களுக்குள் மேற்காணும் எனது கோரிக்கை மனுவிற்கு ஒப்புதல் வழங்கவில்லை என்பதையும், மேற்காணும் அரசாணை விதிகளில் வகுத்துரைக்கப்பட்டவாறு 30 தினங்களுக்குள் நிறைவேற்றுகை செய்து வழங்க வேண்டும் என்றும், இயலாது போனால் அதற்கான நியாயமான காரணத்தை மனுதாருக்கு எழுத்து மூலமாக தெரிவிக்கப்பட வேண்டும் என்றும் அரசு ஊழியர்களுக்கான நடைமுறை விதிகளை வகுத்துள்ளது இவ்விதிகளுக்கு முரணாக மனுதாரர் ஆகிய எனது கோரிக்கை மனு மீது மேற்கண்ட விதிமுறைகள் பின்பற்றப்படவில்லை என்பதையும்,\n\nமேற்காணும் சங்கதிகள் தமிழ்நாடு அரசு குடிமை பணி விதிகள் 17 (2), மற்றும் அரசு ஊழியர் நடத்தை விதிகள் - 1975 இன் 20வது பிரிவு படியும், பாரதிய நியாய சன்ஹிதா, 2023 பிரிவு 198 படி தண்டிக்கப்பட வேண்டிய குற்றம் என்பதையும் இதன் மூலம் அறிவிக்கலாயிற்று.';
        defaultContent2 = 'மனுதாராகிய எனது கோரிக்கை மனுவினை இந்த அறிவிப்பு தங்களுக்கு கிடைத்த 15 தினங்களுக்குள் நிறைவேற்றுகை செய்ய தவறும் பட்சத்திலும், வீணான அலைக்கழிப்பு செய்ய வேண்டும் என்ற கெட்ட நோக்கத்தோடு எனக்கு திருப்தி அளிக்காத பதில் வழங்கினாலும் / பதில் வழங்க தவறினாலும் பாரதிய சாக்ஷ்ய அதிநியம், 2023 பிரிவு 109 வது பிரிவு படி மேற்கண்ட குற்றச் செயல்களை மறைமுகமாக ஒப்புக் கொள்வதாக கருதப்படும் என்பதையும்,\n\nமேற்காணும் சங்கதிகள்க்காக மனுதாராகிய எனது வேலையிழப்பு / வீண் அலைச்சல் / மன உளைச்சல் ஆகியவற்றுக்கு ரூ.10 இலட்சம் இழப்பீடாக வழங்க வேண்டும் என்றும் இதன் மூலம் அறிவிக்க லாயிற்று. மேலும் எனது கோரிக்கையை நிறைவேற்றுகை செய்யாத பட்சத்தில் மனித உரிமை பாதுகாப்பு சட்டம் - 1993 இன் படியும், நுகர்வோர் பாதுகாப்பு சட்டம் - 1986 இன் பிரிவு 12 இன் படியும் நுகர்வோர் குறைதீர் மன்றத்திலும் வழக்கு தொடுக்க இதுவே ஆவணமாகி விடும் என்பதையும், எனக்கான நஷ்ட ஈட்டு தொகையான ரூ.10, இலட்சம் and வழக்கு செலவினங்கள் ஆகியவற்றிற்கு தாங்களே தார்மீகப் பொறுப்பு ஏற்க நேரிடும் என்பதையும் இதன் மூலம் அறிவிக்க லாயிற்று.';
      }
    } else if (widget.petitionType == 'BNSS 218 Permission Petition') {
      defaultTitle = 'அரசு ஊழியர் மீது வழக்கு தொடர அனுமதி கோரும் மனு (BNSS 218)';
      defaultSubject = 'பாரதிய நாகரிக சுரக்ஷா சன்ஹிதா (BNSS), 2023 பிரிவு 218-ன் கீழ் அரசு ஊழியர் மீது வழக்கு தொடர அனுமதி வேண்டுதல் தொடர்பாக.';
      
      String intro = 'வணக்கம்,\nநான் மேற்கண்ட முகவரியில் வசித்து வருகிறேன். மேலும் நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கத்தின் ';
      final roleBNSS = _senderDesignationController.text.replaceAll('நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கம்', '').trim();
      if (roleBNSS.contains('உறுப்பினர்')) {
        intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
      } else if (roleBNSS.isNotEmpty) {
        intro += '$roleBNSS ஆகவும் இருந்து வருகிறேன்.';
      } else {
        intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
      }
      defaultContent1 = intro;
      defaultContent2 = 'அரசு ஊழியர்கள் தங்களின் கடமையை செய்யத் தவறும் பட்சத்திலும், பொதுமக்களின் கோரிக்கை மனுக்களை நிறைவேற்றத் தவறும் பட்சத்திலும் அவர்கள் மீது சட்டப்படி நடவடிக்கை எடுக்க பாரதிய நாகரிக சுரக்ஷா சன்ஹிதா, 2023 பிரிவு 218-ன் கீழ் அனுமதி வழங்க அதிகாரம் உள்ளது. எனவே, சம்பந்தப்பட்ட அரசு ஊழியர் மீது வழக்கு தொடர உரிய அனுமதி அளிக்குமாறு தாழ்மையுடன் கேட்டுக்கொள்கிறேன்.';
    }

    // Set controllers
    _titleController = TextEditingController(text: defaultTitle);
    _subjectController = TextEditingController(text: defaultSubject);
    
    // Always start with 2 fields
    _contentControllers = [
      TextEditingController(text: defaultContent1),
      TextEditingController(text: defaultContent2),
    ];

    debugPrint('Initial Content Controllers count: ${_contentControllers.length} for type: ${widget.petitionType}');

    // User requested to REMOVE Body Content 3 completely for ALL types.
    // We now strictly default to 2 fields.
    debugPrint('Defaulting to exactly 2 content fields for all petition types.');
    
    _reqDocumentsControllers = [TextEditingController()];
    _attachmentControllers = [
      TextEditingController(
        text: (widget.petitionType == 'Reminder Petition' || widget.petitionType == 'Legal Notice')
          ? 'பார்வையில் காணும் கோரிக்கை மனு நாள்.........................,........ நகல்.' 
          : (isEvidenceAct ? 'ரூபாய் 20/- மதிப்புள்ள நீதிமன்றவில்லை' : '')
      )
    ];
    _ccControllers = [TextEditingController()];
  }

  void _updateContentBasedOnDesignation() {
    final String typeLower = (widget.petitionType ?? '').toLowerCase();
    final bool isEvidenceAct = typeLower.contains('evidence') && typeLower.contains('act');
    
    if (widget.petitionType != 'Reminder Petition' && 
        widget.petitionType != 'Legal Notice' && 
        !isEvidenceAct) return;
    
    final designation = _senderDesignationController.text.trim();
    final role = designation.replaceAll('நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கம்', '').trim();
    String intro = 'வணக்கம்,\nநான் மேற்கண்ட முகவரியில் வசித்து வருகிறேன். மேலும் நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கத்தின் ';
    
    if (role.contains('உறுப்பினர்')) {
      intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
    } else if (role.isNotEmpty) {
      intro += '$role ஆகவும் இருந்து வருகிறேன்.';
    } else {
      intro += 'உறுப்பினராகவும் இருந்து வருகிறேன்.';
    }

    String mainText = '';
    
    if (widget.petitionType == 'Reminder Petition') {
       mainText = '\n\nபார்வையில் காணும் கோரிக்கை மனுவினை கடந்த................................. தேதியன்று அனுப்பி இன்றுடன்....................... நாட்கள் முடிவடைந்து விட்டது. நாளது தேதி வரை எனது கோரிக்கை அரசால் நிறைவேற்றுகை செய்யப்படவில்லை. இது தமிழ்நாடு அரசாணை எண்.73/2018 நாள்.11.06.2018 இல் கண்டுள்ள நெறிகளின்படி இது குற்றமுறு நடவடிக்கையாக கருதப்படுகிறது. மேலும் மேற்காணும் அரசாணை விதிகளுக்கு ஆதரவாக ஒவ்வொரு அரசு அலுவலகங்களும் பொது மக்களிடம் பெறுகின்ற கோரிக்கை மனுவினை 30 தினங்களுக்குள் நிறைவேற்றுகை செய்ய வேண்டும் என்பதை உறுதி படுத்தி சென்னை உயர் நீதிமன்றம் வழக்கு எண். W. P. No. 20527 /2014 and M. P. No. 1/2014 நாள்.01.08.2014 என்ற வழக்கு தீர்ப்புரையில் உறுதி செய்து தீரப்பு வழங்கியுள்ளது. மேற்காணும் அரசாணை மற்றும் தீரப்பு ஆகியவை எனது இந்த கோரிக்கை மனுவுக்கும் இந்திய அரசியல் அமைப்பு சட்டம் 1950 இன் 14 வது பிரிவுப்படி பொருந்தும் என மனுதாராகிய என்னால் கருதப்பட்டு நினைவூட்டும் முகமாக தங்களுக்கு பணிந்து அனுப்ப படுகிறது.';
    } else if (isEvidenceAct) {
       mainText = ''; // Evidence Act intro is just the intro itself for now, Content 2 is fixed.
    } else {
       mainText = ' நான் கடந்த 22/05/2024 தேதியில் கோரிக்கை மனு ஒன்றை தங்களது அலுவலகத்திற்கு அஞ்சல் வழியில் மனு செய்திருந்தேன். மேற்கண்ட எனது மனுவின் மீது இது நாள் வரை எந்த ஒரு நடவடிக்கையும் மேற்கொள்ளவில்லை.\n\nஅம்மனுவினை பெற்றுக் கொண்டதற்கான ஒப்புதல் தமிழ்நாடு அரசாணை எண்.73/2018 - நாள்:11-06-2018 இல் வகுத்துரைக்கப்பட்டவாறு 5 தினங்களுக்குள் மேற்காணும் எனது கோரிக்கை மனுவிற்கு ஒப்புதல் வழங்கவில்லை என்பதையும், மேற்காணும் அரசாணை விதிகளில் வகுத்துரைக்கப்பட்டவாறு 30 தினங்களுக்குள் நிறைவேற்றுகை செய்து வழங்க வேண்டும் என்றும், இயலாது போனால் அதற்கான நியாயமான காரணத்தை மனுதாருக்கு எழுத்து மூலமாக தெரிவிக்கப்பட வேண்டும் என்றும் அரசு ஊழியர்களுக்கான நடைமுறை விதிகளை வகுத்துள்ளது இவ்விதிகளுக்கு முரணாக மனுதாரர் ஆகிய எனது கோரிக்கை மனு மீது மேற்கண்ட விதிமுறைகள் பின்பற்றப்படவில்லை என்பதையும்,\n\nமேற்காணும் சங்கதிகள் தமிழ்நாடு அரசு குடிமை பணி விதிகள் 17 (2), மற்றும் அரசு ஊழியர் நடத்தை விதிகள் - 1975 இன் 20வது பிரிவு படியும், பாரதிய நியாய சன்ஹிதா, 2023 பிரிவு 198 படி தண்டிக்கப்பட வேண்டிய குற்றம் என்பதையும் இதன் மூலம் அறிவிக்கலாயிற்று.';
    }

    // Only update if the user hasn't manually changed the text significantly 
    // or if it's the first initialization.
    // For simplicity and as per user request "update it", we'll refresh it.
    // However, if we do it every time they type, it might be annoying.
    // Let's only update if the content STARTS with the intro pattern.
    if (_contentControllers[0].text.isEmpty || _contentControllers[0].text.contains('நீதியைத்தேடி சட்ட விழிப்புணர்வு')) {
       _contentControllers[0].text = '$intro$mainText';
    }
  }

  void _loadAddressFrom(String savedAddress) {
    debugPrint('Parsing Address: "$savedAddress"');
    if (savedAddress.trim().isEmpty) {
      debugPrint('Address is empty, skipping parse.');
      setState(() {
        _hasSavedAddress = false;
        _relationType = RelationType.sonOf; 
      });
      return;
    }

    _hasSavedAddress = true; // Mark as having a saved address

    // Default values
    String father = '', door = '', street = '', vil = '', po = '', taluk = '', dist = '', pin = '';
    RelationType rType = RelationType.sonOf;

    // Check if the address follows the new KEY:VALUE| format
    if (savedAddress.contains(':') && savedAddress.contains('|')) {
      debugPrint('Using Key-Value parsing...');
      Map<String, String> addressMap = {};
      
      List<String> parts = savedAddress.split('|');
      for (String part in parts) {
        int colonIndex = part.indexOf(':');
        if (colonIndex != -1) {
          String key = part.substring(0, colonIndex).trim().toUpperCase(); // Normalize key
          String value = part.substring(colonIndex + 1).trim();
          addressMap[key] = value;
        }
      }

      debugPrint('Parsed Map: $addressMap');

      // Extract values with fallback keys
      if (addressMap.containsKey('RELATION')) {
          String rel = addressMap['RELATION']!;
          if (rel == 'wifeOf') rType = RelationType.wifeOf;
          else if (rel == 'daughterOf') rType = RelationType.daughterOf;
          else rType = RelationType.sonOf;
      }

      father = addressMap['FATHER'] ?? addressMap['WIFE'] ?? addressMap['DAUGHTER'] ?? '';
      door = addressMap['DOOR'] ?? '';
      street = addressMap['STREET'] ?? '';
      vil = addressMap['VILLAGE'] ?? '';
      po = addressMap['POST'] ?? addressMap['PO'] ?? '';
      taluk = addressMap['TALUK'] ?? '';
      dist = addressMap['DISTRICT'] ?? addressMap['DIST'] ?? '';
      pin = addressMap['PINCODE'] ?? addressMap['PIN'] ?? '';

    } else {
      debugPrint('Using Legacy split parsing (comma separated)...');
      // Legacy: Door, Street, Village, Post, Taluk, Dist, Pin
      List<String> parts = savedAddress.split(',');
      if (parts.isNotEmpty) door = parts[0].trim();
      if (parts.length > 1) street = parts[1].trim();
      if (parts.length > 2) vil = parts[2].trim();
      if (parts.length > 3) po = parts[3].trim();
      if (parts.length > 4) taluk = parts[4].trim();
      if (parts.length > 5) dist = parts[5].trim();
      if (parts.length > 6) pin = parts[6].trim();
    }

    // Update Controllers
    setState(() {
      _relationType = rType;
      _fatherNameController.text = father;
      _doorNoController.text = door;
      _streetController.text = street;
      _villageController.text = vil;
      _postOfficeController.text = po;
      _talukController.text = taluk;
      _districtController.text = dist;
      _pincodeController.text = pin;
      
      // Auto-check "Save this address" if we loaded one, so users know it's active
      _saveAddress = true; 
    });
  }

  Future<void> _manualLoadFromProfile() async {
    debugPrint('Manual Load initiated...');
    setState(() => _isLoading = true);
    try {
      // FORCE REFRESH from Firestore instead of reading cached value
      final authState = ref.read(authStateProvider);
      final authUser = authState.value;
      if (authUser == null) {
        debugPrint('Auth user is null, cannot load.');
        return;
      }
      
      debugPrint('Fetching fresh user data for: ${authUser.uid}');
      final freshUser = await ref.read(firebaseServiceProvider).getUserData(authUser.uid);
      
      if (freshUser != null) {
        debugPrint('Fresh user found. Address: "${freshUser.address}"');
        _loadAddressFrom(freshUser.address ?? '');
        setState(() {
          _hasSavedAddress = (freshUser.address ?? '').isNotEmpty;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('சுயவிவர முகவரி ஏற்றப்பட்டது (Profile address loaded)'),
              backgroundColor: Colors.blue,
            )
          );
        }
      } else {
        debugPrint('Fresh user record is NULL');
      }
    } catch (e) {
      debugPrint('Error manually loading address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfileDetails() async {
    debugPrint('Updating Name/Designation/Phone...');
    final name = _senderNameController.text.trim();
    final designation = _senderDesignationController.text.trim();
    final phone = _senderMobileController.text.trim();

    if (name.isEmpty || designation.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, Designation and Phone cannot be empty.'), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserModel? userToUpdate = widget.currentUser;
      
      // Fallback identification
      if (userToUpdate == null) {
          final authState = ref.read(authStateProvider);
          final uid = authState.value?.uid;
          if (uid != null) {
             userToUpdate = await ref.read(firebaseServiceProvider).getUserData(uid);
          }
      }

      if (userToUpdate == null) {
        throw Exception("User not identified. Please login again.");
      }

      final updatedUser = userToUpdate.copyWith(
        name: name,
        designation: designation,
        phone: phone,
      );
      
      await ref.read(firebaseServiceProvider).saveUserData(updatedUser);
      debugPrint('Profile Name/Designation/Phone updated.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile Name, Designation & Phone Updated!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAllProfileInfo() async {
    debugPrint('Unified Update: Profile + Address...');
    final name = _senderNameController.text.trim();
    final designation = _senderDesignationController.text.trim();
    final phone = _senderMobileController.text.trim();

    if (name.isEmpty || designation.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, Designation and Phone cannot be empty.'), backgroundColor: Colors.orange)
      );
      return;
    }

    // Format address
    String prefix = 'FATHER';
    if (_relationType == RelationType.wifeOf) prefix = 'WIFE';
    else if (_relationType == RelationType.daughterOf) prefix = 'DAUGHTER';

    String storageAddress = [
      'RELATION:${_relationType.name}',
      '$prefix:${_fatherNameController.text.trim()}',
      'DOOR:${_doorNoController.text.trim()}',
      'STREET:${_streetController.text.trim()}',
      'VILLAGE:${_villageController.text.trim()}',
      'POST:${_postOfficeController.text.trim()}',
      'TALUK:${_talukController.text.trim()}',
      'DISTRICT:${_districtController.text.trim()}',
      'PINCODE:${_pincodeController.text.trim()}'
    ].join('|');

    setState(() => _isLoading = true);
    try {
      UserModel? userToUpdate = widget.currentUser;
      
      if (userToUpdate == null) {
          final authState = ref.read(authStateProvider);
          final uid = authState.value?.uid;
          if (uid != null) {
             userToUpdate = await ref.read(firebaseServiceProvider).getUserData(uid);
          }
      }

      if (userToUpdate == null) {
        throw Exception("User not identified. Please login again.");
      }

      final updatedUser = userToUpdate.copyWith(
        name: name,
        designation: designation,
        phone: phone,
        address: storageAddress,
      );
      
      await ref.read(firebaseServiceProvider).saveUserData(updatedUser);
      debugPrint('Unified Profile updated.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile details & Address Updated! (சொந்த விவரங்கள் புதுப்பிக்கப்பட்டது)'), 
            backgroundColor: Colors.green
          )
        );
        // Refresh intro text after saving profile (since designation might have changed)
        _updateContentBasedOnDesignation();
      }
    } catch (e) {
      debugPrint('Error in unified update: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showContentActionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Content & Profile Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_outline, color: Theme.of(context).primaryColor),
              title: const Text('Update Account Profile'),
              subtitle: const Text('Save current Name, Role & Address to your profile permanently.'),
              onTap: () {
                Navigator.pop(ctx);
                _updateAllProfileInfo();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Reset Intro to Template'),
              subtitle: const Text('Restore the official legal template text for this petition.'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _updateContentBasedOnDesignation();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Content Reset to Official Template!'), backgroundColor: Colors.orange)
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  final _recipientNameController = TextEditingController(text: 'R.முத்துராஜா');
  final _recipientDesignationController = TextEditingController(text: 'துணைக்காவல் கண்காணிப்பாளர்');
  final _recipientAddressController = TextEditingController(text: 'இலுப்பூர் சரகம், புதுக்கோட்டை மாவட்டம்-622102');
  late final TextEditingController _titleController;
  late final TextEditingController _subjectController;
  late List<TextEditingController> _contentControllers;

  // Editable submission details
  late final TextEditingController _placeController;
  late final TextEditingController _dateController;

  @override
  void dispose() {
    _senderNameController.dispose();
    _senderDesignationController.dispose();
    _senderMobileController.dispose();
    
    _fatherNameController.dispose();
    _doorNoController.dispose();
    _streetController.dispose();
    _villageController.dispose();
    _postOfficeController.dispose();
    _talukController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    
    _recipientNameController.dispose();
    _recipientDesignationController.dispose();
    _recipientAddressController.dispose();
    
    _titleController.dispose();
    _subjectController.dispose();
    for (var controller in _contentControllers) {
      controller.dispose();
    }
    _razorpay.clear();
    for (var controller in _reqDocumentsControllers) {
      controller.dispose();
    }
    for (var controller in _attachmentControllers) {
      controller.dispose();
    }
    for (var controller in _ccControllers) {
      controller.dispose();
    }
    _placeController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _generatePdf() async {
    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please fill all required fields correctly'), backgroundColor: Colors.orange)
       );
       return;
    }
    _showPdfPreviewDialog();
  }

  Future<void> _showPdfPreviewDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview PDF Petition Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreviewItem('Title', _titleController.text),
                _buildPreviewItem('Subject', _subjectController.text),
                _buildPreviewItem('Sender', _senderNameController.text),
                if (_senderDesignationController.text.isNotEmpty)
                  _buildPreviewItem('Sender Designation', _senderDesignationController.text),
                _buildPreviewItem('Recipient', _recipientNameController.text),
                if (_recipientDesignationController.text.isNotEmpty)
                  _buildPreviewItem('Recipient Designation', _recipientDesignationController.text),
                
                const Divider(),
                const Text('Required Documents:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ..._reqDocumentsControllers.where((c) => c.text.isNotEmpty).map((c) => 
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('• ${c.text}', style: const TextStyle(fontSize: 12)),
                  )
                ),
                
                const SizedBox(height: 10),
                const Text('Petition Content:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _contentControllers.map((c) => c.text).where((t) => t.isNotEmpty).join('\n\n').trim(),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),

                const SizedBox(height: 10),
                const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ..._attachmentControllers.where((c) => c.text.isNotEmpty).map((c) => 
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('• ${c.text}', style: const TextStyle(fontSize: 12)),
                  )
                ),

                if (_ccControllers.any((c) => c.text.isNotEmpty)) ...[
                   const SizedBox(height: 10),
                   const Text('Copy Recipients:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                   ..._ccControllers.where((c) => c.text.isNotEmpty).map((c) => 
                     Padding(
                       padding: const EdgeInsets.only(left: 8, top: 2),
                       child: Text('• ${c.text}', style: const TextStyle(fontSize: 12)),
                     )
                   ),
                ],

                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPreviewItem('Place', _placeController.text),
                    _buildPreviewItem('Date', _dateController.text),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Edit More'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _executePdfGeneration();
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Confirm & Generate PDF'),
          ),
        ],
      ),
    );
  }



  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (mounted && _pendingPaymentModel != null && _onPaymentSuccess != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Payment successful! ID: ${response.paymentId ?? "N/A"}')),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
      _onPaymentSuccess!(_pendingPaymentModel!);
    }
    _pendingPaymentModel = null;
    _onPaymentSuccess = null;
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _pendingPaymentModel = null;
    _onPaymentSuccess = null;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Payment failed: ${response.message ?? "Unknown error"}')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('External wallet selected: ${response.walletName}'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _showPaymentDialog(PetitionModel model, void Function(PetitionModel) onPaySuccess) {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Petition Generation Fee: ₹${PaymentConfig.petitionFee.toInt()}'),
            const SizedBox(height: 10),
            Text(
              PaymentConfig.useMockPayment 
                ? 'Test Mode — payment will be simulated.' 
                : 'Pay via Razorpay to download this petition.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (PaymentConfig.useMockPayment) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science, size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 6),
                    Text('TEST MODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: Icon(PaymentConfig.useMockPayment ? Icons.science : Icons.payment, size: 18),
            label: Text(PaymentConfig.useMockPayment 
              ? '✅ Test Pay ₹${PaymentConfig.petitionFee.toInt()}'
              : 'Pay ₹${PaymentConfig.petitionFee.toInt()}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaymentConfig.useMockPayment ? Colors.green : null,
              foregroundColor: PaymentConfig.useMockPayment ? Colors.white : null,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              
              if (PaymentConfig.useMockPayment) {
                // ── Mock Payment Simulation ──────────────────
                _simulateMockPayment(model, onPaySuccess);
              } else {
                // ── Real Razorpay Checkout ────────────────────
                _pendingPaymentModel = model;
                _onPaymentSuccess = onPaySuccess;
                
                var options = {
                  'key': PaymentConfig.razorpayKey,
                  'amount': PaymentConfig.petitionFeeInPaise,
                  'name': PaymentConfig.merchantName,
                  'description': 'Petition Fee - ${widget.petitionType ?? "General"}',
                  'prefill': {
                    'contact': widget.currentUser?.phone ?? '',
                    'email': widget.currentUser?.email ?? '',
                  },
                  'theme': {'color': PaymentConfig.themeColor}
                };
                
                try {
                  _razorpay.open(options);
                } catch (e) {
                  debugPrint('Error opening Razorpay: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error opening payment: $e'), backgroundColor: Colors.red),
                  );
                  _pendingPaymentModel = null;
                  _onPaymentSuccess = null;
                }
              }
            },
          ),
        ],
      )
    );
  }

  void _simulateMockPayment(PetitionModel model, void Function(PetitionModel) onPaySuccess) {
    // Show a processing overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Processing Test Payment...', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('₹${PaymentConfig.petitionFee.toInt()} for ${widget.petitionType ?? "Petition"}', 
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );

    // Simulate 1.5 second delay, then succeed
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('✅ Test Payment Successful! (Mock Mode)')),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
      
      onPaySuccess(model);
    });
  }

  Future<void> _saveAddressToProfile() async {
    debugPrint('Attempting to save address...');
    String prefix = 'FATHER';
    if (_relationType == RelationType.wifeOf) prefix = 'WIFE';
    else if (_relationType == RelationType.daughterOf) prefix = 'DAUGHTER';

    String storageAddress = [
      'RELATION:${_relationType.name}',
      '$prefix:${_fatherNameController.text.trim()}',
      'DOOR:${_doorNoController.text.trim()}',
      'STREET:${_streetController.text.trim()}',
      'VILLAGE:${_villageController.text.trim()}',
      'POST:${_postOfficeController.text.trim()}',
      'TALUK:${_talukController.text.trim()}',
      'DISTRICT:${_districtController.text.trim()}',
      'PINCODE:${_pincodeController.text.trim()}'
    ].join('|');

    debugPrint('Formatted Address: $storageAddress');

    try {
      UserModel? userToUpdate = widget.currentUser;

      // Fallback if widget.currentUser is null
      if (userToUpdate == null) {
        final authState = ref.read(authStateProvider);
        final uid = authState.value?.uid;
        if (uid != null) {
           userToUpdate = await ref.read(firebaseServiceProvider).getUserData(uid);
        }
      }

      if (userToUpdate == null) {
        throw Exception("User not identified. Please login again.");
      }

      final updatedUser = userToUpdate.copyWith(address: storageAddress);
      await ref.read(firebaseServiceProvider).saveUserData(updatedUser);
      debugPrint('Address saved successfully to Firebase.');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address saved to profile!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint('Error saving address to Firebase: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save address: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _executePdfGeneration([PetitionModel? preBuiltModel]) async {
    
    try {
      PetitionModel model;

      if (preBuiltModel != null) {
        model = preBuiltModel;
      } else {
        // Construct address for PDF (Readable)
        List<String> pdfParts = [];
        if (_fatherNameController.text.isNotEmpty) {
          String nameLabel = _getRelationLabel();
          pdfParts.add('$nameLabel: ${_fatherNameController.text}');
        }
        if (_doorNoController.text.isNotEmpty) pdfParts.add(_doorNoController.text);
        if (_streetController.text.isNotEmpty) pdfParts.add(_streetController.text);
        if (_villageController.text.isNotEmpty) pdfParts.add(_villageController.text);
        if (_postOfficeController.text.isNotEmpty) pdfParts.add('${_postOfficeController.text} (PO)');
        if (_talukController.text.isNotEmpty) pdfParts.add('${_talukController.text} Taluk');
        if (_districtController.text.isNotEmpty) pdfParts.add('${_districtController.text} District');
        String readableAddress = pdfParts.join(', ');
        if (_pincodeController.text.isNotEmpty) readableAddress += ' - ${_pincodeController.text}';

        model = PetitionModel(
          senderName: _senderNameController.text,
          senderDesignation: _senderDesignationController.text,
          senderAddress: readableAddress,
          senderMobile: _senderMobileController.text,
          recipientName: _recipientNameController.text,
          recipientDesignation: _recipientDesignationController.text,
          recipientAddress: _recipientAddressController.text,
          title: _titleController.text,
          subject: _subjectController.text,
          content: _contentControllers.map((c) => c.text).where((t) => t.isNotEmpty).join('\n\n').trim(),
          reqDocuments: _reqDocumentsControllers.map((c) => c.text).where((t) => t.isNotEmpty).join('\n'),
          attachments: _attachmentControllers.map((c) => c.text).where((t) => t.isNotEmpty).join('\n'),
          place: _placeController.text,
          date: _dateController.text,
          copyRecipients: _ccControllers.asMap().entries.map((e) => '${e.key + 1}. ${e.value.text}').where((t) => t.length > 3).join('\n'),
        );

        // Check Access (Role Exempt OR Free Access Type)
        final user = widget.currentUser;
        final isRoleExempt = user?.role.name.toLowerCase().contains('board') == true || 
                             user?.role.name.toLowerCase().contains('committee') == true ||
                             user?.role.name.toLowerCase().contains('admin') == true;
        
        final isFreeAccess = (user?.isPetitionFree ?? false) || isRoleExempt;

        if (preBuiltModel == null && !isFreeAccess) {
             _showPaymentDialog(model, _executePdfGeneration);
             return;
        }

        // Save address logic
        if (_saveAddress && widget.currentUser != null) {
          await _saveAddressToProfile();
        }
      }









      final pdfBytes = await PetitionPdfService().generatePetitionPdf(model);

      if (mounted && pdfBytes.isNotEmpty) {
        debugPrint('Saving PDF document...');
        
        if (Platform.isAndroid || Platform.isIOS) {
           // Mobile "Save As" flow
           try {
             final tempDir = await getTemporaryDirectory();
             final file = File('${tempDir.path}/Petition_${DateTime.now().millisecondsSinceEpoch}.pdf');
             await file.writeAsBytes(pdfBytes);
             
             final params = SaveFileDialogParams(sourceFilePath: file.path);
             final filePath = await FlutterFileDialog.saveFile(params: params);
             
             if (filePath != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF Saved Successfully!'), backgroundColor: Colors.green)
                );
             }
           } catch (e) {
             debugPrint('Error saving PDF: $e');
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Error saving PDF: $e'), backgroundColor: Colors.red)
               );
             }
           }
        } else {
          // Desktop/Web fallback
          await Printing.sharePdf(
            bytes: Uint8List.fromList(pdfBytes),
            filename: 'Petition_${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
        }
      }

      // Save history record ASYNC (non-blocking)
      _recordPetitionHistory(
        petitionType: widget.petitionType ?? 'General',
        title: _titleController.text,
        subject: _subjectController.text,
        content: _contentControllers.map((c) => c.text).where((t) => t.isNotEmpty).join('\n\n').trim(),
      );

    } catch (e, stackTrace) {
      debugPrint('Error generating PDF: $e\n$stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'COPY',
              textColor: Colors.white,
              onPressed: () => Clipboard.setData(ClipboardData(text: e.toString())),
            ),
          ),
        );
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  /// Helper to record petiton history without blocking the main export flow
  void _recordPetitionHistory({
    required String petitionType,
    required String title,
    required String subject,
    required String content,
  }) {
    if (widget.currentUser == null) return;
    
    // Run in background
    Future(() async {
      try {
        debugPrint('Recording petition history in background...');
        final record = PetitionRecord(
          id: '', // Firestore will generate
          userId: widget.currentUser!.uid,
          userName: widget.currentUser!.name,
          petitionType: petitionType,
          title: title,
          subject: subject,
          content: content,
          timestamp: DateTime.now(),
        );
        await ref.read(firebaseServiceProvider).savePetitionRecord(record);
        debugPrint('Petition history recorded successfully.');
      } catch (e) {
        debugPrint('Error recording petition history: $e');
      }
    });
  }

  void _generateWord() async {
    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please fill all required fields correctly'), backgroundColor: Colors.orange)
       );
       return;
    }
    
    _showWordPreviewDialog();
  }

  Future<void> _showWordPreviewDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Petition Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreviewItem('Title', _titleController.text),
                _buildPreviewItem('Subject', _subjectController.text),
                _buildPreviewItem('Sender', _senderNameController.text),
                if (_senderDesignationController.text.isNotEmpty)
                  _buildPreviewItem('Sender Designation', _senderDesignationController.text),
                _buildPreviewItem('Recipient', _recipientNameController.text),
                if (_recipientDesignationController.text.isNotEmpty)
                  _buildPreviewItem('Recipient Designation', _recipientDesignationController.text),
                
                const Divider(),
                const Text('Required Documents:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ..._reqDocumentsControllers.where((c) => c.text.isNotEmpty).map((c) => 
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('• ${c.text}', style: const TextStyle(fontSize: 12)),
                  )
                ),
                
                const SizedBox(height: 10),
                const Text('Petition Content:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _contentControllers.map((c) => c.text).where((t) => t.isNotEmpty).join('\n\n').trim(),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),

                const SizedBox(height: 10),
                const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ..._attachmentControllers.where((c) => c.text.isNotEmpty).map((c) => 
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('• ${c.text}', style: const TextStyle(fontSize: 12)),
                  )
                ),

                if (_ccControllers.any((c) => c.text.isNotEmpty)) ...[
                   const SizedBox(height: 10),
                   const Text('Copy Recipients:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                   ..._ccControllers.where((c) => c.text.isNotEmpty).map((c) => 
                     Padding(
                       padding: const EdgeInsets.only(left: 8, top: 2),
                       child: Text('• ${c.text}', style: const TextStyle(fontSize: 12)),
                     )
                   ),
                ],

                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPreviewItem('Place', _placeController.text),
                    _buildPreviewItem('Date', _dateController.text),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Edit More'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _executeWordExport();
            },
            icon: const Icon(Icons.file_download),
            label: const Text('Confirm & Export'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 13),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value.isEmpty ? '(Empty)' : value),
          ],
        ),
      ),
    );
  }

  void _executeWordExport([PetitionModel? preBuiltModel]) async {
    setState(() => _isWordLoading = true);
    
    try {
      PetitionModel model;

      if (preBuiltModel != null) {
        model = preBuiltModel;
      } else {
        // Construct address for PDF (Readable)
        List<String> pdfParts = [];
        if (_fatherNameController.text.isNotEmpty) {
          String nameLabel = _getRelationLabel();
          pdfParts.add('$nameLabel: ${_fatherNameController.text}');
        }
        if (_doorNoController.text.isNotEmpty) pdfParts.add(_doorNoController.text);
        if (_streetController.text.isNotEmpty) pdfParts.add(_streetController.text);
        if (_villageController.text.isNotEmpty) pdfParts.add(_villageController.text);
        if (_postOfficeController.text.isNotEmpty) pdfParts.add('${_postOfficeController.text} (PO)');
        if (_talukController.text.isNotEmpty) pdfParts.add('${_talukController.text} Taluk');
        if (_districtController.text.isNotEmpty) pdfParts.add('${_districtController.text} District');
        String readableAddress = pdfParts.join(', ');
        if (_pincodeController.text.isNotEmpty) readableAddress += ' - ${_pincodeController.text}';

        model = PetitionModel(
          senderName: _senderNameController.text,
          senderDesignation: _senderDesignationController.text,
          senderAddress: readableAddress,
          senderMobile: _senderMobileController.text,
          recipientName: _recipientNameController.text,
          recipientDesignation: _recipientDesignationController.text,
          recipientAddress: _recipientAddressController.text,
          title: _titleController.text,
          subject: _subjectController.text,
          content: _contentControllers.map((c) => c.text).where((t) => t.isNotEmpty).join('\n\n').trim(),
          reqDocuments: _reqDocumentsControllers.map((c) => c.text).where((t) => t.isNotEmpty).join('\n'),
          attachments: _attachmentControllers.map((c) => c.text).where((t) => t.isNotEmpty).join('\n'),
          place: _placeController.text,
          date: _dateController.text,
          copyRecipients: _ccControllers.asMap().entries.map((e) => '${e.key + 1}. ${e.value.text}').where((t) => t.length > 3).join('\n'),
        );

        // Check Access (Role Exempt OR Free Access Type)
        final user = widget.currentUser;
        final isRoleExempt = user?.role.name.toLowerCase().contains('board') == true || 
                             user?.role.name.toLowerCase().contains('committee') == true ||
                             user?.role.name.toLowerCase().contains('admin') == true;
        
        final isFreeAccess = (user?.isPetitionFree ?? false) || isRoleExempt;

        if (preBuiltModel == null && !isFreeAccess) {
             _showPaymentDialog(model, _executeWordExport);
             return;
        }

        // Save address logic
        if (_saveAddress && widget.currentUser != null) {
          await _saveAddressToProfile();
        }
      }




      debugPrint('Exporting to Word...');
      await PetitionDocService().exportToDoc(model);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Word file (.doc) generated!'), backgroundColor: Colors.green)
        );
      }

      // Save history record ASYNC
      _recordPetitionHistory(
        petitionType: widget.petitionType ?? 'General',
        title: _titleController.text,
        subject: _subjectController.text,
        content: _contentControllers.map((c) => c.text).where((t) => t.isNotEmpty).join('\n\n').trim(),
      );
    } catch (e) {
      debugPrint('Word Export Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting to Word: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isWordLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.petitionType ?? 'New Petition'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Header Details'),
              _buildTextField('Petition Title', _titleController),
              const SizedBox(height: 20),

              _buildSectionHeader('Sender Details'),
              _buildTextField('Name', _senderNameController),
              _buildTextField('Designation', _senderDesignationController),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _updateProfileDetails,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Update Profile (பெயர், பதவி & தொலைபேசி புதுப்பி)'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Address Details', style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.blueGrey
                  )),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        _hasSavedAddress ? Icons.check_circle : Icons.help_outline,
                        size: 12,
                        color: _hasSavedAddress ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _hasSavedAddress ? 'சுயவிவரத்தில் முகவரி உள்ளது (Address in profile)' : 'முகவரி இல்லை (No address in profile)',
                          style: TextStyle(
                            fontSize: 11,
                            color: _hasSavedAddress ? Colors.green : Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _manualLoadFromProfile,
                          icon: _isLoading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download, size: 18),
                          label: const Text('Load from Profile'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetForm,
                          icon: const Icon(Icons.refresh, size: 18, color: Colors.orange),
                          label: const Text('Reset', style: TextStyle(color: Colors.orange)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Father/Husband/Daughter Name Toggle
              Row(
                children: [
                  Radio<RelationType>(
                    value: RelationType.sonOf,
                    groupValue: _relationType,
                    onChanged: (val) => setState(() => _relationType = val ?? RelationType.sonOf),
                    activeColor: Theme.of(context).primaryColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('S/O', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Radio<RelationType>(
                    value: RelationType.wifeOf,
                    groupValue: _relationType,
                    onChanged: (val) => setState(() => _relationType = val ?? RelationType.wifeOf),
                    activeColor: Theme.of(context).primaryColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('W/O', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Radio<RelationType>(
                    value: RelationType.daughterOf,
                    groupValue: _relationType,
                    onChanged: (val) => setState(() => _relationType = val ?? RelationType.daughterOf),
                    activeColor: Theme.of(context).primaryColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('D/O', style: TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              _buildTextField(_getRelationLongLabel(), _fatherNameController, required: false),
              _buildTextField('Door No (கதவு எண்)', _doorNoController, required: false),
              _buildTextField('Street (தெரு)', _streetController, required: false),
              _buildTextField('Village (கிராமம்)', _villageController, required: false),
              _buildTextField('Post Office (அஞ்சல் நிலையம்)', _postOfficeController, required: false),
              
              Row(
                children: [
                   Expanded(
                     child: _buildTextField('Taluk', _talukController, required: false),
                   ),
                   const SizedBox(width: 15),
                   Expanded(
                     child: _buildTextField('District', _districtController, required: false),
                   ),
                ],
              ),
              
              _buildTextField('Pincode', _pincodeController, keyboardType: TextInputType.number, required: false),
              
              // Save Option
                Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2))
                ),
                margin: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text(
                        "Save this address to my profile",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        "Future petitions will use this updated address",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: _saveAddress, 
                      activeColor: Colors.blue,
                      onChanged: (val) => setState(() => _saveAddress = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Validate at least some fields are filled
                            if (_districtController.text.isEmpty && _talukController.text.isEmpty) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text('Please fill at least District/Taluk to save.'), backgroundColor: Colors.orange)
                               );
                               return;
                            }
                            await _saveAddressToProfile();
                          },
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('Save Address Now (முகவரியை சேமி)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Notes removed as per user request (redundant with Save button)

              _buildTextField('Mobile', _senderMobileController, keyboardType: TextInputType.phone),

              const SizedBox(height: 20),
              _buildSectionHeader('Recipient Details'),
              _buildTextField('Name', _recipientNameController, required: false),
              _buildTextField('Designation', _recipientDesignationController),
              _buildTextField('Address', _recipientAddressController, maxLines: 2),

              const SizedBox(height: 20),
              _buildSectionHeader('Content Details'),
              _buildTextField('Subject (பார்வை)', _subjectController, hint: 'Enter subject/reference...', required: false),
              _buildBodyContentList(),
              if (widget.petitionType != 'Reminder Petition' && 
                  widget.petitionType != 'Legal Notice' && 
                  widget.petitionType != 'Police Complaint' && 
                  widget.petitionType != 'SP Appeal Petition' &&
                  widget.petitionType != 'BNSS 218 Permission Petition' &&
                  widget.petitionType != 'General Petition') ...[
                _buildRequiredDocumentsList(),
                
                // Concluding statement after Required Documents
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Text(
                    'மேற்கண்ட ஆவணங்களை சான்றிட்ட நகலாக வழங்குமாறு கேட்டுக்கொள்கிறேன்.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _buildSectionHeader('Footer Details'),
              _buildTextField('Place (இடம்)', _placeController),
              _buildTextField('Date (நாள்)', _dateController),
              _buildAttachmentsList(),
              
              const SizedBox(height: 20),
              _buildSectionHeader('நகல் சமர்ப்பிக்கப்படுகிறது: (Copy Recipients)'),
              _buildCCList(),


              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generatePdf,
                        icon: _isLoading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf, size: 28),
                        label: Text(
                          _isLoading ? 'PDF...' : 'Generate PDF',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isWordLoading ? null : _generateWord,
                        icon: _isWordLoading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.description, size: 28),
                        label: Text(
                          _isWordLoading ? 'Word...' : 'Export to Word',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18, 
          fontWeight: FontWeight.bold, 
          color: Theme.of(context).primaryColor
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType, String? hint, bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildBodyContentList() {
    final String typeLower = (widget.petitionType ?? '').trim().toLowerCase();
    final bool isSpecialType = typeLower.contains('police') || 
                              typeLower.contains('legal notice') || 
                              typeLower.contains('sp appeal') ||
                              typeLower.contains('bnss 218') ||
                              typeLower.contains('evidence act');

    final bool isEvidenceAct = typeLower.contains('evidence act');

    Widget addMoreButton = (isEvidenceAct) 
      ? const SizedBox.shrink() 
      : Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  if (isSpecialType) {
                    // Insert at index 1 (between first and last default fields)
                    _contentControllers.insert(1, TextEditingController());
                  } else {
                    // Standard behavior (add to end)
                    _contentControllers.add(TextEditingController());
                  }
                });
              },
              icon: const Icon(Icons.add_comment),
              label: const Text('Add More Content (கூடுதல் விவரம் சேர்க்க)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                side: BorderSide(color: Theme.of(context).primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._contentControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          
          List<Widget> children = [
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(top: 15),
                    child: Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      maxLines: 5,
                      decoration: InputDecoration(
                      labelText: 'Body Content ${index + 1}',
                      hintText: index == 0 ? 'Enter first part of content...' : 'Enter more content...',
                      suffixIcon: (index == 0 && (isSpecialType || typeLower.contains('reminder') || typeLower.contains('legal notice')))
                          ? IconButton(
                              tooltip: 'Content actions (Reset/Update)',
                              icon: Icon(Icons.tune, color: Theme.of(context).primaryColor),
                              onPressed: _showContentActionDialog,
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      alignLabelWithHint: true,
                    ),
                    ),
                  ),
                  if (_contentControllers.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _contentControllers[index].dispose();
                            _contentControllers.removeAt(index);
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ];

          if (isSpecialType && index == 0) {
            children.add(addMoreButton);
          }

          return Column(
            children: children,
          );
        }),
        
        if (!isSpecialType) addMoreButton,
        
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRequiredDocumentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'தேவைப்படும் ஆவணங்கள் (Required Documents)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        ..._reqDocumentsControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  alignment: Alignment.center,
                  child: Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'ஆவணம் ${index + 1} (Document ${index + 1})',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                if (_reqDocumentsControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _reqDocumentsControllers[index].dispose();
                        _reqDocumentsControllers.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _reqDocumentsControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Document (ஆவணம் சேர்க்க)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              side: BorderSide(color: Theme.of(context).primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAttachmentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachments (இணைப்பு)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        ..._attachmentControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Attachment ${index + 1}',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                if (_attachmentControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _attachmentControllers[index].dispose();
                        _attachmentControllers.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _attachmentControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Attachment'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              side: BorderSide(color: Theme.of(context).primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      List<String> list = prefs.getStringList('custom_recipients') ?? [];
      
      // FORCE PURGE: Remove the old hardcoded Madurai defaults if they exist in the saved list
      list.removeWhere((item) => 
        item == 'The District Collector, Madurai District.' ||
        item == 'The Superintendent of Police, Madurai District.' ||
        item == 'The Tahsildar, Madurai North Taluk.' ||
        item == 'The Inspector of Police, Tallakulam Police Station.'
      );
      
      _savedPresets = list;
      // Persist the cleaned list immediately
      prefs.setStringList('custom_recipients', _savedPresets);
    });
  }

  Future<void> _deletePreset(String recipient) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPresets.remove(recipient);
      // Create a fresh list for identity check
      _savedPresets = [..._savedPresets];
    });
    await prefs.setStringList('custom_recipients', _savedPresets);
  }

  Future<void> _updatePreset(String oldText, String newText) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      int index = _savedPresets.indexOf(oldText);
      if (index != -1) {
        _savedPresets[index] = newText;
        _savedPresets = [..._savedPresets]; // identity change
      }
    });
    await prefs.setStringList('custom_recipients', _savedPresets);
  }

  Future<void> _savePreset(String recipient) async {
    if (!_savedPresets.contains(recipient)) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _savedPresets = [..._savedPresets, recipient]; // Use spread to change list identity
      });
      await prefs.setStringList('custom_recipients', _savedPresets);
    }
  }

  Future<void> _showAddRecipientDialog({int targetIndex = 1, String? initialValue}) async {
    final fullRecipientController = TextEditingController(text: initialValue);
    final bool isEditing = initialValue != null;
    
    return showDialog(
      context: context,
      barrierDismissible: false, // Force user to use buttons
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Update Saved Recipient' : 'Add Custom Recipient'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paste or type the full recipient details here:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: fullRecipientController,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Details (முகவரி விவரங்கள்)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    onChanged: (val) {
                      setDialogState(() {}); // Rebuild local dialog for preview
                    },
                  ),
                  const SizedBox(height: 16),
                  if (fullRecipientController.text.isNotEmpty) ...[
                    const Text(
                      'Preview (How it will appear):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        fullRecipientController.text,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final rawText = fullRecipientController.text.trim();
                  if (rawText.isNotEmpty) {
                    try {
                      if (isEditing) {
                        await _updatePreset(initialValue, rawText);
                      } else {
                        await _savePreset(rawText);
                      }
                      
                      // Auto-select in the target slot
                      if (_ccControllers.length > targetIndex) {
                        setState(() { // This is the outer class setState
                          _ccControllers[targetIndex].text = rawText;
                        });
                      }
                      
                      if (mounted) Navigator.of(dialogContext, rootNavigator: true).pop();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditing ? 'Recipient updated successfully!' : 'Recipient saved successfully!'), 
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        )
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                      );
                    }
                  }
                },
                child: Text(isEditing ? 'Update' : 'Save'),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildCCList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._ccControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;

          // SPECIAL CASE: 1st Recipient (Index 0) is a Dropdown
          if (index == 0) {
             // Ensure the controller has a valid default if empty
             if (controller.text.isEmpty) {
               controller.text = 'இந்திய அரசியலமைப்பு பிரிவு 226 இன் படி பொதுப்பதிவாளர் உயர்நீதிமன்றம், சென்னை';
             }
             
             return Padding(
               padding: const EdgeInsets.only(bottom: 8.0),
               child: Row(
                 children: [
                   Container(
                     width: 30,
                     alignment: Alignment.center,
                     child: Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                   ),
                   Expanded(
                     child: DropdownButtonFormField<String>(
                       value: controller.text,
                       isExpanded: true,
                       decoration: InputDecoration(
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                         filled: true,
                         fillColor: Colors.grey[50],
                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                       ),
                       items: const [
                         DropdownMenuItem(
                           value: 'இந்திய அரசியலமைப்பு பிரிவு 226 இன் படி பொதுப்பதிவாளர் உயர்நீதிமன்றம், சென்னை',
                           child: Text('சென்னை உயர்நீதிமன்றம் (Chennai High Court)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                         ),
                         DropdownMenuItem(
                           value: 'இந்திய அரசியலமைப்பு பிரிவு 226 இன் படி  கூடுதல் பொதுப்பதிவாளர்,சென்னை உயர்நீதிமன்ற மதுரை கிளை, மதுரை-625023',
                           child: Text('மதுரை கிளை (Madurai Bench)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                         ),
                       ],
                       onChanged: (String? newValue) {
                         if (newValue != null) {
                           setState(() {
                             controller.text = newValue;
                           });
                         }
                       },
                     ),
                   ),
                   // Don't allow removing the 1st MANDATORY recipient easily, or keep logic simple
                   // If we want to allow removing, we can show button. 
                   // But user requested "User can choose either or...", implying this slot is for that.
                   // I will HIDE the remove button for the 1st slot to ensure one of these is always picked?
                   // No, let's keep it consistent. If they remove it, index 0 might change... 
                   // Actually, if they remove index 0, index 1 becomes index 0. 
                   // So this logic works. If they remove it, the next one becomes the dropdown. 
                   // Wait, that might be confusing. 
                   // Let's assume the 1st recipient is ALWAYS one of these two.
                   if (_ccControllers.length > 1) 
                     IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            // If we remove index 0, the next item takes its place.
                            // If the next item has custom text, it will be forced into the dropdown?
                            // Yes, and if the text doesn't match, dropdown might error or show null.
                            // To be safe, if we remove index 0, we should probably reset the new index 0 to a valid dropdown value 
                            // OR we just accept that the 1st slot is special.
                            
                            _ccControllers[index].dispose();
                            _ccControllers.removeAt(index);
                            
                            // Safety check for new Index 0
                            if (_ccControllers.isNotEmpty) {
                               String firstText = _ccControllers[0].text;
                               if (firstText != 'இந்திய அரசியலமைப்பு பிரிவு 226 இன் படி பொதுப்பதிவாளர் உயர்நீதிமன்றம், சென்னை' && 
                                   firstText != 'இந்திய அரசியலமைப்பு பிரிவு 226 இன் படி  கூடுதல் பொதுப்பதிவாளர்,சென்னை உயர்நீதிமன்ற மதுரை கிளை, மதுரை-625023') {
                                     // If the new first item isn't a valid dropdown value, set it to default.
                                     _ccControllers[0].text = 'இந்திய அரசியலமைப்பு பிரிவு 226 இன் படி பொதுப்பதிவாளர் உயர்நீதிமன்றம், சென்னை';
                               }
                            }
                          });
                        },
                     )
                 ],
               ),
             );
          }

          // SPECIAL CASE: 2nd & 3rd Recipient (Index 1 & 2) is Dropdown + Custom Add
          if (index == 1 || index == 2) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 30,
                          alignment: Alignment.center,
                          child: Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        TextButton.icon(
                          onPressed: () => _showAddRecipientDialog(targetIndex: index),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Custom Recipient', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero
                          ),
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 30), // Indent to match text
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('recipient_dropdown_${index}_${_savedPresets.join(',').hashCode}'), 
                            value: _savedPresets.contains(controller.text) ? controller.text : null,
                            isExpanded: true,
                            itemHeight: null, 
                            isDense: true,
                            hint: const Text('Select Recipient (Collector, SP, etc.)'),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            selectedItemBuilder: (BuildContext context) {
                              return _savedPresets.map((String value) {
                                return Text(
                                  value, 
                                  style: const TextStyle(fontSize: 13), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                );
                              }).toList();
                            },
                            items: _savedPresets.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          value, 
                                          style: const TextStyle(fontSize: 13, height: 1.2), 
                                          maxLines: 5, 
                                          overflow: TextOverflow.ellipsis
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                      onPressed: () {
                                        _showAddRecipientDialog(targetIndex: index, initialValue: value);
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      onPressed: () {
                                        _deletePreset(value);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  controller.text = newValue;
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _ccControllers[index].dispose();
                                _ccControllers.removeAt(index);
                              });
                            },
                        )
                      ],
                    ),
                  ],
                ),
              );
          }

          // Normal Text Field for Index > 0
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  alignment: Alignment.center,
                  child: Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Enter recipient ${index + 1}...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                if (_ccControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _ccControllers[index].dispose();
                        _ccControllers.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _ccControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add CC Recipient'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepPurple,
              side: const BorderSide(color: Colors.deepPurple),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
  void _resetForm() {
    setState(() {
      // Reset Sender Details but keep Name/Mobile if user is logged in (optional, but "Reset" usually means clear form inputs)
      // Actually, let's keep Name and Mobile as they are likely constant for the user.
      // _senderNameController.clear(); 
      // _senderMobileController.clear();
      // Wait, user asked for "Refresh" or "Reset". Usually means "I messed up, let me start over".
      // Starting over includes keeping the user's identity.
      
      _senderNameController.text = widget.currentUser?.name ?? '';
      _senderMobileController.text = widget.currentUser?.phone ?? '';
      
      _senderDesignationController.text = widget.currentUser?.role == UserRole.admin 
          ? 'மாநில தலைவர் நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கம்' 
          : 'உறுப்பினர் நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கம்';

      // Clear Address
      _fatherNameController.clear();
      _doorNoController.clear();
      _streetController.clear();
      _villageController.clear();
      _postOfficeController.clear();
      _talukController.clear();
      _districtController.clear();
      _pincodeController.clear();
      _relationType = RelationType.sonOf;
      _saveAddress = false;
      
      _hasSavedAddress = (widget.currentUser?.address ?? '').isNotEmpty;

      // Clear Recipient Details
      _recipientNameController.clear();
      _recipientDesignationController.clear();
      _recipientAddressController.clear();

      // Clear Content
      _subjectController.clear();
      for (var c in _contentControllers) c.dispose();
      _contentControllers.clear();
      
      // Re-initialize with defaults based on current petition type
      _initializeContentDefaults();
      _placeController.clear();
      // Date usually stays today
      _dateController.text = "${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}";

      // Reset Dynamic Lists
      for (var c in _reqDocumentsControllers) c.dispose();
      _reqDocumentsControllers.clear();
      _reqDocumentsControllers.add(TextEditingController());

      for (var c in _attachmentControllers) c.dispose();
      _attachmentControllers.clear();
      _attachmentControllers.add(TextEditingController());

      for (var c in _ccControllers) c.dispose();
      _ccControllers.clear();
      _ccControllers.add(TextEditingController(text: 'இந்திய அரசியலமைப்பு பிரிவு 226 இன் படி பொதுப்பதிவாளர் உயர்நீதிமன்றம், சென்னை'));
      _ccControllers.add(TextEditingController());
      _ccControllers.add(TextEditingController());
    });
    
    // Re-apply designation logic to content if needed, though we just cleared it.
    // _updateContentBasedOnDesignation(); 
    // Since content is cleared, we don't need to update it.
  }

  String _getRelationLabel() {
    switch (_relationType) {
      case RelationType.sonOf: return 'S/O';
      case RelationType.wifeOf: return 'W/O';
      case RelationType.daughterOf: return 'D/O';
    }
  }

  String _getRelationLongLabel() {
    switch (_relationType) {
      case RelationType.sonOf: return 'S/O (தந்தை பெயர்)';
      case RelationType.wifeOf: return 'W/O (கணவர் பெயர்)';
      case RelationType.daughterOf: return 'D/O (தந்தை பெயர்)';
    }
  }
}
