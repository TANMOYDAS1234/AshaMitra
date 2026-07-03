import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../utils/logger.dart';
import 'answer_codes.dart';
import 'api_service.dart';
import 'vitals_extractor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GeminiConversationService
// App → Backend (/api/chat) → Gemini
// The API key never lives in the app.
// ─────────────────────────────────────────────────────────────────────────────

class ConversationTurn {
  final String role; // 'asha' or 'assistant'
  final String text;
  const ConversationTurn({required this.role, required this.text});
}

class ConversationResponse {
  final String spokenResponse;
  final Map<String, bool> extractedAnswers;
  final Map<String, double> extractedVitals;
  final bool shouldFinish;
  final String riskLevel;
  /// The question id (e.g. "c7") that Gemini actually asked in
  /// [spokenResponse], as reported by the model itself. The caller records the
  /// worker's next bare yes/no against THIS id — eliminating the old, fragile
  /// "guess the question from a priority list" attribution that caused the
  /// triage loop (the guess list had drifted out of sync with the prompt's, so
  /// "হ্যাঁ" was recorded against the wrong question and Gemini re-asked the
  /// real one forever). Null when Gemini asked nothing (e.g. should_finish).
  final String? askedQuestionId;
  /// MP3 bytes returned by the combined /chat-with-voice endpoint (2b).
  /// When non-null the caller can play these directly and skip the
  /// separate /tts round-trip — saving ~200-500ms on Render.
  final List<int>? prefetchedAudio;
  /// Set by the LLM when the conversation should end without writing a
  /// report — e.g. the worker was just chatting / testing / has no real
  /// patient situation. The caller speaks [spokenResponse] (a warm
  /// farewell) and navigates home; _submitAnswers is NOT called.
  final bool cancelSession;

  const ConversationResponse({
    required this.spokenResponse,
    required this.extractedAnswers,
    this.extractedVitals = const {},
    required this.shouldFinish,
    required this.riskLevel,
    this.askedQuestionId,
    this.prefetchedAudio,
    this.cancelSession = false,
  });
}

