import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../models/workout_record.dart';
import '../providers/auth_provider.dart';

class ShareScreen extends StatefulWidget {
  final WorkoutRecord record;
  final String routineName;
  final File? initialImage;
  final List<Map<String, dynamic>>? setDetails;
  final String? memo;

  const ShareScreen({super.key, required this.record, required this.routineName, this.initialImage, this.setDetails, this.memo});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final GlobalKey _globalKey = GlobalKey();
  File? _backgroundImage;
  bool _isCapturing = false;
  
  // 텍스트 이동 및 확대 축소 제어용
  Offset _textPosition = const Offset(24, 40);
  double _textScale = 1.0;
  double _baseScale = 1.0;

  String _customTitle = '오늘도 오운완! 💪';
  int _selectedTemplate = 0; // 0: Sporty, 1: Neon, 2: Strava, 3: Polaroid, 4: Vintage, 5: Modern
  bool _isDetailedMode = false;
  int _selectedFontIndex = 0;
  bool _isTwoColumnLayout = false;
  final Map<String, bool> _expandedExercises = {};

  @override
  void initState() {
    super.initState();
    _backgroundImage = widget.initialImage;
    for (var ex in widget.record.exercises) {
      _expandedExercises[ex.exerciseName] = false; // 화면 차지를 줄이기 위해 기본 접힘 상태
    }
  }

  TextStyle _getCustomFont({required Color color, required double fontSize, FontWeight? fontWeight, List<Shadow>? shadows, double? height}) {
    switch (_selectedFontIndex) {
      case 1:
        return GoogleFonts.nanumPenScript(color: color, fontSize: fontSize + 6, fontWeight: fontWeight, shadows: shadows, height: height);
      case 2:
        return GoogleFonts.jua(color: color, fontSize: fontSize + 2, fontWeight: fontWeight, shadows: shadows, height: height);
      case 3:
        return GoogleFonts.blackHanSans(color: color, fontSize: fontSize, fontWeight: fontWeight, shadows: shadows, height: height);
      case 0:
      default:
        return GoogleFonts.notoSansKr(color: color, fontSize: fontSize, fontWeight: fontWeight, shadows: shadows, height: height);
    }
  }

