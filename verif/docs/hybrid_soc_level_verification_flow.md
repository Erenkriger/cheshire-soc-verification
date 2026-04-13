# Hybrid SoC-Level Verification Flow (C Tests + UVM)

## 1) Kisa cevap

Evet, C testlerinden uretilen ELF dosyalarini calistirmak SoC-level fonksiyonel dogrulamanin bir parcasidir.
Ancak tek basina yeterli degildir.

- C/ELF calisma: CPU yazilim yolu, peripheral bring-up, temel sistem davranisi
- UVM ortami: protocol-level kontrol, assertion (SVA), functional coverage, constrained-random stimulus

En dogru yontem: **C test + UVM hibrit akis**.

## 2) C-only ve UVM farki

### C-only (ELF'i dogrudan calistirma)
Kazandirdiklari:
- Gercek yazilim akisina en yakin senaryolar
- Boot, driver, MMIO erisim, sistem entegrasyon hatalarini yakalama
- Board/sunucu tarafi bring-up guveni

Eksikleri:
- UVM functional coverage bin/cross metrikleri uretmez
- UVM monitor/scoreboard guvencesi azalir
- SVA pass/fail gozlemi yoksa protocol ihlalleri kacabilir
- Constrained-random stimulus kapsami dusuk kalir

### UVM + C/ELF birlikte
Kazandirdiklari:
- Yazilim gercekligi + verification metrikleri birlikte
- Coverage kapanisi ve SVA ile signoff kalitesine yakinlasma
- Waveform debug ve root-cause hizlanmasi

## 3) Bu repoda onerilen akis

### Asama A - C testlerini derle

- Komut: `cd verif/sw && make all`
- Uretilenler: `build/*.elf`, `build/*.dump`, `build/*.memh`

### Asama B - C-only SoC bring-up (sunucu)

- ELF dosyalarini sunucuya aktar
- SoC ortaminda calistir
- Beklenen: test return code 0, EOC PASS, temel UART loglari

### Asama C - Ayni testleri UVM icinde kos

- Hedef: C test stimulusunu UVM monitor/scoreboard/SVA/coverage ile birlikte gozlemek
- Not: Bu repoda SW-driven yol var; `chs_sw_driven_vseq` DRAM'a program yukleyip EOC bekliyor.
- Oneri: ELF/memh dosyalarini SW-driven teste baglayan loader katmani eklenmeli (kisa teknik backlog maddesi)

### Asama D - Coverage + Assertion kapanisi

- Functional coverage raporu kontrol
- SVA ihlalleri kontrol
- Basarisiz testlerde waveform analizi

## 4) Yeni eklenen C testleri (UVM sequence karsiliklari)

Aşağıdaki C testleri eklendi:

- `verif/sw/tests/test_concurrent.c` (chs_concurrent_vseq benzeri)
- `verif/sw/tests/test_allproto.c` (chs_cov_allproto_vseq benzeri)
- `verif/sw/tests/test_periph_stress.c` (chs_periph_stress_vseq benzeri)
- `verif/sw/tests/test_error_inject.c` (chs_error_inject_vseq CPU-safe benzeri)

Uretilen ELF dosyalari:

- `verif/sw/build/test_concurrent.elf`
- `verif/sw/build/test_allproto.elf`
- `verif/sw/build/test_periph_stress.elf`
- `verif/sw/build/test_error_inject.elf`

## 5) Error-inject konusunda onemli not

`chs_error_inject_vseq` icindeki bazı adimlar DMI/SBA'ya ozgudur (ornegin unmapped SBA access).
CPU uzerinden C kodunda bire bir aynisini yapmak trap/exception yonetimi gerektirir.
Bu nedenle C testte CPU-safe yaklasim kullanildi:

- RO register davranis kontrolu
- SPI error enable yolu
- I2C NAK tolerance yolu
- Yogun legal erisim storm sonrasi sistem canlilik kontrolu

## 6) Signoff icin karar kriteri

Yalnizca C-only gecisi signoff degildir.
Asgari kriter:

1. C-only testler PASS (sunucu/target)
2. UVM regresyonda ayni alanlar PASS
3. Coverage hedefi saglanmis
4. Kritik SVA ihlali yok
5. Waveform ile kritik akislarda beklenen protokol gorunumu dogrulanmis

## 7) Kisa operasyon plani

1. Gunluk: `verif/sw` C test derleme + hizli calisma
2. Gece: UVM regresyon + coverage merge + SVA raporu
3. Haftalik: coverage gap analizi, eksik senaryoya yeni C veya UVM test
4. Milestone: C-only + UVM + SVA + coverage birlikte pass olmadan signoff yok

## 8) Basitten zora UVM dogrulama merdiveni

### Seviye 0 - Plan ve mimari hazirlik

- SoC bellek haritasi, clock/reset topolojisi, interrupt matrisi, power domain cikar
- Verification Plan: ozellik listesi, risk listesi, olcum metrigi (coverage/assertion)
- Cikis kriteri: hangi ozellik hangi testle kapanacak tanimli olmali

### Seviye 1 - Block-Level UVM (IP bazli)

- Her IP icin agent + monitor + driver + scoreboard
- RAL modeli ve reset/access testleri
- SVA: protocol ve register davranis assertion'lari
- Burada C test genelde zorunlu degil; stimulusun buyuk kismi SV sequence

### Seviye 2 - Subsystem-Level UVM

- Interconnect + birden fazla IP birlikte
- Arbitration, backpressure, timeout, error propagation, interrupt routing
- Cross-coverage acilir (IP-A x IP-B x bus-state)
- C test burada secmeli: CPU bagimli akis varsa eklenir

### Seviye 3 - SoC-Level UVM + SW-driven

- CPU firmware calisirken UVM monitorleri aktif kalir
- ELF/memh tabanli SW testleri ile gercek yazilim akisina yaklasilir
- UVM sequence + C test senaryolari birbirini tamamlar

### Seviye 4 - SoC stress ve negatif testler

- Uzun regresyon, rastgelelestirilmis trafik, hata enjeksiyonu
- Recovery, deadlock/livelock, veri butunlugu, interrupt firtinasi
- SVA temizligi ve coverage closure takibi zorunlu

### Seviye 5 - Signoff

- Test pass oran hedefi
- Functional coverage hedefi (feature + cross)
- Assertion hedefi (kritik SVA ihlali 0)
- Regresyon stabilitesi (ardisik calismalarda tekrar edilebilirlik)

## 9) C testlerde UVM nerede kullanilir?

- Simulasyonda ELF/C testi kosuyorsaniz: UVM TAM kullanilir.
- UVM monitor, scoreboard, coverage ve SVA ayni kosuda calisir.
- Gercek kart/sunucuda sadece ELF kosuyorsaniz: UVM coverage/SVA yoktur.

Pratik yorum:

- C-only: bring-up ve fonksiyonel guven
- UVM-only: protocol/coverage guvencesi
- Hibrit: signoff'a en yakin yontem