class GeminiConversationService {
  static String _systemPrompt(String caseType, String moduleId) => '''
তুমি আশামিত্র — গ্রামীণ ভারতের ASHA কর্মীদের বিশ্বস্ত সঙ্গী।
তুমি একজন অভিজ্ঞ দিদি বা দাদার মতো কথা বলো — উষ্ণ, সাহসী, এবং স্পষ্ট।
তুমি কখনো ভয় দেখাও না, কিন্তু বিপদ থাকলে সরাসরি বলো।

কেস টাইপ: $caseType
ক্লিনিক্যাল মডিউল: $moduleId

── কথা বলার ধরন (আশামিত্র ভয়েস-সহায়কের মতোই উষ্ণ ও স্বাভাবিক) ──
- একজন প্রকৃত দিদির মতো স্বাভাবিক, বন্ধুসুলভ কথোপকথন করো — ফর্ম পূরণের মতো নয়।
- ⭐ প্রতিবার আলাদা ভাবে বলো। একই ওপেনার বারবার নয় — "বুঝেছি," বা
  "এখন বলুন তো," প্রতিটি উত্তরে বলবে না। স্বীকৃতি, সাড়া আর প্রশ্ন একটি
  প্রবহমান বাক্যে স্বাভাবিকভাবে মিশিয়ে দাও, যেন সত্যিকারের কথা হচ্ছে।
- ASHA যা বললেন তাতে সত্যিকারের সাড়া দাও (শুধু যান্ত্রিক "বুঝেছি" নয়) —
  দরকারে এক টুকরো আশ্বাস বা ছোট পরামর্শ দাও, তারপর স্বাভাবিকভাবে একটি প্রশ্নে যাও।
- প্রশ্ন স্বাভাবিক কথার মতো হোক, ফর্মের মতো নয়:
  "মাথা ব্যথা আছে?"  "মাথায় কি কোনো ব্যথা বা ভারী লাগছে?"
- বিপদচিহ্ন নিশ্চিত হলে — আত্মবিশ্বাসের সাথে, ভয় না দেখিয়ে:
  "এটা একটু সতর্কতার বিষয়, এখনই PHC-তে নিয়ে যাওয়া দরকার।"
- GREEN হলে — উৎসাহ দাও: "ভালো খবর, এখন পর্যন্ত সব ঠিক আছে।"

── ভাষার নিয়ম ──
- সবসময় সহজ বাংলায় উত্তর দাও
- বাংলা, হিন্দি, ইংরেজি, মিশ্র — সব বুঝবে, বাংলায় উত্তর দেবে
- সর্বোচ্চ ২-৩ বাক্য — সংক্ষিপ্ত রাখো
- "extracted_answers" বা "JSON" বা কোনো টেকনিক্যাল শব্দ কখনো বলবে না

── সিদ্ধান্তের আত্মবিশ্বাস ──
- নিশ্চিত বিপদচিহ্ন থাকলে: "এটা গুরুতর, দেরি না করে..."
- সম্ভাব্য বিপদ থাকলে: "এটা একটু দেখা দরকার..."
- সব ঠিক থাকলে: "এখন পর্যন্ত ভালো আছেন..."
- কখনো "মনে হয়" বা "হয়তো" দিয়ে সিদ্ধান্ত দেবে না

${_moduleContext(caseType)}

── অনিশ্চয়তার নিয়ম (অত্যন্ত গুরুত্বপূর্ণ — over-triage এড়াতে) ──
- ASHA যদি স্পষ্ট ও নিশ্চিতভাবে "হ্যাঁ" বা সমার্থক বলে কোনো বিপদচিহ্ন
  নিশ্চিত করেন — তবেই extracted_answers-এ সেই key true করো
- ASHA যদি "মনে হয়", "একটু", "হয়তো", "ঠিক বুঝতে পারছি না" বলেন —
  সেই key extracted_answers থেকে বাদ দাও (false-ও নয়, true-ও নয়)
- ASHA যদি বিষয়টি উল্লেখই না করেন — সেই key extracted_answers থেকে বাদ
- "ঠিক আছে", "ভালো আছে", "কোনো সমস্যা নেই" → extracted_answers: {}
  (একদম খালি — কিছু infer করবে না)
- "false" শুধু তখনই দিও যখন ASHA সরাসরি ও সুস্পষ্টভাবে "না" বলেছেন
  সেই নির্দিষ্ট প্রশ্নের উত্তরে

অতি সংবেদনশীল উদাহরণ (এটা করবে না):
   ASHA: "মাথা একটু ভারী লাগছে।"
   ভুল: extracted_answers: {"p1": true}  ← "একটু" = অনিশ্চিত, true করো না
   সঠিক: extracted_answers: {}  ← key বাদ দাও

সঠিক উদাহরণ:
   ASHA: "হ্যাঁ, তীব্র মাথা ব্যথা আছে।"
   extracted_answers: {"p1": true}  ← স্পষ্ট নিশ্চিত হ্যাঁ

কারণ: একটি ভুলভাবে true করা key পুরো ফলাফলকে YELLOW করে দিতে পারে।
অনিশ্চিত হলে চুপ থাকো — key বাদ দাও।

── পাঠ্যক্রম-বহির্ভূত প্রশ্নের ক্ষেত্রে ──
ASHA-র ইনপুট দুই ধরনের হতে পারে: (ক) ক্লিনিক্যাল প্রশ্ন — তিনি কোনো
চিকিৎসা বিষয়ে জানতে চাইছেন, (খ) সাধারণ অফ-টপিক — ব্যক্তিগত কথা, আবহাওয়া,
আশামিত্র সম্পর্কে। দু'টোর জবাব আলাদা।

(ক) ক্লিনিক্যাল প্রশ্ন — যেমন "ORS কীভাবে বানাবো?", "জ্বর কত হলে বিপদ?",
"PSBI মানে কী?", "ANC কতবার করতে হবে?" — তখন **সংক্ষিপ্ত, সঠিক ও কাজে-আসার মতো
উত্তর দাও (১-২ বাক্য, প্রকৃত সংখ্যা/পদক্ষেপ সহ)**, তারপর কেসের প্রশ্নে ফিরো।
"পরে বলবো" বা এড়িয়ে যাবে না — ASHA-এর সিদ্ধান্ত নিতে এই তথ্য দরকার।

উদাহরণ:
- ASHA: "ORS কীভাবে বানাবো?"
  উত্তর: "১ লিটার বিশুদ্ধ পানিতে ১ প্যাকেট ORS গুলিয়ে দিন, প্রতিবার পাতলা
  পায়খানার পর আধা কাপ। এখন বলুন তো, শিশুর পানিশূন্যতার কোনো লক্ষণ আছে?"
- ASHA: "নবজাতকের জ্বর কত হলে বিপদ?"
  উত্তর: "যেকোনো জ্বর (≥৩৭.৫°C) নবজাতকের জন্য বিপদ। আপনার শিশুর গা গরম
  লাগছে কি?"
- ASHA: "ANC কতবার?"
  উত্তর: "কমপক্ষে ৪ বার — ৩, ৬, ৮, ৯ মাসে। মা কি সব ভিজিট করেছেন?"

(খ) সাধারণ অফ-টপিক — উষ্ণ, সংক্ষিপ্ত (১-২ বাক্য) সাড়া, তারপর কেসে ফিরো।

উদাহরণ:
- ASHA: "আমি ক্লান্ত।"
  উত্তর: "আপনি একটু বিশ্রাম নিন, দিদি। চলুন রোগীর কথায় ফিরি — তিনি এখন কেমন আছেন?"
- ASHA: "এই অ্যাপ কে বানিয়েছে?"
  উত্তর: "আশামিত্র আপনার সহায়তার জন্য তৈরি। এখন বলুন তো, রোগীর অবস্থা কী?"
- ASHA: "আজ বৃষ্টি হবে?"
  উত্তর: "সেটা আমি বলতে পারব না, দিদি। কিন্তু আপনি রোগীর সম্পর্কে কী বলবেন?"

গুরুত্বপূর্ণ: ASHA প্রশ্ন করলে extracted_answers-এ কিছু রাখবে না — তিনি
ক্লিনিক্যাল কোনো উত্তর দেননি, শুধু জানতে চেয়েছেন।

কখনো এমন উত্তর দেবে না: "এটা আমার কাজ নয়" বা "আমি জানি না" বা চুপ থাকবে।
সবসময় কিছু বলো, তারপর কেসে ফিরো।

── কখন কথোপকথন শেষ করবে (cancel_session) ──
যদি ASHA-র সাথে কোনো প্রকৃত রোগীর পরিস্থিতি নিয়ে কথা না হচ্ছে — অর্থাৎ
ধারাবাহিকভাবে অফ-টপিক চলছে, বা ASHA স্পষ্টভাবে বলছেন যে তিনি কোনো
রোগীর কথা বলছেন না — তবে cancel_session: true সেট করো এবং উষ্ণ
বিদায় বলো। শর্তগুলো:

1. পরপর ২টি টার্নে কোনো রোগী-সংক্রান্ত বিষয় আসেনি (শুধু আশামিত্র
   সম্পর্কে, আবহাওয়া, ব্যক্তিগত কথা ইত্যাদি) — তবে এই টার্নে আগে
   একবার নিশ্চিত করো: "আপনি কি কোনো রোগীর সমস্যা নিয়ে কথা বলছেন?"
2. ASHA যদি স্পষ্টভাবে বলেন "না", "শুধু পরীক্ষা করছি", "কোনো রোগী
   নেই", "পরে কথা বলবো", "ধন্যবাদ, এখন না" — তবে cancel_session: true
3. ASHA যদি বলেন এটা পরীক্ষা/ডেমো — cancel_session: true

cancel_session: true হলে spoken_response-এ একটি উষ্ণ বিদায় দাও —
উদাহরণ: "ঠিক আছে দিদি, কোনো রোগীর প্রয়োজন হলে আমাকে আবার ডাকুন।
ভালো থাকুন।" — এবং কোনো প্রশ্ন করবে না।

cancel_session: true সেট করলে should_finish ও extracted_answers
গুরুত্বহীন — এই কেসের জন্য কোনো রিপোর্ট তৈরি হবে না।
''';

