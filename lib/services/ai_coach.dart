import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../game/run_insights.dart';

// ============================================================
// AI 비서 - AI 평가의 한 줄 평과 조언을 Gemini가 씁니다.
//
// [나눠 맡는 일]
//   점수(꾸준함·운동량·흐름)는 지금처럼 폰에서 규칙으로 계산합니다(run_insights.dart).
//   Gemini는 그 숫자를 받아 문장만 씁니다. 점수까지 맡기면 같은 기록인데도 볼 때마다
//   점수가 달라질 수 있기 때문입니다.
//
// [연결]
//   Firebase AI Logic(firebase_ai)으로 부릅니다. API 키를 앱에 넣지 않습니다.
//   앱에 키를 넣으면 APK를 풀어서 누구나 꺼낼 수 있고, 저장소가 GitHub에 있어서
//   커밋되는 순간 남이 가져다 쓸 수 있습니다.
//   Firebase 콘솔 > AI Logic 에서 "Gemini Developer API"를 켜야 동작합니다.
//
// [보내는 것]
//   주간/월간 숫자(횟수, 거리, 움직인 시간, 페이스, 점수)만 보냅니다.
//   GPS 경로, 닉네임, 이메일은 보내지 않습니다.
//
// [아끼기]
//   결과를 users/{uid}/insights/{week|month}에 저장해 두고, 보낸 숫자가 바뀌었을 때만
//   다시 묻습니다. 실패하거나 늦으면 null을 돌려주고, 화면은 규칙 문장을 그대로 씁니다.
// ============================================================
class AiCoach {
  AiCoach._();

  static final AiCoach instance = AiCoach._();

  // 빠르고 저렴한 모델. 바꿀 때는 여기만 고치면 됩니다.
  static const String modelName = 'gemini-3.1-flash-lite';

  static const Duration timeout = Duration(seconds: 12);

  // 말투 규칙. 비서처럼 정중하고 나서지 않으며, 자신이 AI임을 압니다.
  static const String systemInstruction = '''
당신은 러닝 앱 "달리랑"의 AI 비서입니다. 사용자의 주간 또는 월간 러닝 기록 숫자를 받아 짧은 평가를 작성합니다.

지켜야 할 것:
- 당신은 AI 비서이며 그 사실을 알고 있습니다. 사람인 척하지 않습니다. 자기소개는 하지 않습니다.
- 정중한 비서처럼 차분하게 씁니다. 나서지 않습니다. 과장, 감탄, 들뜬 응원, 훈계를 하지 않습니다.
- 모든 문장은 반드시 "습니다." 또는 "입니다."로 끝냅니다.
  예: "달렸습니다.", "줄었습니다.", "있습니다.", "좋습니다.", "수준입니다.", "것으로 보입니다."
  "합니다.", "됩니다.", "바랍니다.", "드립니다.", "권장합니다."처럼 끝내지 않습니다.
  권할 때는 "~하는 것이 좋습니다."처럼 씁니다. 질문하지 않습니다. "~요"체와 반말은 쓰지 않습니다.
- 받은 숫자에 근거해 객관적이고 정량적으로 씁니다. 거리, 횟수, 시간, 페이스, 증감을 숫자로 밝힙니다.
- 받지 않은 사실(날씨, 몸 상태, 심박, 식사 등)은 지어내지 않습니다.
- 이모티콘, 이모지, 느낌표, 물결표 같은 꾸밈 기호를 쓰지 않습니다.
- 의학적 진단이나 처방을 하지 않습니다.

출력은 JSON 하나입니다.
- headline: 40자 이내의 한 문장. 이번 기간을 숫자로 요약합니다.
- comments: 2개 또는 3개. 각 text는 80자 이내의 한두 문장입니다.
  tone은 good(잘한 점), warn(주의할 점), info(참고할 점) 중 하나입니다.
''';

