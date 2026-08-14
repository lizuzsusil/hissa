// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Nepali (`ne`).
class AppLocalizationsNe extends AppLocalizations {
  AppLocalizationsNe([String locale = 'ne']) : super(locale);

  @override
  String get appTitle => 'हिस्सा';

  @override
  String get tagline => 'तपाईंका सबै खर्च, एउटै ठाउँमा';

  @override
  String get home => 'गृह';

  @override
  String get expenses => 'खर्चहरू';

  @override
  String get settle => 'मिलान';

  @override
  String get insights => 'विश्लेषण';

  @override
  String get settings => 'सेटिङ';

  @override
  String get add => 'थप्नुहोस्';

  @override
  String get cancel => 'रद्द गर्नुहोस्';

  @override
  String get delete => 'मेट्नुहोस्';

  @override
  String get save => 'बचत गर्नुहोस्';

  @override
  String get saveChanges => 'परिवर्तनहरू बचत गर्नुहोस्';

  @override
  String get continueLabel => 'जारी राख्नुहोस्';

  @override
  String get next => 'अर्को';

  @override
  String get skip => 'छोड्नुहोस्';

  @override
  String get getStarted => 'सुरु गर्नुहोस्';

  @override
  String get apply => 'लागू गर्नुहोस्';

  @override
  String get review => 'हेर्नुहोस्';

  @override
  String get viewAll => 'सबै हेर्नुहोस्';

  @override
  String get all => 'सबै';

  @override
  String get cycle => 'चक्र';

  @override
  String get even => 'बराबर';

  @override
  String get you => 'तपाईं';

  @override
  String get today => 'आज';

  @override
  String get yesterday => 'हिजो';

  @override
  String get ok => 'ठिक छ';

  @override
  String get general => 'सामान्य';

  @override
  String get unknown => 'अज्ञात';

  @override
  String get attached => 'संलग्न';

  @override
  String get other => 'अन्य';

  @override
  String get expense => 'खर्च';

