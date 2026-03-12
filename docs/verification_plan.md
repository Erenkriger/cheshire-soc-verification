# Cheshire SoC — Verification Plan (Doğrulama Planı)

> **Project:** Cheshire SoC UVM Verification  
> **DUT:** pulp-platform/cheshire (RISC-V CVA6-based Linux-capable SoC)  
> **Methodology:** UVM 1.2 (Accellera)  
> **Simulators:** QuestaSim ≥ 2022.3 / VCS ≥ 2024.09 / Xilinx Vivado xsim  
> **Date:** March 2026  

---

## 1. SoC Doğrulaması Nasıl Planlanır?

### 1.1 Mimari Analiz (Architecture Study)

SoC doğrulamasına başlamanın **ilk adımı**, DUT'un mimarisini eksiksiz anlamaktır.
Cheshire SoC'nin blok diyagramı şu bileşenleri gösterir:

```
┌──────────────────────────────────────────────────────────────────┐
│                        Cheshire SoC                             │
│                                                                  │
│  ┌─────────┐  ┌─────────┐         ┌──────────────────────────┐  │
│  │ CVA6 #0 │  │ CVA6 #1 │  ...    │  External AXI Masters    │  │
│  │  +CLIC  │  │  +CLIC  │         │  (cfg.AXiExtNumMst)      │  │
│  └────┬────┘  └────┬────┘         └────────────┬─────────────┘  │
│       │            │                            │                │
│  ┌────┴────────────┴────────────────────────────┴──────────┐    │
│  │              AXI4+ATOP Crossbar                         │    │
│  └─┬────────┬──────────┬───────────┬───────────┬───────────┘    │
│    │        │          │           │           │                 │
│  ┌─┴──┐  ┌─┴───┐  ┌───┴────┐  ┌──┴───┐  ┌───┴──────────┐     │
│  │LLC │  │Debug│  │iDMA    │  │Regbus│  │Ext AXI Slaves│     │
│  │SPM │  │ROM  │  │Engine  │  │Demux │  │              │     │
│  └─┬──┘  └─────┘  └────────┘  └──┬───┘  └──────────────┘     │
│    │                              │                             │
│  ┌─┴──┐            ┌─────────────┼─────────────────────┐       │
│  │DRAM│            │  Regbus Peripherals (32-bit)      │       │
│  └────┘            │  ┌──────┐ ┌───┐ ┌─────┐ ┌────┐   │       │
│                     │  │ UART │ │I2C│ │SPI  │ │GPIO│   │       │
│                     │  └──────┘ └───┘ └─────┘ └────┘   │       │
│                     │  ┌──────┐ ┌─────┐ ┌──────────┐   │       │
│                     │  │ PLIC │ │CLINT│ │IRQ Router│   │       │
│                     │  └──────┘ └─────┘ └──────────┘   │       │
│                     │  ┌────────┐ ┌───┐ ┌──────────┐   │       │
│                     │  │SoC Regs│ │VGA│ │Serial Lnk│   │       │
│                     │  └────────┘ └───┘ └──────────┘   │       │
│                     │  ┌─────┐ ┌────────┐              │       │
│                     │  │ USB │ │Boot ROM│              │       │
│                     │  └─────┘ └────────┘              │       │
│                     └──────────────────────────────────┘       │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 Memory Map Çıkarma

Cheshire'ın statik bellek haritası:

| Bölge | Başlangıç | Bitiş | Boyut | Açıklama |
|-------|-----------|-------|-------|----------|
| Debug ROM | `0x0000_0000` | `0x0003_FFFF` | 256K | AXI periphs |
| iDMA Cfg | `0x0100_0000` | `0x0100_0FFF` | 4K | AXI periphs |
| Boot ROM | `0x0200_0000` | `0x0203_FFFF` | 256K | Reg periphs |
| CLINT | `0x0204_0000` | `0x0207_FFFF` | 256K | Reg periphs |
| IRQ Router | `0x0208_0000` | `0x020B_FFFF` | 256K | Reg periphs |
| AXI RT Cfg | `0x020C_0000` | `0x020F_FFFF` | 256K | Reg periphs |
| SoC Regs | `0x0300_0000` | `0x0300_0FFF` | 4K | Reg periphs |
| LLC Cfg | `0x0300_1000` | `0x0300_1FFF` | 4K | Reg periphs |
| UART | `0x0300_2000` | `0x0300_2FFF` | 4K | TI 16750 compat. |
| I2C | `0x0300_3000` | `0x0300_3FFF` | 4K | OpenTitan IP |
| SPI Host | `0x0300_4000` | `0x0300_4FFF` | 4K | OpenTitan IP |
| GPIO | `0x0300_5000` | `0x0300_5FFF` | 4K | OpenTitan IP |
| Serial Link Cfg | `0x0300_6000` | `0x0300_6FFF` | 4K | Reg periphs |
| VGA Cfg | `0x0300_7000` | `0x0300_7FFF` | 4K | Reg periphs |
| USB 1.1 Cfg | `0x0300_8000` | `0x0300_8FFF` | 4K | OHCI |
| UNBENT | `0x0300_9000` | `0x0300_9FFF` | 4K | Bus Error Unit |
| PLIC | `0x0400_0000` | `0x07FF_FFFF` | 64M | INTCs |
| CLICs | `0x0800_0000` | `0x0BFF_FFFF` | 64M | INTCs |
| LLC SPM (cached) | `0x1000_0000` | `0x13FF_FFFF` | 64M | CIE |
| LLC SPM (uncached) | `0x1400_0000` | `0x17FF_FFFF` | 64M | IE |
| External On-chip | `0x2000_0000` | `0x7FFF_FFFF` | param | Parameterized |
| LLC Out (DRAM) | `0x8000_0000` | `0xFFFF_FFFF` | ≤2GB | CIE |

### 1.3 Doğrulama Kapsamı Belirleme

SoC-level doğrulamada **her şeyi** tek seferde doğrulamaya çalışmak verimsizdir.  
**Katmanlı (hierarchical) yaklaşım** kullanılır:

| Katman | Kapsam | Öncelik |
|--------|--------|---------|
| **IP-Level** | Her periferalin bağımsız doğrulaması (UART, SPI, I2C, GPIO ayrı ayrı) | P0 |
| **Subsystem-Level** | Interconnect + bellek haritası doğrulaması, AXI crossbar, Regbus demux | P0 |
| **SoC-Level** | End-to-end senaryolar: boot, DMA transfer, interrupt routing, multi-master | P1 |
| **System-Level** | Linux boot, SW/HW co-verification (opsiyonel, uzun vadeli hedef) | P2 |

### 1.4 Risk Analizi

| Risk | Etki | Azaltma |
|------|------|---------|
| AXI crossbar deadlock | Yüksek | Multi-master concurrent test, outstanding txn limitleri |
| Interrupt kaybı/yanlış yönlendirme | Yüksek | PLIC + CLINT + IRQ Router senaryoları |
| Boot ROM hatası | Kritik | Her boot mode test edilmeli (JTAG/SerialLink/UART/Autonomous) |
| Memory coherence | Yüksek | Self-invalidation senaryoları, AMO testleri |
| Regbus atomics | Orta | AMO filter doğrulaması |

---

## 2. UVM Ortamı Nasıl Kurulur?

### 2.1 Mimari Karar: Cheshire'ın Mevcut TB'si vs. UVM Katmanı

Cheshire, `fixture_cheshire_soc` + `vip_cheshire_soc` ile task-based bir testbench sağlar.
Bizim UVM ortamımız bunu **tamamlayıcı** olacak:

```
                        ┌─────────────────────────┐
                        │     UVM Test Layer       │
                        │  soc_base_test           │
                        │  soc_boot_test           │
                        │  soc_periph_test         │
                        └────────┬────────────────┘
                                 │
                        ┌────────┴────────────────┐
                        │     soc_env              │
                        │  ┌──────────────────┐   │
                        │  │ virtual_sequencer │   │
                        │  └──────────────────┘   │
                        │  ┌──────────────────┐   │
                        │  │   scoreboard      │   │
                        │  └──────────────────┘   │
                        │  ┌──────────────────┐   │
                        │  │   coverage        │   │
                        │  └──────────────────┘   │
                        │  ┌──────────────────┐   │
                        │  │   RAL model       │   │
                        │  └──────────────────┘   │
                        │                         │
                        │  ┌─────────┬─────────┐  │
                        │  │  AXI    │  Regbus  │  │
                        │  │ Agent   │  Agent   │  │
                        │  └────┬────┴────┬────┘  │
                        │  ┌────┴────┬────┴────┐  │
                        │  │JTAG │UART│SPI│I2C │  │
                        │  │Agent│Agnt│Agt│Agt │  │
                        │  └─────┴────┴───┴────┘  │
                        └────────┬────────────────┘
                                 │ virtual interfaces
                        ┌────────┴────────────────┐
                        │  fixture_cheshire_soc    │
                        │  (DUT + VIP wrapper)     │
                        │  cheshire_soc instance   │
                        └─────────────────────────┘
