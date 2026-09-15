const fs=require('fs'); const p='lib/social_ui.dart';let s=fs.readFileSync(p,'utf8');
s=s.replace('const SocialHome({super.key, required this.profile});','const SocialHome({super.key, required this.profile, this.database});\n  final FirebaseFirestore? database;');
s=s.replace('late final stream = FirebaseFirestore.instance\n', 'late final stream = (widget.database ?? FirebaseFirestore.instance)\n');
s=s.replace('const SocialMessages({super.key, required this.profile, required this.navigate});','const SocialMessages({super.key, required this.profile, required this.navigate, this.database});\n  final FirebaseFirestore? database;');
// formatted constructors can span lines
s=s.replace('class SocialMessages extends StatefulWidget {\n', 'class SocialMessages extends StatefulWidget {\n');
let a=s.indexOf('class SocialMessages');let b=s.indexOf('class _SocialMessagesState',a);let part=s.slice(a,b);if(!part.includes('final FirebaseFirestore? database;')){part=part.replace('    super.key,','    super.key,\n    this.database,').replace('  final UserProfile profile;', '  final FirebaseFirestore? database;\n  final UserProfile profile;');s=s.slice(0,a)+part+s.slice(b);}
s=s.replace('late final users = FirebaseFirestore.instance', 'late final users = (widget.database ?? FirebaseFirestore.instance)');s=s.replace('late final chats = FirebaseFirestore.instance','late final chats = (widget.database ?? FirebaseFirestore.instance)');
a=s.indexOf('class SocialProfile');b=s.indexOf('class EditSocialProfile',a);part=s.slice(a,b).replace('    super.key,','    super.key,\n    this.database,').replace('  final UserProfile profile;', '  final FirebaseFirestore? database;\n  final UserProfile profile;').replace('stream: FirebaseFirestore.instance','stream: (database ?? FirebaseFirestore.instance)');s=s.slice(0,a)+part+s.slice(b);
fs.writeFileSync(p,s);
