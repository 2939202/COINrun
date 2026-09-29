import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/run_log.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

// ============================================================
// 휴지통
//
// 휴지통을 켜두면 삭제한 기록이 지워지지 않고 여기로 옵니다.
// 여기서 되살리거나 완전히 지울 수 있습니다.
//
// 휴지통에 있는 동안에도 주간·월간 기록에서는 빠져 있습니다.
// "삭제하면 주간·월간에서 빠집니다"라고 해놓고 계속 세고 있으면 말이 다르기 때문입니다.
// 되살리면 다시 더해집니다.
//
// 버린 지 7일이 지나면 알아서 완전히 지워집니다. 서버가 따로 없어서, 이 화면을 열 때와
// 러닝을 저장할 때 앱이 직접 정리합니다.
// ============================================================
class TrashScreen extends StatefulWidget {
  final String userId;

  const TrashScreen({super.key, required this.userId});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late final Stream<List<RunLog>> _trash = UserRepository.instance.watchTrash(
    widget.userId,
  );

  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    // 기한이 지난 것을 먼저 치웁니다. 실패해도 목록은 그대로 보여줍니다.
    UserRepository.instance.pruneTrash(widget.userId).catchError((_) {});
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      _toast(done);
    } on FirebaseException catch (error) {
      _toast(
        error.code == 'permission-denied'
            ? 'Firestore 규칙에 막혔습니다. 콘솔에 firestore.rules를 게시했는지 봐주세요.'
            : '처리하지 못했습니다. (${error.code})',
      );
    } catch (error) {
      _toast('처리하지 못했습니다. ($error)');
    }
    if (mounted) setState(() => _isBusy = false);
  }

  Future<void> _emptyAll(List<RunLog> runs) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('휴지통을 비울까요?'),
        content: Text('${runs.length}개가 완전히 지워집니다. 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('비우기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(
      () => UserRepository.instance.purgeRuns(widget.userId, runs),
      '휴지통을 비웠습니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('휴지통')),
      body: StreamBuilder<List<RunLog>>(
        stream: _trash,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<RunLog> runs = snapshot.data ?? [];
          if (runs.isEmpty) return const _Empty();

          return Column(
            children: [
              if (_isBusy) const LinearProgressIndicator(),
              Expanded(
                child: ListView.separated(
                  itemCount: runs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) => _TrashRow(
                    run: runs[index],
                    isBusy: _isBusy,
                    onRestore: () => _run(
                      () => UserRepository.instance.restoreRun(
                        widget.userId,
                        runs[index],
                      ),
                      '기록을 되살렸습니다.',
                    ),
                    onPurge: () => _run(
                      () => UserRepository.instance.purgeRuns(widget.userId, [
                        runs[index],
                      ]),
                      '기록을 완전히 지웠습니다.',
                    ),
                  ),
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isBusy ? null : () => _emptyAll(runs),
                    child: Text('휴지통 비우기 (${runs.length}개)'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 자동 삭제까지 며칠 남았는지
String _remaining(DateTime thrownAt) {
  final DateTime gone = thrownAt.add(
    const Duration(days: UserRepository.trashKeepDays),
  );
  final int days = gone.difference(DateTime.now()).inDays;
  if (days <= 0) return '곧 자동 삭제';
  return '$days일 뒤 자동 삭제';
}

class _TrashRow extends StatelessWidget {
  final RunLog run;
  final bool isBusy;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  const _TrashRow({
    required this.run,
    required this.isBusy,
    required this.onRestore,
    required this.onPurge,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final DateTime? ran = run.createdAt;
    final DateTime? thrown = run.deletedAt;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatKm(run.distanceMeters)} km',
                  style: textTheme.titleMedium,
                ),
                Text(
                  '${ran == null ? '날짜 없음' : formatMonthDay(ran)} 러닝'
                  '${thrown == null ? '' : ' · ${formatMonthDay(thrown)} 버림'}',
                  style: textTheme.labelMedium,
                ),
                if (thrown != null)
                  Text(
                    _remaining(thrown),
                    style: textTheme.labelMedium?.copyWith(color: Colors.red),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: isBusy ? null : onRestore,
            child: const Text('되살리기'),
          ),
          IconButton(
            tooltip: '완전히 지우기',
            onPressed: isBusy ? null : onPurge,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          '휴지통이 비어 있어요.\n버린 기록은 ${UserRepository.trashKeepDays}일 동안 보관됩니다.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mute),
        ),
      ),
    );
  }
}