  @override
  String settlementsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेटलमेन्टहरू पर्खिरहेका छन्',
      one: '1 सेटलमेन्ट पर्खिरहेको छ',
    );
    return '$_temp0';
  }

  @override
  String splitPersons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count व्यक्तिहरू',
      one: '1 व्यक्ति',
    );
    return '$_temp0';
  }

  @override
  String expensesAndTotal(int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count खर्चहरू · $total',
      one: '1 खर्च · $total',
    );
    return '$_temp0';
  }

  @override
  String memberPaidShare(String paid, String share) {
    return 'तिरेको $paid · भाग $share';
  }

  @override
  String paidByMemberDay(String name, String day) {
    return '$name ले तिर्नुभयो · $day';
  }

  @override
  String owes(String from, String to) {
    return '$from ले $to लाई तिर्न बाँकी';
  }

  @override
  String fromTo(String from, String to) {
    return '$from → $to';
  }

  @override
  String settlementMethodDay(String method, String day) {
    return '$method · $day';
  }

  @override
  String memberJoinedDate(String role, String date) {
    return '$role · $date मा सामेल';
  }

  @override
  String cycleNameByCategory(String name) {
    return '$name श्रेणी अनुसार';
  }

  @override
  String addedMember(String name) {
    return '$name ठाउँमा थपियो';
  }

  @override
  String removeMemberTitle(String name) {
    return '$name हटाउने हो?';
  }

  @override
  String closeCycleTitle(String name) {
    return '$name बन्द गर्ने हो?';
  }

  @override
  String spaceMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्यहरू',
      one: '1 सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get category => 'श्रेणी';

  @override
  String get amount => 'रकम';

  @override
  String get description => 'विवरण';

  @override
  String get descriptionHint => 'यो केका लागि थियो?';

  @override
  String get paidBy => 'तिर्ने व्यक्ति';

  @override
  String get date => 'मिति';

  @override
  String get splitBetween => 'बाँड्ने व्यक्तिहरू';

  @override
  String get note => 'नोट';

  @override
  String get noteOptionalHint => 'नोट थप्नुहोस् (वैकल्पिक)';

  @override
  String get splitPreview => 'बाँडफाँट पूर्वावलोकन';

  @override
  String get total => 'जम्मा';

  @override
  String get selectParticipant => 'कम्तीमा एक जना सहभागी छान्नुहोस्।';

  @override
  String get splitLabelEqual => 'बराबर';

  @override
  String get splitLabelPercent => 'प्रतिशत';

  @override
  String get splitLabelAmounts => 'रकम';

  @override
  String get splitLabelShares => 'सेयर';

  @override
  String get assigned => 'जम्मा गरिएको';

  @override
  String get totalShares => 'कुल सेयर';

  @override
  String get createGroup => 'समूह बनाउनुहोस्';

  @override
  String get ungroup => 'समूह हटाउनुहोस्';

  @override
  String get selectGroupMembers => 'समूहमा राख्न सदस्यहरू छान्नुहोस्';

  @override
  String get editExpense => 'खर्च सम्पादन गर्नुहोस्';

  @override
  String get addExpense => 'खर्च थप्नुहोस्';

  @override
  String get yourBalance => 'तपाईंको ब्यालेन्स';

  @override
  String get youPaid => 'तपाईंले तिरेको';

  @override
  String get yourShare => 'तपाईंको भाग';

  @override
  String get youReceive => 'तपाईंले पाउनुहुने';

  @override
  String get youOwe => 'तपाईंले तिर्न बाँकी';

  @override
  String get totalSpending => 'कुल खर्च';

  @override
  String get spaceBalances => 'ठाउँका ब्यालेन्सहरू';

  @override
  String get recentExpenses => 'भर्खरका खर्चहरू';

  @override
  String get thisMonth => 'यो महिना';

  @override
  String get lastMonth => 'गत महिना';

  @override
  String vsMonth(Object month) {
    return '$month सँग';
  }

  @override
  String get noExpensesYet => 'अहिलेसम्म कुनै खर्च छैन';

  @override
  String get noExpensesMessage => 'पहिलो खर्च थप्न + बटन थिच्नुहोस्।';

  @override
  String get settleUp => 'मिलान गर्नुहोस्';

  @override
  String get searchExpenses => 'खर्च खोज्नुहोस्';

  @override
  String get filterExpenses => 'खर्च फिल्टर गर्नुहोस्';

  @override
  String get everyone => 'सबैजना';

  @override
  String get noMatchingExpenses => 'मिल्दो खर्च भेटिएन';

  @override
  String get noMatchingMessage =>
      'अर्को खोज वा फिल्टर प्रयास गर्नुहोस्, वा नयाँ खर्च थप्नुहोस्।';

  @override
  String get expenseDetails => 'खर्चको विवरण';

  @override
  String get split => 'बाँडफाँट';

  @override
  String get receipt => 'रसिद';

  @override
  String get whoPaysWhat => 'कसले कति तिर्छ';

  @override
  String get paid => 'तिरियो';

  @override
  String get cycleClosedHint =>
      'यो चक्र बन्द भइसकेको छ, त्यसैले खर्चहरू अब सम्पादन गर्न सकिँदैन।';

  @override
  String get legacyExpenseHint =>
      'यो केवल-पढ्न सकिने ऐतिहासिक रेकर्ड हो। यो स्वामित्व ट्र्याक गर्न सुरु गर्नुभन्दा अघि बनाइएको थियो, त्यसैले यसलाई अब सम्पादन वा मेटाउन सकिँदैन।';

  @override
  String get deleteExpenseTitle => 'यो खर्च मेट्ने हो?';

  @override
  String get deleteExpenseMessage =>
      'खर्च मेट्दा सबैको हालको ठाउँ ब्यालेन्समा परिवर्तन आउँछ।';

  @override
  String get monthlySpending => 'मासिक खर्च';

  @override
  String get categoryBreakdown => 'श्रेणी विभाजन';

  @override
  String get whoPaidThisCycle => 'यो चक्रमा कसले तिर्यो';

  @override
  String get selectCycle => 'चक्र छान्नुहोस्';

  @override
  String get nothingToChart => 'चार्ट बनाउन केही छैन';

  @override
  String get nothingToChartMessage =>
      'खर्च थपेर आफ्नो खर्चको विवरण हेर्नुहोस्।';

  @override
  String get lifetimeSummary => 'कुल सारांश';

  @override
  String get totalSpent => 'जम्मा खर्च';

  @override
  String get average => 'औसत';

  @override
  String get introTitle1 => 'हिस्सामा स्वागत छ';

  @override
  String get introSubtitle1 =>
      'समूह, रूममेट र परिवारहरूले साझा खर्च सँगै ट्र्याक गर्ने सबैभन्दा सजिलो तरिका।';

  @override
  String get introTitle2 => 'हरेक खर्च ट्र्याक गर्नुहोस्';

  @override
  String get introSubtitle2 =>
      'सेकेन्डमै खर्च थप्नुहोस्। बिलहरू बराबर, प्रतिशत वा अनुकूल रकम अनुसार बाँड्नुहोस् — हिस्साले हिसाब ठ्याक्कै मिलाउँछ।';

  @override
  String get introTitle3 => 'सही तरिकाले मिलान गर्नुहोस्';

  @override
  String get introSubtitle3 =>
      'कसले कसलाई तिर्न बाँकी छ एकै नजरमा हेर्नुहोस् र नगद, बैंक ट्रान्सफर, ई-सेवा वा खल्तीबाट एक ट्यापमा भुक्तानी रेकर्ड गर्नुहोस्।';

  @override
  String get introTitle4 => 'आफ्नो खर्च बुझ्नुहोस्';

  @override
  String get introSubtitle4 =>
      'मासिक विश्लेषण, श्रेणी विवरण र एक-ट्याप CSV निर्यातले पैसा कहाँ जाँदैछ भन्ने कुरामा तपाईंलाई सचेत राख्छ।';

  @override
  String get onboardingTitle => 'कसरी\nखर्च बाँड्दै हुनुहुन्छ?';

  @override
  String get onboardingSubtitle =>
      'तपाईंको समूहसँग मिल्ने सेटअप छान्नुहोस्। तपाईं कुनै पनि समयमा परिवर्तन गर्न सक्नुहुन्छ।';

  @override
  String get modeTwoPeople => 'दुई जना';

  @override
  String get modeTwoPeopleSubtitle => 'जीवन र बिलहरू बाँड्ने जोडी';

  @override
  String get modeFamily => 'परिवार';

  @override
  String get modeFamilySubtitle => 'अभिभावक, छोराछोरी र सम्पूर्ण परिवार';

  @override
  String get modeRoommates => 'रूममेटहरू';

  @override
  String get modeRoommatesSubtitle => 'भाडा र सुविधाहरू बाँड्ने घरसाथीहरू';

  @override
  String get modeOther => 'अन्य';

  @override
  String get modeOtherSubtitle => 'खर्च बाँड्ने कुनै पनि सानो समूह';

  @override
  String get setUpSubtitle =>
      'नयाँ ठाउँ बनाउनुहोस् वा इन्भाइट कोडबाट सामेल हुनुहोस्।';

  @override
  String get create => 'सिर्जना गर्नुहोस्';

  @override
  String get join => 'सामेल हुनुहोस्';

  @override
  String get whoLivesHere => 'यहाँ को-को बस्नुहुन्छ?';

  @override
  String get addMember => 'सदस्य थप्नुहोस्';

  @override
  String get name => 'नाम';

  @override
  String get currency => 'मुद्रा';

  @override
  String get inviteLater => 'पछि सेटिङबाट थप मानिसहरूलाई बोलाउन सक्नुहुन्छ';

  @override
  String get inviteCode => 'इन्भाइट कोड';

  @override
  String get inviteCodeHint => 'ABCDE2';

  @override
  String get inviteCodeHelp =>
      'ठाउँको मालिकलाई उनीहरूको इन्भाइट कोड सोध्नुहोस्। कोडहरू सेटिङ → ठाउँमा देखिन्छन्।';

  @override
  String get inviteNotFound =>
      'इन्भाइट कोड भेटिएन। कोड जाँचेर फेरि प्रयास गर्नुहोस्।';

  @override
  String get enterMemberNameError => 'सदस्यको नाम लेख्नुहोस्';

  @override
  String get duplicateMemberError => 'त्यो नाम सूचीमा पहिल्यै छ';

  @override
  String get enterInviteCodeError => 'इन्भाइट कोड लेख्नुहोस्';

  @override
  String get inviteCodeFormatError => 'इन्भाइट कोड ६ अक्षरको हुन्छ';

  @override
  String get mySpaces => 'मेरा स्पेसहरू';

  @override
  String get mySpacesSubtitle => 'तपाईंका सबै खर्च स्पेस एकै ठाउँमा';

  @override
  String get noSpacesYet => 'अहिलेसम्म कुनै स्पेस छैन';

  @override
  String get noSpace => 'कुनै ठाउँ छैन';

  @override
  String get noSpacesMessage =>
      'खर्च ट्र्याक गर्न स्पेस सिर्जना गर्नुहोस्, वा अवस्थित स्पेसमा सामेल हुनुहोस्।';

  @override
  String get createSpace => 'स्पेस सिर्जना गर्नुहोस्';

  @override
  String get joinSpace => 'स्पेसमा सामेल हुनुहोस्';

  @override
  String get switchSpace => 'मेरा स्पेसहरू';

  @override
  String get switchSpaceSubtitle => 'आफ्ना स्पेसहरू बीच स्विच गर्नुहोस्';

  @override
  String get splitMode => 'विभाजन मोड';

  @override
  String get personalMode => 'व्यक्तिगत मोड';

  @override
  String get spaceName => 'स्पेसको नाम';

  @override
  String get spaceNameHint => 'जस्तै: हाम्रो घर';

  @override
  String get spaceNameRequired => 'स्पेसको नाम चाहिन्छ';

  @override
  String get chooseSpaceMode => 'यसलाई कसरी प्रयोग गर्नुहुन्छ छान्नुहोस्';

  @override
  String get splitModeDescription =>
      'खर्च बाँड्नुहोस्, ब्यालेन्स गणना गर्नुहोस् र मिलान गर्नुहोस्।';

  @override
  String get personalModeDescription =>
      'विभाजन वा मिलान बिना आफ्नै खर्च ट्र्याक गर्नुहोस्।';

  @override
  String get createSpaceTitle => 'स्पेस सिर्जना गर्नुहोस्';

  @override
  String get createSpaceSubtitle =>
      'आफ्नो स्पेसको नाम लेख्नुहोस् र कसरी प्रयोग गर्ने छान्नुहोस्।';

  @override
  String get createdSpaceTitle => 'स्पेस सिर्जना भयो';

  @override
  String get joinedSpaceTitle => 'स्पेसमा सामेल भयो';

  @override
  String get createAccount => 'खाता बनाउनुहोस्';

  @override
  String get logIn => 'लग इन गर्नुहोस्';

  @override
  String get createYourAccount => 'आफ्नो खाता बनाउनुहोस्';

  @override
  String get welcomeBack => 'फेरि स्वागत छ';

  @override
  String welcomeUser(String name) {
    return 'स्वागत छ, $name';
  }

  @override
  String get authSignupSubtitle =>
      'केही सेकेन्डमै साझा खर्च ट्र्याक गर्न सुरु गर्नुहोस्।';

  @override
  String get authLoginSubtitle =>
      'आफ्नो स्पेसहरू सेन्क्रोन राख्न लग इन गर्नुहोस्।';

  @override
  String get yourName => 'तपाईंको नाम';

  @override
  String get emailAddress => 'इमेल ठेगाना';

  @override
  String get password => 'पासवर्ड';

  @override
  String get continueWithGoogle => 'Google बाट जारी राख्नुहोस्';

  @override
  String get or => 'वा';

  @override
  String get alreadyHaveAccount => 'पहिल्यै खाता छ? ';

  @override
  String get logInLink => 'लग इन गर्नुहोस्';

  @override
  String get newToHissa => 'हिस्सामा नयाँ? ';

  @override
  String get createOne => 'खाता बनाउनुहोस्';

  @override
  String get errEmailRequired => 'इमेल ठेगाना चाहिन्छ';

  @override
  String get errEmailInvalid => 'मान्य इमेल ठेगाना लेख्नुहोस्';

  @override
  String get errPasswordRequired => 'पासवर्ड चाहिन्छ';

  @override
  String get errPasswordShort => 'पासवर्ड कम्तीमा ६ अक्षरको हुनुपर्छ';

  @override
  String get errPasswordLong => 'पासवर्ड ६४ अक्षर वा कम हुनुपर्छ';

  @override
  String get errNameRequired => 'तपाईंको नाम चाहिन्छ';

  @override
  String get errFieldRequired => 'यो फिल्ड आवश्यक छ';

  @override
  String get errTooLong => 'नाम ४० अक्षर वा कम हुनुपर्छ';

  @override
  String get errIncorrectCredentials =>
      'इमेल वा पासवर्ड गलत छ। फेरि प्रयास गर्नुहोस् वा खाता बनाउनुहोस्।';

  @override
  String get authGoogleConflict =>
      'त्यो इमेलमा पहिल्यै पासवर्ड खाता छ। यसको सट्टा इमेल र पासवर्डबाट लग इन गर्नुहोस्।';

  @override
  String get authEmailInUse =>
      'त्यो इमेलमा पहिल्यै खाता छ। यसको सट्टा लग इन गर्नुहोस्।';

  @override
  String get authWeakPassword =>
      'त्यो पासवर्ड धेरै कमजोर छ। कम्तीमा ६ अक्षर प्रयोग गर्नुहोस्।';

  @override
  String get authInvalidEmail => 'त्यो इमेल ठेगाना मान्य देखिँदैन।';

  @override
  String get authIncorrect => 'इमेल वा पासवर्ड गलत छ।';

  @override
  String get authUserDisabled => 'यो खाता बन्द गरिएको छ।';

  @override
  String get authTooManyRequests =>
      'धेरै प्रयास भयो। केही बेर पर्खेर फेरि प्रयास गर्नुहोस्।';

  @override
  String get authNetwork =>
      'इन्टरनेट जडान छैन। जडान जाँचेर फेरि प्रयास गर्नुहोस्।';

  @override
  String get authOperationNotAllowed =>
      'यो लगइन विधि अहिले सक्रिय छैन। Firebase कन्सोलमा सक्रिय गर्नुहोस्।';

  @override
  String get authConfigError =>
      'प्रमाणीकरण सही तरिकाले कन्फिगर गरिएको छैन। Firebase कन्सोलको एप कन्फिग र कुञ्जीहरू जाँच्नुहोस्।';

  @override
  String get authFirestoreDenied =>
      'डाटाबेसले यो कार्य अस्वीकार गर्दैछ। firestore.rules फाइल Firebase मा प्रकाशित गर्नुहोस्।';

  @override
  String get authFirestoreUnavailable =>
      'डाटाबेस व्यस्त छ वा तयार छैन। फेरि प्रयास गर्नुहोस्।';

  @override
  String get authGoogleConfig =>
      'Google लगइन अहिले कन्फिगर गरिएको छैन। Firebase कन्सोलमा Android SHA-1 फिङ्गरप्रिन्ट थपेपछि `flutterfire configure` फेरि चलाउनुहोस्।';

  @override
  String get authGooglePlayServices =>
      'यो यन्त्रमा Google Play सेवाहरू उपलब्ध छैनन् वा गलत कन्फिगर छन्।';

  @override
  String get authGoogleUi =>
      'अहिले Google लगइन विन्डो देखाउन सकिएन। फेरि प्रयास गर्नुहोस्।';

  @override
  String get authSomethingWentWrong =>
      'केही गडबड भयो। सटीक त्रुटिका लागि डिबग लग जाँच्नुहोस्।';

  @override
  String get rememberMe => 'याद राख्नुहोस्';

  @override
  String get biometricLogin => 'बायोमेट्रिकबाट लग इन गर्नुहोस्';

  @override
  String get biometricUnavailable =>
      'यो यन्त्रमा बायोमेट्रिक प्रमाणीकरण उपलब्ध छैन।';

  @override
  String get biometricFailed =>
      'बायोमेट्रिक प्रमाणीकरण असफल भयो। फेरि प्रयास गर्नुहोस्।';

  @override
  String get biometricNotEnrolled =>
      'कुनै बायोमेट्रिक दर्ता छैन। सेटिङमा Face ID / Touch ID सेटअप गर्नुहोस्।';

  @override
  String get security => 'सुरक्षा';

  @override
  String get usePassword => 'पासवर्ड प्रयोग गर्नुहोस्';

  @override
  String validationFieldRequired(String label) {
    return '$label चाहिन्छ';
  }

  @override
  String validationTooLong(String label, int max) {
    return '$label $max अक्षर वा कम हुनुपर्छ';
  }

  @override
  String get validationNameTooLong => 'नाम ४० अक्षर वा कम हुनुपर्छ';

  @override
  String get validationDuplicateMember => 'त्यो नाम सूचीमा पहिल्यै छ';

  @override
  String get validationEmailInvalid => 'मान्य इमेल ठेगाना लेख्नुहोस्';

  @override
  String get validationPasswordShort => 'पासवर्ड कम्तीमा ६ अक्षरको हुनुपर्छ';

  @override
  String get validationPasswordLong => 'पासवर्ड ६४ अक्षर वा कम हुनुपर्छ';

  @override
  String get validationInviteFormat => 'इन्भाइट कोड ६ अक्षरको हुन्छ';

  @override
  String get recordSettlement => 'सेटलमेन्ट रेकर्ड गर्नुहोस्';

  @override
  String get pays => 'तिर्छ';

  @override
  String get receives => 'पाउँछ';

  @override
  String get paymentMethod => 'भुक्तानी विधि';

  @override
  String get confirmPayment => 'भुक्तानी पुष्टि गर्नुहोस्';

  @override
  String get settlementRecorded => 'सेटलमेन्ट रेकर्ड भयो';

  @override
  String get toBeSettled => 'मिलान गर्न बाँकी';

  @override
  String get whoOwesWhom => 'कसले कसलाई तिर्न बाँकी';

  @override
  String get settleHint =>
      'भुक्तानी भएपछि एक पटक रेकर्ड गर्नुहोस्। ब्यालेन्सहरू आफैं अपडेट हुन्छन्।';

  @override
  String get settlementHistory => 'सेटलमेन्ट इतिहास';

  @override
  String get allSettled => 'सबै मिलान भयो!';

  @override
  String get allSettledMessage => 'यो चक्रमा सबैजना बराबर छन्। राम्रो सहकार्य।';

  @override
  String get settleAction => 'मिलान';

  @override
  String get profile => 'प्रोफाइल';

  @override
  String get displayName => 'देखाउने नाम';

  @override
  String get displayNameHint => 'यो नाम तपाईंको ठाउँका सदस्यहरूसँग साझा हुन्छ।';

  @override
  String get enterNameError => 'आफ्नो नाम लेख्नुहोस्';

  @override
  String get space => 'ठाउँ';

  @override
  String get spaceAndMembers => 'ठाउँ र सदस्यहरू';

  @override
  String get categories => 'श्रेणीहरू';

  @override
  String get defaultCategories => 'पूर्वनिर्धारित श्रेणीहरू';

  @override
  String get customCategories => 'अनुकूल श्रेणीहरू';

  @override
  String get newCategory => 'नयाँ श्रेणी';

  @override
  String get categoryName => 'श्रेणीको नाम';

  @override
  String get categoryNameHint => 'जस्तै: बालबच्चा, घरपालुवा, जिम';

  @override
  String get icon => 'आइकन';

  @override
  String get colour => 'रङ्ग';

  @override
  String get addCategory => 'श्रेणी थप्नुहोस्';

  @override
  String get enterCategoryNameError => 'श्रेणीको नाम लेख्नुहोस्';

  @override
  String get categoryTooLongError => '२४ अक्षरभन्दा कम राख्नुहोस्';

  @override
  String get duplicateCategoryError => 'त्यो श्रेणी पहिल्यै छ';

  @override
  String get inviteCodeCopied => 'इन्भाइट कोड प्रतिलिपि गरियो';

  @override
  String get shareInviteHint =>
      'यो कोड साझा गर्नुहोस् ताकि साथी र रूममेटहरू तपाईंको ठाउँमा सामेल हुन सकून्।';

  @override
  String get members => 'सदस्यहरू';

  @override
  String get addMemberFieldHint => 'नाम';

  @override
  String get addMemberHelper =>
      'तपाईंले थप्ने सदस्यहरू खर्च बाँडफाँटमा आफैं देखिनेछन्।';

  @override
  String get removeMemberMessage =>
      'उनीहरूको पुराना खर्चहरू इतिहासमा रहन्छन्, तर उनीहरूले अब यो ठाउँ देख्नेछैनन्।';

  @override
  String get roleOwner => 'मालिक';

  @override
  String get roleAdmin => 'प्रशासक';

  @override
  String get roleMember => 'सदस्य';

  @override
  String get statusActive => 'सक्रिय';

  @override
  String get statusReady => 'मिलान गर्न तयार';

  @override
  String get statusSettled => 'मिलान भयो';

  @override
  String get statusClosed => 'बन्द';

  @override
  String get statusPending => 'पर्खिरहेको';

  @override
  String get statusPartiallyPaid => 'आंशिक भुक्तानी';

  @override
  String get statusCancelled => 'रद्द भयो';

  @override
  String get spendingCycle => 'खर्च चक्र';

  @override
  String get currentCycle => 'हालको चक्र';

  @override
  String get noActiveCycle => 'कुनै सक्रिय चक्र छैन';

  @override
  String get ownersCanManage => 'मालिकहरूले चक्र व्यवस्थापन गर्न सक्छन्';

  @override
  String get closeCurrentCycle => 'हालको चक्र बन्द गर्नुहोस्';

  @override
  String get startNewCycle => 'नयाँ चक्र सुरु गर्नुहोस्';

  @override
  String get closeCycle => 'चक्र बन्द गर्नुहोस्';

  @override
  String get closeCycleMessage =>
      'चक्र केवल-पढ्न मिल्ने र ऐतिहासिक हुनेछ। अर्को चक्र अर्को महिना सुरु हुनेछ।';

  @override
  String get data => 'डाटा';

  @override
  String get export => 'निर्यात';

  @override
  String get csvOfCurrentCycle => 'हालको चक्रको CSV';

  @override
  String get notifications => 'सूचनाहरू';

  @override
  String get notificationsSubtitle => 'खर्च, ब्यालेन्स र रिमाइन्डरहरू';

  @override
  String get notificationsSheet =>
      'कनेक्टेड बिल्डमा फायरबेस क्लाउड मेसेजिङसँग पुश सूचनाहरू आउँछन्।';

  @override
  String get appearance => 'रूपरंग';

  @override
  String get darkMode => 'डार्क मोड';

  @override
  String get onValue => 'अन';

  @override
  String get offValue => 'अफ';

  @override
  String get signOut => 'लग आउट गर्नुहोस्';

  @override
  String get signOutSubtitle => 'खाता वा ठाउँ परिवर्तन गर्नुहोस्';

  @override
  String get signOutTitle => 'लग आउट गर्ने हो?';

  @override
  String get signOutMessage => 'कुनै पनि समयमा फेरि लग इन गर्न सक्नुहुन्छ।';

  @override
  String get appName => 'हिस्सा · ठाउँ खर्च ट्र्याकर';

  @override
  String get version => 'v1.0.0';

  @override
  String get newCycleStarted => 'नयाँ चक्र सुरु भयो';

  @override
  String get cycleClosed => 'चक्र बन्द भयो';

  @override
  String get settleBeforeClose =>
      'चक्र बन्द गर्नुअघि सबै ब्यालेन्सहरू मिलान गर्नुहोस्';

  @override
  String get csvExport => 'CSV निर्यात';

  @override
  String get currentCycleFallback => 'हालको चक्र';

  @override
  String get preview => 'पूर्वावलोकन';

  @override
  String get copyCsv => 'CSV क्लिपबोर्डमा प्रतिलिपि गर्नुहोस्';

  @override
  String get csvCopied => 'CSV क्लिपबोर्डमा प्रतिलिपि गरियो';

  @override
  String get shareReport => 'रिपोर्ट साझा गर्नुहोस्';

  @override
  String get csvCopiedShare =>
      'CSV प्रतिलिपि भयो – जहाँ पनि टाँसेर साझा गर्नुहोस्';

  @override
  String get emptyPreview => '…';

  @override
  String get noExpensesForExport => 'निर्यात गर्न कुनै खर्च छैन';

  @override
  String get language => 'भाषा';

  @override
  String get languageSubtitle => 'एप प्रदर्शन भाषा';

  @override
  String get english => 'English';

  @override
  String get nepali => 'नेपाली';

  @override
  String get expenseAmountError => '0 भन्दा बढी रकम लेख्नुहोस्।';

  @override
  String get expenseDescriptionError => 'छोटो विवरण लेख्नुहोस्।';

  @override
  String get expensePayerError => 'तिर्ने व्यक्ति छान्नुहोस्।';

  @override
  String get expenseParticipantError => 'कम्तीमा एक जना सहभागी छान्नुहोस्।';

  @override
  String get expensePercentError => 'प्रतिशतहरूको जोड १००% हुनुपर्छ।';

  @override
  String get expenseCustomError => 'अनुकूल रकमहरूको जोड जम्मा बराबर हुनुपर्छ।';

  @override
  String get expenseSharesError => 'कम्तीमा एक सेयर लेख्नुहोस्।';
}
