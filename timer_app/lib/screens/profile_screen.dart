import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models/workout_record.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: Text('내 정보 및 기록', style: GoogleFonts.notoSansKr(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppConstants.primaryText),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppConstants.accentRed),
            onPressed: () async {
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          )
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProfileHeader(context, authProvider, user),
                const Divider(color: AppConstants.secondaryText, height: 1),
                Expanded(
                  child: _buildWorkoutTimeline(user.uid),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AuthProvider authProvider, user) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _changeProfileImage(context, authProvider),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppConstants.dialogBackground,
                  backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                  child: user.photoURL == null 
                      ? const Icon(Icons.person, size: 40, color: AppConstants.secondaryText) 
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppConstants.primaryBlue, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.displayName ?? '이름 없음',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 22, 
                        fontWeight: FontWeight.bold, 
                        color: AppConstants.primaryText
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showEditNameDialog(context, user, authProvider),
                      child: const Icon(Icons.edit, size: 18, color: AppConstants.secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? '이메일 없음',
                  style: GoogleFonts.poppins(
                    fontSize: 14, 
                    color: AppConstants.secondaryText
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeProfileImage(BuildContext context, AuthProvider authProvider) async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile == null) return;

      final user = authProvider.user;
      if (user == null || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필 이미지를 업로드하는 중입니다...')));

      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance.ref().child('profile_images').child('${user.uid}.jpg');

      // Upload to Firebase Storage
      await ref.putFile(file);
      final downloadURL = await ref.getDownloadURL();

      // Update Firebase Auth user profile
      await user.updatePhotoURL(downloadURL);

      // Update user document in Firestore (optional but good practice)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'photoURL': downloadURL}, SetOptions(merge: true));

      // Refresh the user state in the provider to update UI immediately
      await authProvider.refreshUser();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필 이미지가 성공적으로 변경되었습니다.')));
      }
    } catch (e) {
      debugPrint("Error changing profile image: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지 변경 중 오류가 발생했습니다: $e')));
      }
    }
  }

  void _showEditNameDialog(BuildContext context, user, AuthProvider authProvider) {
    final TextEditingController nameController = TextEditingController(text: user.displayName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppConstants.dialogBackground,
          title: Text('닉네임 변경', style: GoogleFonts.notoSansKr(color: AppConstants.primaryText)),
          content: TextField(
            controller: nameController,
            style: GoogleFonts.notoSansKr(color: AppConstants.primaryText),
            decoration: InputDecoration(
              hintText: '새로운 닉네임을 입력하세요',
              hintStyle: GoogleFonts.notoSansKr(color: AppConstants.secondaryText),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.secondaryText)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.primaryBlue)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: GoogleFonts.notoSansKr(color: AppConstants.secondaryText)),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                Navigator.pop(context);
                if (newName.isNotEmpty) {
                  await user.updateDisplayName(newName);
                  await authProvider.refreshUser();
                }
              },
              child: Text('저장', style: GoogleFonts.notoSansKr(color: AppConstants.primaryBlue)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWorkoutTimeline(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('workouts')
          .orderBy('id', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.accentRed));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('데이터를 불러오는 중 오류가 발생했습니다.', 
              style: GoogleFonts.notoSansKr(color: AppConstants.primaryText)
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('아직 운동 기록이 없습니다.\n첫 운동을 시작해보세요!', 
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(color: AppConstants.secondaryText, fontSize: 16)
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final record = WorkoutRecord.fromJson(data);
            final routineName = data['routineName'] as String? ?? '기본 운동';
            return WorkoutTimelineCard(
              record: record, 
              isLast: index == docs.length - 1,
              userId: uid,
              routineName: routineName,
            );
          },
        );
      },
    );
  }
}

class WorkoutTimelineCard extends StatelessWidget {
  final WorkoutRecord record;
  final bool isLast;
  final String userId;
  final String routineName;

  const WorkoutTimelineCard({
    super.key, 
    required this.record, 
    required this.isLast,
    required this.userId,
    required this.routineName,
  });

  String _formatTotalTime(int ms) {
    int hours = (ms ~/ 3600000);
    int minutes = (ms % 3600000) ~/ 60000;
    int seconds = (ms % 60000) ~/ 1000;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }
  
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Node & Line
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppConstants.accentRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppConstants.backgroundColor, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppConstants.secondaryText.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // Card Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppConstants.dialogBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(record.date),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppConstants.secondaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              routineName,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 16,
                                color: AppConstants.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppConstants.accentRed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatTotalTime(record.totalTimeMs),
                              style: GoogleFonts.poppins(color: AppConstants.accentRed, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _showDeleteConfirmDialog(context),
                            child: const Icon(Icons.delete_outline, size: 20, color: AppConstants.secondaryText),
                          ),
                        ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...record.exercises.asMap().entries.map((entry) {
                      int idx = entry.key;
                      ExerciseSet ex = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _showEditExerciseDialog(context, ex, idx),
                                child: Row(
                                  children: [
                                    Icon(Icons.fitness_center, size: 16, color: AppConstants.secondaryText),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ex.exerciseName,
                                        style: GoogleFonts.notoSansKr(
                                          fontSize: 15,
                                          color: AppConstants.primaryText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.edit, size: 14, color: AppConstants.secondaryText),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              '${ex.completed}/${ex.target} 세트',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 14,
                                color: ex.completed >= ex.target ? Colors.greenAccent : AppConstants.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditExerciseDialog(BuildContext context, ExerciseSet ex, int index) {
    final TextEditingController controller = TextEditingController(text: ex.exerciseName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppConstants.dialogBackground,
          title: Text('종목 이름 변경', style: GoogleFonts.notoSansKr(color: AppConstants.primaryText)),
          content: TextField(
            controller: controller,
            style: GoogleFonts.notoSansKr(color: AppConstants.primaryText),
            decoration: InputDecoration(
              hintText: '예: 스쿼트, 벤치프레스',
              hintStyle: GoogleFonts.notoSansKr(color: AppConstants.secondaryText),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.secondaryText)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.accentRed)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: GoogleFonts.notoSansKr(color: AppConstants.secondaryText)),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                Navigator.pop(context);
                if (newName.isNotEmpty) {
                  _updateExerciseName(index, newName);
                }
              },
              child: Text('저장', style: GoogleFonts.notoSansKr(color: AppConstants.accentRed)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppConstants.dialogBackground,
          title: Text('기록 삭제', style: GoogleFonts.notoSansKr(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
          content: Text('이 운동 기록을 삭제하시겠습니까?\n삭제된 기록은 복구할 수 없습니다.', style: GoogleFonts.notoSansKr(color: AppConstants.secondaryText)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: GoogleFonts.notoSansKr(color: AppConstants.secondaryText)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                FirebaseFirestore.instance.collection('users').doc(userId).collection('workouts').doc(record.id).delete();
              },
              child: Text('삭제', style: GoogleFonts.notoSansKr(color: AppConstants.accentRed)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateExerciseName(int exerciseIndex, String newName) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .doc(record.id);

      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        final currentRecord = WorkoutRecord.fromJson(data);
        
        final List<ExerciseSet> updatedExercises = List.from(currentRecord.exercises);
        final oldEx = updatedExercises[exerciseIndex];
        updatedExercises[exerciseIndex] = ExerciseSet(
          exerciseNum: oldEx.exerciseNum,
          exerciseName: newName,
          completed: oldEx.completed,
          target: oldEx.target,
        );

        await docRef.update({
          'exercises': updatedExercises.map((e) => e.toJson()).toList(),
        });
      }
    } catch (e) {
      debugPrint('Error updating exercise name: $e');
    }
  }
}
