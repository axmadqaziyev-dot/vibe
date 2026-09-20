import 'dart:js_interop';

/// Brauzerdə `index.html` içindəki köməkçilərə bağlanır.
@JS('vibeCanInstall')
external JSBoolean _canInstall();

@JS('vibeInstall')
external void _install();

@JS('vibeIsIos')
external JSBoolean _isIos();

@JS('vibeIsStandalone')
external JSBoolean _isStandalone();

bool canInstallApp() {
  try {
    return _canInstall().toDart;
  } catch (_) {
    return false;
  }
}

bool isRunningStandalone() {
  try {
    return _isStandalone().toDart;
  } catch (_) {
    return false;
  }
}

bool isIosBrowser() {
  try {
    return _isIos().toDart;
  } catch (_) {
    return false;
  }
}

void promptInstallApp() {
  try {
    _install();
  } catch (_) {}
}

@JS('vibeHideSplash')
external void _hideSplash();

/// Flutter ilk kadrı çəkəndən sonra HTML açılış ekranını söndürür.
void hideStartupSplash() {
  try {
    _hideSplash();
  } catch (_) {}
}

@JS('vibeIsUpdateReady')
external JSBoolean _updateReady();

@JS('vibeReload')
external void _reload();

/// Serverdə yeni versiya varmı?
bool isUpdateReady() {
  try {
    return _updateReady().toDart;
  } catch (_) {
    return false;
  }
}

/// Səhifəni yenidən yükləyib yeni versiyanı açır.
void reloadApp() {
  try {
    _reload();
  } catch (_) {}
}
