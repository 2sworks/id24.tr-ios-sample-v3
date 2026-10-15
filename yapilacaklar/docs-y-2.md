# iOS-Y-2: Selfie rehberindeki kısa örnek hata mesajını temizlemiyor

Önem: Orta. 3.2.0'da duruyor.

## Sorun

Selfie rehberindeki kısa özel ekran örneği hata mesajını göstermiyor ve temizlemiyor. Bu örnekle yazılan ekran ilk "tekrar deneyin"den sonra otomatik çekimi durduruyor, hak bitince de sonraki adıma geçmiyor.

## 3.2.0'daki yer

`Selfie.md:55-83`. Tam örnek (`SelfieCustomView.swift:92`) mesajı doğru temizliyor.

## Yapılacaklar

1. Kısa örneğe hata mesajının gösterilmesini ve `consumePendingAlertAction()` ile temizlenmesini ekle.
2. Diğer modül rehberlerinin kısa örneklerini aynı açıdan gözden geçir.

## Bitti sayılması için

- Kısa örnekle yazılan ekran, yüz karşılaştırması tutmayınca yeniden çekim yapıyor ve hak bitince sonraki adıma geçiyor.
