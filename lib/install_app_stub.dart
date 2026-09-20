/// Mobil/masaüstü hədəflərdə quraşdırma təklifi mənasızdır —
/// tətbiq onsuz da quraşdırılıb.
bool canInstallApp() => false;

bool isRunningStandalone() => true;

bool isIosBrowser() => false;

void promptInstallApp() {}

/// Mobil platformalarda açılış ekranı sistem tərəfindən idarə olunur.
void hideStartupSplash() {}

/// Mağaza tətbiqində yeniləmə mağaza tərəfindən gəlir.
bool isUpdateReady() => false;

void reloadApp() {}
