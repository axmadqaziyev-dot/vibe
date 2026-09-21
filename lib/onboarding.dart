import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'countries.dart';
import 'spoken.dart';
import 'country_picker.dart';
import 'media_store.dart';
import 'telemetry.dart';
import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';

/// Qeydiyyatdan sonra profili tamamlayan üç addımlı ekran.
///
/// Şəkil, cins, yaş və maraqlar olmadan Kəşf lenti və Ani tanışlıq boş
/// görünür — bu ekran həmin boşluğu doldurur. Bir dəfə tamamlanır
/// (`onboardedAt` yazılır) və bir daha göstərilmir.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.uid,
    required this.data,
    this.database,
  });

  final String uid;
  final Map<String, dynamic> data;
  final FirebaseFirestore? database;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

/// Profilin tamamlanmasına ehtiyac varmı?
bool needsOnboarding(Map<String, dynamic> data) {
  if (data['onboardedAt'] != null) return false;
  final gender = '${data['gender'] ?? data['sex'] ?? ''}'.trim();
  final tags = (data['interests'] as List?) ?? (data['tags'] as List?);
  return gender.isEmpty || tags == null || tags.isEmpty;
}

const List<String> _interestOptions = [
  'Musiqi',
  'Səsli söhbət',
  'Oyunlar',
  'Film və serial',
  'İdman',
  'Səyahət',
  'Yemək',
  'Kitab',
  'Rəsm',
  'Texnologiya',
  'Heyvanlar',
  'Rəqs',
  'Fotoqrafiya',
  'Avtomobil',
  'Moda',
  'Yumor',
];

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController pager = PageController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  int step = 0;
  StoredImage? photo;
  String gender = '';
  Country? country;
  int birthYear = DateTime.now().year - 22;
  final Set<String> interests = {};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameController.text = '${widget.data['name'] ?? ''}'.trim();
    cityController.text = '${widget.data['city'] ?? ''}'.trim();

    final age = int.tryParse('${widget.data['age'] ?? ''}');
    if (age != null && age >= 18 && age <= 90) {
      birthYear = DateTime.now().year - age;
    }

    country = countryByCode('${widget.data['countryCode'] ?? ''}');
  }

  @override
  void dispose() {
    pager.dispose();
    nameController.dispose();
    cityController.dispose();
    super.dispose();
  }

  int get age => DateTime.now().year - birthYear;

  String? get blocker {
    switch (step) {
      case 0:
        return nameController.text.trim().length < 2
            ? 'Adını yaz (ən az 2 hərf).'
            : null;
      case 1:
        if (gender.isEmpty) return 'Cinsini seç.';
        if (country == null) return 'Ölkəni seç.';
        if (age < 18) return 'VIBE yalnız 18 yaşdan yuxarı üçündür.';
        return null;
      default:
        return interests.isEmpty ? 'Ən az bir maraq seç.' : null;
    }
  }

  void _next() {
    final problem = blocker;
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    if (step < 2) {
      setState(() => step++);
      pager.animateToPage(
        step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _finish();
  }

  void _back() {
    if (step == 0) return;
    setState(() => step--);
    pager.animateToPage(
      step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickPhoto() async {
    final picked = await pickStoredImage();
    if (picked == null || !mounted) return;
    setState(() => photo = picked);
  }

  Future<void> _finish() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      if (photo != null) {
        await saveProfilePhoto(uid: widget.uid, image: photo!, database: db);
      }

      await db.collection('users').doc(widget.uid).set({
        'uid': widget.uid,
        'name': nameController.text.trim(),
        'city': cityController.text.trim(),
        'gender': gender,
        if (country != null) 'country': country!.name,
        if (country != null) 'countryCode': country!.code,
        // Danışıq dili ölkədən çıxarılır: adam ayrıca seçmir, amma
        // otaqlar və tanışlıq siyahısı ona görə süzülür. Boş nişan
        // heç kimə fayda vermir.
        if (country != null) 'lang': spokenForCountry(country!.code).id,
        'age': age,
        'birthDate': Timestamp.fromDate(DateTime(birthYear, 1, 1)),
        'interests': interests.toList(),
        'tags': interests.toList(),
        'onboardedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'online': true,
      }, SetOptions(merge: true));
      Telemetry.log('onboarding_complete', {
        'interests': interests.length,
        'photo': photo != null ? 1 : 0,
      });
      // AuthGate dəyişikliyi görüb əsas ekrana keçir.
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yadda saxlanmadı: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: PageView(
                  controller: pager,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_stepName(), _stepAbout(), _stepInterests()],
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          if (step > 0)
            IconButton(
              onPressed: saving ? null : _back,
              icon: const Icon(Icons.arrow_back_rounded, color: vInk),
            ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i <= step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == step ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? vPink : vLine,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          if (step > 0) const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _title(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: vInk,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: vMuted, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 22),
        ],
      );

  Widget _field(TextEditingController controller, String hint,
      {TextInputType? type}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: vInk),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: vMuted),
        filled: true,
        fillColor: vPanel,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: vLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: vLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: vPurple, width: 1.4),
        ),
      ),
    );
  }

  Widget _stepName() {
    final preview = photo?.thumb ?? '${widget.data['photoUrl'] ?? ''}';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Səni necə tanısınlar?',
              'Şəkil və ad profilinə ilk baxışda etibar qazandırır.'),
          Center(
            child: PressableScale(
              onTap: _pickPhoto,
              child: Column(
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: vPanel,
                      border: Border.all(color: vPurple, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: preview.isEmpty
                        ? const Icon(Icons.add_a_photo_rounded,
                            color: vMuted, size: 34)
                        : VibePhoto(
                            url: preview,
                            name: nameController.text,
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    preview.isEmpty ? 'Şəkil əlavə et' : 'Şəkli dəyiş',
                    style: const TextStyle(
                      color: vPink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Text('Ad', style: TextStyle(color: vMuted, fontSize: 13)),
          const SizedBox(height: 6),
          _field(nameController, 'Adın'),
          const SizedBox(height: 16),
          const Text('Şəhər', style: TextStyle(color: vMuted, fontSize: 13)),
          const SizedBox(height: 6),
          _field(cityController, 'Bakı'),
        ],
      ),
    );
  }

  Widget _stepAbout() {
    final years = List.generate(73, (i) => DateTime.now().year - 18 - i);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Bir az özün haqqında',
              'Bu məlumatlar sənə uyğun insanları tapmağa kömək edir.'),
          const Text('Cins', style: TextStyle(color: vMuted, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              _genderCard('Qadın', 'qadın', Icons.female_rounded, vPink),
              const SizedBox(width: 12),
              _genderCard('Kişi', 'kişi', Icons.male_rounded, vBlue),
            ],
          ),
          const SizedBox(height: 26),
          const Text('Ölkə', style: TextStyle(color: vMuted, fontSize: 13)),
          const SizedBox(height: 10),
          PressableScale(
            onTap: () async {
              final picked = await pickCountry(
                context,
                selectedCode: country?.code,
              );
              if (picked != null && mounted) {
                setState(() => country = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: vPanel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: country == null ? vLine : vPurple,
                  width: country == null ? 1 : 1.4,
                ),
              ),
              child: Row(
                children: [
                  if (country != null)
                    Text(country!.flag, style: const TextStyle(fontSize: 20))
                  else
                    const Icon(Icons.public_rounded, color: vMuted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      country?.name ?? 'Haralısan?',
                      style: TextStyle(
                        color: country == null ? vMuted : vInk,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: vMuted, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Text('Doğum ili', style: TextStyle(color: vMuted, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: vPanel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: vLine),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_rounded, color: vMuted, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: birthYear,
                      isExpanded: true,
                      dropdownColor: vPanelHigh,
                      iconEnabledColor: vMuted,
                      style: const TextStyle(color: vInk, fontSize: 15),
                      items: years
                          .map((y) => DropdownMenuItem(
                                value: y,
                                child: Text('$y  ·  ${DateTime.now().year - y} yaş'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => birthYear = v ?? birthYear),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'VIBE 18 yaşdan yuxarı istifadəçilər üçündür.',
            style: TextStyle(color: vMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _genderCard(String label, String value, IconData icon, Color color) {
    final selected = gender == value;
    return Expanded(
      child: PressableScale(
        onTap: () => setState(() => gender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .18) : vPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : vLine,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : vMuted, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? vInk : vMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepInterests() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Nə xoşuna gəlir?',
              'Seçdiklərin profilində görünür və oxşar insanları sənə yaxınlaşdırır.'),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: _interestOptions
                .map((option) => VibeChip(
                      label: option,
                      selected: interests.contains(option),
                      onTap: () => setState(() {
                        if (!interests.remove(option)) interests.add(option);
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(
            '${interests.length} seçildi',
            style: const TextStyle(color: vMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientButton(
            label: saving
                ? 'Yadda saxlanır…'
                : (step < 2 ? 'Davam et' : 'VIBE-a başla'),
            height: 54,
            fontSize: 16,
            gradient: vBrand,
            onPressed: saving ? null : _next,
          ),
          if (step == 0) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: saving ? null : () => FirebaseAuth.instance.signOut(),
              child: const Text(
                'Çıxış et',
                style: TextStyle(color: vMuted, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
