import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/course.dart';
import '../services/course_repository.dart';
import '../services/seoul_districts.dart';
import '../theme/app_theme.dart';
import '../widgets/course_widgets.dart';

// ============================================================
// 코스 고르기
//
//   맨 위 검색창  - 구 이름으로 찾기 ("노원" -> 노원구)
//   지금 구       - 처음에는 내 위치로 정합니다
//   클래식 코스   - 공식 코스 최대 9개 (3 x 3)
//   ✂ - - - - -   절취선
//   사설 코스     - 하트 많은 순 상위 3개
//
// 코스를 누르면 그 코스를 들고 러닝 화면으로 돌아갑니다. (Navigator.pop)
// ============================================================
class CourseScreen extends StatefulWidget {
  final LatLng? position; // 아직 GPS를 못 잡았으면 null
  final String? selectedId; // 지금 골라둔 코스

  const CourseScreen({super.key, this.position, this.selectedId});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  static const int classicLimit = 9;
  static const int userLimit = 3;

  // 서울 밖이거나 위치를 모를 때 보여줄 구. 대회장이 있는 곳입니다.
  static const String fallbackDistrict = '노원구';

  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  SeoulDistricts? _districts;
  String? _myDistrict; // 내 위치의 구 (서울 밖이면 null)
  String _district = fallbackDistrict; // 지금 보고 있는 구
  Stream<List<Course>>? _userCourses;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    _loadDistricts();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadDistricts() async {
    final SeoulDistricts districts = await SeoulDistricts.load();
    if (!mounted) return;
    final LatLng? position = widget.position;
    final String? mine = position == null
        ? null
        : districts.districtAt(position);
    setState(() {
      _districts = districts;
      _myDistrict = mine;
    });
    _show(mine ?? fallbackDistrict);
  }

  // 스트림은 구가 바뀔 때만 새로 만듭니다. (build에서 만들면 매번 다시 연결됨)
  void _show(String district) {
    setState(() {
      _district = district;
      _userCourses = CourseRepository.instance.watchUserCourses(
        district,
        limit: userLimit,
      );
    });
  }

  void _pickDistrict(String district) {
    _search.clear();
    _searchFocus.unfocus();
    _show(district);
  }

  void _choose(Course course) => Navigator.pop(context, course);

  Future<void> _seeAll({required bool official}) async {
    final Course? course = await Navigator.push<Course>(
      context,
      slideFromRight(
        CourseListScreen(
          district: _district,
          official: official,
          selectedId: widget.selectedId,
        ),
      ),
    );
    if (course != null && mounted) _choose(course);
  }

