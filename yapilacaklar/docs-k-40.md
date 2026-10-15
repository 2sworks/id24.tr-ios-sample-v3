# iOS-K-40: WebRTC 153 sabitlemesi belgede yazmıyor

Önem: Düşük. 3.2.0'da duruyor.

## Sorun

3.1.1'den beri WebRTC tam 153.0.0'a sabit. README bunu yazmıyor. WebRTC'nin başka bir sürümünü kullanan uygulama paketi çözemiyor.

## 3.2.0'daki yer

Dağıtım deposundaki `README.md` esnek aralık öneriyor, kısıt yazmıyor.

## Yapılacaklar

1. README'ye "WebRTC 153.0.0 tam sürüm gerekiyor" notunu ekle.
2. Kurulum örneğinde SDK için Exact kuralı göster.

## Bitti sayılması için

- README WebRTC kısıtını ve önerilen SPM kuralını gösteriyor.
