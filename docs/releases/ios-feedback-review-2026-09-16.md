# iOS geri bildirim incelemesi, 16 Eylül 2026

Kaynak: `clockin-main/iOS`, başlangıç commit'i `c35b6fd`. Düzeltmeler yereldir; yeni TestFlight yüklemesi yapılmadı ve mevcut TestFlight binary'si bu kaynakla birebir karşılaştırılmadı.

## Sonuç

| Öncelik | Bulgu | Sonuç |
|---|---|---|
| P1 | Dakikalık yenileme eski chime ayarını kullanıp kapatılan bildirimleri yeniden planlıyor | iOS günlükleriyle üretildi, düzeltildi ve tekrar sınandı |
| P1 | Uzun kayıt yalnızca not değiştirilirken kısalabiliyor | UI'da üretildi; bitiş tarihi, mola ve saniyeler korunarak düzeltildi |
| P1 | Aynı başlangıç günlü ücretlerde Current rate ve hesaplama farklı kural seçebiliyor | Ortak kural seçimi ve tekrar engeli; otomatik ve UI kontrolü geçti |
| P1 | Gece yarısını geçen oturumun snapshot'ına bugünün ücreti yazılıyor | Oturumun güncel ücreti kullanılıyor; otomatik kontrol geçti |
| P2 | Düzenleyicide saniye yuvarlaması sahte overlap uyarısı oluşturabiliyor | Önizleme, overlap ve kayıt aynı saat çözümünü kullanıyor; UI kontrolü geçti |
| P2 | Chime sıradan bildirim için incoming-call zilini kullanıyor | Normal bildirim sesine geçirildi |
| Araştırma | TRY seçildiğinde üstte USD kalıyor | Bu sürümde simülatör ana ekranı ve kilit ekranı Live Activity'de yeniden üretilemedi; ikisi de ₺ gösterdi |

## Bildirim kök nedeni ve kanıt

`RootView.task(id:scenePhase)` içindeki uzun ömürlü döngü eski `@AppStorage` değerlerini tutuyordu. Kullanıcı aralığı 1 dakika seçse de döngü tekrar 10 dakikayı uygulayabiliyor, hatta chime kapatıldıktan sonra yeniden bildirim planlayabiliyordu. Preview kendi içinde tekrar döngüsü oluşturmuyor.

Düzeltme: `RootView.updateChimes` artık `SessionMirror.refreshChimes` kullanıyor. Her yenileme güncel store ve UserDefaults değerlerini okuyor; force parametresi de korunuyor. Ringtone tercihi normal bildirim sesine düşüyor.

16 Eylül, Europe/Istanbul saatleriyle ayrı test simülatöründeki SpringBoard/UserNotifications günlükleri:

- Önce: UI'da yaklaşık 18:52:55'te kapatıldıktan sonra **18:53:52'de 20 yeni istek** eklendi.
- Tek preview: 18:50:14.699'da bir banner; 18:50:23'te kayboldu. Tek dokunuşun tekrar ettiği gözlenmedi.
- Sonra: 1 dakika ayarında **18:58:42.124** ve **18:59:42.171** teslimleri; dakikalık yenileme aralığı geri çevirmedi.
- Pause: 18:59:55 civarı; 19:00–19:01 sonrasındaki gözlemde yeni planlama/teslim yok.
- Uygulamayı arka plana alıp geri açma sonrasında chime OFF: **19:03:30–19:05:30** aralığında yeni planlama/teslim yok.
- Tekrar etkinleştirip clock out: yaklaşık 19:06:20; 19:06:30–19:07 sonrası gözlemde yeni planlama/teslim yok.

Tekrar tarifi: `iOS/Tests/manual/chime/README.md`. Geçici kanıtlar `/private/tmp/clockin-feedback-review/` altında `disabled-before-fix.log`, `enabled-after-fix.log`, `paused-after-fix.log`, `disabled-after-fix.log`, `clocked-out-after-fix.log`.

## Uzun kayıt ve overlap

26 saatlik dış aralığı, 1 saat molası olan kayıt önce editörde **1h / ₺60** görünüyordu; doğrusu **25h / ₺1500**. `EntryTimes.editorTimes` artık mevcut kaydın açık bitiş tarihini koruyor. Editörde bitiş tarihi seçilebiliyor; önizleme, overlap ve kaydetme tek çözümü kullanıyor. Değişmeyen saatlerde orijinal saniyeler geri kullanılıyor.

