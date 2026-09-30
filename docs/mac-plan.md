# Clockin for Mac: eşitlik ve senkron planı

2026-09-29'da kararlaştırıldı. Her aşama bitince bu dosyadaki durumu güncelle.

## Kararlar

- **Tek kod tabanı.** Mac uygulaması bu repoda, `Clockin.xcodeproj` içinde
  native bir macOS hedefi (`ClockinMac`) olarak yeniden kurulur. `Shared/`
  ve `Clockin/` altındaki ekranların çoğu iki hedefte ortak derlenir;
  platforma özgü kısımlar `#if os(macOS)` / `#if os(iOS)` ile ya da ayrı
  dosyalarla ayrılır. Bundan sonra bir özellik ya da düzeltme tek yerde
  yazılır.
- **Kimlik korunur.** Bundle id `com.ismailakdag.clockin`, Developer ID
  `erdem incedere (LU36PKDPT3)`, mevcut Sparkle akışı
  (`ismailakdag/clockin` → `macos-updates/appcast.xml`) ve EdDSA anahtarı.
  1.1.6 kullanıcıları yerinde 2.0'a güncellenir.
- **Veri yerinde kalır.** `~/Library/Application Support/Clockin/clockin.json`,
  yanındaki `Backups/` ve `com.ismailakdag.clockin` UserDefaults alanı. Bu
  yol iPhone kodundaki `ClockStore.defaultFileURL` ile zaten aynı. Mac'te App
  Group klasörü widget aşamasına kadar kullanılmaz.
- **Her şey senkronlanır:** iş verisi, hedefler, companion/gardırop/oda,
  görünüm ve sesler. Yalnızca cihaza bağlı durum dışarıda kalır (aşama 5).
- **Sıra:** önce tam eşitlik, sonra senkron.
- **Lisans notu.** Eski Mac uygulaması MIT ve `ismailakdag/clockin`
  reposunda; yeni kod bu repoda PolyForm Noncommercial. Güncelleme akışı o
  repodan yayınlandığı için 2.0'ı o akışa koymadan önce ortakla konuşulmalı.

## Aşamalar

### 0. Envanter ve uyumluluk

- Her iPhone dosyası için macOS durumu: olduğu gibi derlenir / `#if` gerekir /
  yalnızca iOS / Mac karşılığı yazılacak. Kullandığı iOS'a özgü API'ler.
- Eski Mac uygulamasının her dosyası için: yeni uygulamada karşılığı var mı,
  taşınacak mı, bırakılacak mı.
- UserDefaults anahtar eşlemesi (Mac ↔ iPhone): aynı, adı farklı, yalnızca
  Mac, yalnızca iPhone. Geçiş gereken anahtarlar.
- Mac'in yazdığı `clockin.json` iPhone çözücüsüyle okunuyor mu? iPhone
  çözücüsü daha katı (geçersiz süreyi reddeder); okunamazsa store boş başlar.
  Sentetik Mac verisiyle manual check, gerçek dosyayla salt okunur deneme.

Çıktı: `docs/mac-port-inventory.md`, `Tests/manual/maccompat/`.

### 1. macOS hedefi iskeleti

- `ClockinMac` hedefi: macOS 14, universal, hardened runtime, sandbox yok
  (eski uygulama gibi), `LSUIElement` davranışı eski uygulamayla aynı.
  Info.plist'te `SUFeedURL`, `SUPublicEDKey`. Sparkle SPM paketi yalnızca bu
  hedefe bağlı.
- `Shared/` ve ortak ekranlar macOS için derlenir. Platform ara katmanları:
  haptics Mac'te no-op, ActivityKit / Live Activity / Control Center yalnızca
  iOS, `UIImage`/`UIColor` yerine platform tipi.
- Kabul: Mac hedefi derlenir, gerçek veriyi okur, sayaç çalışır; iOS hedefi
  ve bütün manual check'ler değişmeden geçer.

### 2. Ekran eşitliği

Mac düzeni: kenar çubuklu ana pencere (Today, History, Insights, Companion) +
`Settings` sahnesi + menü komutları. iPhone ekranları yeniden yazılmaz,
Mac'e uyarlanır (sheet/popover, hover, klavye, pencere boyutu).

- 2a. Today: sayaç kartı, elle başlatma/giriş, oturum özeti, Today düzeni.
- 2b. History: sayfalı aralıklar, grafik, düzenle/sil, çakışma uyarıları,
  CSV ve yapıştırılan timecard içe aktarma, yedekler, ücret takvimi.