```

### 2.2 Neden Bu Yapı?

1. **Cheshire'ın kendi fixture/VIP'i zaten var** → task-based preload, JTAG driver, UART receiver.
   Bu, bare-metal test çalıştırmak için yeterlidir.

2. **UVM katmanı ekleyerek kazandıklarımız:**
   - **Constrained-random stimulus** (rastgele ama kontrollü trafik üretimi)
   - **Functional Coverage** (ne kadarını doğruladık bilgisi)
   - **Scoreboard/Checker** (otomatik sonuç kontrolü)
   - **Reusability** (agent'lar başka SoC'lerde tekrar kullanılabilir)
   - **Regression automation** (testler otomatik çalıştırılır)

3. **Hybrid yaklaşım:** Cheshire'ın VIP task'larını UVM sequence'lar içinden çağırarak
   her iki dünyanın avantajlarını birleştiririz.

### 2.3 Agent Gereksinimleri

Cheshire'ın **dış IO'larına** bakarak hangi agent'lara ihtiyacımız olduğunu çıkarıyoruz:

| Interface | Protokol | Agent Türü | Öncelik | Açıklama |
|-----------|----------|------------|---------|----------|
| `jtag_*` | IEEE 1149.1 | **JTAG Agent** | P0 | Debug, ELF preload, SBA erişimi |
| `uart_tx/rx` | TI 16750 | **UART Agent** | P0 | Konsol çıkışı, ELF preload |
| `spih_*` | SPI (Quad) | **SPI Agent** | P0 | Flash boot, data transfer |
| `i2c_*` | I2C | **I2C Agent** | P0 | EEPROM boot |
| `gpio_*` | GPIO | **GPIO Agent** | P1 | Dijital I/O |
| `axi_llc_mst_*` | AXI4 | **AXI Slave Agent** | P0 | DRAM memory model |
| `slink_*` | Serial Link | **SLink Agent** | P1 | Chip-to-chip |
| `vga_*` | VGA | **VGA Monitor** | P2 | Passive, sadece izleme |
| `usb_*` | USB 1.1 | **USB Agent** | P2 | OHCI host |
| `boot_mode_i` | Logic | **Config Driver** | P0 | Boot mode kontrolü |

### 2.4 Kodlamaya Nereden Başlanır ve Neden?

**Başlama sırası** (kritiklik ve bağımlılık zinciri):

```
Adım 1: tb_top + fixture entegrasyonu (DUT bağlantısı)
    ↓
