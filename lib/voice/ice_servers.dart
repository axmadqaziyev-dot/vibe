/// WebRTC bağlantısı üçün server siyahısı.
///
/// **STUN** cihaza öz xarici ünvanını tapmağa kömək edir. Açıq şəbəkələrdə
/// (ev Wi-Fi) çox vaxt bu kifayətdir.
///
/// **TURN** isə hər iki tərəf "sərt" NAT arxasında olanda (mobil operatorlar,
/// iş yerləri, bəzi Wi-Fi şəbəkələri) səsi öz üzərindən ötürür. TURN olmadan
/// zəng "qoşulur" yazıb ilişib qalır — mobil internetdə ən çox rast gəlinən
/// problem budur.
///
/// Bir neçə ünvan veririk, çünki şəbəkələr fərqli qapıları bağlayır:
///   * 80 UDP   — ən sürətlisi, adətən işləyir
///   * 80 TCP   — UDP bağlıdırsa
///   * 443 TCP  — korporativ şəbəkələrdə çox vaxt yeganə açıq qapı
///   * 443 TLS  — dərin yoxlama aparan şəbəkələrdə (HTTPS kimi görünür)
///
/// Cihaz onları paralel sınayır və ilk işləyəni seçir.
///
/// Öz serverini qurmaq istəsən (`coturn`), build zamanı ver:
/// `flutter build apk --dart-define=TURN_URL=turn:... --dart-define=TURN_USERNAME=... --dart-define=TURN_CREDENTIAL=...`
library;

/// Hesab dəyişəndə yalnız bu iki sətir yenilənir (metered.ca → TURN Server).
///
/// Bu açarlar gizli deyil: TURN açarları tətbiqin içində hər istifadəçinin
/// cihazına düşür, onları gizli saxlamaq texniki olaraq mümkün deyil.
/// Qorunma aylıq həddin özündədir — hədd dolanda server dayanır.
const _defaultTurnUser = '64e322513c2d6658feb17413';
const _defaultTurnPass = 'SRvj9xIaiyfqimdF';

const _turnUser = String.fromEnvironment(
  'TURN_USERNAME',
  defaultValue: _defaultTurnUser,
);

const _turnPass = String.fromEnvironment(
  'TURN_CREDENTIAL',
  defaultValue: _defaultTurnPass,
);

/// Öz serverin varsa bu ünvan verilir — o zaman yalnız o işlənir.
const _customTurnUrl = String.fromEnvironment('TURN_URL');

/// Metered-in ötürücü ünvanları.
const _meteredUrls = [
  'turn:global.relay.metered.ca:80',
  'turn:global.relay.metered.ca:80?transport=tcp',
  'turn:global.relay.metered.ca:443',
  'turns:global.relay.metered.ca:443?transport=tcp',
];

/// Bütün WebRTC bağlantıları üçün ortaq konfiqurasiya.
Map<String, dynamic> get vibeIceConfig => {
      'iceServers': [
        {
          'urls': [
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302',
            'stun:stun.relay.metered.ca:80',
          ],
        },

        if (_customTurnUrl.isNotEmpty)
          {
            'urls': _customTurnUrl,
            'username': _turnUser,
            'credential': _turnPass,
          }
        else if (_turnUser.isNotEmpty && _turnPass.isNotEmpty)
          {
            'urls': _meteredUrls,
            'username': _turnUser,
            'credential': _turnPass,
          },
      ],

      // Bağlantı qurulmasa, ötürücü server üzərindən yenidən cəhd olunur.
      'iceCandidatePoolSize': 2,
      'sdpSemantics': 'unified-plan',
    };

/// TURN qoşulubmu? Diaqnostika üçün.
bool get hasTurnServer =>
    _customTurnUrl.isNotEmpty || (_turnUser.isNotEmpty && _turnPass.isNotEmpty);