- 2c. Insights: hedefler, pace, momentum, kazanç, rozetler, paylaşılabilir
  istatistik görseli.
- 2d. Companion: maskot ve hareketleri, kutlamalar, level-up, gardırop,
  mağaza ve coin'ler, oda düzenleyici.
- 2e. Settings, rehber, dil, focus chime ve radyo, nudge'lar ve uzun oturum
  hatırlatıcısı (UserNotifications), Kısayollar (App Intents Mac'te de var).

### 3. Mac'e özgü özellikler

`clockin-main/Sources/Clockin`'den taşınır (MIT, `NOTICE.md` korunur):
menü çubuğu durum öğesi ve paneli, minimal mod, sabit pencere ve beş düzeni,
global klavye kısayolları, arayüz boyutu, Sparkle ile güncelleme,
Applications'a taşıma. iPhone'daki desk mode'un Mac karşılığı tam ekran ya
da sabit pencere olur.

### 4. Geçiş ve yayın (2.0.0)

- 1.1.6'dan yerinde güncelleme provası: önce gerçek verinin ve tercihlerin
  yedeği, sonra yeni sürümün aynı dosyayı ve tercihleri okuduğunun kontrolü.
- Level: Mac iPhone kuralına geçer (hedefler XP vermez). Mac kullanıcısının
  seviyesi değişebilir; sürüm notunda söylenir. `PARITY.md`'deki "Different
  on purpose" tablosu kapanır.
- xcodebuild archive, notarize, staple, DMG, imzalı appcast. Yayın betikleri
  SPM'den Xcode arşivine uyarlanır.

### 5. Senkron (CloudKit)

- **Altyapı:** `CKSyncEngine` (iOS 17 / macOS 14), private database, özel
  zone `Clockin`, konteyner `iCloud.com.erdmncdr.clockin`. Hesap ya da sunucu
  yok; veri kullanıcının iCloud'unda.
- **Kayıt tipleri:** `Session` ve `RateRule` (UUID başına), `Running`
  (tekil), `Profile` (ücret, para birimi), `Preference` (anahtar başına),
  `WardrobePurchase` (satın alma başına, yalnızca eklenir), `WardrobeState`
  (giyilenler, oda düzeni).
- **Store'a bağlantı:** `ClockStore` her kaydettiğinde önceki ve yeni
  `ClockinData` karşılaştırılır, fark bekleyen kayıt değişikliklerine
  dönüşür. Gelen değişiklik store'a uzaktan diye işaretlenerek uygulanır,
  geri yankılanmaz. Arşiv şeması değişmez; değişiklik zamanları, CloudKit
  sistem alanları ve engine durumu ayrı bir yan dosyada tutulur.
- **Çakışmalar:** kayıt başına son değiştiren kazanır; silme kazanır;
  satın almalar birleşir (çift harcama olmaz); bitmiş bir koşu dirilmez
  (`running.start` ile başlayan bir Clockin kaydı varsa çalışan sayaç düşer);
  iki cihazda aynı anda clock in edilirse sonraki kazanır, öteki cihaz
  bunu söyler.
- **İlk birleştirme:** iki cihazda da geçmiş var. İlk senkronda önizleme:
  "iPhone'dan X, Mac'ten Y, Z aynı kayıt"; onaydan önce iki tarafta yedek.
  Aynı kayıt, içe aktarmanın mevcut tekilleştirme anahtarıyla bulunur.
- **Cihazda kalanlar:** Live Activity token ve izinleri, pencere konum ve
  boyutları, arayüz boyutu, bildirim zamanlama durumu, kurulum işaretleri.
- **Widget ve Live Activity:** gelen değişiklik `SessionMirror`'dan geçer,
  widget'lar yenilenir. Mac'te başlatılan sayaç için iPhone'da Live Activity
  arka planda başlatılamaz; push-to-start ile `services/live-activity`
  üzerinden sonraki iş.
- **Senin yapman gerekenler:** developer portalda `com.ismailakdag.clockin`
  ve `com.erdmncdr.clockin` App ID'lerine iCloud yeteneği ve aynı konteyner,
  Mac için Developer ID provisioning profile, CloudKit Dashboard'da şemayı
  production'a almak.

## İş bölümü

- **Codex:** envanter ve araştırma, Foundation düzeyinde `Shared/` kodu,
  platform ara katmanları, senkron çekirdeği (fark, birleştirme, kayıt
  eşleme), manual check'ler, eski Mac uygulamasındaki AppKit dışı mantığın
  taşınması. Kendi worktree'sinde, arka planda çalışır.
- **Claude:** Xcode hedefleri ve `project.pbxproj`, SwiftUI/AppKit bağlama,
  xcodebuild, simülatörde ve Mac'te çalıştırma, Codex diff'lerinin
  incelenmesi, commit'ler.
- Her Codex işi `docs/codex/` altında bir brief ile başlar (amaç, dokunulacak
  ve dokunulmayacak dosyalar, kabul kontrolleri) ve bir sonuç dosyasıyla
  biter. Birleştirmeden önce Claude inceler, iki hedefi derler ve kontrolleri
  koşar.

## Riskler

- iPhone çözücüsü Mac verisini reddederse kullanıcı boş store görür
  (aşama 0 bunu önceden yakalar).
- `project.pbxproj` elle düzenleniyor; iOS hedefi bozulmamalı. Her adımda iki
  hedef de derlenir.
- macOS 15'te `group.` önekli App Group onay istemi çıkarır; Mac widget'ları
  gelene kadar App Group kullanılmaz.
- CloudKit, Developer ID ile dağıtılan uygulamada provisioning profile ister;
  bu adım senin hesabında yapılır.

## Durum

- [x] 0. Envanter ve uyumluluk: `docs/mac-port-inventory.md`,
  `Tests/manual/maccompat`. Gerçek Mac verisi (salt okunur deneme) iPhone
  çözücüsüyle açılıyor; yine de eski Mac'in yazabildiği 20 bozuk şekil tüm
  arşivi reddettiriyor → kayıt bazında karantina (brief 03).
- [x] 1. macOS hedefi iskeleti: `ClockinMac` derleniyor ve açılıyor; Debug
  derlemesi `Clockin Debug` klasörünü ve `com.ismailakdag.clockin.debug`
  alanını kullanıyor. iOS derlemesi değişmeden geçiyor.
- [ ] 2. Ekran eşitliği (2a–2e): sheet boyutları, grouped formlar,
  segmented etiketleri, Today'in okunur genişliği, ayar düğmesinin kenar
  çubuğuna gitmesi, kutlama katmanı ve paylaşım/companion sheet'leri,
  uygulama genelinde chime/nudge/hatırlatıcı/kutlama tazelemesi
  (`MacAppServices`), geçmişin güne göre/oturumlar listesi (brief 04), Mac
  rehberi, masa modu penceresi (⌃⌘F) yapıldı. Menü çubuğu paneli ve sabit
  sayaç (Kazanç, Tümü) açılıp doğrulandı; ikisindeki çökmeler düzeltildi
  (serbest boyutlu rolling yazı tipi, ortam nesnesi sırası). Kalan: oda
  düzenleyicinin elle denenmesi, sabit sayacın "Tümü" düzeninde ses
  etiketinin kesilmesi.
  Arayüz boyutu (UIScale, 2026-09-29): kaldırıldı. Pencere serbestçe
  boyutlanıyor; `Clockin.UIScalePercent` ve `Clockin.UIScale` silinmeden
  kalır. 2.0 sürüm notunda söylenecek.
- [x] 3. Mac'e özgü özellikler (brief 02): menü çubuğu ve paneli, minimal
  mod, sabit pencere ve beş düzeni, global kısayollar (Carbon; erişilebilirlik
  izni istemez), Sparkle, Applications'a taşıma, Clock menüsü, ⌘1–⌘4.
  Gerçek güncelleme provası aşama 4'te.
- [x] 4. Geçiş ve yayın: Mac 2.0.0 (11) 2026-09-30'da mevcut Sparkle akışına
  yayınlandı (`docs/releases/mac-2.0.0-11.md`). Web sitesindeki indirme hâlâ
  1.1.6.
- [x] 5. Senkron: CloudKit şeması production'da; iPhone 0.2 (43) TestFlight'ta
  (`docs/releases/ios-testflight-0.2-43.md`) ve Mac 2.0 senkronla çıktı.
  Dil her cihazda ayrı. Sonraki işler: kurtarma sayfasının iPhone'da gerçek
  bir değişiklikle denenmesi, web sitesinin 2.0'a geçirilmesi.