  static String _moduleContext(String caseType) => switch (caseType) {
    'pregnancy' => '''
গর্ভাবস্থার বিপদচিহ্ন:
- রক্তচাপ বেশি (প্রি-এক্লাম্পসিয়া)
- মাথা ব্যথা — বিচ্ছিন্ন হলে সাধারণ; কিন্তু তীব্র/২ দিনের বেশি/বাড়ছে, অথবা ফোলা বা ঝাপসা দৃষ্টির সাথে হলে = বিপদ
- পা বা মুখ ফোলা (এডিমা)
- রক্তপাত বা তীব্র পেট ব্যথা (APH)
- বাচ্চার নড়াচড়া কমেছে
- চোখে ঝাপসা দেখা (এক্লাম্পসিয়া প্রোড্রোম)
- মাথা ঘোরা বা দুর্বলতা (রক্তাল্পতা/নিম্ন রক্তচাপ)
- খুব ফ্যাকাশে বা সামান্য পরিশ্রমেই হাঁপানো (গুরুতর রক্তাল্পতা)
- জ্বর, বিশেষ করে কাঁপুনি দিয়ে (সেপসিস/ম্যালেরিয়া)
- যোনিপথে হঠাৎ জল ভাঙা বা ক্রমাগত জল ঝরা (PROM)
- খিঁচুনি বা ফিট (এক্লাম্পসিয়া — জীবনসংকটাপন্ন)
- ANC চেকআপ মিস''',
    'postpartum' => '''
প্রসব-পরবর্তী বিপদচিহ্ন:
- অতিরিক্ত রক্তপাত বা দুর্গন্ধ স্রাব (PPH/সেপসিস)
- জ্বর বা ঠান্ডা লাগা
- স্তনে ব্যথা বা ফোলা
- পেটে তীব্র ব্যথা বা সেলাইয়ে সমস্যা
- প্রস্রাবে জ্বালা
- খুব দুর্বল বা মাথা ঘোরা
- খিঁচুনি বা ফিট (পোস্টপার্টাম এক্লাম্পসিয়া)
- শ্বাস নিতে কষ্ট
- মন খুব খারাপ, কান্না, ঘুম/খাওয়া কমে যাওয়া, বা বাচ্চার প্রতি আগ্রহ নেই (প্রসব-পরবর্তী বিষণ্নতা)''',
    'newborn' => '''
নবজাতকের বিপদচিহ্ন (PSBI):
- দুধ খেতে পারছে না
- জ্বর (যেকোনো জ্বর = বিপদচিহ্ন)
- শ্বাসকষ্ট বা দ্রুত শ্বাস (≥৬০/মিনিট)
- নাভিতে লালভাব বা পুঁজ
- নিস্তেজ বা কম নড়াচড়া
- ত্বক হলুদ বা নীলাভ
- খিঁচুনি বা অস্বাভাবিক নড়াচড়া
- শরীর ঠান্ডা বা স্বাভাবিকের চেয়ে কম গরম (হাইপোথার্মিয়া)
- ত্বকে অনেক ফুসকুড়ি/পুঁজভরা ফোস্কা বা কান থেকে পুঁজ
- মাথার নরম অংশ (তালু) ফুলে উঁচু (মেনিনজাইটিস)''',
    'child' => '''
শিশুর বিপদচিহ্ন:
- পাঁচ দিনের বেশি জ্বর (ম্যালেরিয়া/ডেঙ্গু)
- কাশি বা শ্বাসকষ্ট (নিউমোনিয়া)
- ডায়রিয়া বা বমি (পানিশূন্যতা)
- খাওয়া বন্ধ করেছে
- চোখ গর্তে বা ঠোঁট শুকনো
- ওজন অনেক কম
- খিঁচুনি বা ফিট (সাধারণ বিপদচিহ্ন)
- নিস্তেজ, অস্বাভাবিক ঘুমন্ত বা অজ্ঞান
- যা-ই খাচ্ছে সব বমি করে ফেলছে
- ঘাড় শক্ত, আলোয় কষ্ট, বা জ্বরসহ প্রচণ্ড মাথাব্যথা (মেনিনজাইটিস)
- পায়খানার সাথে রক্ত বা আমাশা (ডিসেন্ট্রি — অ্যান্টিবায়োটিক দরকার)
- হাতের তালু বা চোখের পাতা খুব ফ্যাকাশে (রক্তাল্পতা)''',
    'emergency' => '''
জরুরি বিপদচিহ্ন:
- অতিরিক্ত রক্তপাত
- খিঁচুনি বা অজ্ঞান
- শ্বাস বন্ধ বা গুরুতর শ্বাসকষ্ট
- সাড়া দিচ্ছে না
- সাপে কামড়, বিষাক্ত পোকা বা পশুর কামড়
- বিষ/কীটনাশক/অতিরিক্ত ওষুধ খাওয়া
- ঠান্ডা-ঘামে ভেজা, খুব দুর্বল নাড়ি, অত্যন্ত নিস্তেজ (শক)
- গুরুতর আঘাত, বড় ক্ষত থেকে রক্তপাত, বা মারাত্মক পোড়া''',
    'immunisation' => '''
টিকার মূল্যায়ন:
- শিশুর বয়স ও প্রয়োজনীয় টিকা যাচাই করো (BCG, OPV, DPT, Pentavalent, PCV, RVV, fIPV, MR — মনে রেখো MR, MMR নয়)
- টিকা মিস হয়েছে কিনা জিজ্ঞেস করো
- এখন অসুস্থ থাকলে টিকা দেওয়া যাবে না — সুস্থ হলে দিতে হবে
- বুস্টার ডোজ মিস হয়েছে কিনা দেখো
- আগের কোনো টিকার পর গুরুতর প্রতিক্রিয়া (AEFI) হয়েছিল কিনা — হলে পরের ডোজের আগে MO-কে দেখাতে হবে
- প্রতিটি টিকার পর শিশুকে নির্ধারিত সময় পর্যন্ত পর্যবেক্ষণ করো''',
    _ => 'সাধারণ স্বাস্থ্য মূল্যায়ন করো।',
  };

