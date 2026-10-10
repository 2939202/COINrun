import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../game/felt_calibration.dart';
import '../game/goal_policy.dart';
import '../game/stats_period.dart';
import '../game/training_model.dart';
import '../game/week_plan.dart';
import '../models/run_log.dart';
import 'ai_coach.dart';
import 'ai_guard.dart';
import 'user_repository.dart';

// ============================================================
// 이번 주 목표를 정하고 저장하는 곳
//
//   1. 지난 기록으로 목표 범위를 계산합니다. (goal_policy.dart, 폰에서)
//   2. Gemini가 범위 안에서 거리를 고르고, 이유와 실행 방법을 씁니다.
//   3. 앱이 검사합니다. 범위 밖이면 끝값으로 자르고, 말투를 어기거나
//      보낸 사실에 없는 숫자를 쓴 문장은 버립니다. 다 버려지면 규칙 문장을 씁니다.
//   4. users/{uid}/goals/{주}에 저장합니다. 한 주 동안 목표가 바뀌지 않고,
//      다음 주에 이 값과 실제 거리로 달성률을 계산해 다시 1번에 넣습니다.
// ============================================================
class WeekCoach {
  WeekCoach._();

  static final WeekCoach instance = WeekCoach._();

  static const String goalInstruction =
      '''
${AiCoach.toneRules}
출력은 JSON 하나입니다. 할 일:
- 받은 "이번 주 목표 거리 허용 범위" 안에서 goalKm 하나를 고릅니다. 범위를 벗어나지 않습니다.
- why: 그 거리를 고른 이유를 받은 숫자에 근거해 두 문장 이내로 씁니다.
- plan: 이번 주에 어떻게 나누어 달리면 좋은지 1~3개 문장으로 씁니다. 받은 요일과 횟수를 씁니다.
''';

  static final Schema _schema = Schema.object(
    properties: {
      'goalKm': Schema.number(),
      'why': Schema.string(),
      'plan': Schema.array(items: Schema.string(), minItems: 1, maxItems: 3),
    },
  );

