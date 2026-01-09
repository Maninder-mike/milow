import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/core/providers/permission_provider.dart';

void main() {
  group('UserPermissions', () {
    group('empty()', () {
      test('returns permissions with no access', () {
        final perms = UserPermissions.empty();

        expect(perms.isAdmin, isFalse);
        expect(perms.has('vehicles.read'), isFalse);
        expect(perms.canRead('vehicles'), isFalse);
        expect(perms.canWrite('vehicles'), isFalse);
        expect(perms.canDelete('vehicles'), isFalse);
      });

      test('all returns empty set', () {
        final perms = UserPermissions.empty();
        expect(perms.all, isEmpty);
      });
    });

    group('admin()', () {
      test('returns permissions with full access', () {
        final perms = UserPermissions.admin();

        expect(perms.isAdmin, isTrue);
        expect(perms.has('vehicles.read'), isTrue);
        expect(perms.has('any.permission'), isTrue);
        expect(perms.canRead('vehicles'), isTrue);
        expect(perms.canWrite('trips'), isTrue);
        expect(perms.canDelete('users'), isTrue);
        expect(perms.canManage('drivers'), isTrue);
      });

      test('all returns wildcard set', () {
        final perms = UserPermissions.admin();
        expect(perms.all, equals({'*'}));
      });
    });

    group('fromJson()', () {
      test('deserializes permissions correctly', () {
        final json = {
          'permissions': ['vehicles.read', 'trips.write', 'users.delete'],
          'isAdmin': false,
        };

        final perms = UserPermissions.fromJson(json);

        expect(perms.isAdmin, isFalse);
        expect(perms.has('vehicles.read'), isTrue);
        expect(perms.has('trips.write'), isTrue);
        expect(perms.has('users.delete'), isTrue);
        expect(perms.has('other.permission'), isFalse);
      });

      test('deserializes admin correctly', () {
        final json = {'permissions': [], 'isAdmin': true};

        final perms = UserPermissions.fromJson(json);
        expect(perms.isAdmin, isTrue);
      });

      test('handles null permissions list', () {
        final json = <String, dynamic>{'isAdmin': false};

        final perms = UserPermissions.fromJson(json);
        expect(perms.all, isEmpty);
      });
    });

    group('toJson()', () {
      test('serializes permissions correctly', () {
        final perms = UserPermissions.fromJson({
          'permissions': ['vehicles.read', 'trips.write'],
          'isAdmin': false,
        });

        final json = perms.toJson();

        expect(json['isAdmin'], isFalse);
        expect(
          json['permissions'],
          containsAll(['vehicles.read', 'trips.write']),
        );
      });

      test('serializes admin correctly', () {
        final perms = UserPermissions.admin();
        final json = perms.toJson();

        expect(json['isAdmin'], isTrue);
      });
    });

    group('permission checks', () {
      late UserPermissions perms;

      setUp(() {
        perms = UserPermissions.fromJson({
          'permissions': [
            'vehicles.read',
            'vehicles.write',
            'trips.read',
            'users.read',
            'users.delete',
          ],
          'isAdmin': false,
        });
      });

      test('has() returns true for existing permissions', () {
        expect(perms.has('vehicles.read'), isTrue);
        expect(perms.has('vehicles.write'), isTrue);
        expect(perms.has('trips.read'), isTrue);
      });

      test('has() returns false for missing permissions', () {
        expect(perms.has('vehicles.delete'), isFalse);
        expect(perms.has('trips.write'), isFalse);
        expect(perms.has('nonexistent.permission'), isFalse);
      });

      test('canRead() checks resource.read permission', () {
        expect(perms.canRead('vehicles'), isTrue);
        expect(perms.canRead('trips'), isTrue);
        expect(perms.canRead('drivers'), isFalse);
      });

      test('canWrite() checks resource.write permission', () {
        expect(perms.canWrite('vehicles'), isTrue);
        expect(perms.canWrite('trips'), isFalse);
      });

      test('canDelete() checks resource.delete permission', () {
        expect(perms.canDelete('users'), isTrue);
        expect(perms.canDelete('vehicles'), isFalse);
      });

      test('canManage() requires both read and write', () {
        expect(perms.canManage('vehicles'), isTrue); // has both
        expect(perms.canManage('trips'), isFalse); // only read
        expect(perms.canManage('users'), isFalse); // read + delete, no write
      });
    });

    group('toString()', () {
      test('returns admin string for admin permissions', () {
        final perms = UserPermissions.admin();
        expect(perms.toString(), equals('UserPermissions(admin)'));
      });

      test('returns permissions set for regular permissions', () {
        final perms = UserPermissions.fromJson({
          'permissions': ['test.read'],
          'isAdmin': false,
        });
        expect(perms.toString(), contains('UserPermissions'));
        expect(perms.toString(), contains('test.read'));
      });
    });
  });
}
