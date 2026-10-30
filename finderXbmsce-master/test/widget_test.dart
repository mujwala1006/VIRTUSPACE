import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finderr/features/batches/domain/batch.dart';
import 'package:finderr/features/batches/domain/batch_task.dart';
import 'package:finderr/features/notifications/domain/app_notification.dart';
import 'package:finderr/features/posts/domain/post.dart';
import 'package:finderr/features/projects/domain/project.dart';
import 'package:finderr/features/users/domain/user_profile.dart';

void main() {
  final date = DateTime.utc(2024, 1, 31);

  test('profile serializes the unified uid-keyed schema', () {
    final skills = <String>['Dart'];
    final profile = UserProfile(
      uid: 'uid-1',
      role: UserRole.student,
      name: 'Student',
      bio: 'Bio',
      photoUrl: '',
      department: 'CSE',
      skills: skills,
      interests: const ['AI'],
      followersCount: 2,
      followingCount: 3,
      resumeUrl: null,
      createdAt: date,
      domains: const ['Robotics'],
      certificationUrls: const ['https://example.test/cert.pdf'],
    );
    skills.add('Flutter');

    final map = profile.toMap();
    expect(
        map.keys,
        containsAll([
          'role',
          'name',
          'bio',
          'photoUrl',
          'department',
          'skills',
          'interests',
          'domains',
          'certificationUrls',
          'followersCount',
          'followingCount',
          'resumeUrl',
          'createdAt',
        ]));
    expect(map, isNot(contains('email')));
    expect(map['skills'], ['Dart']);
    final restored = UserProfile.fromMap('uid-1', map);
    expect(restored.role, UserRole.student);
    expect(restored.domains, ['Robotics']);
    expect(restored.certificationUrls, ['https://example.test/cert.pdf']);
  });

  test('notification maps underscore type names and read state', () {
    final notification = AppNotification(
      id: 'notice-1',
      toUid: 'to',
      fromUid: 'from',
      type: NotificationType.batchInvite,
      refId: 'batch-1',
      createdAt: date,
      read: false,
    );
    final roundTrip = AppNotification.fromMap(
      notification.id,
      notification.toMap(),
    );
    expect(roundTrip.type, NotificationType.batchInvite);
    expect(roundTrip.toUid, 'to');
    expect(roundTrip.read, isFalse);
    final teammateInvite = AppNotification(
      id: 'notice-2',
      toUid: 'to',
      fromUid: 'from',
      type: NotificationType.teammateInvite,
      refId: 'project-1',
      createdAt: date,
      read: false,
    );
    expect(
      AppNotification.fromMap(teammateInvite.id, teammateInvite.toMap()).type,
      NotificationType.teammateInvite,
    );
  });

  test('post and project round-trip with their schema field names', () {
    final post = Post(
      id: 'post-1',
      authorUid: 'author',
      type: PostType.certification,
      text: 'Completed certification',
      imageUrls: const ['https://example.test/cert.png'],
      createdAt: date,
      likesCount: 0,
    );
    final project = Project(
      id: 'project-1',
      ownerUid: 'owner',
      title: 'Project',
      description: 'Description',
      domains: const ['web'],
      requiredSkills: const ['Flutter'],
      status: 'open',
      batchId: null,
      createdAt: date,
      doneTaskCount: 2,
      totalTaskCount: 5,
    );

    expect(Post.fromMap(post.id, post.toMap()).type, PostType.certification);
    final restored = Project.fromMap(project.id, project.toMap());
    expect(restored.ownerUid, 'owner');
    expect(restored.doneTaskCount, 2);
    expect(restored.totalTaskCount, 5);
    expect(
      () => Project(
        id: 'invalid-project',
        ownerUid: 'owner',
        title: 'Invalid project',
        description: 'Description',
        domains: const [],
        requiredSkills: const [],
        status: 'open',
        batchId: null,
        createdAt: date,
        doneTaskCount: 4,
        totalTaskCount: 2,
      ),
      throwsArgumentError,
    );
  });

  test('batch enforces minimum team size and three-month duration', () {
    final batch = Batch(
      id: 'batch-1',
      teacherUid: 'teacher',
      studentUids: const ['a', 'b', 'c', 'd'],
      projectId: 'project-1',
      startDate: date,
      endDate: Batch.addThreeMonths(date),
      status: BatchStatus.active,
    );
    expect(batch.endDate, DateTime.utc(2024, 4, 30));
    expect(
      () => Batch(
        id: 'invalid',
        teacherUid: 'teacher',
        studentUids: const ['a', 'b', 'c'],
        projectId: 'project-1',
        startDate: date,
        endDate: Batch.addThreeMonths(date),
        status: BatchStatus.active,
      ),
      throwsArgumentError,
    );
    expect(
      Batch.fromMap(
        batch.id,
        {
          ...batch.toMap(),
          'startDate': Timestamp.fromDate(batch.startDate),
          'endDate': Timestamp.fromDate(batch.endDate),
        },
      ).studentUids.length,
      4,
    );
  });

  test('batch task serializes its status and editor', () {
    final task = BatchTask(
      id: 'task-1',
      title: 'Build UI',
      description: 'Implement the dashboard',
      assigneeUid: 'student-1',
      status: TaskStatus.doing,
      updatedBy: 'student-1',
      updatedAt: date,
    );
    final restored = BatchTask.fromMap(task.id, task.toMap());
    expect(restored.status, TaskStatus.doing);
    expect(restored.updatedBy, 'student-1');
  });
}
