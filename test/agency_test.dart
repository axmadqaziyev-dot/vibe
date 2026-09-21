import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/agency.dart';

void main() {
  const team = Agency(
    id: 'a1',
    name: 'WANNESA',
    ownerUid: 'sahib',
    hosts: ['sahib', 'yayimci'],
    code: 'ABC234',
  );

  group('pay', () {
    test('faiz düzgün hesablanır', () {
      expect(agencyCut(1000), 100);
      expect(agencyCut(55), 5);
    });

    test('mənfi və sıfır sıfır verir', () {
      expect(agencyCut(0), 0);
      expect(agencyCut(-100), 0);
    });

    test('pay tam ədəddir — kəsr sikkə yoxdur', () {
      expect(agencyCut(9), 0);
      expect(agencyCut(19), 1);
    });
  });

  group('kod', () {
    test('altı simvoldur', () {
      expect(newAgencyCode(random: Random(1)).length, 6);
    });

    test('səhv oxunan simvollar yoxdur', () {
      // 0/O və 1/I qarışdırılır; kod ağızdan-ağıza paylaşılır.
      for (var i = 0; i < 200; i++) {
        final code = newAgencyCode(random: Random(i));
        expect(code.contains('0'), isFalse);
        expect(code.contains('O'), isFalse);
        expect(code.contains('1'), isFalse);
        expect(code.contains('I'), isFalse);
      }
    });

    test('yazılan kod təmizlənir', () {
      expect(cleanAgencyCode(' abc-234 '), 'ABC234');
      expect(cleanAgencyCode('a b c 2 3 4'), 'ABC234');
    });

    test('uzunluq yoxlanılır', () {
      expect(isValidAgencyCode('abc234'), isTrue);
      expect(isValidAgencyCode('abc23'), isFalse);
      expect(isValidAgencyCode(''), isFalse);
    });
  });

  group('rollar', () {
    test('sahib və yayımçı ayrılır', () {
      expect(team.roleOf('sahib'), AgencyRole.owner);
      expect(team.roleOf('yayimci'), AgencyRole.host);
      expect(team.roleOf('kenar'), AgencyRole.outsider);
      expect(team.roleOf(''), AgencyRole.outsider);
    });

    test('yalnız sahib idarə edir', () {
      expect(team.canManage('sahib'), isTrue);
      expect(team.canManage('yayimci'), isFalse);
    });

    test('sahib özünü çıxara bilmir', () {
      expect(team.canRemove('sahib', 'sahib'), isFalse);
      expect(team.canRemove('sahib', 'yayimci'), isTrue);
      expect(team.canRemove('yayimci', 'sahib'), isFalse);
    });

    test('sahib agentlikdən çıxa bilmir', () {
      expect(team.canLeave('sahib'), isFalse);
      expect(team.canLeave('yayimci'), isTrue);
      expect(team.canLeave('kenar'), isFalse);
    });
  });

  group('sənəddən oxumaq', () {
    test('boş sənəd tətbiqi qırmır', () {
      final empty = Agency.from('x', const {});

      expect(empty.name, 'Agentlik');
      expect(empty.hosts, isEmpty);
      expect(empty.earned, 0);
    });

    test('dolu agentlik tanınır', () {
      final full = Agency(
        id: 'x',
        name: 'Dolu',
        hosts: List.generate(maxAgencyHosts, (i) => 'u$i'),
      );

      expect(full.isFull, isTrue);
      expect(team.isFull, isFalse);
    });
  });

  group('ad', () {
    test('boş ad əvəzlənir', () {
      expect(cleanAgencyName('  '), 'Yeni agentlik');
    });

    test('uzun ad kəsilir', () {
      expect(cleanAgencyName('a' * 60).length, 30);
    });
  });
}
