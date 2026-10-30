import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/project.dart';

class ProjectRepository {
  ProjectRepository(this._firestore);

  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _projects =>
      _firestore.collection('projects');

  Stream<List<Project>> watchProjects() {
    return _projects.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((document) => Project.fromMap(document.id, document.data()))
            .toList(growable: false));
  }

  Stream<List<Project>> watchOwnedBy(String ownerUid) {
    return _projects
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((document) => Project.fromMap(document.id, document.data()))
            .toList(growable: false));
  }

  Future<void> create(Project project) =>
      _projects.doc(project.id).set(project.toMap());

  Future<void> update(Project project) =>
      _projects.doc(project.id).update(project.toMap());
}
