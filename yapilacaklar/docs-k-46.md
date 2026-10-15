# iOS-K-46 + K-01: README ve rehberdeki kurulum örneği derlenmiyor

Önem: Düşük. 3.2.0'da duruyor.

## Sorun

v3 örnek README'si ve rehberlerdeki kurulum kodu derlenmiyor: tek parametreli `SDKNetworkOptions(useSslPinning:)` ve `Color(hex:)` public değil. Derlense de `error == nil` kontrolü akışı hiç başlatmıyor, çünkü SDK başarıda da boş bir hata nesnesi gönderiyor.

## 3.2.0'daki yer

`README.md:97`, `:107`. `FULL-INTERGATION.md:76`, `:147`, `:1794`. `docs/guides/theming.md`.

## Yapılacaklar

1. Örneklerdeki `SDKNetworkOptions` çağrısını public init'le değiştir.
2. `Color(hex:)` yerine public bir renk API'si göster.
3. Başarı kontrolünü düzelt: `errorMessages` boşsa ve bağlantı ile oda sonucu tamamsa akış başlasın.
4. Örnekteki SPM kuralı Exact 3.2.0 olsun.

## Bitti sayılması için

- README'deki kurulum kodu boş bir projeye yapıştırılınca derleniyor ve akışı başlatıyor.