  static Map<String, String> _questionDescriptions(String moduleId) =>
      switch (moduleId) {
        'pregnancy' => {
          'p1': 'রক্তচাপ বেশি',
          'p2': 'পা বা মুখ ফোলা',
          'p3': 'রক্তপাত বা তীব্র পেট ব্যথা',
          'p4': 'বাচ্চার নড়াচড়া কমেছে',
          'p5': 'ANC চেকআপ মিস',
          'p6': 'চোখে ঝাপসা দেখা',
          'p7': 'খিঁচুনি বা ফিট (এক্লাম্পসিয়া)',
          'p8': 'খুব ফ্যাকাশে বা হাঁপানো (গুরুতর রক্তাল্পতা)',
          'p9': 'জ্বর, বিশেষ করে কাঁপুনি দিয়ে',
          'p9r': 'জ্বরের সাথে কাঁপুনি/শীত-শীত (ম্যালেরিয়া/সেপসিস)',
          'p10': 'যোনিপথে জল ভাঙা বা ক্রমাগত জল ঝরা (PROM)',
          'p11': 'মাথা ব্যথা',
          'p11d': 'মাথা ব্যথা তীব্র / ২ দিনের বেশি / বাড়ছে',
          'p12': 'মাথা ঘোরা বা দুর্বলতা',
        },
        'delivery_pnc' => {
          'pp1': 'অতিরিক্ত রক্তপাত বা দুর্গন্ধ স্রাব',
          'pp2': 'জ্বর বা ঠান্ডা লাগা',
          'pp3': 'স্তনে ব্যথা বা ফোলা',
          'pp4': 'পেটে তীব্র ব্যথা বা সেলাইয়ে সমস্যা',
          'pp5': 'প্রস্রাবে জ্বালা',
          'pp6': 'খুব দুর্বল বা মাথা ঘোরা',
          'pp6s': 'তীব্র মাথা ঘোরা/অজ্ঞান-ভাব (লুকানো রক্তক্ষরণ/শক)',
          'pp7': 'খিঁচুনি বা ফিট (পোস্টপার্টাম এক্লাম্পসিয়া)',
          'pp8': 'শ্বাস নিতে কষ্ট',
          'pp9': 'মন খারাপ, কান্না, বাচ্চার প্রতি আগ্রহ নেই (বিষণ্নতা)',
          'pp10': 'প্রস্রাব/পায়খানা ধরে রাখতে পারছেন না (অসংযম)',
        },
        'newborn' => {
          'n1': 'দুধ খেতে পারছে না',
          'n2': 'জ্বর আছে',
          'n3': 'শ্বাসকষ্ট বা দ্রুত শ্বাস',
          'n4': 'নাভিতে লালভাব বা পুঁজ',
          'n5': 'নিস্তেজ বা কম নড়াচড়া',
          'n6': 'ত্বক হলুদ বা নীলাভ',
          'n7': 'খিঁচুনি বা অস্বাভাবিক নড়াচড়া',
          'n8': 'শরীর ঠান্ডা (হাইপোথার্মিয়া)',
          'n9': 'ত্বকে ফুসকুড়ি/পুঁজ বা কানে পুঁজ',
          'n10': 'মাথার তালু ফুলে উঁচু (ফন্টানেল)',
          'n11': 'প্রথম ২৪ ঘণ্টায় মলত্যাগ বা ৪৮ ঘণ্টায় মূত্রত্যাগ করেনি',
          'n12': 'পাতলা পায়খানা (ডায়রিয়া)',
          'n13': 'চোখ লাল/ফোলা বা চোখে পুঁজ',
          'n14': 'অঙ্গের জন্মগত ত্রুটি',
        },
        'child' => {
          'c1': 'পাঁচ দিনের বেশি জ্বর',
          'c2': 'কাশি বা শ্বাসকষ্ট',
          'c3': 'ডায়রিয়া বা বমি',
          'c4': 'খাওয়া বন্ধ করেছে',
          'c5': 'চোখ গর্তে বা ঠোঁট শুকনো',
          'c6': 'ওজন অনেক কম',
          'c7': 'খিঁচুনি বা ফিট',
          'c8': 'নিস্তেজ, অস্বাভাবিক ঘুমন্ত বা অজ্ঞান',
          'c9': 'যা-ই খাচ্ছে সব বমি করছে',
          'c10': 'ঘাড় শক্ত বা জ্বরসহ প্রচণ্ড মাথাব্যথা (মেনিনজাইটিস)',
          'c11': 'পায়খানায় রক্ত বা আমাশা (ডিসেন্ট্রি)',
          'c12': 'হাত/চোখের পাতা খুব ফ্যাকাশে (রক্তাল্পতা)',
          'c13': 'বুক ভেতরে ঢোকা বা বিশ্রামেও শ্বাসের শব্দ (গুরুতর নিউমোনিয়া)',
        },
        'emergency' => {
          'e1': 'অতিরিক্ত রক্তপাত',
          'e2': 'খিঁচুনি বা অজ্ঞান',
          'e3': 'শ্বাস বন্ধ বা গুরুতর শ্বাসকষ্ট',
          'e4': 'সাড়া দিচ্ছে না',
          'e5': 'সাপে কামড় বা পশুর কামড়',
          'e6': 'বিষ/কীটনাশক খাওয়া',
          'e7': 'শক (ঠান্ডা-ঘাম, দুর্বল নাড়ি)',
          'e8': 'গুরুতর আঘাত/রক্তপাত/পোড়া',
        },
        'immunisation' => {
          'im1': 'শিশুর বয়স ০-১২ মাস',
          'im2': 'টিকা মিস হয়েছে',
          'im3': 'টিকা ৩ মাসের বেশি বাকি',
          'im4': 'এখন অসুস্থ',
          'im5': 'বুস্টার ডোজ মিস',
          'im6': 'আগের টিকার পর গুরুতর প্রতিক্রিয়া (AEFI)',
        },
        _ => {},
      };

