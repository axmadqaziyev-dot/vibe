import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/comment_thread.dart';

ThreadComment c(
  String id, {
  String parent = '',
  int minute = 0,
  String name = 'Ad',
}) =>
    ThreadComment(
      id: id,
      uid: 'u_$id',
      name: name,
      text: 'mətn $id',
      parentId: parent,
      createdAt: DateTime(2026, 1, 1, 12, minute),
    );

void main() {
  test('valideynsiz şərhlər kökdür', () {
    final nodes = buildThread([c('a'), c('b', minute: 1)]);

    expect(nodes.length, 2);
    expect(nodes.first.comment.id, 'a');
    expect(nodes.first.replies, isEmpty);
  });

  test('cavab öz kökünün altına düşür', () {
    final nodes = buildThread([
      c('a'),
      c('r1', parent: 'a', minute: 2),
      c('b', minute: 1),
    ]);

    expect(nodes.map((n) => n.comment.id), ['a', 'b']);
    expect(nodes.first.replies.map((r) => r.id), ['r1']);
  });

  test('köklər köhnədən yeniyə düzülür', () {
    final nodes = buildThread([
      c('yeni', minute: 9),
      c('kohne', minute: 1),
    ]);

    expect(nodes.map((n) => n.comment.id), ['kohne', 'yeni']);
  });

  test('cavablar da köhnədən yeniyə düzülür', () {
    final nodes = buildThread([
      c('a'),
      c('r2', parent: 'a', minute: 5),
      c('r1', parent: 'a', minute: 2),
    ]);

    expect(nodes.first.replies.map((r) => r.id), ['r1', 'r2']);
  });

  test('valideyni silinən cavab itmir, kökə qalxır', () {
    // Bir şərhi silməklə bütün budaq gözdən yox olmamalıdır.
    final nodes = buildThread([
      c('r1', parent: 'silinmis', minute: 2),
      c('b', minute: 1),
    ]);

    expect(nodes.map((n) => n.comment.id), ['b', 'r1']);
  });

  test('cavabın cavabı yeni pillə açmır', () {
    final reply = c('r1', parent: 'a');
    expect(rootIdFor(reply), 'a');

    final root = c('a');
    expect(rootIdFor(root), 'a');
  });

  test('ümumi say cavabları da sayır', () {
    final nodes = buildThread([
      c('a'),
      c('r1', parent: 'a', minute: 1),
      c('b', minute: 2),
    ]);

    expect(countComments(nodes), 3);
  });

  test('boş siyahı boş nəticə verir', () {
    expect(buildThread(const []), isEmpty);
    expect(countComments(const []), 0);
  });

  test('sənəddən oxumaq sahəsi olmayanda da işləyir', () {
    final comment = ThreadComment.from('x', const {});

    expect(comment.id, 'x');
    expect(comment.text, '');
    expect(comment.likeCount, 0);
    expect(comment.parentId, '');
  });
}
