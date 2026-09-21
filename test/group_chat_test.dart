import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/group_chat.dart';

void main() {
  const team = GroupInfo(
    id: 'g1',
    name: 'Dostlar',
    ownerUid: 'sahib',
    members: ['sahib', 'admin', 'uzv', 'susdurulmus'],
    admins: ['admin'],
    muted: ['susdurulmus'],
  );

  group('rollar', () {
    test('hər kəs öz rolunu alır', () {
      expect(team.roleOf('sahib'), GroupRole.owner);
      expect(team.roleOf('admin'), GroupRole.admin);
      expect(team.roleOf('uzv'), GroupRole.member);
      expect(team.roleOf('kenar'), GroupRole.outsider);
    });

    test('sahib və admin idarəçidir', () {
      expect(team.isManager('sahib'), isTrue);
      expect(team.isManager('admin'), isTrue);
      expect(team.isManager('uzv'), isFalse);
    });
  });

  group('yazmaq', () {
    test('adi üzv yaza bilir', () {
      expect(team.canWrite('uzv'), isTrue);
      expect(team.writeBlockReason('uzv'), isNull);
    });

    test('susdurulmuş üzv yaza bilmir', () {
      expect(team.canWrite('susdurulmus'), isFalse);
      expect(team.writeBlockReason('susdurulmus'), contains('dayandırılıb'));
    });

    test('kənar adam yaza bilmir', () {
      expect(team.canWrite('kenar'), isFalse);
    });

    test('elan rejimində yalnız adminlər yazır', () {
      const announce = GroupInfo(
        id: 'g2',
        name: 'Elan',
        ownerUid: 'sahib',
        members: ['sahib', 'admin', 'uzv'],
        admins: ['admin'],
        onlyAdminsWrite: true,
      );

      expect(announce.canWrite('sahib'), isTrue);
      expect(announce.canWrite('admin'), isTrue);
      expect(announce.canWrite('uzv'), isFalse);
      expect(announce.writeBlockReason('uzv'), contains('adminlər'));
    });
  });

  group('çıxarmaq', () {
    test('admin adi üzvü çıxara bilir', () {
      expect(team.canRemove('admin', 'uzv'), isTrue);
    });

    test('adi üzv heç kimi çıxara bilmir', () {
      expect(team.canRemove('uzv', 'admin'), isFalse);
      expect(team.canRemove('uzv', 'susdurulmus'), isFalse);
    });

    test('sahibi heç kim çıxara bilmir', () {
      // Onsuz qrupu oğurlamaq olardı.
      expect(team.canRemove('admin', 'sahib'), isFalse);
      expect(team.canRemove('sahib', 'sahib'), isFalse);
    });

    test('admini yalnız sahib çıxarır', () {
      // Əks halda adminlər bir-birini təmizləyərdi.
      const two = GroupInfo(
        id: 'g3',
        name: 'İki admin',
        ownerUid: 'sahib',
        members: ['sahib', 'a1', 'a2'],
        admins: ['a1', 'a2'],
      );

      expect(two.canRemove('a1', 'a2'), isFalse);
      expect(two.canRemove('sahib', 'a2'), isTrue);
    });

    test('özünü çıxarmaq olmaz — bunun üçün "çıx" var', () {
      expect(team.canRemove('admin', 'admin'), isFalse);
    });
  });

  group('admin təyini', () {
    test('yalnız sahib təyin edir', () {
      expect(team.canPromote('sahib', 'uzv'), isTrue);
      expect(team.canPromote('admin', 'uzv'), isFalse);
    });

    test('qrupda olmayan adam admin olmur', () {
      expect(team.canPromote('sahib', 'kenar'), isFalse);
    });
  });

  group('çıxmaq', () {
    test('üzv çıxa bilir', () {
      expect(team.canLeave('uzv'), isTrue);
    });

    test('sahib çıxa bilmir', () {
      expect(team.canLeave('sahib'), isFalse);
    });

    test('kənar adam çıxa bilmir', () {
      expect(team.canLeave('kenar'), isFalse);
    });
  });

  group('sənəddən oxumaq', () {
    test('boş sənəd tətbiqi qırmır', () {
      final empty = GroupInfo.from('x', const {});

      expect(empty.name, 'Qrup');
      expect(empty.members, isEmpty);
      expect(empty.roleOf('a'), GroupRole.outsider);
    });

    test('siyahılar mətnə çevrilir', () {
      final parsed = GroupInfo.from('x', {
        'name': 'Test',
        'ownerUid': 'o',
        'members': ['o', 'b'],
        'admins': ['b'],
      });

      expect(parsed.members, ['o', 'b']);
      expect(parsed.roleOf('b'), GroupRole.admin);
    });
  });

  group('ad', () {
    test('boş ad əvəzlənir', () {
      expect(cleanGroupName('   '), 'Yeni qrup');
    });

    test('uzun ad kəsilir', () {
      expect(cleanGroupName('a' * 80).length, 40);
    });

    test('adi ad toxunulmaz qalır', () {
      expect(cleanGroupName(' Dostlar '), 'Dostlar');
    });
  });
}
