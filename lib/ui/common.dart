import 'package:flutter/material.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../app/session.dart';
import '../domain/models.dart';

void notice(BuildContext context, String key) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Strings.of(context).t(key))));
}
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.profile, {super.key, this.radius = 28});
  final Profile profile;
  final double radius;
  @override Widget build(BuildContext context) {
    const colors = [Color(0xFFE1DAFF), Color(0xFFFFE1D5), Color(0xFFD8ECEA), Color(0xFFF4DDEE), Color(0xFFFFEECD), Color(0xFFDCE5FF)];
    return CircleAvatar(radius: radius, backgroundColor: colors[profile.avatar % colors.length],
      child: Text(profile.name.isEmpty ? '?' : profile.name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: radius * .8, fontWeight: FontWeight.w800, color: ink)));
  }
}
class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color = Colors.white});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  @override Widget build(BuildContext context) => Container(padding: padding,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFECE9F2))), child: child);
}
class AsyncPanel<T> extends StatelessWidget {
  const AsyncPanel({super.key, required this.future, required this.builder, required this.retry});
  final Future<T> future;
  final Widget Function(T) builder;
  final VoidCallback retry;
  @override Widget build(BuildContext context) => FutureBuilder<T>(future: future, builder: (context, snapshot) {
    if (snapshot.hasError) return EmptyPanel(icon: Icons.cloud_off_rounded, text: Strings.of(context).t('error'),
      action: TextButton(onPressed: retry, child: Text(Strings.of(context).t('retry'))));
    if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
    return builder(snapshot.data as T);
  });
}
class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(32),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 48, color: violet), const SizedBox(height: 16),
      Text(text, textAlign: TextAlign.center), if (action != null) action!,
    ])));
}
class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(Strings.of(context).t(title), style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8), Text(Strings.of(context).t(subtitle), style: const TextStyle(color: Colors.black54)),
    ]));
}
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override Widget build(BuildContext context) => DropdownButtonHideUnderline(child: DropdownButton<String>(
    value: value, icon: const Icon(Icons.language, size: 20),
    items: const [DropdownMenuItem(value: 'en', child: Text('English  ')),
      DropdownMenuItem(value: 'az', child: Text('Azərbaycan  ')), DropdownMenuItem(value: 'tr', child: Text('Türkçe  '))],
    onChanged: (v) { if (v != null) onChanged(v); }));
}
void showRules(BuildContext context) {
  final s = Strings.of(context);
  showDialog<void>(context: context, builder: (context) => AlertDialog(
    title: Text(s.t('rules')), content: SingleChildScrollView(child: Text(s.t('rulesBody'))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
}
Future<bool> confirm(BuildContext context, String title, String body) async {
  final s = Strings.of(context);
  return await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: Text(s.t(title)), content: Text(s.t(body)), actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t(title))),
    ])) ?? false;
}
Future<void> reportPerson(BuildContext context, String id) async {
  final session = Session.of(context);
  final s = Strings.of(context);
  final reason = await showDialog<String>(context: context, builder: (context) => SimpleDialog(
    title: Text(s.t('report')), children: ['Harassment','Spam','Inappropriate content','Underage','Other'].map((r) =>
      SimpleDialogOption(onPressed: () => Navigator.pop(context, r), child: Text(s.t(r)))).toList()));
  if (reason == null) return;
  try {
    await session.repository.report(id, reason);
    if (context.mounted) notice(context, session.repository.isPreview ? 'previewReport' : 'reportSent');
  } catch (_) { if (context.mounted) notice(context, 'error'); }
}