  // ── Main conversational turn ───────────────────────────────────────────────
  Future<ConversationResponse> respond({
    required String caseType,
    required String moduleId,
    required List<ConversationTurn> history,
    required String newInput,
    required Map<String, dynamic> currentAnswers,
    required int turnNumber,
    int maxTurns = 8,
    String? authToken,
    void Function(String partial)? onPartialResponse,
  }) async {
    // Keep only the last 6 turns (3 exchanges) — enough context for Gemini
    // without bloating the prompt on long sessions.
    final trimmedHistory = history.length > 6 ? history.sublist(history.length - 6) : history;
    final historyText = trimmedHistory.isEmpty
        ? ''
        : trimmedHistory
            .map((t) => t.role == 'asha' ? 'ASHA: \${t.text}' : 'আশামিত্র: \${t.text}')
            .join('\n');

    final questionDescs = _questionDescriptions(moduleId);
    final questionList = questionDescs.entries.map((e) => '${e.key}: ${e.value}').join('\n');

    final spokenVitals = VitalsExtractor.extract(newInput);
    final vitalsSummary = VitalsExtractor.summarise(spokenVitals);
    final vitalsContext = vitalsSummary.isNotEmpty ? '\nমাপা ভাইটাল সাইন: $vitalsSummary' : '';

    final answeredIds = currentAnswers.keys.toSet();
    const priorityOrder = {
      'pregnancy':    ['p7','p9r','p1','p3','p6','p9','p10','p8','p4','p11','p11d','p2','p12','p5'],
      'delivery_pnc': ['pp1','pp7','pp8','pp6s','pp2','pp4','pp10','pp6','pp3','pp5','pp9'],
      'newborn':      ['n7','n1','n2','n3','n5','n12','n4','n6','n13','n11','n8','n9','n10','n14'],
      'child':        ['c7','c13','c4','c8','c9','c10','c1','c5','c2','c3','c11','c6','c12'],
      'emergency':    ['e1','e2','e3','e4','e5','e6','e7','e8'],
      'immunisation': ['im4','im2','im1','im5','im3','im6'],
    };
    final order = priorityOrder[moduleId] ?? <String>[];
    final unanswered = order.where((id) => !answeredIds.contains(id)).toList();
    final confirmedDanger = currentAnswers.entries
        .where((e) => AnswerCodes.isAffirmative(e.value))
        .map((e) => questionDescs[e.key] ?? e.key)
        .join(', ');
    final mostUrgent = unanswered.isNotEmpty
        ? '${questionDescs[unanswered.first] ?? unanswered.first} (${unanswered.first})'
        : 'সব প্রশ্নের উত্তর পাওয়া গেছে';
    final turnsLeft = maxTurns - turnNumber;

    final answeredList =
        answeredIds.isEmpty ? 'কোনোটি নয়' : answeredIds.join(', ');
    final turnCtx = '''
══ কথোপকথনের বর্তমান অবস্থা ══
প্রশ্ন নম্বর: $turnNumber / $maxTurns${turnsLeft <= 2 ? ' | সতর্কতা: মাত্র ${turnsLeft}টি প্রশ্ন বাকি' : ''}
নিশ্চিত বিপদচিহ্ন: ${confirmedDanger.isEmpty ? 'এখনো কোনোটি নিশ্চিত নয়' : confirmedDanger}
ইতিমধ্যে উত্তর পাওয়া প্রশ্ন (এগুলো আর জিজ্ঞেস করবে না): $answeredList
এখনো অজানা (${unanswered.length}টি): ${unanswered.isEmpty ? 'সব জানা' : unanswered.map((id) => '${questionDescs[id] ?? id}($id)').join(' | ')}
প্রাসঙ্গিক কিছু না পেলে নিরাপত্তা-ফলব্যাক প্রশ্ন (শুধু তখনই): $mostUrgent
''';

    final prompt = '''
${_systemPrompt(caseType, moduleId)}

$turnCtx
এখন পর্যন্ত কথোপকথন:
$historyText

ASHA এইমাত্র বললেন: "$newInput"$vitalsContext

ক্লিনিক্যাল প্রশ্নের তালিকা (id: বিষয়):
$questionList

তোমার উত্তর হবে একটি স্বাভাবিক, উষ্ণ, প্রবহমান বার্তা (সর্বোচ্চ ৩ বাক্য) —
ঠিক আশামিত্র ভয়েস-সহায়ক যেভাবে কথা বলে। নিচের উপাদানগুলো আলাদা ধাপ বা
টেমপ্লেট নয়; স্বাভাবিকভাবে মিশিয়ে দাও এবং প্রতিবার আলাদা শব্দে বলো:

ক) স্বীকৃতি — ASHA যা বললেন তাতে সত্যিকারের, বৈচিত্র্যময় সাড়া (প্রতিবার
   "বুঝেছি" নয়)। বিপদচিহ্নে: "আপনি ভালো করেছেন জানিয়েছেন।"; সব ঠিক থাকলে:
   "এটা শুনে ভালো লাগল।"; সাধারণ: স্বাভাবিক যেকোনো উষ্ণ সাড়া।

২. পদক্ষেপ (১ বাক্য, যদি দরকার) — বিপদচিহ্ন নিশ্চিত হলে সরাসরি বলো।
   - উদাহরণ: "এটা এখনই PHC-তে দেখানো দরকার।"

৩. পরবর্তী প্রশ্ন — "এখনো অজানা" তালিকা থেকে সেই প্রশ্নটি বেছে জিজ্ঞেস করো যা
   ASHA এইমাত্র যা বললেন তার সাথে সবচেয়ে প্রাসঙ্গিক। কখনোই একটি ফিক্সড ক্রমে
   যেও না — পরিস্থিতি অনুযায়ী আলাদা প্রশ্ন করো:
   - জ্বর বললে → জ্বর কত দিন ধরে, সাথে আর কী লক্ষণ (জ্বর-সম্পর্কিত)।
   - খেতে চাইছে না / দুর্বল বললে → খাওয়া কমেছে কিনা, নিস্তেজ/ঝিমিয়ে আছে কিনা।
   - শ্বাসকষ্ট বললে → শ্বাসের গতি, বুক ডেবে যাওয়া।
   একই প্রশ্ন (যেমন "খিঁচুনি বা ফিট") প্রতিবার করো না — প্রতিটি পরিস্থিতিতে মানানসই।
   - নিরাপত্তা ব্যতিক্রম: ASHA যদি প্রাণঘাতী কিছুর ইঙ্গিত দেন (খিঁচুনি, অজ্ঞান,
     তীব্র রক্তপাত, প্রবল শ্বাসকষ্ট) — তখন সেটিই আগে জিজ্ঞেস করো।
   - প্রশ্ন স্বাভাবিক কথার মতো হোক:
     "রক্তপাত হচ্ছে?"  "কোনো রক্তপাত বা তলপেট ব্যথা দেখা দিচ্ছে?"
   - **ইতিমধ্যে উত্তর পাওয়া প্রশ্ন কখনো আবার জিজ্ঞেস করবে না।** প্রতিটি টার্নে
     নতুন একটি প্রশ্ন করো; ক্রম নমনীয়, কিন্তু শেষ করার আগে সব অজানা প্রশ্ন
     একসময় ঢাকা পড়বে (কভারেজ বাধ্যতামূলক)।

asked_question_id: তুমি এই উত্তরে (spoken_response-এ) যে প্রশ্নটি জিজ্ঞেস করছ
তার ঠিক সেই id (যেমন "c7", "p1") — উপরের "ক্লিনিক্যাল প্রশ্নের তালিকা" থেকে।
কোনো প্রশ্ন না করলে (should_finish বা cancel_session হলে) null দাও। এই id দিয়েই
ASHA-র পরের সংক্ষিপ্ত "হ্যাঁ/না" সঠিক প্রশ্নে যুক্ত হবে — তাই অবশ্যই সঠিক id দাও।

should_finish: true দাও যদি:
- ২+ RED বিপদচিহ্ন নিশ্চিত
- সব অজানা প্রশ্নের উত্তর পাওয়া গেছে
- turn $turnNumber >= $maxTurns

শুধুমাত্র এই JSON দিয়ে উত্তর দাও (কোনো markdown নয়):
{
  "spoken_response": "স্বাভাবিক বাংলা উত্তর — সর্বোচ্চ ৩ বাক্য",
  "extracted_answers": {"p1": true, "p3": false},
  "asked_question_id": "p6",
  "should_finish": false,
  "cancel_session": false,
  "risk_level": "low"
}

risk_level অবশ্যই এর মধ্যে একটি: "low", "medium", "high", "emergency"
extracted_answers শুধু সেই প্রশ্নগুলো যা কথোপকথন থেকে নিশ্চিতভাবে বোঝা গেছে
''';

    // ── Always fetch a FRESH decision — no cache, no replay ───────────────────
    // Triage is online-only and Gemini DECIDES the band, so we must NEVER serve
    // a cached reply: a repeated prompt has to hit Gemini again. (A stale
    // Groq-era cache entry would otherwise replay an old, wrong attribution —
    // exactly the "it still uses a fallback" behaviour.) We also tell the
    // backend to skip ITS AiCache (skipCache:true) for the same reason.
    Map<String, dynamic>? bodyJson;
    List<int>? prefetchedAudio;
    {
      // Combined chat + voice — one round-trip (text + MP3). Retry for
      // cold-start / rural network; on failure fall through to legacy /chat.
      Map<String, dynamic>? combined;
      const timeouts = [Duration(seconds: 25), Duration(seconds: 35)];
      for (int attempt = 0; attempt < timeouts.length; attempt++) {
        combined = await ApiService.chatWithVoice(
          prompt: prompt,
          voiceField: 'spoken_response',
          tone: 'normal',
          skipCache: true,
          timeout: timeouts[attempt],
        );
        if (combined != null) break;
        if (attempt < timeouts.length - 1) {
          await Future.delayed(Duration(seconds: attempt + 1));
        }
      }

      if (combined != null) {
        bodyJson = combined;
        final audioB64 = combined['audio'] as String?;
        if (audioB64 != null && audioB64.isNotEmpty) {
          try {
            prefetchedAudio = base64Decode(audioB64);
          } catch (_) { /* fall back to /tts in caller */ }
        }
      } else {
        // Legacy /api/chat (no prefetched audio), also skipping the server cache.
        http.Response? response;
        for (int attempt = 0; attempt < timeouts.length; attempt++) {
          try {
            response = await http.post(
              Uri.parse('${ApiConstants.baseUrl}/chat'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'prompt': prompt, 'skipCache': true}),
            ).timeout(timeouts[attempt]);
            if (response.statusCode == 200) break;
            if (response.statusCode != 503) break;
            await Future.delayed(Duration(seconds: attempt + 1));
          } on Exception {
            if (attempt == timeouts.length - 1) rethrow;
            await Future.delayed(Duration(seconds: attempt + 1));
          }
        }
        if (response == null || response.statusCode != 200) {
          AppLogger.e('Chat HTTP ${response?.statusCode}');
          throw Exception('Backend chat error ${response?.statusCode}');
        }
        bodyJson = jsonDecode(response.body) as Map<String, dynamic>;
      }
    }
    final raw = (bodyJson['text'] as String? ?? '')
        .trim()
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    // Recover the human-facing line FIRST — robustly, so a reply that was
    // clipped mid-JSON still yields clean text instead of leaking the literal
    // `"spoken_response": {...` to the screen or TTS. (Rare now that the
    // server disables model "thinking", but cheap insurance.)
    final spokenFromText = _extractSpokenResponse(raw);