Adım 2: JTAG Agent (Debug erişimi — her şeyin temeli)
    ↓
Adım 3: AXI Slave Agent (DRAM memory model — testlerin çalışması için zorunlu)
    ↓
Adım 4: UART Agent (log çıktısı, temel iletişim doğrulaması)
    ↓
Adım 5: RAL Model (register erişimi — tüm periferallerin kontrol yolu)
    ↓
Adım 6: soc_env + scoreboard + coverage (ortamın iskelet yapısı)
    ↓
Adım 7: SPI + I2C Agent (boot yolları)
    ↓
Adım 8: Virtual sequences (boot, DMA, interrupt senaryoları)
    ↓
Adım 9: GPIO, Serial Link, VGA, USB (tamamlayıcı agent'lar)
```

**Neden bu sıra?**
- JTAG olmadan hiçbir register'a erişemez, core'u durduramazsınız
- AXI Slave (DRAM model) olmadan boot ROM execution başarısız olur
- UART olmadan test sonucunu göremezsiniz
- RAL olmadan register tabanlı peripheral konfigürasyonu yapılamaz

---

## 3. Hedefler ve Coverage Metrikleri

### 3.1 Functional Coverage Hedefleri

| Coverage Grubu | Hedef % | Açıklama |
|----------------|---------|----------|
| **Boot Mode Coverage** | 100% | Tüm boot modları: JTAG(0), SerialLink(1), UART(2), Autonomous(SD/SPI/I2C) |
| **Memory Map Coverage** | 100% | Her adres bölgesine en az 1 okuma + 1 yazma |
| **AXI Transaction Coverage** | ≥95% | Burst type (FIXED/INCR/WRAP), size, len, response cross |
| **Interrupt Coverage** | ≥95% | Her interrupt kaynağı tetiklenmeli, PLIC + CLINT + CLIC |
| **Register Coverage** | 100% | RAL üzerinden her register'a R/W (SoC Regs, periph regs) |
| **DMA Transfer Coverage** | ≥90% | 1D/2D transfer, farklı boyutlar, overlap olmayan bölgeler |
| **Multi-master Coverage** | ≥85% | Concurrent core + DMA + debug erişimi |
| **Error Path Coverage** | ≥80% | AXI error response, bus error, slverr |
| **Peripheral Protocol Coverage** | ≥90% | UART baud rates, SPI modes (CPOL/CPHA), I2C speeds |

### 3.2 Code Coverage Hedefleri

| Metrik | Hedef % | Açıklama |
|--------|---------|----------|
| **Line Coverage** | ≥90% | Her satırın en az 1 kez execute edilmesi |
| **Branch Coverage** | ≥85% | if/else, case dallarının çoğunluğu |
| **Toggle Coverage** | ≥80% | Sinyal değişim oranı |
| **FSM Coverage** | 100% | Her state machine'de tüm state + transition'lar |
| **Condition Coverage** | ≥80% | Complex boolean expression sub-conditions |

### 3.3 Bu Hedeflere Ulaşmak İçin Neler Yapmalıyız?

1. **Constrained-Random + Directed Test Dengesi:**
   - %60 constrained-random testler (coverage hole'ları kapatır)
   - %30 directed testler (critical path'ler: boot, interrupt, error injection)
   - %10 corner case testler (boundary conditions, max burst, timeout)

2. **Coverage-Driven Verification (CDV) Döngüsü:**
   ```
   Test Yaz → Simülasyon Çalıştır → Coverage Analiz → Gap Tespit → Test Ekle → Tekrarla
   ```

3. **Exclusion Management:**
   - Parametrik olarak disable edilen bloklar (VGA=0, USB=0 ise) coverage'dan çıkarılmalı
   - Unreachable code (Cheshire `cheshire_soc.sv`'deki TODO'lar) exclude listesine eklenmeli

4. **Regression Suite:**
   - Nightly regression: tüm testler
   - Commit regression: smoke testler (5-10 dk)
   - Weekly: full coverage merge + analiz

---

## 4. Doğrulama Ortamını Kurduktan Sonra Yol Haritası

### 4.1 Fazlar

| Faz | Süre (tahmini) | Hedef |
|-----|----------------|-------|
| **Faz 0: Ortam Kurulumu** | 2-3 hafta | tb_top, agent'lar, soc_env, RAL, temel sekanslat |
| **Faz 1: Smoke Tests** | 1-2 hafta | Boot (JTAG preload), UART hello world, register R/W |
| **Faz 2: IP-Level Tests** | 3-4 hafta | Her periferalin fonksiyonel doğrulaması |
| **Faz 3: Subsystem Tests** | 2-3 hafta | AXI crossbar, interrupt routing, DMA |
| **Faz 4: SoC-Level Tests** | 3-4 hafta | Multi-master, boot modes, error injection |
| **Faz 5: Coverage Closure** | 2-4 hafta | Coverage gap analizi, ek testler |
| **Faz 6: Regression & Sign-off** | 1-2 hafta | Full regression, bug fix, raporlama |

### 4.2 Başka Bir SoC'ye Transfer Edilecek Bilgi Birikimi

Bu projede öğrenilecek transferable bilgiler:

1. **Agent Reuse:** AXI, JTAG, UART, SPI, I2C agent'ları herhangi bir SoC'de kullanılabilir
2. **RAL Methodology:** Register model oluşturma süreci standarttır
3. **Virtual Sequence Patterns:** Boot, DMA, interrupt senaryoları SoC'den bağımsızdır
4. **Coverage Model:** AXI transaction coverage, memory map coverage template olarak kullanılabilir
5. **Scoreboard Architecture:** Protocol-aware checking pattern'leri taşınabilir

---

## 5. Test Senaryoları (Detaylı)

### 5.1 P0 — Kritik Testler

| Test ID | Senaryo | Beklenen Sonuç |
|---------|---------|----------------|
| `T001` | JTAG üzerinden halt/resume CVA6 | Core durur/devam eder |
| `T002` | JTAG SBA ile DRAM read/write | Doğru data geri okunur |
| `T003` | JTAG ile ELF preload + execute | helloworld başarılı çıktı verir |
| `T004` | UART preload mode | Binary yüklenir, execute edilir |
| `T005` | SPI Flash boot (autonomous) | Boot ROM → SPI NOR → SPM → execute |
| `T006` | I2C EEPROM boot (autonomous) | Boot ROM → I2C EEPROM → SPM → execute |
| `T007` | SoC register read (HW_FEATURES) | Aktif özellikler doğru bildirilir |
| `T008` | Memory map boundary check | Her bölgenin start/end adresi erişilebilir |
| `T009` | LLC SPM mode R/W | SPM olarak write/read match |
| `T010` | DRAM (LLC out) R/W | Cache through DRAM erişimi doğru |

### 5.2 P1 — Yüksek Öncelik

| Test ID | Senaryo | Beklenen Sonuç |
|---------|---------|----------------|
| `T011` | iDMA mem-to-mem transfer | Source→Dest data match |
| `T012` | PLIC interrupt routing | External IRQ → PLIC → core meip |
| `T013` | CLINT timer interrupt | RTC tick → mtip assertion |
| `T014` | Multi-core JTAG debug | Her core bağımsız halt/resume |
| `T015` | UART TX/RX loopback | Gönderilen = alınan |
| `T016` | SPI QSPI mode transfer | 4-lane data doğru |
| `T017` | I2C slave ACK/NACK | Protocol compliance |
| `T018` | GPIO output/input | Set → Read match |
| `T019` | Serial Link R/W | Cross-chip register access |
| `T020` | AXI ATOP (atomics) | AMO operations correct |

### 5.3 P2 — Tamamlayıcı

| Test ID | Senaryo |
|---------|---------|
| `T021` | VGA frame buffer DMA |
| `T022` | USB enumeration |
| `T023` | AXI-RT bandwidth regulation |
| `T024` | IRQ Router dynamic remapping |
| `T025` | Bus Error (UNBENT) detection |
| `T026` | Multi-boot mode transition |
| `T027` | LLC way partitioning (SPM↔Cache) |

---

## 6. Proje Dizin Yapısı

```
soc_uvm/
├── cheshire/                  # Klonlanmış Cheshire RTL reposu (READ-ONLY)
│   ├── hw/                    # RTL kaynaklar
│   ├── sw/                    # Software stack
│   └── target/sim/            # Mevcut fixture + VIP
│
├── verif/                     # ← BİZİM UVM ORTAMIMIZ
│   ├── tb/
│   │   ├── top/               # tb_top.sv (UVM entry point)
│   │   ├── agents/            # Protokol agent'ları
│   │   │   ├── axi_agent/
│   │   │   ├── jtag_agent/
│   │   │   ├── uart_agent/
│   │   │   ├── spi_agent/
│   │   │   ├── i2c_agent/
│   │   │   ├── gpio_agent/
│   │   │   └── regbus_agent/
│   │   ├── env/               # soc_env, scoreboard, coverage, RAL
│   │   ├── sequences/
│   │   │   ├── ip/            # IP-level sequences
│   │   │   └── virtual/       # System-level virtual sequences
│   │   └── tests/             # UVM test classes
│   │
│   └── sim/                   # Simulation scripts
│       ├── Makefile
│       ├── compile.f
│       └── run scripts
│
└── docs/                      # Dokümanlar + sunum materyali
    └── verification_plan.md
```

---

## 7. Farklı Bir SoC'ye Uyarlama Yol Haritası

Eğer bu verification ortamını **başka bir SoC**'ye taşımak isterseniz:

### Adım 1: Mimari Analiz (1-2 gün)
- Yeni SoC'nin blok diyagramını çıkar
- Memory map tablosu oluştur
- Dış arayüzleri (IO) listele
- Parametre/konfigürasyon yapısını anla

### Adım 2: Agent Eşleştirme (1 gün)
- Mevcut agent'ların hangisi doğrudan kullanılabilir?
- Hangi agent'lar parametre değişikliği gerektirir?
- Yeni protokol agent'ı yazılması gerekiyor mu?

### Adım 3: Environment Adaptasyonu (3-5 gün)
- `soc_env` konfigürasyonunu güncelle (aktif agent seçimi)
- RAL model'i yeni register map'e göre oluştur
- Scoreboard'u yeni veri yollarına uyarla
- Coverage model'i güncelle

### Adım 4: Test Geliştirme (2-4 hafta)
- Smoke testleri yeni SoC'ye uyarla
- SoC'ye özel senaryolar ekle
- Coverage-driven iteration başlat

### Adım 5: Regression & Sign-off (1-2 hafta)
- Full regression çalıştır
- Coverage raporlarını analiz et
- Bug fix döngüsü

---

## 8. Önemli Tasarım Kararları

### 8.1 Cheshire VIP'i Kullanma Stratejisi

Cheshire zaten `vip_cheshire_soc` modülünde JTAG, UART, SPI, I2C için driver task'ları sağlıyor.
**Kararımız:** Bu task'ları UVM sequence body'leri içinden DPI veya hierarchical reference ile
çağırmak yerine, **kendi UVM agent'larımızı yazacağız**. 

**Neden?**
- UVM standardına uygunluk (reuse, portability)
- Functional coverage toplama
- Constrained-random stimulus generation
- TLM-based scoreboard bağlantısı

Ancak, Cheshire'ın `fixture_cheshire_soc` ve `clk_rst_gen` modüllerini
tb_top'ta DUT instantiation için **doğrudan kullanabiliriz**.

### 8.2 AXI vs. Regbus Agent Kararı

Cheshire'da iki bus hiyerarşisi var:
- **AXI4+ATOP Crossbar** (yüksek performans, burst, out-of-order)
- **Regbus Demux** (32-bit, no-burst, basit register erişimi)

Periferaller Regbus üzerinden erişilir, ancak dışarıdan bakıldığında
tüm erişim AXI4 üzerinden gelir (AXI→Regbus bridge var).

**Kararımız:** 
- AXI Slave Agent → DRAM port (LLC out) için
- JTAG Agent → SBA (System Bus Access) üzerinden dolaylı register erişimi
- Periferalin kendi IO'larına doğrudan agent bağlantısı (UART TX/RX, SPI, I2C)
- Regbus agent'ı opsiyonel — internal monitoring için

---

*Bu doğrulama planı, Cheshire SoC'nin UVM-based doğrulamasının temelini oluşturur.
Planın uygulanması sırasında iteratif olarak güncellenecektir.*