  void _showFontSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16.0), child: Text('인증샷 폰트 선택', style: TextStyle(color: AppConstants.primaryText, fontSize: 18, fontWeight: FontWeight.bold))),
              ListTile(
                title: Text('기본 폰트 (Noto Sans)', style: GoogleFonts.notoSansKr(fontSize: 16, color: AppConstants.primaryText)),
                onTap: () { setState(() => _selectedFontIndex = 0); Navigator.pop(context); }),
              ListTile(
                title: Text('다짐하는 손글씨체 (Nanum Pen Script)', style: GoogleFonts.nanumPenScript(fontSize: 22, color: AppConstants.primaryText)),
                onTap: () { setState(() => _selectedFontIndex = 1); Navigator.pop(context); }),
              ListTile(
                title: Text('귀여운 둥근체 (Jua)', style: GoogleFonts.jua(fontSize: 18, color: AppConstants.primaryText)),
                onTap: () { setState(() => _selectedFontIndex = 2); Navigator.pop(context); }),
              ListTile(
                title: Text('강력한 굵은체 (Black Han Sans)', style: GoogleFonts.blackHanSans(fontSize: 16, color: AppConstants.primaryText)),
                onTap: () { setState(() => _selectedFontIndex = 3); Navigator.pop(context); }),
            ],
          ),
        );
      }
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _backgroundImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _backgroundImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _shareImage() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imgFile = File('${directory.path}/workout_share.png');
      await imgFile.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(imgFile.path)],
        text: '$_customTitle #HealthTimer',
      );
    } catch (e) {
      debugPrint('Error sharing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공유하는 중 오류가 발생했습니다.')));
      }
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  String _formatSetTime(int ms) {
    int minutes = (ms ~/ 60000);
    int seconds = (ms % 60000) ~/ 1000;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTotalTime(int ms) {
    int hours = (ms ~/ 3600000);
    int minutes = (ms % 3600000) ~/ 60000;
    int seconds = (ms % 60000) ~/ 1000;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  void _showEditTitleDialog() {
    final controller = TextEditingController(text: _customTitle);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppConstants.dialogBackground,
          title: Text('인증 문구 수정', style: GoogleFonts.notoSansKr(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: _getCustomFont(color: AppConstants.primaryText, fontSize: 16),
            decoration: const InputDecoration(
              hintText: '예: 하체 부수는 날🔥',
              hintStyle: TextStyle(color: AppConstants.secondaryText),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.secondaryText)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.primaryBlue)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: GoogleFonts.notoSansKr(color: AppConstants.secondaryText)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _customTitle = controller.text.trim().isNotEmpty ? controller.text.trim() : '오늘도 오운완! 💪';
                });
                Navigator.pop(context);
              },
              child: Text('확인', style: GoogleFonts.notoSansKr(color: AppConstants.primaryBlue, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWorkoutDetails(Color textColor) {
    final int totalSets = widget.record.exercises.fold(0, (sum, ex) => sum + ex.completed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isDetailedMode = !_isDetailedMode),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text('${widget.routineName} · ${widget.record.exercises.length}종목 · $totalSets세트', style: _getCustomFont(color: textColor, fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              if (!_isCapturing) ...[
                const SizedBox(width: 4),
                Icon(_isDetailedMode ? Icons.expand_less : Icons.expand_more, color: textColor.withOpacity(0.5), size: 16),
                if (_isDetailedMode) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _isTwoColumnLayout = !_isTwoColumnLayout),
                    child: Icon(_isTwoColumnLayout ? Icons.view_list_outlined : Icons.view_module_outlined, color: textColor.withOpacity(0.7), size: 16),
                  )
                ]
              ],
            ],
          ),
        ),
        if (_isDetailedMode) ...[
          const SizedBox(height: 6),
          if (_isTwoColumnLayout)
            _buildTwoColumnDetails(textColor)
          else
            ...widget.record.exercises.asMap().entries.map((entry) {
              int index = entry.key;
              var ex = entry.value;
              bool isExpanded = _expandedExercises[ex.exerciseName] ?? false;
              List<Map<String, dynamic>> details = [];
              if (widget.setDetails != null && widget.setDetails!.isNotEmpty) {
                // 사용자가 운동 이름을 변경했더라도 순서를 기반으로 과거 이름과 매핑
                List<String> uniqueOldNames = [];
                for (var d in widget.setDetails!) {
                  String name = d['exercise'] as String;
                  if (!uniqueOldNames.contains(name)) uniqueOldNames.add(name);
                }
                String? targetOldName = (index < uniqueOldNames.length) ? uniqueOldNames[index] : ex.exerciseName;

                details = widget.setDetails!
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .where((d) => d['exercise'] == targetOldName)
                    .toList();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _expandedExercises[ex.exerciseName] = !isExpanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isCapturing) 
                          Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, color: textColor, size: 14),
                        Flexible(child: Text('${ex.exerciseName} ${ex.completed}/${ex.target}세트', style: _getCustomFont(color: textColor, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 2.0, bottom: 6.0),
                      child: details.isEmpty
                          ? Text('상세 기록 없음', style: _getCustomFont(color: textColor.withOpacity(0.5), fontSize: 11))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: details.map((d) {
                                int timeMs = d['timeMs'] as int? ?? 0;
                                String timeStr = timeMs > 0 ? _formatSetTime(timeMs) : '-';
                                String weightStr = d['weight']?.toString() ?? '';
                                String setInfo = '${d['set']}세트 - $timeStr';
                                if (weightStr.isNotEmpty) {
                                  setInfo += ' / $weightStr kg';
                                }
                                return Text(setInfo, style: _getCustomFont(color: textColor.withOpacity(0.8), fontSize: 11), overflow: TextOverflow.ellipsis);
                              }).toList(),
                            ),
                    ),
                ],
              );
            }).toList(),
        ],
        if (widget.memo != null && widget.memo!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote, color: textColor.withOpacity(0.6), size: 14),
                const SizedBox(width: 4),
                Flexible(child: Text(widget.memo!, style: _getCustomFont(color: textColor.withOpacity(0.9), fontSize: 12))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTwoColumnDetails(Color textColor) {
    List<String> allSetDetailsStrings = [];

    if (widget.setDetails != null && widget.setDetails!.isNotEmpty) {
      List<String> uniqueOldNames = [];
      for (var d in widget.setDetails!) {
        String name = d['exercise'] as String;
        if (!uniqueOldNames.contains(name)) uniqueOldNames.add(name);
      }

      for (int i = 0; i < widget.record.exercises.length; i++) {
        var ex = widget.record.exercises[i];
        String targetOldName = (i < uniqueOldNames.length) ? uniqueOldNames[i] : ex.exerciseName;

        List<Map<String, dynamic>> details = widget.setDetails!
            .where((d) => d['exercise'] == targetOldName)
            .toList();

        if (details.isNotEmpty) {
          for (var d in details) {
            int timeMs = d['timeMs'] as int? ?? 0;
            String timeStr = timeMs > 0 ? _formatSetTime(timeMs) : '-';
            String weightStr = d['weight']?.toString() ?? '';
            String setInfo = '${ex.exerciseName} ${d['set']}세트: $timeStr';
            if (weightStr.isNotEmpty) {
              setInfo += ' / $weightStr kg';
            }
            allSetDetailsStrings.add(setInfo);
          }
        }
      }
    }

    if (allSetDetailsStrings.isEmpty) {
      return Text('상세 기록 없음', style: _getCustomFont(color: textColor.withOpacity(0.5), fontSize: 11));
    }

    List<Widget> leftColumn = [];
    List<Widget> rightColumn = [];

    for (int i = 0; i < allSetDetailsStrings.length; i++) {
      final textWidget = Padding(
        padding: const EdgeInsets.only(bottom: 2.0),
        child: Text(allSetDetailsStrings[i], style: _getCustomFont(color: textColor.withOpacity(0.8), fontSize: 10), overflow: TextOverflow.ellipsis),
      );
      if (i.isEven) {
        leftColumn.add(textWidget);
      } else {
        rightColumn.add(textWidget);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: leftColumn)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rightColumn)),
      ],
    );
  }

  Widget _buildWatermark(String nickname, String? photoUrl, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (photoUrl != null) ...[
          CircleAvatar(radius: 10, backgroundImage: NetworkImage(photoUrl)),
          const SizedBox(width: 6),
        ] else ...[
          Icon(Icons.person, color: textColor, size: 14),
          const SizedBox(width: 4),
        ],
        Flexible(child: Text('HealthTimer | @$nickname', style: GoogleFonts.poppins(color: textColor, fontSize: 12, fontWeight: FontWeight.w600, shadows: [if(textColor == Colors.white) const Shadow(blurRadius: 4, color: Colors.black54)]), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  // GestureDetector로 감싸 텍스트 스케일 및 이동 처리를 공통으로 수행
  Widget _buildDraggableText(Widget child) {
    return Positioned(
      left: _textPosition.dx, top: _textPosition.dy,
      child: GestureDetector(
        onScaleStart: (details) {
          _baseScale = _textScale;
        },
        onScaleUpdate: (details) {
          setState(() {
            _textPosition += details.focalPointDelta;
            _textScale = _baseScale * details.scale;
          });
        },
        child: Transform.scale(
          scale: _textScale,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
    );
  }

  Widget _buildSportyTemplate(int totalSets, String nickname, String? photoUrl) {
    return Stack(
      children: [
        if (_backgroundImage != null) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.25))),
        _buildDraggableText(
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _showEditTitleDialog,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(_customTitle, style: _getCustomFont(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), if(!_isCapturing) ...[const SizedBox(width: 6), const Icon(Icons.edit, color: Colors.white70, size: 14)]]),
                    ),
                    const SizedBox(height: 2),
                    Text(_formatTotalTime(widget.record.totalTimeMs), style: GoogleFonts.poppins(color: AppConstants.primaryBlue, fontSize: 56, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1)),
                    const SizedBox(height: 4),
                    _buildWorkoutDetails(Colors.white.withOpacity(0.9)),
                    const SizedBox(height: 2),
                    Text(_formatDate(widget.record.date), style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(right: 16, bottom: 16, child: _buildWatermark(nickname, photoUrl, Colors.white)),
      ],
    );
  }

  Widget _buildAppleTemplate(int totalSets, String nickname, String? photoUrl) {
    return Stack(
      children: [
        if (_backgroundImage != null) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),
        _buildDraggableText(
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _showEditTitleDialog,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(_customTitle, style: _getCustomFont(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), if(!_isCapturing) ...[const SizedBox(width: 6), const Icon(Icons.edit, color: Colors.white70, size: 14)]]),
                    ),
                    const SizedBox(height: 8),
                    Text(_formatTotalTime(widget.record.totalTimeMs), style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 48, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _buildWorkoutDetails(Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(right: 16, bottom: 16, child: _buildWatermark(nickname, photoUrl, Colors.white)),
      ],
    );
  }

  Widget _buildStravaTemplate(int totalSets, String nickname, String? photoUrl) {
    return Stack(
      children: [
        if (_backgroundImage != null) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.2))),
        Positioned(
          left: 0, right: 0, top: 0,
          child: Container(
            color: const Color(0xFFFC4C02).withOpacity(0.9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showEditTitleDialog,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(_customTitle, style: _getCustomFont(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), if(!_isCapturing) ...[const SizedBox(width: 6), const Icon(Icons.edit, color: Colors.white70, size: 14)]]),
                  ),
                ),
                _buildWatermark(nickname, photoUrl, Colors.white),
              ],
            ),
          ),
        ),
        _buildDraggableText(
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 8)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('TIME', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(_formatTotalTime(widget.record.totalTimeMs), style: GoogleFonts.poppins(color: Colors.black87, fontSize: 36, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Container(height: 1, width: 150, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    _buildWorkoutDetails(Colors.black87),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPolaroidTemplate(int totalSets, String nickname, String? photoUrl) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppConstants.dialogBackground,
                image: _backgroundImage != null ? DecorationImage(image: FileImage(_backgroundImage!), fit: BoxFit.cover) : null,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.25),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _showEditTitleDialog,
                          child: Row(children: [Flexible(child: Text(_customTitle, style: _getCustomFont(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), if(!_isCapturing) ...[const SizedBox(width: 4), const Icon(Icons.edit, color: Colors.black38, size: 14)]]),
                        ),
                        const SizedBox(height: 4),
                        _buildWorkoutDetails(Colors.black54),
                        const SizedBox(height: 4),
                        Text(_formatDate(widget.record.date), style: _getCustomFont(color: Colors.black38, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatTotalTime(widget.record.totalTimeMs), style: GoogleFonts.poppins(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  _buildWatermark(nickname, photoUrl, Colors.black45),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildVintagePolaroidTemplate(int totalSets, String nickname, String? photoUrl) {
    return Container(
      color: const Color(0xFFFFF9E6),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        children: [
          Container(height: 12, width: 100, color: Colors.amber.withOpacity(0.4)),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppConstants.dialogBackground,
                image: _backgroundImage != null ? DecorationImage(image: FileImage(_backgroundImage!), fit: BoxFit.cover) : null,
                boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showEditTitleDialog,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(_customTitle, style: _getCustomFont(color: Colors.brown[800]!, fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                if(!_isCapturing) ...[const SizedBox(width: 6), const Icon(Icons.edit, color: Colors.brown, size: 16)]
              ]
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.25),
            child: SingleChildScrollView(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildWorkoutDetails(Colors.brown[600]!)),
                  const SizedBox(width: 8),
                  Text(_formatTotalTime(widget.record.totalTimeMs), style: GoogleFonts.poppins(color: Colors.brown[900], fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildWatermark(nickname, photoUrl, Colors.brown[400]!),
        ],
      ),
    );
  }

  Widget _buildModernTemplate(int totalSets, String nickname, String? photoUrl) {
    return Stack(
      children: [
        if (_backgroundImage != null) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.15))),
        _buildDraggableText(
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _showEditTitleDialog,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(_customTitle, style: _getCustomFont(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), if(!_isCapturing) ...[const SizedBox(width: 6), const Icon(Icons.edit, color: Colors.white70, size: 14)]]),
                        ),
                        const SizedBox(height: 8),
                        Text(_formatTotalTime(widget.record.totalTimeMs), style: GoogleFonts.poppins(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w300)),
                        const SizedBox(height: 12),
                        _buildWorkoutDetails(Colors.white.withOpacity(0.9)),
                        const SizedBox(height: 8),
                        Text(_formatDate(widget.record.date), style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(right: 16, bottom: 16, child: _buildWatermark(nickname, photoUrl, Colors.white)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final nickname = authProvider.user?.displayName ?? '사용자';
    final photoUrl = authProvider.user?.photoURL;
    final int totalSets = widget.record.exercises.fold(0, (sum, ex) => sum + ex.completed);

    Widget currentTemplateWidget;
    if (_selectedTemplate == 1) {
      currentTemplateWidget = _buildAppleTemplate(totalSets, nickname, photoUrl);
    } else if (_selectedTemplate == 2) {
      currentTemplateWidget = _buildStravaTemplate(totalSets, nickname, photoUrl);
    } else if (_selectedTemplate == 3) {
      currentTemplateWidget = _buildPolaroidTemplate(totalSets, nickname, photoUrl);
    } else if (_selectedTemplate == 4) {
      currentTemplateWidget = _buildVintagePolaroidTemplate(totalSets, nickname, photoUrl);
    } else if (_selectedTemplate == 5) {
      currentTemplateWidget = _buildModernTemplate(totalSets, nickname, photoUrl);
    } else {
      currentTemplateWidget = _buildSportyTemplate(totalSets, nickname, photoUrl);
    }

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text('SNS 인증샷 공유', style: GoogleFonts.notoSansKr(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppConstants.primaryText),
        actions: [
          IconButton(
            icon: const Icon(Icons.font_download, color: AppConstants.primaryText),
            onPressed: _showFontSelectionDialog,
            tooltip: '글씨체 변경',
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt, color: AppConstants.primaryText),
            onPressed: _takePhoto,
            tooltip: '카메라로 다시 촬영',
          ),
          IconButton(
            icon: const Icon(Icons.image, color: AppConstants.primaryBlue),
            onPressed: _pickImage,
            tooltip: '배경 사진 선택',
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _globalKey,
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 백그라운드 이미지만 개별적으로 확대/이동 가능하도록 분리
                      if (_backgroundImage != null && _selectedTemplate != 3 && _selectedTemplate != 4)
                        InteractiveViewer(
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.file(_backgroundImage!, fit: BoxFit.cover),
                        ),
                      if (_backgroundImage == null && _selectedTemplate != 3 && _selectedTemplate != 4)
                        Container(color: AppConstants.dialogBackground),
                      // 템플릿 영역 (텍스트/위젯 등)
                      currentTemplateWidget,
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTemplateTab(0, '스포티', Icons.directions_run),
                const SizedBox(width: 8),
                _buildTemplateTab(1, '네온', Icons.watch),
                const SizedBox(width: 8),
                _buildTemplateTab(2, '스트라바', Icons.map),
                const SizedBox(width: 8),
                _buildTemplateTab(3, '폴라로이드', Icons.photo_camera_front),
                const SizedBox(width: 8),
                _buildTemplateTab(4, '빈티지', Icons.camera_roll),
                const SizedBox(width: 8),
                _buildTemplateTab(5, '모던', Icons.blur_on),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 20.0, bottom: 30.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              icon: _isCapturing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.share),
              label: Text(_isCapturing ? '이미지 생성 중...' : '인스타그램 등 SNS에 공유하기', style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: _isCapturing ? null : _shareImage,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTemplateTab(int index, String title, IconData icon) {
    final isSelected = _selectedTemplate == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTemplate = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryBlue : AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppConstants.secondaryText),
            const SizedBox(width: 6),
            Text(title, style: GoogleFonts.notoSansKr(color: isSelected ? Colors.white : AppConstants.secondaryText, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}