    // Fire partial callback with the spoken text only — never raw JSON.
    if (onPartialResponse != null) {
      if (spokenFromText != null && spokenFromText.isNotEmpty) {
        onPartialResponse(spokenFromText);
      } else if (raw.isNotEmpty) {
        onPartialResponse('বিশ্লেষণ করছি...');
      }
    }
    // Safe JSON parse — Gemini occasionally returns markdown leaks or
    // truncated output. Rather than crashing to offline, return a minimal
    // valid response (carrying the text we already recovered) so the
    // conversation continues without ever speaking raw JSON.
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return ConversationResponse(
        spokenResponse: (spokenFromText != null && spokenFromText.isNotEmpty)
            ? spokenFromText
            : 'বুঝেছি, একটু অপেক্ষা করুন।',
        extractedAnswers: const {},
        extractedVitals: spokenVitals,
        shouldFinish: false,
        riskLevel: 'low',
        prefetchedAudio: prefetchedAudio,
      );
    }

    final extracted = <String, bool>{};
    final rawAnswers = json['extracted_answers'] as Map<String, dynamic>? ?? {};
    for (final e in rawAnswers.entries) {
      if (e.value is bool) extracted[e.key] = e.value as bool;
    }

    // The id of the question Gemini just asked (so the caller attributes the
    // worker's next bare yes/no to the RIGHT question). Validate it's a known
    // id for this module; ignore anything malformed so a bad value can't
    // mis-record an answer.
    final rawAsked = (json['asked_question_id'] as String?)?.trim();
    final askedQuestionId =
        (rawAsked != null && questionDescs.containsKey(rawAsked))
            ? rawAsked
            : null;

    final jsonSpoken = (json['spoken_response'] as String?)?.trim();
    String spokenResponse = (jsonSpoken != null && jsonSpoken.isNotEmpty)
        ? jsonSpoken
        : (spokenFromText ?? newInput);
    if (spokenVitals.isNotEmpty) {
      final alert = VitalsExtractor.getDangerAlert(spokenVitals, moduleId);
      if (alert != null) spokenResponse = '$alert $spokenResponse';
    }

    return ConversationResponse(
      spokenResponse: spokenResponse,
      extractedAnswers: extracted,
      extractedVitals: spokenVitals,
      shouldFinish: json['should_finish'] == true,
      riskLevel: json['risk_level'] as String? ?? 'low',
      askedQuestionId: askedQuestionId,
      prefetchedAudio: prefetchedAudio,
      cancelSession: json['cancel_session'] == true,
    );
  }

  /// Pulls the human-facing "spoken_response" line out of the model's JSON
  /// output. Tries a strict parse of a balanced object first, then an
  /// open-ended regex that tolerates a value clipped mid-string (no closing
  /// quote) — so a truncated reply still yields clean text instead of leaking
  /// the literal `"spoken_response": {...` to the screen or TTS. Returns null
  /// when nothing usable is found.
  static String? _extractSpokenResponse(String raw) {
    if (raw.isEmpty) return null;
    // 1) Strict: first balanced {...} object.
    final obj = _extractJsonObject(raw);
    if (obj != null) {
      try {
        final v = (jsonDecode(obj) as Map<String, dynamic>)['spoken_response'];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      } catch (_) { /* fall through to regex */ }
    }
    // 2) Open-ended: capture the value even if the closing quote is missing.
    final m =
        RegExp(r'"spoken_response"\s*:\s*"((?:\\.|[^"\\])*)').firstMatch(raw);
    if (m != null) {
      final unescaped = (m.group(1) ?? '')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', ' ')
          .replaceAll(r'\\', r'\')
          .trim();
      if (unescaped.isNotEmpty) return unescaped;
    }
    // 3) Last resort: prose before any brace (model ignored the JSON contract).
    if (!raw.trimLeft().startsWith('{')) {
      final prose = raw.split('{').first.trim();
      if (prose.isNotEmpty) return prose;
    }
    return null;
  }

  /// Returns the first balanced {...} object substring, or null. Tolerates
  /// braces and quotes that appear inside string values.
  static String? _extractJsonObject(String s) {
    final start = s.indexOf('{');
    if (start < 0) return null;
    int depth = 0;
    bool inStr = false;
    bool esc = false;
    for (int i = start; i < s.length; i++) {
      final c = s[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == r'\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
        continue;
      }
      if (c == '"') {
        inStr = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return s.substring(start, i + 1);
      }
    }
    return null;
  }

}