  @override
  Widget build(BuildContext context) {
    final bool searching = _searchFocus.hasFocus || _search.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('코스')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            _buildSearchField(),
            const SizedBox(height: AppSpacing.md),
            if (searching) _buildSuggestions() else ..._buildCourses(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _search,
      focusNode: _searchFocus,
      onChanged: (_) => setState(() {}),
      onSubmitted: (text) {
        final List<String> found = _districts?.search(text) ?? const [];
        if (found.isNotEmpty) _pickDistrict(found.first);
      },
      textInputAction: TextInputAction.search,
      style: AppTheme.sans.copyWith(fontSize: 15, color: AppColors.black),
      decoration: InputDecoration(
        hintText: '구 이름으로 찾기 (예: 노원)',
        hintStyle: AppTheme.sans.copyWith(fontSize: 15, color: AppColors.label),
        prefixIcon: const Icon(Icons.search, color: AppColors.black),
        suffixIcon: _search.text.isEmpty && !_searchFocus.hasFocus
            ? null
            : IconButton(
                tooltip: '닫기',
                icon: const Icon(Icons.close, color: AppColors.black),
                onPressed: () {
                  _search.clear();
                  _searchFocus.unfocus();
                  setState(() {});
                },
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.black, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.black, width: 2),
        ),
      ),
    );
  }

  // 검색 중에는 코스 대신 구 이름 목록을 보여줍니다.
  Widget _buildSuggestions() {
    final SeoulDistricts? districts = _districts;
    if (districts == null) return const SizedBox.shrink();
    final List<String> found = districts.search(_search.text);
    if (found.isEmpty) {
      return const CourseEmpty(message: '서울에 그런 구가 없어요');
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final name in found)
          GestureDetector(
            onTap: () => _pickDistrict(name),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md - 2,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: name == _district ? AppColors.black : AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.black, width: 1.2),
              ),
              child: Text(
                name,
                style: AppTheme.sans.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: name == _district ? AppColors.white : AppColors.black,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildCourses() {
    final List<Course> classic = CourseRepository.instance.officialCourses(
      _district,
    );

    return [
      _buildDistrictLine(),
      const SizedBox(height: AppSpacing.lg),

      CourseSectionHead(
        caption: 'CLASSIC',
        title: '클래식 코스',
        onSeeAll: () => _seeAll(official: true),
      ),
      const SizedBox(height: AppSpacing.md),
      if (classic.isEmpty)
        const CourseEmpty(message: '이 구에는 아직 클래식 코스가 없어요')
      else
        CourseGrid(
          courses: classic.take(classicLimit).toList(),
          selectedId: widget.selectedId,
          onTap: _choose,
        ),

      const SizedBox(height: AppSpacing.lg),
      const TearLine(),
      const SizedBox(height: AppSpacing.lg),

      CourseSectionHead(
        caption: 'PRIVATE',
        title: '사설 코스',
        onSeeAll: () => _seeAll(official: false),
      ),
      const SizedBox(height: AppSpacing.md),
      StreamBuilder<List<Course>>(
        stream: _userCourses,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const CourseEmpty(message: '사설 코스를 불러오지 못했어요');
          }
          final List<Course> courses = snapshot.data ?? const [];
          if (courses.isEmpty) {
            return const CourseEmpty(message: '아직 사설 코스가 없어요');
          }
          return CourseGrid(
            courses: courses,
            selectedId: widget.selectedId,
            onTap: _choose,
          );
        },
      ),
    ];
  }

  // 지금 보고 있는 구. 내 위치가 아닌 구를 보고 있으면 "내 위치로"를 띄웁니다.
  Widget _buildDistrictLine() {
    final String? mine = _myDistrict;
    final String note = mine == null
        ? (widget.position == null ? '위치를 아직 못 찾았어요' : '서울 밖이에요')
        : (mine == _district ? '내 위치' : '');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.place_outlined, size: 20, color: AppColors.black),
        const SizedBox(width: AppSpacing.xs),
        Text(
          _district,
          style: AppTheme.serifNumber.copyWith(
            fontSize: 22,
            color: AppColors.black,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (note.isNotEmpty)
          Text(
            note,
            style: AppTheme.sans.copyWith(fontSize: 13, color: AppColors.label),
          ),
        const Spacer(),
        if (mine != null && mine != _district)
          GestureDetector(
            onTap: () => _show(mine),
            child: Text(
              '내 위치로',
              style: AppTheme.sans.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.accent,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent,
              ),
            ),
          ),
      ],
    );
  }
}

// 전체보기: 한 구의 클래식 또는 사설 코스 전부
class CourseListScreen extends StatefulWidget {
  final String district;
  final bool official;
  final String? selectedId;

  const CourseListScreen({
    super.key,
    required this.district,
    required this.official,
    this.selectedId,
  });

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  late final Stream<List<Course>> _userCourses = CourseRepository.instance
      .watchUserCourses(widget.district);

  void _choose(Course course) => Navigator.pop(context, course);

  @override
  Widget build(BuildContext context) {
    final String kind = widget.official ? '클래식' : '사설';
    return Scaffold(
      appBar: AppBar(title: Text('${widget.district} $kind 코스')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            if (widget.official)
              _grid(CourseRepository.instance.officialCourses(widget.district))
            else
              StreamBuilder<List<Course>>(
                stream: _userCourses,
                builder: (context, snapshot) =>
                    _grid(snapshot.data ?? const []),
              ),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Course> courses) {
    if (courses.isEmpty) {
      return CourseEmpty(
        message: widget.official ? '아직 클래식 코스가 없어요' : '아직 사설 코스가 없어요',
      );
    }
    return CourseGrid(
      courses: courses,
      selectedId: widget.selectedId,
      onTap: _choose,
    );
  }
}
