# YipYip

**Kopyaladığın her şeyi hatırlar. Sen unutursun, o unutmaz.**

![Lisans](https://img.shields.io/badge/Lisans-MIT-blue) ![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey) ![Fiyat](https://img.shields.io/badge/Fiyat-bedava-brightgreen) ![Reklam](https://img.shields.io/badge/Reklam-yok-ff69b4)

<!-- Ekran görüntüsü: ./Scripts/capture-screenshot.sh -->

---

## Şöyle bir şey yaşadın mı?

Bir link kopyaladın. Sonra "dur bir şuna bakayım" dedin, başka bir şey kopyaladın.
Sonra o ilk link... gitti. Yok. Buhar oldu. Nereye gitti? Kimse bilmiyor.
Pano dediğin şey, kafasında tek bir düşünce tutabilen bir arkadaş gibidir.

**YipYip o arkadaşın hafıza kartı takılmış hâli.**

Kopyaladığın her şeyi kenara not eder, sen isteyince önüne serer, "hangisiydi?"
diye düşünmene bile gerek kalmadan aratır. Üstelik hepsini kendi bilgisayarında
tutar — dedikoducu değildir, kimseye anlatmaz.

---

## Nasıl kullanılır? (üç adım, bitti)

**1.** Bir şey kopyala. Ne olursa. Link, şifre değil ama, metin, fotoğraf, dosya, video.

**2.** Sonra bir ara `⌘⌥V` bas. (Yani Command + Option + V. Aynı anda. Evet, üç parmak. Yaparsın.)

**3.** Arama kutusuna aklında kalan neyse onu yaz, Enter'a bas. Kopyaladığın şey,
imlecin nerede duruyorsa oraya iner. Sen hiçbir şey yapmazsın. O halleder.

Aklında sadece "yatırım" kelimesi mi kaldı? Yaz gitsin. Türkçe karakter derdi de yok:
**"insallah" yazarsan "inşallah"ı bulur.** Klavye ayarı, şapka, nokta derdi yok.
"gunes" yaz, "güneş"i getirir. "istanbul" yaz, "İSTANBUL"u getirir. Anlaşıyoruz yani.

---

## Kurulum

Korkma, üç satır. Terminal'i aç (Spotlight'a "Terminal" yaz, Enter) ve şunları
sırayla yapıştır:

```bash
git clone https://github.com/atakansavas/YipYip.git
cd YipYip
./Scripts/build-app.sh
```

Bir şeyler akmaya başlayacak. Panik yok, o normal. Bilgisayar çalışıyor,
"acaba bir şey mi bozdum" diye düşünme.

İşi bitince:

```bash
open /Applications/YipYip.app
```

Menü çubuğunun sağ üst köşesinde küçük bir pano ikonu belirecek. **Tebrikler,
artık hafızan var.**

> Not: Bunun için Mac'inde geliştirici araçları lazım. Yoksa terminal sana zaten
> "yükleyeyim mi?" diye soracak, "evet" de, gerisi kendiliğinden olur.

---

## İlk açılışta macOS iki soru soracak

Apple temkinlidir, her yeni tanıdığını sorgular. İkisi de zararsız:

**1. "YipYip anahtarlığındaki bilgiye erişmek istiyor"**
→ **"Her Zaman İzin Ver"** de.
Bu, geçmişini kilitleyen anahtarın kasası. YipYip kendi kasasının anahtarını
istiyor, senin banka şifreni değil. Bu izni vermezsen uygulama kapıda öylece bekler.

**2. Erişilebilirlik (Accessibility) izni**
→ Ver gitsin.
Bu izin olmadan da her şey çalışır ama seçtiğin şeyi imlecine kendisi yapıştıramaz,
sen `⌘V` yapmak zorunda kalırsın. Yani bir tuş fazla basarsın. Dünyanın sonu değil
ama neden?

---

## Neler var içinde?