  static final Schema _schema = Schema.object(
    properties: {
      'headline': Schema.string(),
      'comments': Schema.array(
        minItems: 2,
        maxItems: 3,
        items: Schema.object(
          properties: {
            'tone': Schema.enumString(enumValues: ['good', 'warn', 'info']),
            'text': Schema.string(),
          },
        ),
      ),
    },
  );

  late final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: modelName,
    systemInstruction: Content.system(systemInstruction),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: _schema,
      temperature: 0.3, // 같은 숫자면 비슷한 문장이 나오게 낮게 둡니다.
    ),
  );

  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 마지막으로 AI 문장을 못 받은 이유. AI 평가 화면 아래에 작게 띄워서,
  // 폰에서 바로 원인을 볼 수 있게 합니다. 성공하면 null로 돌아갑니다.
  String? lastError;

  // 홈 카드와 AI 평가 화면이 동시에 물어도 한 번만 부르도록 진행 중인 것을 기억합니다.
  final Map<String, Future<AiWords?>> _inFlight = {};

  // 이 보고서에 맞는 AI 문장. 기록이 하나도 없거나 실패하면 null
  Future<AiWords?> wordsFor(String userId, InsightReport report) {
    if (!report.hasAnyRun) return Future.value(null);
    final String key = inputKey(report);
    final String flightKey = '$userId/${report.range.name}/$key';
    return _inFlight[flightKey] ??= _load(
      userId,
      report,
      key,
    ).whenComplete(() => _inFlight.remove(flightKey));
  }

  Future<AiWords?> _load(
    String userId,
    InsightReport report,
    String key,
  ) async {
    final DocumentReference<Map<String, dynamic>> doc = _firestore
        .collection('users')
        .doc(userId)
        .collection('insights')
        .doc(report.range.name);

    AiWords? cached;
    try {
      final snapshot = await doc.get();
      final Map<String, dynamic>? data = snapshot.data();
      if (data != null) {
        cached = AiWords.fromMap(data);
        // 보낼 숫자가 지난번과 같으면 다시 묻지 않습니다.
        if (data['inputKey'] == key && cached != null) return cached;
      }
    } catch (error) {
      debugPrint('AI 평가 저장본 읽기 실패: $error');
    }

    try {
      final response = await _model
          .generateContent([Content.text(buildPrompt(report))])
          .timeout(timeout);
      final AiWords? words = parse(response.text);
      if (words == null) {
        lastError = '답의 형식이 맞지 않습니다';
        return cached;
      }
      lastError = null;
      await doc.set({
        ...words.toMap(),
        'inputKey': key,
        'model': modelName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return words;
    } catch (error) {
      // 숫자가 조금 바뀌었어도, 새로 못 받았으면 지난번 문장이 규칙 문장보다 낫습니다.
      debugPrint('AI 평가 받기 실패: $error');
      lastError = error is TimeoutException
          ? '응답이 ${timeout.inSeconds}초 안에 오지 않았습니다'
          : '$error';
      return cached;
    }
  }

  // ----------------------------------------------------------
  // 아래는 화면/네트워크와 상관없는 부분이라 테스트로 확인합니다.
  // ----------------------------------------------------------

  // Gemini에게 보내는 숫자. 개인을 알아볼 수 있는 것은 넣지 않습니다.
  static String buildPrompt(InsightReport report) {
    final InsightRange range = report.range;
    final StringBuffer out = StringBuffer()
      ..writeln('기간 단위: ${range.label} (${range.unit} 단위)')
      ..writeln(
        '${range.current} 경과율: ${(report.progress * 100).round()}% '
        '(${range.current}는 아직 끝나지 않았을 수 있습니다)',
      )
      ..writeln(
        '${range.current} 예상 거리(지금 속도 유지 시): '
        '${report.projectedKm.toStringAsFixed(1)}km',
      )
      ..writeln('목표 거리: ${range.unit}당 ${range.targetKm.toStringAsFixed(0)}km')
      ..writeln()
      ..writeln('기간별 기록 (오래된 것부터, 마지막이 ${range.current}):');
    for (int i = 0; i < report.periods.length; i++) {
      final PeriodSummary p = report.periods[i];
      final bool isCurrent = i == report.periods.length - 1;
      final String label = isCurrent
          ? range.current
          : '${report.periods.length - 1 - i}${range.unit} 전';
      final double? pace = p.paceMinPerKm;
      out.writeln(
        '- $label: ${p.runs}회, ${p.km.toStringAsFixed(2)}km, '
        '움직인 시간 ${(p.movingSeconds / 60).round()}분, '
        '페이스 ${pace == null ? '없음' : '${pace.toStringAsFixed(1)}분/km'}',
      );
    }
    out
      ..writeln()
      ..writeln(
        '점수: ${report.score}/100 '
        '(꾸준함 ${report.consistencyScore}/40, '
        '운동량 ${report.volumeScore}/30, '
        '흐름 ${report.trendScore}/30)',
      )
      ..writeln()
      ..write('위 숫자만 근거로 headline과 comments를 작성해 주십시오.');
    return out.toString();
  }

  // 보낸 숫자를 한 줄로. 이게 같으면 같은 답이 나올 것이라 다시 묻지 않습니다.
  static String inputKey(InsightReport report) => [
    report.range.name,
    for (final p in report.periods)
      '${p.start.toIso8601String().substring(0, 10)}'
          ':${p.runs}:${p.km.toStringAsFixed(2)}:${p.movingSeconds}',
    report.score,
  ].join('|');

  // Gemini 답 -> 문장. 형식이 틀리면 null (화면은 규칙 문장을 씁니다)
  static AiWords? parse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      return AiWords.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  // 혹시 섞여 들어온 이모지와 꾸밈 기호를 지웁니다. 지시를 어겨도 화면에는 안 나옵니다.
  static final RegExp _decoration = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}!~♡♥★☆]',
    unicode: true,
  );

  static String clean(String text) =>
      text.replaceAll(_decoration, '').replaceAll(RegExp(r'\s+'), ' ').trim();

  // 모든 문장이 "습니다." 또는 "입니다."로 끝나는지.
  // 지시를 어긴 문장은 화면에 내지 않습니다. (규칙 문장은 이 어미를 지킵니다)
  static bool isFormal(String text) {
    final List<String> sentences = text
        .split(RegExp(r'(?<=[.?])\s+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList();
    if (sentences.isEmpty) return false;
    return sentences.every(
      (sentence) => RegExp(r'(습니다|입니다)\.?$').hasMatch(sentence),
    );
  }
}

// AI 비서가 쓴 한 줄 평과 조언
class AiWords {
  final String headline;
  final List<InsightComment> comments;

  const AiWords({required this.headline, required this.comments});

  static AiWords? fromMap(Map<String, dynamic> map) {
    final String headline = AiCoach.clean(map['headline'] as String? ?? '');
    final List<InsightComment> comments = [
      for (final item in (map['comments'] as List<dynamic>? ?? const []))
        if (item is Map<String, dynamic>)
          InsightComment(
            _tone(item['tone'] as String?),
            AiCoach.clean(item['text'] as String? ?? ''),
          ),
    ].where((comment) => AiCoach.isFormal(comment.text)).toList();
    // 한 줄 평이 어미를 어기면 통째로 버리고 기본 분석을 씁니다.
    if (!AiCoach.isFormal(headline) || comments.isEmpty) return null;
    return AiWords(headline: headline, comments: comments.take(3).toList());
  }

  Map<String, dynamic> toMap() => {
    'headline': headline,
    'comments': [
      for (final comment in comments)
        {'tone': comment.tone.name, 'text': comment.text},
    ],
  };

  static InsightTone _tone(String? name) => InsightTone.values.firstWhere(
    (tone) => tone.name == name,
    orElse: () => InsightTone.info,
  );
}
