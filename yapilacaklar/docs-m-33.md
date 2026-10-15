# iOS-M-33: Flutter ve RN köprü iskeleti KYC ekranını açmıyor

Önem: Düşük. 3.2.0'da duruyor.

## Sorun

Örnek depodaki Flutter ve React Native köprü iskeleti olduğu gibi kullanılırsa kurulum "başarılı" dönüyor ama KYC ekranı açılmıyor. Flutter README'sindeki tema örneği derlenmiyor.

## 3.2.0'daki yer

`docs/integration/flutter/IdentifySdkPlugin.swift:93-124`, `docs/integration/flutter/README.md:47`, `:134`, `docs/integration/react-native/IdentifySdkModule.swift:78-123`.

## Yapılacaklar

1. İskeletlere `prepareForSetup`, ekran sunumu, `coordinator.start()` ve sonuç olayını ekle.
2. Flutter README'sindeki `IdentifySdk.instance.setTheme` örneğini Dart sarmalayıcısıyla uyumlu hale getir.
3. README'deki parametre tablosunu kodla eşitle.

## Bitti sayılması için

- Flutter ve RN iskeletiyle kurulan boş projede KYC ekranı açılıyor.