**Fotoğraf da hatırlar, dosya da.** Ekran görüntüsü aldın mı listede küçük hâlini
görürsün. Video kopyaladıysan onu da tutar — hem de videoyu kopyalamadan, sadece
"şuradaydı" diye not alarak. 4 GB'lık film geçmişinde birkaç harflik yer kaplar.
Zeki çocuk.

**Aynı şeyi tekrar kopyalarsan** listede iki tane olmaz, olan en üste zıplar.
"Ben bunu kopyalamıştım ya, hani nerede?" — burada, en üstte.

**İşine yarayanları asabilirsin.** `⌘P` ile bir klibi panoya asarsın, o artık
kaybolmaz. Sık kullandığın adres, kod, o bir türlü ezberleyemediğin IBAN...
Panolar oluşturup gruplayabilirsin de.

**Şifrelerine bulaşmaz.** Şifre yöneticinden bir şifre kopyaladığında YipYip
başını çevirir, görmezden gelir, kaydetmez. Centilmen adamdır.

**Ses çıkarır.** Kopyalayınca hafif bir "tink", yapıştırınca "tin-tin". Rahatsız
edici alarm sesleri değil, yumuşak şeyler. Sinirini bozarsa ayarlardan kapatırsın,
gücenmez.

**Eskiyenleri kendi temizler.** 30 gün sonra kimsenin umurunda olmayan klipler
sessizce gider. Ne kadar dursun istersen ayarlardan söylersin.

---

## Kısayollar

| Basacağın tuş | Olacak şey |
|---|---|
| `⌘⌥V` | Pencereyi aç (istersen değiştirirsin) |
| `↑` `↓` | Listede gez |
| `↩` | Seçtiğini imlecine yapıştır |
| `⌘P` | Bunu asayım, lazım olacak |
| `⌘⌫` | Bunu görmek istemiyorum |
| `Tab` | Hepsi ↔ Asılanlar |
| `Esc` | Boş ver, kapat |

`⌘⌥V` sana uymadıysa Ayarlar ▸ Shortcut'a gir, kutucuğa tıkla, canın ne isterse ona bas.

---

## "Peki benim verilerim?"

Senin bilgisayarında. Sadece orada. Başka hiçbir yerde.

Hesap yok, üyelik yok, "kaydolun" ekranı yok, bulut yok, senkronizasyon yok,
"deneyiminizi iyileştirmek için veri topluyoruz" yok. İnternete tek bir şey için
çıkar, o da **sen açarsan**: yeni sürüm var mı diye bakmak. Onu da kapalı bırakırsan
YipYip ömrü boyunca internetin yüzünü görmez.

Kopyaladıkların şifrelenerek saklanır. Yani birisi bilgisayarındaki dosyayı açıp
okumaya kalksa karşısına anlamsız harfler çıkar.

---

## Sıkça sorulan (ve sorulmayan) sorular

**Kaç tane şey hatırlıyor?**
1000. Yetmezse arttırırsın. 50.000'e kadar çıkar ama o noktada belki sorun panoda değildir.

**Bilgisayarımı yavaşlatır mı?**
Hayır. Menü çubuğunda oturur, sessiz sakin bekler.

**Adı neden YipYip?**
Kısa. Sevimli. Yazması kolay. Daha iyi bir açıklama arıyorsan yok.

**Bedava mı? Sonradan para isteyecek misin?**
Bedava. Kodu ortada, istersen okursun, istersen değiştirirsin.

**Bozulursa?**
[Buradan derdini anlat](https://github.com/atakansavas/YipYip/issues). Bakarız.

---

## Ayrılık vakti (olmasın ama)

Beğenmedin mi? Kırgınlık yok:

```bash
killall YipYip
rm -rf /Applications/YipYip.app
rm -rf ~/Library/Application\ Support/YipYip
```

Her şeyi silip gider. Arkasından bakmaz.

---

<sub>MIT lisansı · Atakan Savaş · Kodun içine bakmak isteyenlere: [teknik notlar](docs/TECHNICAL.md) · [katkı](CONTRIBUTING.md)</sub>
