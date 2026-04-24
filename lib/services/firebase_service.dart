import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final DatabaseReference rootRef = FirebaseDatabase.instance.ref().child('users');

  /// Returns snapshot and userType when found, or null if not found.
  Future<Map<String, dynamic>?> findUser(String mobile) async {
    final nodes = ['doctor', 'admin', 'patient'];
    for (final node in nodes) {
      final snap = await rootRef.child('$node/$mobile').get();
      if (snap.exists) {
        return {
          'node': node,
          'snapshot': snap,
        };
      }
    }
    return null;
  }

  /// Checks credentials. Throws exceptions with readable messages for UI.
  Future<Map<String, dynamic>> login(String mobile, String password) async {
    final found = await findUser(mobile);
    if (found == null) {
      throw Exception('User not found');
    }

    final DataSnapshot snap = found['snapshot'] as DataSnapshot;
    final node = found['node'] as String;

    final dbPassword = snap.child('password').value?.toString();
    final verified = snap.child('verified').value;
    final isVerified = verified == true || verified == 'true';

    if (dbPassword == null || dbPassword != password) {
      throw Exception('Incorrect password');
    }
    if (!isVerified) {
      throw Exception('Account not verified');
    }

    // Build a simple user map
    final user = <String, String?>{
      'name': snap.child('name').value?.toString(),
      'age': snap.child('age').value?.toString(),
      'email': snap.child('email').value?.toString(),
      'address': snap.child('address').value?.toString(),
      'gender': snap.child('gender').value?.toString(),
      'imageBase64': snap.child('imageBase64').value?.toString(),
      'disease': snap.child('disease').value?.toString(),
      'specialization': snap.child('specialization').value?.toString(),
      'clinicName': snap.child('clinicName').value?.toString(),
      'type': node,
      'count': snap.child('count').value?.toString(),
    };

    return {
      'node': node,
      'user': user,
    };
  }

  /// Attempts to reset password in doctor then patient node
  Future<void> resetPassword(String mobile, String email, String newPassword) async {
    final nodes = ['doctor', 'patient'];
    for (final node in nodes) {
      final snap = await rootRef.child('$node/$mobile').get();
      if (!snap.exists) continue;
      final dbEmail = snap.child('email').value?.toString();
      if (dbEmail == null || dbEmail.toLowerCase() != email.toLowerCase()) {
        throw Exception('Email does not match');
      }
      await rootRef.child('$node/$mobile/password').set(newPassword);
      return;
    }
    throw Exception('No matching user found');
  }
}