  late final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: AiCoach.modelName,
    systemInstruction: Content.system(goalInstruction),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: _schema,
      temperature: 0.3,
    ),
  );

  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, Future<WeekPlanView>> _inFlight = {};

  // 이번 주 목표. 처음 부를 때 만들고, 그 주 안에서는 저장된 것을 돌려줍니다.
  Future<WeekPlanView> planFor(String userId) {
    final String key = StatsPeriod.weekKey(DateTime.now());
    return _inFlight['$userId/$key'] ??= _plan(
      userId,
      key,
    ).whenComplete(() => _inFlight.remove('$userId/$key'));
  }

  Future<WeekPlanView> _plan(String userId, String key) async {
    final DateTime now = DateTime.now();
    final DateTime weekStart = StatsPeriod.weekStart(now);
    final CollectionReference<Map<String, dynamic>> goals = _firestore
        .collection('users')
        .doc(userId)
        .collection('goals');

    final List<RunLog> logs = await UserRepository.instance
        .watchRecentRuns(userId, limit: UserRepository.maxStoredRuns)
        .first;
    final List<Session> sessions = [
      for (final log in logs) ?Session.fromLog(log),
    ];

    // 지난주 목표와 실제 거리 -> 달성률
    final DateTime lastStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day - 7,
    );
    GoalResult? last;
    try {
      final WeekPlan? lastPlan = WeekPlan.fromMap(
        (await goals.doc(StatsPeriod.weekKey(lastStart)).get()).data(),
      );
      if (lastPlan != null) {
        last = GoalResult(
          goalKm: lastPlan.km,
          actualKm: WeekProgress.of(sessions, lastStart).km,
        );
      }
    } catch (error) {
      debugPrint('지난주 목표 읽기 실패: $error');
    }

    final WeekFacts facts = WeekFacts.build(
      sessions: sessions,
      now: now,
      last: last,
      felt: FeltCalibration.of(logs, now),
    );

    // 이번 주 목표가 이미 있으면 그대로 씁니다. (주 중에 목표가 바뀌지 않게)
    final DocumentReference<Map<String, dynamic>> doc = goals.doc(key);
    try {
      final WeekPlan? saved = WeekPlan.fromMap((await doc.get()).data());
      if (saved != null) return WeekPlanView(saved, facts);
    } catch (error) {
      debugPrint('이번 주 목표 읽기 실패: $error');
    }

    final WeekPlan plan = await _ask(key, facts) ?? WeekPlan.rule(key, facts);
    try {
      await doc.set({
        ...plan.toMap(),
        'minKm': facts.goal.minKm,
        'maxKm': facts.goal.maxKm,
        'stage': facts.goal.stage.name,
        'reasons': [for (final r in facts.goal.reasons) r.name],
        'model': plan.writtenByAi ? AiCoach.modelName : null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('이번 주 목표 저장 실패: $error');
    }
    return WeekPlanView(plan, facts);
  }

  Future<WeekPlan?> _ask(String key, WeekFacts facts) async {
    final String prompt = facts.toPrompt();
    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(AiCoach.timeout);
      return parse(response.text, key: key, facts: facts, sent: prompt);
    } catch (error) {
      debugPrint('이번 주 목표 AI 실패: $error');
      return null;
    }
  }

  // Gemini 답 -> 목표. 화면/네트워크와 상관없어서 테스트로 확인합니다.
  //   - goalKm은 범위 안으로 자릅니다.
  //   - why가 말투나 숫자 검사에 걸리면 규칙 문장으로 바꿉니다.
  //   - plan은 검사를 통과한 문장만 남기고, 하나도 없으면 규칙 문장을 씁니다.
  static WeekPlan? parse(
    String? text, {
    required String key,
    required WeekFacts facts,
    required String sent,
  }) {
    if (text == null || text.trim().isEmpty) return null;
    final Map<String, dynamic> map;
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      map = decoded;
    } catch (_) {
      return null;
    }
    final double? goalKm = (map['goalKm'] as num?)?.toDouble();
    if (goalKm == null) return null;

    // AI가 고른 목표에서 바로 나오는 숫자도 허용합니다.
    //   목표, 남은 거리, 남은 횟수, 한 번에 달릴 거리(전체/남은 것 기준)
    final double chosen = facts.goal.clampKm(goalKm);
    final WeekProgress done = facts.progress;
    final int leftRuns = (facts.goal.runs - done.runs).clamp(1, 7);
    final double leftKm = (chosen - done.km).clamp(0, chosen).toDouble();
    final AllowedNumbers allowed = AiGuard.allowedFrom(
      '$sent $chosen $leftKm $leftRuns '
      '${chosen / facts.goal.runs} ${leftKm / leftRuns}',
    );
    bool ok(String s) => AiCoach.isFormal(s) && AiGuard.supported(s, allowed);

    final String why = AiCoach.clean(map['why'] as String? ?? '');
    final List<String> plan = [
      for (final p in (map['plan'] as List<dynamic>? ?? const []))
        if (p is String && ok(AiCoach.clean(p))) AiCoach.clean(p),
    ];
    final bool whyOk = ok(why);
    if (!whyOk && plan.isEmpty) return null;

    return WeekPlan(
      weekKey: key,
      km: facts.goal.clampKm(goalKm),
      runs: facts.goal.runs,
      longestKm: facts.goal.longestKm,
      why: whyOk ? why : facts.ruleWhy(),
      plan: plan.isEmpty ? facts.rulePlan() : plan,
      writtenByAi: true,
    );
  }
}

// 화면에 넘기는 것: 저장된 목표 + 지금 계산한 근거와 이번 주 진행
class WeekPlanView {
  final WeekPlan plan;
  final WeekFacts facts;

  const WeekPlanView(this.plan, this.facts);
}
