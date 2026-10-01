'use strict';
const CLOCKIN_TRANSLATIONS = {
  "en": {
    "tabToday": "Today",
    "tabHistory": "History",
    "tabProgress": "Progress",
    "tabSettings": "Settings",
    "productTitle": "Right at home on your Mac.",
    "productCopy": "The clock, the money and the month so far.<br>In a window, in the menu bar, or in a corner of the screen.",
    "captionToday": "Start, pause, and watch what the hours are worth.",
    "captionHistory": "A week, a month or six: earnings, averages and worked days.",
    "captionProgress": "Goals, your plan, and the time you will reach today’s.",
    "captionSettings": "Rates, currency, menu bar, chime, radio, themes, iCloud.",
    "altToday": "Clockin on a Mac: a running timer, the money earned, the focus chime card and today’s totals. Sample data.",
    "altHistory": "Clockin history: monthly earnings over six months with averages and worked days. Sample data.",
    "altProgress": "Clockin progress: monthly goal, today’s goal and the work plan. Sample data.",
    "altSettings": "Clockin settings: iCloud sync, pinned controls and menu bar options.",
    "altMenubar": "The Clockin menu bar panel: timer, earnings, the month so far and the clock-out buttons.",
    "altPinned": "The pinned Clockin timer: elapsed time, earnings and the hourly rate in a small window.",
    "altDesk": "Clockin desk mode: a full-screen room with the clock, the earnings and the companion at its desk.",
    "reachTitle": "Without leaving your work.",
    "reachMenubarTitle": "The menu bar panel",
    "reachMenubarCopy": "Click the icon and the timer opens over whatever you are doing, full-screen apps included.",
    "reachPinnedTitle": "A pinned timer",
    "reachPinnedCopy": "A small window that stays on top, in the size and detail you want.",
    "deskTitle": "Desk mode, for the long stretches.",
    "deskCopy": "One key turns the screen into a quiet room: the clock, what you have earned and your companion at its desk.",
    "featuresTitle": "What else is in there.",
    "featRateTitle": "Rates that change over time",
    "featRateCopy": "Give each rate a start date and Clockin pays old work at the rate it was earned at. Amounts show in your currency with a Turkish lira equivalent.",
    "featImportTitle": "Your timecard, imported",
    "featImportCopy": "Bring in a CSV or paste the text straight from a timecard page. Clockin compares it with what you already have and refuses to double a day.",
    "featGoalsTitle": "Goals that know your pace",
    "featGoalsCopy": "Set daily and monthly hours and how many days a week you work. Progress shows what is left and the time you will reach today’s goal.",
    "featCompanionTitle": "A companion that keeps you company",
    "featCompanionCopy": "The pixel mascot reacts to your work, levels up, earns coins, and has a wardrobe and a room you can arrange.",
    "featFocusTitle": "Focus chime and radio",
    "featFocusCopy": "A gentle chime on the interval you pick, eight sounds to choose from, and internet radio while you work.",
    "featSyncTitle": "Your iPhone and Mac, in step",
    "featSyncCopy": "Work, goals, companion and settings move between your devices through your own iCloud. There is no Clockin account and no server.",
    "iphoneTitle": "And in your pocket.",
    "iphoneCopy": "The iPhone app keeps the same work and the same companion. The Lock Screen Live Activity and the Dynamic Island show the money going up, with pause and clock out right there, and the widgets keep today in view. It is in testing now.",
    "sourceLink": "Source on GitHub",
    "skip": "Skip to content",
    "explore": "Explore Clockin",
    "download": "Download for Mac",
    "heroTitle": "Make time<br>feel well spent.",
    "heroCopy": "Find your focus.<br>Clockin keeps track of your time and earnings.",
    "compatibility": "macOS 14 or later",
    "tour": "Take a little tour",
    "try": "Try Clockin",
    "duration": "time well spent",
    "session": "This session",
    "sampleRate": "Sample timer · TRY 300 / hour",
    "today": "Your work today",
    "summaryCopy": "4 hours, 10 minutes. A little further along.",
    "levelTitle": "A little more progress.",
    "levelCopy": "Earn experience with every session.",
    "sampleDay": "An example workday",
    "focus": "Focus",
    "break": "Take a break",
    "reward": "See your progress",
    "realScreens": "Real screenshots from the app. Sample data.",
    "closing": "Here’s to a good day’s work.",
    "footer": "Made for your Mac.",
    "downloadTitle": "Clockin is on its way.",
    "downloadCopy": "The Mac installer is being prepared. Once it’s ready, you’ll be able to download it right here.",
    "done": "Got it",
    "homeLabel": "Clockin home",
    "navLabel": "Main navigation",
    "mascotLabel": "Meet the Clockin mascot and see its next pose",
    "journeyLabel": "An example workday with Clockin",
    "demoLabel": "Interactive Clockin demo",
    "chartLabel": "Sample daily earnings chart: earnings rise to TRY 1,250",
    "sceneLabel": "Demo scenes",
    "screenLabel": "Choose an app screen",
    "closeLabel": "Close",
    "historyAlt": "Clockin history: daily earnings chart and work averages. Sample data.",
    "timerAlt": "Clockin timer: work duration, live earnings and focus mascot. Sample data.",
    "progressAlt": "Clockin progress: level, experience points and work streak. Sample data.",
    "coffeeAlt": "Clockin mascot taking a coffee break",
    "title": "Clockin — Make time feel well spent.",
    "description": "Track your time and earnings on your Mac with Clockin. A little work companion, by your side.",
    "hello": "Hi, I’m Clockin.\nShall we get to work?",
    "working": "You find your focus.\nI’ll keep track of the time.",
    "coffee": "Time for a coffee?\nI’ll be here when you’re back.",
    "celebrate": "Every session is a step forward.\nLet’s see how far you’ve come.",
    "soon": "See you on your Mac\nsoon!",
    "seeYou": "See you on your Mac!",
    "workTime": "09:00 / A fresh start",
    "workTitle": "One click.<br> Find your focus.",
    "workDescription": "You take the first step. Clockin keeps track of your time and what it’s worth.",
    "workSpeech": "Ready when you are.",
    "workAlt": "Clockin mascot working at a laptop",
    "breakTime": "10:00 / A moment to yourself",
    "breakTitle": "Make room<br> for a breather.",
    "breakDescription": "One hour in. Take a coffee break, then pick up right where you left off.",
    "breakSpeech": "Coffee’s on me. No rush.",
    "breakAlt": "Clockin mascot taking a coffee break",
    "rewardTime": "13:40 / Nicely done",
    "rewardTitle": "See what your<br> time adds up to.",
    "rewardDescription": "Your hours, your earnings, your little wins. Look back on a day well spent.",
    "rewardSpeech": "Look how far you’ve come today.",
    "rewardAlt": "Clockin mascot celebrating your progress",
    "start": "Start focusing",
    "resume": "Resume focus",
    "pause": "Take a break",
    "running": "Focus time",
    "paused": "On a break",
    "ready": "Ready when you are",
    "runningSpeech": "Time’s on me. You do your thing.",
    "pausedSpeech": "Take your time. I’m right here.",
    "resumeSpeech": "Right where we left off.",
    "themeDark": "Switch to dark mode",
    "themeLight": "Switch to light mode"
  },
  "tr": {
    "tabToday": "Bugün",
    "tabHistory": "Geçmiş",
    "tabProgress": "İlerleme",
    "tabSettings": "Ayarlar",
    "productTitle": "Mac’inde yerini bulur.",
    "productCopy": "Saat, para ve ayın başından beri biriken.<br>Pencerede, menü çubuğunda ya da ekranın bir köşesinde.",
    "captionToday": "Başlat, mola ver, saatlerin karşılığını gör.",
    "captionHistory": "Hafta, ay ya da altı ay: kazanç, ortalamalar ve çalışılan günler.",
    "captionProgress": "Hedefler, planın ve bugünkünü kaçta tamamlayacağın.",
    "captionSettings": "Ücret, para birimi, menü çubuğu, zil, radyo, temalar, iCloud.",
    "altToday": "Mac’te Clockin: çalışan sayacı, kazanılan parayı, odak zili kartını ve bugünün toplamını gösteriyor. Veriler örnektir.",
    "altHistory": "Clockin geçmiş ekranı: altı aylık kazanç grafiği, ortalamalar ve çalışılan günler. Veriler örnektir.",
    "altProgress": "Clockin ilerleme ekranı: aylık hedef, bugünün hedefi ve çalışma planı. Veriler örnektir.",
    "altSettings": "Clockin ayarları: iCloud eşitleme, sabitlenen kontroller ve menü çubuğu seçenekleri.",
    "altMenubar": "Clockin menü çubuğu paneli: sayacı, kazancı, ayın toplamını ve mesai bitirme düğmelerini gösteriyor.",
    "altPinned": "Sabitlenmiş Clockin sayacı: geçen süre, kazanç ve saatlik ücret küçük bir pencerede.",
    "altDesk": "Clockin masa modu: tam ekran bir oda, saat, kazanç ve masasındaki maskot.",
    "reachTitle": "İşini bölmeden.",
    "reachMenubarTitle": "Menü çubuğu paneli",
    "reachMenubarCopy": "İkona basınca sayacı ne yapıyorsan onun üstünde açılır; tam ekran uygulamalarda da.",
    "reachPinnedTitle": "Sabit sayacı",
    "reachPinnedCopy": "Üstte duran küçük bir pencere; boyutunu ve ne yazacağını sen seçersin.",
    "deskTitle": "Uzun mesailer için masa modu.",
    "deskCopy": "Tek tuş ekranı sakin bir odaya çevirir: saat, o ana kadar kazandığın ve masasında çalışan maskotun.",
    "featuresTitle": "İçinde başka neler var.",
    "featRateTitle": "Zamanla değişen ücretler",
    "featRateCopy": "Her ücrete başlangıç tarihi ver; Clockin eski işi kazanıldığı ücretten hesaplar. Tutarlar kendi para biriminde, yanında Türk lirası karşılığıyla görünür.",
    "featImportTitle": "Puantajını içeri al",
    "featImportCopy": "CSV dosyasını ekle ya da puantaj sayfasındaki metni olduğu gibi yapıştır. Clockin elindekiyle karşılaştırır ve bir günü iki kez eklemez.",
    "featGoalsTitle": "Temponu bilen hedefler",
    "featGoalsCopy": "Günlük ve aylık saatini, haftada kaç gün çalıştığını yaz. İlerleme ekranı ne kaldığını ve bugünkü hedefi kaçta tamamlayacağını gösterir.",
    "featCompanionTitle": "Yanında bir arkadaş",
    "featCompanionCopy": "Piksel maskot çalışmanı takip eder, seviye atlar, jeton kazanır; gardırobu ve düzenleyebileceğin bir odası vardır.",
    "featFocusTitle": "Odak zili ve radyo",
    "featFocusCopy": "Seçtiğin aralıkta çalan yumuşak bir zil, sekiz ses seçeneği ve çalışırken dinleyebileceğin internet radyosu.",
    "featSyncTitle": "iPhone’unla Mac’in aynı yerde",
    "featSyncCopy": "Çalışman, hedeflerin, maskotun ve ayarların kendi iCloud hesabın üzerinden cihazların arasında gezer. Clockin hesabı da sunucusu da yok.",
    "iphoneTitle": "Bir de cebinde.",
    "iphoneCopy": "iPhone uygulaması aynı çalışmayı ve aynı maskotu taşır. Kilit ekranındaki Live Activity ve Dynamic Island paranın artışını gösterir; mola ve mesai bitirme oradadır, widget’lar da bugünü gözönünde tutar. Şu an test aşamasında.",
    "sourceLink": "GitHub’da kaynak kod",
    "skip": "İçeriğe geç",
    "explore": "Uygulamaya göz at",
    "download": "Mac için indir",
    "heroTitle": "Zamanın<br>yerini bulsun.",
    "heroCopy": "Sen işine odaklan.<br>Clockin süreni ve kazancını takip etsin.",
    "compatibility": "macOS 14 ve üzeri",
    "tour": "Birlikte bakalım",
    "try": "Clockin’i dene",
    "duration": "çalışma süren",
    "session": "Bu seans",
    "sampleRate": "Örnek sayaç · Saatlik ₺300",
    "today": "Bugünkü emeğin",
    "summaryCopy": "4 saat 10 dakika. Kendin için bir adım daha.",
    "levelTitle": "Biraz daha ilerledin.",
    "levelCopy": "Her seansla deneyim kazan.",
    "sampleDay": "Örnek bir iş günü",
    "focus": "Odaklan",
    "break": "Mola ver",
    "reward": "Karşılığını gör",
    "realScreens": "Uygulamadan gerçek görüntüler. Veriler örnektir.",
    "closing": "Güzel bir iş günü olsun.",
    "footer": "Mac’in için yapıldı.",
    "downloadTitle": "Clockin yola çıkıyor.",
    "downloadCopy": "Mac kurulum paketi hazırlanıyor. Hazır olduğunda buradan tek tıkla indirebileceksin.",
    "done": "Tamam",
    "homeLabel": "Clockin ana sayfa",
    "navLabel": "Ana gezinme",
    "mascotLabel": "Clockin maskotuyla tanış, sonraki pozu göster",
    "journeyLabel": "Clockin ile örnek bir iş günü",
    "demoLabel": "Etkileşimli Clockin demosu",
    "chartLabel": "Örnek günlük kazanç grafiği: kazanç gün içinde 1.250 liraya yükseliyor",
    "sceneLabel": "Demo sahneleri",
    "screenLabel": "Uygulama ekranını seç",
    "closeLabel": "Kapat",
    "historyAlt": "Clockin geçmiş ekranı: günlük kazanç grafiği ve çalışma ortalamaları. Örnek veriler.",
    "timerAlt": "Clockin sayacı: aktif çalışma süresi, anlık kazanç ve odak maskotu. Örnek veriler.",
    "progressAlt": "Clockin ilerleme ekranı: seviye, deneyim puanı ve çalışma serisi. Örnek veriler.",
    "coffeeAlt": "Kahve molasındaki Clockin maskotu",
    "title": "Clockin — Zamanın yerini bulsun.",
    "description": "Clockin ile çalışma süreni ve kazancını Mac’inde takip et. Küçük bir çalışma arkadaşı, gün boyu yanında.",
    "hello": "Selam, ben Clockin.\nBugün birlikte çalışalım mı?",
    "working": "Sen işine odaklan.\nZamanını ben takip ederim.",
    "coffee": "Bir kahve molası?\nDöndüğünde buradayım.",
    "celebrate": "Her seans bir adım daha.\nİlerlemeni birlikte görelim.",
    "soon": "Yakında Mac’inde\ngörüşmek üzere!",
    "seeYou": "Mac’inde görüşürüz!",
    "workTime": "09.00 / Yeni bir başlangıç",
    "workTitle": "Bir tık.<br> Ve odaktasın.",
    "workDescription": "İlk adımı sen at. Süreni ve emeğinin karşılığını Clockin takip etsin.",
    "workSpeech": "Hazırım. Hadi başlayalım.",
    "workAlt": "Bilgisayarında çalışan Clockin maskotu",
    "breakTime": "10.00 / Bir nefes arası",
    "breakTitle": "Biraz da<br> kendine zaman.",
    "breakDescription": "Bir saati tamamladın. Kahve molası ver, sonra kaldığın yerden devam et.",
    "breakSpeech": "Kahveler benden. Acelemiz yok.",
    "breakAlt": "Kahve molası veren Clockin maskotu",
    "rewardTime": "13.40 / İyi iş çıkardın",
    "rewardTitle": "Emeğinin<br> karşılığı burada.",
    "rewardDescription": "Çalıştığın saatler, kazancın, küçük zaferlerin. Gününe dönüp bir bak.",
    "rewardSpeech": "Bak, bugün ne kadar yol aldın.",
    "rewardAlt": "İlerlemeni kutlayan Clockin maskotu",
    "start": "Çalışmaya başla",
    "resume": "Devam et",
    "pause": "Mola ver",
    "running": "Odak zamanı",
    "paused": "Moladasın",
    "ready": "Başlamaya hazır",
    "runningSpeech": "Tamam, zaman bende. Sen işine bak.",
    "pausedSpeech": "Hazır olduğunda buradayım.",
    "resumeSpeech": "Kaldığımız yerden devam.",
    "themeDark": "Koyu moda geç",
    "themeLight": "Açık moda geç"
  }
};
(() => {
  let language=ClockinPreferences.language;
  const t=key=>CLOCKIN_TRANSLATIONS[language][key] || CLOCKIN_TRANSLATIONS.en[key] || key;
  const money=value=>new Intl.NumberFormat(language==='tr'?'tr-TR':'en-GB',{style:'currency',currency:'TRY',currencyDisplay:language==='tr'?'symbol':'code'}).format(value);
  window.ClockinLocale={t,money,get language(){return language;}};
  function themeLabel(){
    const dark=document.documentElement.dataset.theme==='dark';
    const button=document.querySelector('#theme-toggle');
    button.setAttribute('aria-label',t(dark?'themeLight':'themeDark'));
    button.title=t(dark?'themeLight':'themeDark');
    document.querySelector('meta[name="theme-color"]').content=dark?'#141923':'#f5f6f8';
  }
  function apply(value){
    language=value==='tr'?'tr':'en';
    document.documentElement.lang=language;
    document.title=t('title');
    document.querySelector('meta[name="description"]').content=t('description');
    document.querySelectorAll('[data-i18n]').forEach(el=>{el.innerHTML=t(el.dataset.i18n);});
    for(const attr of ['aria-label','alt'])document.querySelectorAll(`[data-i18n-${attr}]`).forEach(el=>el.setAttribute(attr,t(el.getAttribute(`data-i18n-${attr}`))));
    document.querySelectorAll('[data-language]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.language===language)));
    document.querySelector('#summary-money').textContent=money(1250);
    themeLabel();
    document.dispatchEvent(new Event('clockin-language'));
  }
  // View transitions where supported: a short cross-fade for language, and the
  // new theme revealed as a circle growing from the toggle. Without support, or
  // with reduced motion, the change is simply instant.
  const calm=()=>matchMedia('(prefers-reduced-motion: reduce)').matches;
  function transition(change,className,origin){
    if(!document.startViewTransition||calm()||document.hidden){change();return;}
    const root=document.documentElement;
    if(origin){
      const r=origin.getBoundingClientRect(),x=r.left+r.width/2,y=r.top+r.height/2;
      root.style.setProperty('--vt-x',x+'px');root.style.setProperty('--vt-y',y+'px');
      root.style.setProperty('--vt-r',Math.hypot(Math.max(x,innerWidth-x),Math.max(y,innerHeight-y))+'px');
    }
    if(className)root.classList.add(className);
    const vt=document.startViewTransition(change);
    // A skipped transition (for example a hidden tab) still applies the change;
    // its rejected promises are expected and must not surface as errors.
    vt.ready.catch(()=>{});
    vt.finished.catch(()=>{}).finally(()=>className&&root.classList.remove(className));
  }
  document.querySelectorAll('[data-language]').forEach(button=>button.addEventListener('click',()=>{
    if(button.dataset.language===language)return;
    ClockinPreferences.saveLanguage(button.dataset.language);
    transition(()=>apply(button.dataset.language));
  }));
  const themeButton=document.querySelector('#theme-toggle');
  themeButton.addEventListener('click',()=>transition(()=>ClockinPreferences.toggleTheme(),'theme-transition',themeButton));
  document.addEventListener('clockin-theme',themeLabel);
  apply(language);
})();
