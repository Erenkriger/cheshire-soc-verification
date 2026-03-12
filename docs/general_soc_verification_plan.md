# General SoC Verification Plan
### A Comprehensive Guide to System-on-Chip Verification Methodology

> **Amaç:** Herhangi bir SoC projesine uygulanabilecek, endüstri standardı doğrulama
> metodolojisini adım adım anlatan, sunum niteliğinde bir referans dokümanı.

---

## İçindekiler

1. [Neden SoC Doğrulaması Zordur?](#1-neden-soc-doğrulaması-zordur)
2. [Doğrulama Planına Nereden Başlanır?](#2-doğrulama-planına-nereden-başlanır)
3. [Hedeflerin Belirlenmesi](#3-hedeflerin-belirlenmesi)
4. [Hiyerarşik Doğrulama Stratejisi](#4-hiyerarşik-doğrulama-stratejisi)
5. [UVM Ortamının Mimarisi](#5-uvm-ortamının-mimarisi)
6. [Doğrulamaya Hangi Birimden Başlanır?](#6-doğrulamaya-hangi-birimden-başlanır)
7. [İlerleme Stratejisi: Block → Subsystem → SoC](#7-i̇lerleme-stratejisi-block--subsystem--soc)
8. [Test Senaryoları Nasıl Tasarlanır?](#8-test-senaryoları-nasıl-tasarlanır)
9. [Coverage-Driven Verification (CDV)](#9-coverage-driven-verification-cdv)
10. [Assertion-Based Verification (ABV)](#10-assertion-based-verification-abv)
11. [Regression ve CI/CD Entegrasyonu](#11-regression-ve-cicd-entegrasyonu)
12. [Metrikler ve Tamamlanma Kriterleri](#12-metrikler-ve-tamamlanma-kriterleri)
13. [Sık Yapılan Hatalar ve Çözümleri](#13-sık-yapılan-hatalar-ve-çözümleri)
14. [Zaman Çizelgesi Şablonu](#14-zaman-çizelgesi-şablonu)
15. [Kontrol Listesi (Checklist)](#15-kontrol-listesi-checklist)
16. [Sonuç](#16-sonuç)

---

## 1. Neden SoC Doğrulaması Zordur?

Bir SoC, onlarca IP bloğunun ortak bir bus fabric üzerinde birbirleriyle
haberleştiği, kesmelerin (interrupt) ve DMA transferlerinin eşzamanlı
yürütüldüğü, karmaşık bir sistemdir.

### 1.1 Karmaşıklık Boyutları

| Boyut | Açıklama | Örnek |
|-------|----------|-------|
| **Yapısal** | IP sayısı, bus topolojisi, bellek haritası | 15+ IP, AXI crossbar, 2 GB adres alanı |
| **Zamansal** | Çoklu saat domainleri, asenkron köprüler | CPU 1 GHz, periferik 50 MHz, RTC 32 kHz |
| **Davranışsal** | Yazılım-donanım etkileşimi, boot akışı | Bootloader → OS → user-space driver |
| **Konfigürasyon** | Parametrik tasarım, birden fazla SKU | Tek-çekirdek vs. dört-çekirdek, cache boyutu |

### 1.2 Neden Block-Level Yeterli Değil?

```
  Block-Level'da Yakalanan Hatalar     SoC-Level'da Yakalanan Hatalar
  ─────────────────────────────────    ────────────────────────────────
  ✓ IP protokol uyumu                  ✓ Adres haritası çakışmaları
  ✓ Register read/write                ✓ Interrupt routing hataları
  ✓ FSM geçişleri                      ✓ DMA + CPU eşzamanlı erişim
  ✓ Boundary değerler                  ✓ Clock domain crossing (CDC)
  ✓ FIFO overflow/underflow            ✓ Boot akışı
                                       ✓ Güç yönetimi geçişleri
                                       ✓ Birden fazla IP'nin eşzamanlı çalışması
```

> **Endüstri verisi:** SoC seviyesindeki hataların ~%60'ı block-level testlerle
> yakalanamaz (Mentor Graphics, 2020 Functional Verification Study).

---

## 2. Doğrulama Planına Nereden Başlanır?

### 2.1 Adım 0: Tasarım Spesifikasyonunu Anlayın

Hiçbir doğrulama çalışması, tasarımı tam anlamadan başlamamalıdır.

**Okunması Gereken Dokümanlar:**

| Doküman | İçerik | Neden Önemli |
|---------|--------|--------------|
| Architecture Spec | Blok diyagramı, bellek haritası, bus topolojisi | Ortamın büyük resmini çizer |
| IP Datasheets | Her IP'nin register map'i, modları, kesmeleri | Agent ve sequence tasarımını belirler |
| Integration Guide | Pin mapping, clock/reset dağıtımı, tie-off kuralları | tb_top bağlantılarını belirler |
| Boot Flow Doc | Boot modları, ROM'dan yükleme sırası | İlk test senaryosunu belirler |
| Memory Map | Adres aralıkları, decoders, alias bölgeleri | Scoreboard ve coverage'ı etkiler |

### 2.2 Adım 1: Blok Diyagramını Çıkarın

```
┌─────────────────────────────────────────────────────────┐
│                      SoC Top                            │
│                                                         │
│  ┌─────────┐   ┌──────────────┐   ┌──────────────────┐ │
│  │  CPU(s)  │   │  Bus Fabric  │   │   Memory Ctrl    │ │
│  │ (RISC-V, │◄─►│ (AXI/AHB/   │◄─►│  (DDR/SRAM/      │ │
│  │  ARM)    │   │  APB bridge) │   │   Flash)         │ │
│  └─────────┘   └──────┬───────┘   └──────────────────┘ │
│                        │                                │
│         ┌──────────────┼──────────────┐                 │
│         ▼              ▼              ▼                 │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐            │
│  │  UART    │   │   SPI    │   │  GPIO    │ ...        │
│  └──────────┘   └──────────┘   └──────────┘            │
│                                                         │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐            │
│  │  JTAG    │   │  DMA     │   │  Timer   │            │
│  │  Debug   │   │  Engine  │   │  /WDT    │            │
│  └──────────┘   └──────────┘   └──────────┘            │
└─────────────────────────────────────────────────────────┘
```

Bu diyagramdan çıkarılacak bilgiler:

- **Kaç master var?** (CPU, DMA, Debug — eşzamanlılık senaryoları)
- **Kaç slave var?** (Periferik, bellek — adres dekoding testi)
- **Bus protokolü ne?** (AXI, AHB, APB — VIP seçimi)
- **Kaç saat domaini var?** (CDC analizi)
- **Interrupt yolları neler?** (Periferik → PLIC/NVIC → CPU)

### 2.3 Adım 2: Bellek Haritasını Tablolaştırın

```
 Adres Aralığı        │ Peripheral        │ Boyut   │ Erişim   │ Not
 ──────────────────────┼───────────────────┼─────────┼──────────┼──────────
 0x0000_0000-0x0000_FFFF │ Boot ROM         │ 64 KB   │ RO       │ Reset vektörü
 0x0001_0000-0x0001_0FFF │ Debug Module     │ 4 KB    │ RW       │ JTAG erişimi
 0x1000_0000-0x1000_0FFF │ UART0            │ 4 KB    │ RW       │ APB slave
 0x1000_1000-0x1000_1FFF │ SPI0             │ 4 KB    │ RW       │ APB slave
 0x1000_2000-0x1000_2FFF │ GPIO             │ 4 KB    │ RW       │ APB slave
 0x1000_3000-0x1000_3FFF │ I2C0             │ 4 KB    │ RW       │ APB slave
 0x2000_0000-0x2000_FFFF │ PLIC             │ 64 KB   │ RW       │ Interrupt ctrl
 0x8000_0000-0xFFFF_FFFF │ DRAM             │ 2 GB    │ RW       │ Cacheable
```

> **Neden önemli:** Her adres aralığı bir scoreboard check, bir coverage bin
> ve en az bir test senaryosu demektir.

### 2.4 Adım 3: Doğrulanabilir Özellikleri Listeleyin

Her IP ve sistem-seviye özellik için doğrulanabilir maddeler (features) çıkarın:

```
Feature ID │ Kategori     │ Açıklama                           │ Öncelik
───────────┼──────────────┼────────────────────────────────────┼─────────
F-BOOT-01  │ Boot         │ Boot ROM'dan cold boot             │ P0
F-BOOT-02  │ Boot         │ JTAG üzerinden debug boot          │ P0
F-JTAG-01  │ Debug        │ IDCODE register okunması           │ P0
F-JTAG-02  │ Debug        │ CPU halt/resume                    │ P1
F-UART-01  │ Periferik    │ Byte TX/RX @ 115200 baud           │ P0
F-UART-02  │ Periferik    │ Parity error detection             │ P1
F-DMA-01   │ Data Path    │ Memory-to-memory transfer          │ P0
F-DMA-02   │ Data Path    │ DMA + CPU concurrent access        │ P1
F-IRQ-01   │ Interrupt    │ UART RX interrupt → CPU            │ P0
F-IRQ-02   │ Interrupt    │ Multi-source interrupt priority     │ P1
F-MEM-01   │ Memory       │ Aligned/unaligned access           │ P0
F-MEM-02   │ Memory       │ Burst transfer (AXI)               │ P1
F-CDC-01   │ Clock Domain │ UART async bridge correctness      │ P2
F-PWR-01   │ Power        │ Sleep→active geçişi                │ P2
```

> **Kural:** Özellik listesi, test senaryolarıyla 1:N ilişkide olmalıdır.
> Her özellik en az bir test tarafından kapsanmalıdır.

---

## 3. Hedeflerin Belirlenmesi

### 3.1 Doğrulama Hedef Piramidi

```
                    ▲
                   ╱ ╲
                  ╱   ╲
                 ╱ P2  ╲     ← Tamamlanırsa bonus (Power, CDC corner case)
                ╱───────╲
               ╱   P1    ╲   ← Tape-out için gerekli (edge-case, error injection)
              ╱─────────── ╲
             ╱     P0       ╲ ← Mutlaka tamamlanmalı (temel fonksiyon, boot, basic I/O)
            ╱─────────────────╲
           ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
```

### 3.2 Önceliklendirme Kriterleri

| Öncelik | Tanım | Kriter | Hedef Tamamlanma |
|---------|-------|--------|------------------|
| **P0 — Critical** | Chip çalışmazsa anlamsız | Boot, temel bus erişimi, reset | %100 |
| **P1 — High** | Ürün kalitesini belirler | Interrupt, DMA, error handling | ≥%95 |
| **P2 — Medium** | Gelişmiş özellikler | Power mgmt, performans, CDC corner | ≥%80 |
| **P3 — Low** | Nice-to-have | Exotic konfigürasyonlar, stress | Best effort |

### 3.3 Coverage Hedefleri

```
┌────────────────────────────────────────────────────────────┐
│              Hedef Coverage Metrikleri                      │
├──────────────────────┬─────────┬───────────────────────────┤
│ Metrik               │ Hedef   │ Açıklama                  │
├──────────────────────┼─────────┼───────────────────────────┤
│ Code Coverage        │         │                           │
│   ├ Line Coverage    │ ≥ %90   │ Erişilmeyen satırlar      │
│   ├ Branch Coverage  │ ≥ %85   │ if/else/case dalları      │
│   ├ Toggle Coverage  │ ≥ %80   │ 0→1, 1→0 geçişleri       │
│   └ FSM Coverage     │ %100    │ Tüm durumlar + geçişler   │
├──────────────────────┼─────────┼───────────────────────────┤
│ Functional Coverage  │         │                           │
│   ├ Register Access  │ %100    │ Her register R/W          │
│   ├ Boot Mode        │ %100    │ Tüm boot modları          │
│   ├ Interrupt Path   │ ≥ %95   │ Tüm IRQ kaynakları        │
│   ├ Bus Protocol     │ ≥ %95   │ Burst, size, lock, atomic │
│   ├ DMA Transfer     │ ≥ %90   │ Kaynak × hedef × boyut    │
│   └ Error Injection  │ ≥ %85   │ Parity, timeout, decode   │
├──────────────────────┼─────────┼───────────────────────────┤
│ Assertion Coverage   │ %100    │ Tüm SVA pass etmeli       │
└──────────────────────┴─────────┴───────────────────────────┘
```

### 3.4 "Done" Tanımını Belirleyin

Bir SoC doğrulaması ne zaman "tamamlanmış" sayılır?

```
✅ Tüm P0 testler PASS
✅ Tüm P1 testler PASS (waiver'lar document edilmiş)
✅ Code coverage hedefleri karşılanmış
✅ Functional coverage hedefleri karşılanmış
✅ 0 adet açık Severity-1/2 bug
✅ Regression suite 3 gün üst üste temiz
✅ Coverage kapatılmış (closure analysis tamamlanmış)
✅ Review board onayı alınmış
```

---

## 4. Hiyerarşik Doğrulama Stratejisi

### 4.1 Üç Katmanlı Yaklaşım

```
  Seviye 3: SoC-Level ─────────────────────────────────────────
  │  ◆ Sistem senaryoları (boot, interrupt routing, DMA + CPU)
  │  ◆ Virtual sequences ile çoklu agent koordinasyonu
  │  ◆ Embedded SW testleri (baremetal)
  │  ◆ Power-aware verification
  │
  Seviye 2: Subsystem-Level ───────────────────────────────────
  │  ◆ Bus fabric + birkaç IP birlikte
  │  ◆ Arbiter, decoder doğrulaması
  │  ◆ Clock domain crossing testi
  │  ◆ Multi-master erişim senaryoları
  │
  Seviye 1: Block-Level (IP-Level) ────────────────────────────
     ◆ Tek IP, izole ortamda
     ◆ Protokol uyumu, register map, FSM
     ◆ Boundary değerler, error injection
     ◆ %100 code + functional coverage hedefi
```

### 4.2 Katmanlar Arası Yeniden Kullanım

```
                    Block-Level          SoC-Level
                   ┌───────────┐       ┌──────────────────────┐
  Agent            │ uart_agent│──────►│ uart_agent (aynı)    │
                   └───────────┘       └──────────────────────┘
                   ┌───────────┐       ┌──────────────────────┐
  Sequence         │uart_base_ │──────►│ uart_base_seq        │
                   │seq        │       │   (IP seq olarak)    │
                   └───────────┘       └──────────────────────┘
                                       ┌──────────────────────┐
  Virtual Seq      (yok)               │ soc_boot_vseq        │
                                       │   ├─ jtag_seq        │
                                       │   ├─ uart_seq        │
                                       │   └─ gpio_seq        │
                                       └──────────────────────┘
```

> **Altın Kural:** Block-level agent'lar %100 yeniden kullanılabilir olmalıdır.
> SoC seviyesinde yeni agent yazmak yerine, var olanları virtual
> sequencer ile orkestra edin.

### 4.3 Ne Nerede Test Edilir?

| Feature | Block | Subsystem | SoC | Gerekçe |
|---------|:-----:|:---------:|:---:|---------|
| Register R/W | ✅ | — | — | İzole ortamda daha hızlı |
| Protokol uyumu | ✅ | — | — | VIP ile %100 coverage |
| Interrupt routing | — | ✅ | ✅ | Birden fazla IP gerekli |
| DMA transfer | — | ✅ | ✅ | DMA + memory + arbiter |
| Boot akışı | — | — | ✅ | Tüm SoC gerekli |
| Multi-master contention | — | ✅ | — | Crossbar + 2-3 master yeterli |
| Power sequence | — | — | ✅ | Global power controller |
| End-to-end data path | — | — | ✅ | CPU → bus → periferik → pin |

---

## 5. UVM Ortamının Mimarisi

### 5.1 Genel SoC UVM Ortam Diyagramı

```
┌─────────────────── uvm_test ──────────────────────────────────────────────┐
│                                                                           │
│  ┌─────────────────── soc_env ──────────────────────────────────────────┐ │
│  │                                                                      │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │ │
│  │  │ jtag_    │ │ uart_    │ │ spi_     │ │ i2c_     │ │ gpio_    │  │ │
│  │  │ agent    │ │ agent    │ │ agent    │ │ agent    │ │ agent    │  │ │
│  │  │ ┌─drv──┐ │ │ ┌─drv──┐ │ │ ┌─drv──┐ │ │ ┌─drv──┐ │ │ ┌─drv──┐ │  │ │
│  │  │ │      │ │ │ │      │ │ │ │      │ │ │ │      │ │ │ │      │ │  │ │
│  │  │ ├─mon──┤ │ │ ├─mon──┤ │ │ ├─mon──┤ │ │ ├─mon──┤ │ │ ├─mon──┤ │  │ │
│  │  │ │  ap  │ │ │ │  ap  │ │ │ │  ap  │ │ │ │  ap  │ │ │ │  ap  │ │  │ │
│  │  │ └──┬───┘ │ │ └──┬───┘ │ │ └──┬───┘ │ │ └──┬───┘ │ │ └──┬───┘ │  │ │
│  │  └────┼─────┘ └────┼─────┘ └────┼─────┘ └────┼─────┘ └────┼─────┘  │ │
│  │       │            │            │            │            │         │ │
│  │       ▼            ▼            ▼            ▼            ▼         │ │
│  │  ┌────────────────────────────────────────────────────────────────┐  │ │
│  │  │                     soc_scoreboard                            │  │ │
│  │  │  ┌──────────────────────────────────────────────────────────┐ │  │ │
│  │  │  │  Protocol checkers │ Data integrity │ Ordering checks   │ │  │ │
│  │  │  └──────────────────────────────────────────────────────────┘ │  │ │
│  │  └────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                      │ │
│  │  ┌───────────────────────┐  ┌──────────────────────────────────────┐ │ │
│  │  │  soc_virtual_         │  │         soc_coverage                 │ │ │
│  │  │  sequencer            │  │  ┌─────────┐ ┌────────┐ ┌────────┐  │ │ │
│  │  │  ├─ jtag_sqr handle   │  │  │ boot_cg │ │ irq_cg │ │ bus_cg │  │ │ │
│  │  │  ├─ uart_sqr handle   │  │  └─────────┘ └────────┘ └────────┘  │ │ │
│  │  │  ├─ spi_sqr handle    │  └──────────────────────────────────────┘ │ │
│  │  │  ├─ i2c_sqr handle    │                                           │ │
│  │  │  └─ gpio_sqr handle   │  ┌──────────────────────────────────────┐ │ │
│  │  └───────────────────────┘  │         reg_model (RAL)              │ │ │
│  │                              │  ┌──────┐ ┌──────┐ ┌──────┐        │ │ │
│  │                              │  │ uart │ │ spi  │ │ gpio │ ...    │ │ │
│  │                              │  │ regs │ │ regs │ │ regs │        │ │ │
│  │                              │  └──────┘ └──────┘ └──────┘        │ │ │
│  │                              └──────────────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌──────────────────── tb_top ──────────────────────────────────────────┐ │
│  │  DUT (soc_top)  +  interfaces  +  clock/reset  +  config_db        │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Temel Bileşenler ve Sorumlulukları

| Bileşen | Sorumluluğu | Anahtar Kural |
|---------|-------------|---------------|
| **Agent** | Protokol seviyesinde stimulus üretme ve gözlemleme | 1 agent = 1 protokol arayüzü |
| **Driver** | Sequence item'ları fiziksel sinyallere çevirme | Sadece interface üzerinden DUT'a erişir |
| **Monitor** | Fiziksel sinyalleri gözlemleyip transaction'a çevirme | Pasif — sinyalleri asla sürmez |
| **Sequencer** | Transaction akışını yönetme | Agent içinde, driver'a bağlı |
| **Scoreboard** | Beklenen vs. gerçekleşen sonuçları karşılaştırma | Analysis port üzerinden dinler |
| **Coverage** | Fonksiyonel kapsama verisi toplama | Covergroup'lar transaction bazlı |
| **Virtual Sequencer** | Birden fazla agent'ı koordine etme | Sequencer handle'ları tutar |
| **Reg Model (RAL)** | Register map'i modelleme ve otomatik test üretme | Spec'ten otomatik üretilebilir |
| **Environment** | Tüm bileşenleri bir araya getirme | Koşullu instantiation destekler |
| **Test** | Senaryoyu tanımlama ve ortamı konfigüre etme | 1 test = 1 senaryo |
| **tb_top** | DUT + interface + config_db + run_test() | UVM dışı, modül seviyesi |

### 5.3 Agent Tasarım Prensipleri

```
 Prensip                      │ Açıklama
 ─────────────────────────────┼───────────────────────────────────────────────
 Configurable Active/Passive  │ is_active flag ile driver dahil/hariç
 Protocol-Complete            │ Her protokol varyantını destekle
 Self-Checking                │ Monitor kendi başına geçerli transaction üretir
 Factory Registered           │ `uvm_component_utils` / `uvm_object_utils`
 Config DB Driven             │ Virtual interface ve config nesnesi config_db ile
 Analysis Port                │ Monitor → ap → scoreboard/coverage bağlantısı
 Reusable                     │ Block-level ortamda da SoC-level ortamda da çalışır
```

---

## 6. Doğrulamaya Hangi Birimden Başlanır?

### 6.1 Başlangıç Sıralaması Karar Ağacı

```
                        Başla
                          │
                ┌─────────▼──────────┐
                │ DUT boot edebiliyor │
                │ mu? (Reset çıkışı)  │
                └─────────┬──────────┘
                     Hayır│
                          ▼
              ┌───────────────────────┐
              │  1. Clock/Reset       │ ◄── Her şeyin temeli
              │     doğrulaması       │
              └───────────┬───────────┘
                          │
              ┌───────────▼───────────┐
              │  2. JTAG / Debug      │ ◄── DUT'a ilk erişim noktası
              │     agent             │     (register okuma/yazma)
              └───────────┬───────────┘
                          │
              ┌───────────▼───────────┐
              │  3. Bus Fabric        │ ◄── Tüm IP'lere erişim altyapısı
              │     (AXI/AHB/APB)     │
              └───────────┬───────────┘
                          │
              ┌───────────▼───────────┐
              │  4. İlk Periferik     │ ◄── Genellikle UART (debug çıktısı)
              │     (UART)            │
              └───────────┬───────────┘
                          │
              ┌───────────▼───────────┐
              │  5. Diğer Periferikler│ ◄── SPI, I2C, GPIO, Timer...
              └───────────┬───────────┘
                          │
              ┌───────────▼───────────┐
              │  6. Interrupt Sistemi │ ◄── PLIC/NVIC → CPU
              └───────────┬───────────┘
                          │
              ┌───────────▼───────────┐
              │  7. DMA Engine        │ ◄── Karmaşık data path
              └───────────┬───────────┘
                          │
              ┌───────────▼───────────┐
              │  8. Sistem Senaryoları│ ◄── Boot, concurrent, power
              └───────────────────────┘
```

### 6.2 Gerekçeli Sıralama

| Sıra | Birim | Gerekçe |
|------|-------|---------|
| **1** | Clock/Reset | Her şeyin temeli. Reset sırası yanlışsa hiçbir test çalışmaz |
| **2** | JTAG/Debug | DUT'a ilk backdoor erişimi sağlar. Register okuyarak diğer IP'leri kontrol edebiliriz |
| **3** | Bus Fabric | Tüm IP'ler bus üzerinden erişilir. Bus doğru çalışmadan IP testleri anlamsız |
| **4** | UART | En basit periferik. Debug mesajları için kullanılır. Hızla smoke test sağlar |
| **5** | Diğer Periferikler | SPI, I2C, GPIO — karmaşıklık artan sırada |
| **6** | Interrupt | Periferikler çalıştıktan sonra interrupt routing doğrulanır |
| **7** | DMA | En karmaşık data path — birden fazla master, arbiter, bellek erişimi |
| **8** | Sistem | Tüm parçalar çalıştıktan sonra end-to-end senaryolar |

> **Pratik İpucu:** JTAG agent'ı erken hazır olsun — diğer tüm IP'lerin register
> erişimi JTAG üzerinden System Bus Access (SBA) ile yapılabilir.

---

## 7. İlerleme Stratejisi: Block → Subsystem → SoC

### 7.1 Faz 1: Temel Altyapı (Hafta 1-2)

```
Hedef: "DUT ayağa kalkıyor mu?"

Çıktılar:
 ☐ tb_top.sv — DUT instantiation, clock/reset generation
 ☐ Temel interface dosyaları (JTAG, UART en azından)
 ☐ Simülasyon scripti (compile + run)
 ☐ İlk "hello world" testi: reset → clock çalışıyor → timeout yok
```

### 7.2 Faz 2: İlk Agent + Smoke Test (Hafta 3-4)

```
Hedef: "DUT ile iletişim kurabiliyor muyuz?"

Çıktılar:
 ☐ JTAG agent (full TAP state machine)
 ☐ IDCODE okuma testi (ilk gerçek veri doğrulaması)
 ☐ Debug Module üzerinden basit register R/W
 ☐ UART agent (TX monitor en azından)
 ☐ Scoreboard iskelet yapısı
```

### 7.3 Faz 3: Periferik Agent'lar (Hafta 5-8)

```
Hedef: "Her protokol arayüzü çalışıyor mu?"

Çıktılar:
 ☐ SPI agent (slave mode — DUT master'dır)
 ☐ I2C agent (slave mode — open-drain model)
 ☐ GPIO agent (stimulus + monitor)
 ☐ Timer/WDT agent (gerekirse)
 ☐ Her agent için block-level base sequence
 ☐ Her agent için kendi smoke testi
```

### 7.4 Faz 4: Environment Entegrasyon (Hafta 9-10)

```
Hedef: "Tüm parçalar birlikte çalışıyor mu?"

Çıktılar:
 ☐ soc_env — tüm agent'ları barındırır
 ☐ soc_virtual_sequencer — agent handle'ları
 ☐ soc_scoreboard — per-protocol analysis
 ☐ soc_coverage — covergroup'lar
 ☐ soc_env_config — koşullu agent oluşturma
 ☐ Entegrasyon smoke testi
```

### 7.5 Faz 5: Virtual Sequence'lar + Sistem Testleri (Hafta 11-14)

```
Hedef: "Gerçek kullanım senaryoları çalışıyor mu?"

Çıktılar:
 ☐ Boot sequence (JTAG boot, SPI flash boot, ROM boot)
 ☐ Interrupt routing testi (periferik → PLIC → CPU)
 ☐ DMA transfer testi (memory-to-peripheral, M2M)
 ☐ Concurrent access testi (CPU + DMA aynı anda)
 ☐ Error injection testleri
 ☐ Register model (RAL) entegrasyonu
```

### 7.6 Faz 6: Coverage Closure + Regression (Hafta 15-18)

```
Hedef: "Hedef coverage'a ulaştık mı?"

Çıktılar:
 ☐ Coverage analizi raporu
 ☐ Coverage hole'larını kapatan ek testler
 ☐ Constrained-random testler ile corner case keşfi
 ☐ Regression suite (otomatik, CI/CD entegre)
 ☐ Waiver dokümanı (cover edilemeyen noktalar için)
 ☐ Final coverage raporu + sign-off
```

### 7.7 Faz Geçiş Kriterleri

```
 Faz 1 → Faz 2:  DUT derlenir, reset çalışır, simülasyon timeout'suz biter
 Faz 2 → Faz 3:  JTAG IDCODE doğru okunur, en az 1 register R/W başarılı
 Faz 3 → Faz 4:  Her agent kendi smoke testini geçer
 Faz 4 → Faz 5:  Entegrasyon smoke testi geçer (tüm agent'lar aktif)
 Faz 5 → Faz 6:  P0 testlerin %100'ü, P1 testlerin %80'i PASS
 Faz 6 → Sign-off: Tüm coverage hedefleri karşılanmış, 0 Sev-1/2 bug
```

---

## 8. Test Senaryoları Nasıl Tasarlanır?

### 8.1 Test Kategorileri

```
┌──────────────────────────────────────────────────────────────┐
│                    TEST KATEGORİLERİ                         │
├──────────────────┬───────────────────────────────────────────┤
│ Sanity / Smoke   │ En temel fonksiyon kontrolü               │
│                  │ "DUT canlı mı?" sorusuna cevap            │
├──────────────────┼───────────────────────────────────────────┤
│ Directed         │ Belirli bir feature'ı hedefleyen test     │
│                  │ Spec'ten derive edilen deterministik test │
├──────────────────┼───────────────────────────────────────────┤
│ Constrained      │ Rastgele ama kısıtlı stimulus            │
│ Random           │ Corner case keşfi, coverage closure       │
├──────────────────┼───────────────────────────────────────────┤
│ Error Injection  │ Hatalı girdi/zamanlama/protokol ihlali    │
│                  │ DUT'un hata yönetimini test eder          │
├──────────────────┼───────────────────────────────────────────┤
│ Stress / Corner  │ Sınır değerler, max throughput, FIFO dolu │
│                  │ Performans ve dayanıklılık testi          │
├──────────────────┼───────────────────────────────────────────┤
│ Power-Aware      │ Sleep → active geçişleri, clock gating   │
│                  │ Retention register doğrulaması            │
├──────────────────┼───────────────────────────────────────────┤
│ End-to-End       │ Gerçek kullanım senaryosu                 │
│                  │ CPU kodu çalıştırma, DMA + IRQ + I/O      │
└──────────────────┴───────────────────────────────────────────┘
```

### 8.2 Test Senaryosu Şablonu

Her test senaryosu için aşağıdaki bilgiler belgelenmelidir:

```
╔══════════════════════════════════════════════════════════════╗
║  TEST SENARYOSU KARTI                                        ║
╠══════════════════════════════════════════════════════════════╣
║  Test ID      : T-UART-003                                   ║
║  Başlık       : UART Loopback with Parity Error               ║
║  Öncelik      : P1                                            ║
║  Kategori     : Error Injection                                ║
║  İlgili Feature: F-UART-02 (Parity error detection)           ║
║                                                                ║
║  Ön Koşullar  :                                                ║
║    - DUT reset tamamlanmış                                     ║
║    - UART baud rate 115200, 8E1 (even parity) konfigüre        ║
║                                                                ║
║  Stimulus     :                                                ║
║    1. UART agent üzerinden doğru pariteli 5 byte gönder        ║
║    2. 6. byte'ı yanlış parity ile gönder                       ║
║    3. 7. byte'ı tekrar doğru parity ile gönder                 ║
║                                                                ║
║  Beklenen Sonuç:                                               ║
║    - İlk 5 byte başarılı alınır (scoreboard match)             ║
║    - 6. byte için parity error interrupt oluşur                ║
║    - Error flag register'da set edilir                          ║
║    - 7. byte başarılı alınır (error recovery)                  ║
║                                                                ║
║  Coverage Bin : uart_cg.parity_error (hit)                     ║
║  Assertion    : assert_uart_parity_check                       ║
╚══════════════════════════════════════════════════════════════╝
```

### 8.3 Tipik SoC Test Senaryoları Kataloğu

| ID | Senaryo | Kategori | Öncelik | İlgili Birimler |
|----|---------|----------|---------|-----------------|
| T-001 | Cold boot from ROM | Sanity | P0 | Boot ROM, CPU, Bus |
| T-002 | JTAG IDCODE read | Sanity | P0 | JTAG, Debug Module |
| T-003 | JTAG debug boot | Directed | P0 | JTAG, CPU, Bus, Memory |
| T-004 | SPI flash boot | Directed | P0 | SPI, Boot ROM, CPU |
| T-005 | UART TX single byte | Sanity | P0 | UART |
| T-006 | UART RX + interrupt | Directed | P1 | UART, PLIC, CPU |
| T-007 | UART baud rate sweep | Random | P1 | UART |
| T-008 | SPI flash read (Quad) | Directed | P1 | SPI |
| T-009 | I2C EEPROM write/read | Directed | P1 | I2C |
| T-010 | GPIO output toggle | Sanity | P0 | GPIO |
| T-011 | GPIO input interrupt | Directed | P1 | GPIO, PLIC |
| T-012 | DMA M2M transfer | Directed | P1 | DMA, Bus, Memory |
| T-013 | DMA M2P (→UART) | Directed | P1 | DMA, UART, Bus |
| T-014 | Multi-IRQ priority | Directed | P1 | PLIC, multiple IP |
| T-015 | CPU + DMA concurrent | Stress | P1 | CPU, DMA, Arbiter |
| T-016 | All registers R/W | Directed | P0 | All IP via RAL |
| T-017 | Address decode error | Error | P1 | Bus, Decoder |
| T-018 | UART parity error | Error | P1 | UART |
| T-019 | Watchdog timeout | Directed | P2 | WDT, Reset Ctrl |
| T-020 | Max burst AXI | Stress | P2 | Bus Fabric |

---

## 9. Coverage-Driven Verification (CDV)

### 9.1 CDV Döngüsü

```
  ┌─────────┐     ┌──────────────┐     ┌──────────────┐
  │ Test Yaz │────►│ Simülasyon   │────►│ Coverage     │
  │ / Düzenle│     │ Çalıştır     │     │ Analiz Et    │
  └─────────┘     └──────────────┘     └───────┬──────┘
       ▲                                        │
       │           ┌──────────────┐              │
       └───────────│ Hole'ları    │◄─────────────┘
                   │ Tespit Et    │
                   └──────────────┘
```

> Döngü, tüm coverage hedefleri karşılanana kadar tekrar eder.

### 9.2 Functional Coverage Yapı Taşları

```systemverilog
// ═══════ Covergroup Şablonu ═══════
covergroup soc_boot_cg @(posedge clk);
    option.per_instance = 1;
    option.name = "soc_boot_coverage";

    // Her boot modu denenmiş mi?
    cp_boot_mode: coverpoint boot_mode {
        bins rom_boot   = {2'b00};
        bins spi_boot   = {2'b01};
        bins jtag_boot  = {2'b10};
        bins uart_boot  = {2'b11};
    }

    // Boot başarılı mı?
    cp_boot_status: coverpoint boot_success {
        bins success = {1'b1};
        bins fail    = {1'b0};
    }

    // Cross: Her modda boot başarılı mı?
    cx_boot: cross cp_boot_mode, cp_boot_status;
endgroup
```

### 9.3 Code Coverage vs. Functional Coverage

```
              Code Coverage                    Functional Coverage
         ┌───────────────────────┐        ┌────────────────────────────┐
         │ "RTL kodunun ne kadarı│        │ "Spec'teki feature'ların   │
         │  çalıştırıldı?"       │        │  ne kadarı test edildi?"   │
         ├───────────────────────┤        ├────────────────────────────┤
         │ ✓ Otomatik toplanır   │        │ ✓ Manuel tanımlanır        │
         │ ✓ Line, branch, FSM,  │        │ ✓ Coverpoint, covergroup, │
         │   toggle, condition   │        │   cross coverage           │
         │ ✗ Spec bilmez         │        │ ✗ RTL bilmez               │
         │ ✗ Yanlış pozitif var  │        │ ✗ Eksik tanım riski        │
         └───────────────────────┘        └────────────────────────────┘

         ► İkisi birlikte kullanılmalıdır.
         ► Code coverage %100 olsa bile, functional coverage eksikse
           spec'e uygunluk garanti edilemez.
```

### 9.4 Coverage Closure Süreci

```
Adım 1: Coverage raporunu incele
    │
    ├── Hit olmayan functional coverage bin'leri → Yeni directed test yaz
    │
    ├── Düşük code coverage bölgeleri → Analiz et:
    │       ├── Dead code mu? → Waiver yaz + exclude
    │       ├── Error path mı? → Error injection testi yaz
    │       └── Rare condition mı? → Constrained-random bias ayarla
    │
    └── Tüm hedefler karşılandı mı?
            ├── Evet → Sign-off raporu hazırla
            └── Hayır → Döngüye devam et
```

---

## 10. Assertion-Based Verification (ABV)

### 10.1 Assertion Türleri

| Tür | Konum | Amaç | Örnek |
|-----|-------|------|-------|
| **Interface Assertion** | Agent/Monitor | Protokol uyumu | AXI handshake kuralları |
| **Design Assertion** | RTL modülü içi | Tasarım kuralı | FIFO never overflow |
| **End-to-End Assertion** | tb_top veya env | Sistem davranışı | Interrupt 10 cycle içinde CPU'ya ulaşır |

### 10.2 Örnek SVA Assertion'lar

```systemverilog
// AXI: VALID düşmemeli, READY gelene kadar
property axi_valid_stable;
    @(posedge clk) disable iff (!rst_n)
    (axi_awvalid && !axi_awready) |=> axi_awvalid;
endproperty
assert property (axi_valid_stable)
    else `uvm_error("AXI_PROTOCOL", "AWVALID dropped before AWREADY")

// UART: Start bit sonrası 8 data bit gelmeli
property uart_frame_complete;
    @(posedge clk) disable iff (!rst_n)
    $fell(uart_rx) |-> ##(BIT_PERIOD * 10) 1'b1;  // 1 start + 8 data + 1 stop
endproperty

// Interrupt: Assert edildikten sonra N cycle içinde acknowledge
property irq_latency_check(int max_cycles);
    @(posedge clk) disable iff (!rst_n)
    $rose(irq_pending) |-> ##[1:max_cycles] irq_ack;
endproperty
```

---

## 11. Regression ve CI/CD Entegrasyonu

### 11.1 Regression Stratejisi

```
 Seviye           │ Tetikleyici         │ Test Seti      │ Süre
 ─────────────────┼─────────────────────┼────────────────┼──────────
 Commit Smoke     │ Her git push        │ 5-10 sanity    │ < 10 dk
 Nightly          │ Her gece 00:00      │ Tüm P0+P1      │ 2-4 saat
 Weekly Full      │ Pazar 00:00         │ Tüm testler    │ 8-24 saat
 Release          │ Milestone öncesi    │ Tüm + stress   │ 24-72 saat
```

### 11.2 CI Pipeline Yapısı

```
  ┌──────────┐    ┌───────────┐    ┌────────────┐    ┌──────────────┐
  │ git push │───►│ Compile   │───►│ Smoke Test │───►│ Coverage     │
  │          │    │ (lint +   │    │ (5-10 test)│    │ Merge +      │
  │          │    │  elab)    │    │            │    │ Report       │
  └──────────┘    └─────┬─────┘    └─────┬──────┘    └──────┬───────┘
                   FAIL │           FAIL │                   │
                        ▼                ▼                   ▼
                   ┌─────────────────────────────────────────────┐
                   │         Slack/Email Bildirim                │
                   └─────────────────────────────────────────────┘
```

### 11.3 Seed Yönetimi

```
 Kural                              │ Gerekçe
 ───────────────────────────────────┼───────────────────────────────
 Her çalışmada random seed kaydet   │ Hata tekrar üretilebilir olmalı
 Fail eden seed'ler regression'a    │ Regression edilen hata tekrar
 eklensin                           │ edilebilir olmalı
 Minimum 10 farklı seed ile çalıştır│ Rastgele coverage artışı sağlar
 Seed=0 ile deterministik run       │ Debug için sabit referans noktası
```

---

## 12. Metrikler ve Tamamlanma Kriterleri

### 12.1 Haftalık İzleme Metrikleri

```
 Metrik                          │ Formül / Kaynak
 ────────────────────────────────┼──────────────────────────────
 Test Geçme Oranı                │ PASS / (PASS + FAIL) × 100
 Bug Bulma Hızı                  │ Yeni bug / hafta
 Bug Kapatma Hızı                │ Kapatılan bug / hafta
 Coverage Artış Hızı             │ ΔCoverage / hafta
 Regression Kararlılığı          │ Üst üste temiz geçen gün sayısı
 Açık Bug Sayısı (Sev-1/2)      │ Bug tracker'dan
```

### 12.2 Olgunluk Modeli

```
 Seviye │ Durum               │ Gösterge
 ───────┼──────────────────── ┼──────────────────────────────────
   0    │ Ortam yok           │ Simülasyon yapılamıyor
   1    │ Compile başarılı    │ DUT + TB derleniyor
   2    │ İlk test PASS       │ Smoke test geçiyor
   3    │ Agent'lar çalışıyor │ Her protokol basit TX/RX yapıyor
   4    │ Scoreboard aktif    │ Otomatik hata tespiti var
   5    │ Coverage toplanıyor │ Functional + code coverage raporlanıyor
   6    │ Coverage closure    │ Hedefler karşılanmış, regression stabil
   7    │ Sign-off            │ Tüm kriterler karşılanmış, onay alınmış
```

### 12.3 Bug Ciddiyet Seviyeleri

| Seviye | Tanım | Etki | Örnek |
|--------|-------|------|-------|
| **Sev-1** | Blocker | Chip çalışmaz | Bus deadlock, boot hatası |
| **Sev-2** | Critical | Major fonksiyon bozuk | Interrupt hiç gelmiyor |
| **Sev-3** | Major | Fonksiyon kısmen bozuk | UART 1 modda hatalı |
| **Sev-4** | Minor | Kozmetik / performance | Register reset değeri yanlış |

---

## 13. Sık Yapılan Hatalar ve Çözümleri

### 13.1 Ortam Tasarımı Hataları

| # | Hata | Sonuç | Çözüm |
|---|------|-------|-------|
| 1 | Agent'ı block-level'a özel yazmak | SoC'de yeniden kullanılamaz | Config flag'ler ile parametrik yap |
| 2 | `new()` içinde logic yazmak | Phase ordering sorunları | `build_phase` / `connect_phase` kullan |
| 3 | Virtual interface'i hard-code etmek | Farklı DUT'larda çalışmaz | `uvm_config_db` ile geçir |
| 4 | Scoreboard'u agent içine gömmek | Yeniden kullanılamaz | Ayrı bileşen, analysis port ile bağla |
| 5 | Monitor'ü driver'a bağımlı yapmak | Passive modda çalışmaz | Monitor bağımsız, sadece sinyal gözler |

### 13.2 Test Yazma Hataları

| # | Hata | Sonuç | Çözüm |
|---|------|-------|-------|
| 1 | Sadece directed test yazmak | Corner case kaçırılır | Constrained-random ekle |
| 2 | Timeout koymamak | Simülasyon sonsuza kadar çalışır | `phase.raise_objection` + watchdog |
| 3 | Hata mesajını ignor etmek | Gerçek bug maskelenir | `UVM_ERROR` count > 0 → FAIL |
| 4 | Sıralama bağımlılığı | Farklı seed'de fail | Sequence item bağımsızlığı sağla |
| 5 | Coverage'ı test bitiminde kontrol etmemek | Eksik coverage fark edilmez | `report_phase`'de coverage summary |

### 13.3 SoC Entegrasyon Hataları

| # | Hata | Sonuç | Çözüm |
|---|------|-------|-------|
| 1 | Fixture VIP ile UVM agent çakışması | Sinyal çatışması, X propagation | Ya fixture bypass et, ya VIP devre dışı bırak |
| 2 | Clock domain geçişini test etmemek | Silicon'da metastability | CDC assertion + async FIFO testi |
| 3 | Reset sırasını yanlış yapmak | IP'ler tanımsız durumda | Reset spec'ine uygun sıralı release |
| 4 | Memory model koymamak | AXI slave yanıt vermez, deadlock | `axi_sim_mem` veya benzeri model kullan |
| 5 | Parametre uyumsuzluğu | Compile hatası veya yanlış davranış | DUT parametrelerini tb_top'ta tam eşle |

---

## 14. Zaman Çizelgesi Şablonu

### 14.1 18 Haftalık Plan (Orta Ölçekli SoC)

```
Hafta  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18
───────────────────────────────────────────────────────────────
Faz 1: Altyapı
       ██ ██
Faz 2: İlk Agent + Smoke
             ██ ██
Faz 3: Periferik Agent'lar
                   ██ ██ ██ ██
Faz 4: Environment Entegrasyon
                               ██ ██
Faz 5: Virtual Seq + Sistem Testleri
                                     ██ ██ ██ ██
Faz 6: Coverage Closure + Regression
                                                 ██ ██ ██ ██
Sign-off Review ─────────────────────────────────────────── ◆

Milestone'lar:
  M1 (Hafta 2):  DUT derlenir, ilk simülasyon çalışır
  M2 (Hafta 4):  JTAG IDCODE okunur (ilk gerçek veri)
  M3 (Hafta 8):  Tüm agent'lar smoke test geçer
  M4 (Hafta 10): Entegrasyon smoke test PASS
  M5 (Hafta 14): Tüm P0 testler PASS
  M6 (Hafta 18): Coverage hedefleri karşılanmış, sign-off
```

### 14.2 Kaynak Tahmini

| Rol | Kişi-Hafta | Çıktı |
|-----|-----------|-------|
| Senior Verification Engineer | 18 hafta | Ortam mimarisi, complex sequences, coverage closure |
| Verification Engineer (Mid) | 14 hafta | Agent geliştirme, directed test yazma |
| Verification Engineer (Jr) | 10 hafta | Register test, GPIO test, regression izleme |
| **Toplam** | **42 kişi-hafta** | Orta ölçekli SoC için |

> **Not:** Gerçek süre SoC karmaşıklığına, IP sayısına ve ekip deneyimine
> göre %50 oranında değişebilir.

---

## 15. Kontrol Listesi (Checklist)

### 15.1 Ortam Hazırlık Checklist'i

```
☐ Tasarım spesifikasyonu okundu ve anlaşıldı
☐ Blok diyagramı ve bellek haritası çıkarıldı
☐ Feature listesi hazırlandı ve önceliklendirildi
☐ Coverage hedefleri belirlendi
☐ tb_top.sv oluşturuldu (DUT + interface + config_db)
☐ Clock/reset generation test edildi
☐ Simülasyon scripti çalışıyor (compile + run)
☐ İlk smoke test PASS
```

### 15.2 Agent Kalite Checklist'i (Her Agent İçin)

```
☐ Interface dosyası (clocking block + modport)
☐ Transaction sınıfı (constraint + field macros)
☐ Config sınıfı (is_active + parametreler)
☐ Driver (active modda çalışır)
☐ Monitor (passive modda çalışır, driver'dan bağımsız)
☐ Analysis port bağlı (scoreboard + coverage)
☐ Sequencer tanımlı
☐ Agent sınıfı (factory registered, config_db driven)
☐ Package dosyası (doğru include sırası)
☐ Block-level smoke test PASS
☐ Passive modda test PASS (sadece monitor)
```

### 15.3 SoC Entegrasyon Checklist'i

```
☐ Tüm agent'lar env içinde instantiate ediliyor
☐ Virtual sequencer tüm agent handle'larını tutuyor
☐ Scoreboard tüm analysis portlarına bağlı
☐ Coverage collector aktif
☐ Boot sequence testi PASS
☐ Her periferik en az 1 test ile doğrulanmış
☐ Interrupt routing en az 1 kaynakla test edilmiş
☐ Register R/W testi (RAL varsa)
☐ Regression suite hazır ve CI/CD'ye entegre
```

### 15.4 Sign-off Checklist'i

```
☐ Tüm P0 testler PASS                    — %100
☐ Tüm P1 testler PASS (waiver dahil)     — ≥%95
☐ Line coverage                           — ≥%90
☐ Branch coverage                         — ≥%85
☐ Toggle coverage                         — ≥%80
☐ FSM coverage                            — %100
☐ Functional coverage hedefleri           — Met
☐ 0 açık Sev-1 bug
☐ ≤3 açık Sev-2 bug (waiver ile)
☐ Regression 3+ gün stabil
☐ Coverage closure raporu tamamlanmış
☐ Review board onayı alınmış
```

---

## 16. Sonuç

### 16.1 Temel Prensipler Özeti

```
 1. PLAN FIRST   │ Kodu yazmaya başlamadan önce plan hazırla.
                  │ "1 saat planlama, 10 saat debug'ı önler."
 ─────────────────┼──────────────────────────────────────────────
 2. REUSE         │ Block-level agent'ları SoC'de %100 yeniden kullan.
                  │ Yeni agent yazmak son çare olmalı.
 ─────────────────┼──────────────────────────────────────────────
 3. AUTOMATE      │ Regression, coverage raporlama, CI/CD —
                  │ her tekrarlayan işi otomatikleştir.
 ─────────────────┼──────────────────────────────────────────────
 4. MEASURE       │ Coverage olmadan ilerleme ölçülemez.
                  │ "Ölçemediğin şeyi yönetemezsin."
 ─────────────────┼──────────────────────────────────────────────
 5. ITERATE       │ CDV döngüsü — test → run → analyze → repeat.
                  │ Coverage hole bulunduğunda döngüye devam.
 ─────────────────┼──────────────────────────────────────────────
 6. COMMUNICATE   │ Bug raporları, coverage trendleri, milestone
                  │ durumu — herkes aynı sayfada olmalı.
```

### 16.2 Bu Planı Farklı SoC'lere Uygulama

Bu doküman herhangi bir SoC'ye uygulanabilir. Değişen sadece şunlardır:

| Değişen | Sabit Kalan |
|---------|-------------|
| IP listesi ve sayısı | Hiyerarşik strateji (Block→Sub→SoC) |
| Bus protokolü (AXI/AHB/APB/Wishbone) | UVM ortam mimarisi |
| Bellek haritası | CDV döngüsü |
| Boot akışı | Agent tasarım prensipleri |
| Interrupt topolojisi | Coverage hedef yapısı |
| Saat domainleri | Regression stratejisi |

> **Son söz:** İyi bir doğrulama ortamı, DUT'tan daha uzun ömürlüdür.
> Bugün yazdığınız agent'lar, yarın farklı bir SoC'de de çalışır —
> yeter ki yeniden kullanılabilirlik prensibine sadık kalın.

---

*Bu doküman, Accellera UVM 1.2 User's Guide, Mentor/Siemens Functional Verification Study (2020),
ve endüstri best-practice'lerine dayanılarak hazırlanmıştır.*
