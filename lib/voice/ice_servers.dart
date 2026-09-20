/// WebRTC bağlantısı üçün server siyahısı.
///
/// **STUN** cihaza öz xarici ünvanını tapmağa kömək edir. Çox vaxt bu kifayətdir.
///
/// **TURN** isə hər iki tərəf "sərt" NAT arxasında olanda (mobil operatorlar,
/// iş yerləri, bəzi Wi-Fi şəbəkələri) səsi öz üzərindən ötürür. TURN olmadan
/// zəng "qoşulur" yazıb ilişib qalır — mobil internetdə bu, ən çox rast gəlinən
/// problemdir.
///
/// DİQQƏT: hazırda TURN serveri qoşulmayıb. Open Relay-in bir vaxtlar açıq
/// olan açarları artıq işləmir (yoxlanılıb — `relay` namizədi gəlmir).
/// Pulsuz variant: metered.ca-da hesab aç (kart tələb etmir, ayda 20 GB
/// pulsuz), TURN ünvanı və açarları al, aşağıdakı `--dart-define`
/// dəyərlərinə yaz. Öz serverini qurmaq istəsən — `coturn`.
///
/// Öz serverin varsa, build zamanı verə bilərsən:
/// `flutter build apk --dart-define=TURN_URL=turn:... --dart-define=TURN_USERNAME=... --dart-define=TURN_CREDENTIAL=...`
library;

const _customTurnUrl = String.fromEnvironment('TURN_URL');
const _customTurnUser = String.fromEnvironment('TURN_USERNAME');
const _customTurnPass = String.fromEnvironment('TURN_CREDENTIAL');

/// Bütün WebRTC bağlantıları üçün ortaq konfiqurasiya.
Map<String, dynamic> get vibeIceConfig => {
      'iceServers': [
        {
          'urls': [
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302',
          ],
        },

        // Öz TURN serverin varsa yalnız o işlənir.
        if (_customTurnUrl.isNotEmpty)
          {
            'urls': _customTurnUrl,
            'username': _customTurnUser,
            'credential': _customTurnPass,
          }
        // TURN açarı verilməyibsə yalnız STUN qalır: zəng açıq şəbəkələrdə
        // (ev Wi-Fi) işləyir, sərt NAT arxasında (mobil operator) qoşulmur.
        // Pulsuz TURN üçün metered.ca-da hesab açıb açarları buraya ver.
      ],

      // Bağlantı qurulmasa, ötürücü server üzərindən yenidən cəhd olunur.
      'iceCandidatePoolSize': 2,
      'sdpSemantics': 'unified-plan',
    };
