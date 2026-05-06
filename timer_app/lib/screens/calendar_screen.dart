import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../constants.dart';
import '../models/workout_record.dart';
import '../providers/auth_provider.dart';
import 'profile_screen.dart'; // 타임라인 카드 재사용

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // 시간 단위 때문에 날짜 비교가 어긋나지 않도록 정규화
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text('운동 달력', style: GoogleFonts.notoSansKr(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppConstants.primaryText),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('workouts')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('오류가 발생했습니다.', style: GoogleFonts.notoSansKr(color: AppConstants.secondaryText)));
                }

                Map<DateTime, List<QueryDocumentSnapshot>> events = {};
                int monthlyWorkoutCount = 0;

                // 서버 데이터 -> 달력 Map 구조로 매핑
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    try {
                      final dateStr = data['date'] as String?;
                      if (dateStr != null) {
                        final date = DateTime.parse(dateStr);
                        final normalizedDate = _normalizeDate(date);
                        
                        if (events[normalizedDate] == null) {
                          events[normalizedDate] = [];
                        }
                        events[normalizedDate]!.add(doc);

                        // 현재 보고 있는 달(월)의 총 운동 횟수 카운트
                        if (date.year == _focusedDay.year && date.month == _focusedDay.month) {
                          monthlyWorkoutCount++;
                        }
                      }
                    } catch (e) {
                      debugPrint('Date parsing error: $e');
                    }
                  }
                }

                final selectedDateEvents = events[_normalizeDate(_selectedDay ?? _focusedDay)] ?? [];
                selectedDateEvents.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  final dateA = dataA['date'] as String? ?? '';
                  final dateB = dataB['date'] as String? ?? '';
                  return dateB.compareTo(dateA); // 최신순 정렬
                });

                return Column(
                  children: [
                    // 캘린더 영역 (카드형 디자인)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppConstants.dialogBackground,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onFormatChanged: (format) {
                            if (_calendarFormat != format) {
                              setState(() { _calendarFormat = format; });
                            }
                          },
                          onPageChanged: (focusedDay) {
                            setState(() { _focusedDay = focusedDay; });
                          },
                          eventLoader: (day) => events[_normalizeDate(day)] ?? [],
                          headerStyle: HeaderStyle(
                            titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryText),
                            formatButtonVisible: false,
                            leftChevronIcon: const Icon(Icons.chevron_left, color: AppConstants.primaryText),
                            rightChevronIcon: const Icon(Icons.chevron_right, color: AppConstants.primaryText),
                          ),
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            defaultTextStyle: GoogleFonts.poppins(color: AppConstants.primaryText),
                            weekendTextStyle: GoogleFonts.poppins(color: AppConstants.accentRed),
                            todayDecoration: BoxDecoration(
                              color: AppConstants.primaryBlue.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: const BoxDecoration(
                              color: AppConstants.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            // 운동한 날짜에 도장(마커) 찍기
                            markerBuilder: (context, date, eventsList) {
                              if (eventsList.isNotEmpty) {
                                return Positioned(
                                  right: 1,
                                  bottom: 1,
                                  child: _buildEventsMarker(eventsList),
                                );
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 월간 요약 & 선택 날짜 텍스트
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedDay?.month}월 ${_selectedDay?.day}일의 기록',
                            style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryText),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: AppConstants.surfaceColor, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              '이달 총 $monthlyWorkoutCount회',
                              style: GoogleFonts.notoSansKr(color: AppConstants.primaryBlue, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          )
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // 하단 특정 날짜 기록 리스트 (프로필 뷰의 TimelineCard 재활용)
                    Expanded(
                      child: selectedDateEvents.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.sentiment_dissatisfied, size: 48, color: AppConstants.secondaryText),
                                  const SizedBox(height: 12),
                                  Text('이 날은 휴식하셨네요!', style: GoogleFonts.notoSansKr(color: AppConstants.secondaryText, fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: selectedDateEvents.length,
                              itemBuilder: (context, index) {
                                final data = selectedDateEvents[index].data() as Map<String, dynamic>;
                                final record = WorkoutRecord.fromJson(data);
                                final routineName = data['routineName'] as String? ?? '기본 운동';
                                return WorkoutTimelineCard(
                                  record: record,
                                  isLast: index == selectedDateEvents.length - 1,
                                  userId: user.uid,
                                  routineName: routineName,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // 알림 뱃지(도장) 위젯
  Widget _buildEventsMarker(List events) {
    return Container(
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppConstants.accentRed),
      width: 16.0,
      height: 16.0,
      child: Center(
        child: Text(
          '${events.length}',
          style: const TextStyle().copyWith(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}