Düzeltmeden önce iki yeni regresyon kontrolü başarısız oldu. Düzeltmeden sonra simülatörde yalnız not değiştirilip kaydedildi: liste 25h / ₺1500 gösterdi; diskte 26 saat dış aralık, 25 saat çalışma, orijinal `:17` saniyeleri ve yeni not doğrulandı. Yeniden yükleme testi de geçti.

606 kayıtlı UI fixture'ında:

- A 16:00:30'da biter, B 16:00:31'de başlar: B editöründe overlap yok.
- A 12:00–13:00, B 12:30–13:30: B editöründe bir çakışma ve doğru A kaydı; History başlığında iki çakışan kayıt.

Overlap dış saat aralıklarının kesişmesidir. Model molaların ayrı başlangıç/bitişlerini tutmadığı için uyarı kesin çift sayım teşhisi değildir.

## Ücret ve para birimi

Etiket ve hesaplama ortak `effectiveRateRule(at:)` kullanıyor. Aynı başlangıç gününde ikinci ücret ekleme/düzenleme açıklayıcı hata ile engelleniyor. Eski çift kurallı veriler silinmiyor; etiket ve hesaplama aynı kuralı seçiyor.

UI: saatlik ücret 25→60; klavye açıkken Done sonrasında yeniden açılan ayarda 60.00 ve aktif sayaçta saniyelik 0.0167 doğrulandı. Bugüne 90 eklenince Current rate 90, ayar 90.00 ve saniyelik 0.025 oldu. Aynı güne 120 ekleme açıklayıcı mesajla reddedildi.

Aktif oturum hâlâ başlangıç gününün ücretini kullanır. Yeni günün zammı dün başlayan oturumu otomatik yeniden fiyatlamaz. Snapshot artık aynı `store.currentRate(at:)` değerini kullanır. Bu gece yarısı sınırı otomatik testle doğrulandı; fiziksel cihaz widget testi yapılmadı.

Aktif oturumda USD→TRY: Timer, Today, momentum ve kilit ekranındaki Live Activity **₺** gösterdi (Activity'de ₺2.09 görüldü). Relaunch sonrasında TRY ve ücret korundu. Bu, bildirilen USD sorununun tüm cihazlarda çözüldüğü anlamına gelmez. Mevcut ActivityKit hata yutma yolu değiştirilmedi. Settings swipe-dismiss sırasında odaklı ücret alanı ayrıca doğrulanmadı; Done akışı doğrulandı.

## Genel UI kontrolleri

Ayrı `Clockin Feedback Review` simülatörü, iPhone 17 Pro / iOS 26.5, Xcode Device Hub üzerinden kullanıldı. Kullanıcının gerçek kayıtlarına ve telefonuna dokunulmadı.

- Başlatma, pause/resume, clock out, arka plan/ön plan ve relaunch kontrol edildi.
- Yatay Desk Mode'da timer, TRY, pause/resume; dikeye dönüşte oturumun korunması kontrol edildi.
- 606 sentetik kayıtta History dönemleri: 7D 30 kayıt / ₺2591.28; 30D 168 / ₺6731.28; 3M 528 / ₺17531.28; ALL 606 / ₺19871.28.
- ALL grafiğinde 17 Temmuz seçimi 3h / ₺180 gösterdi. Grafikten başlayan dikey sürükleme listeyi kaydırdı. Mevcut tasarım gün seçimini dokunmayla yapıyor; yatay sürükleme ile sürekli seçim yok.
- Insights ısı haritası süre/TRY değerleriyle açıldı; Badges 26/46 ve XP bilgilerini gösterdi. Bunlar ekran açılış kontrolleridir; her alt akışın uçtan uca testi değildir.
- FPS veya Instruments ölçümü yapılmadı; fiziksel iPhone performansı garanti edilmiyor.

## Derleme ve otomatik kontroller

- **15 grup / 557 başarılı kontrol, sıfır başarısızlık** (mevcut 536 + feedback 21).
- Debug, generic iOS Simulator: **BUILD SUCCEEDED**, uygulama kuruldu ve yukarıdaki UI kontrolleri yapıldı.
- Release, generic iOS device, imzasız: **BUILD SUCCEEDED**. Bu archive/upload veya cihaz kurulumu değildir.
- `git diff --check` temiz.
- Önceden mevcut HistoryView/Combine import uyarıları derlemeyi engellemiyor.

Komutlar `iOS/README.md` içindeki Checks bölümünde. Geçici günlükler: `/private/tmp/clockin-feedback-build.log`, `/private/tmp/clockin-feedback-review/release-build.log`, `check-{1..15}.log`, `check-results.json`. Rapor bu çalıştırmaların kalıcı özetidir.
