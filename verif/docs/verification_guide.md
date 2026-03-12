# Zero to Reusable UVM: Kapsamlı SoC Doğrulama ve Entegrasyon Rehberi

Bu rehber, baştan sona bir System-on-Chip (SoC) için Universal Verification Methodology (UVM) altyapısının nasıl kurulduğunu, projede alınan mimari kararları, tüm test aşamalarını, yazılmış her bir kodu ve elde edilen sonuçların teknik gerçekliğini endüstri standartlarında detaylandırmak üzere **teknik bir sunum dokümanı** olarak hazırlanmıştır.

En temel amacımız: Elimizde çipin RTL (Register Transfer Level) kodları varken bu devasa UVM altyapısını kurmak; ileride RTL koduna sahip olmadığımız, sadece dokümanlara (Spec) bakarak doğrulama yapmamız gereken "Kara Kutu" projelerine geçtiğimizde elimizde güçlü, tekrar kullanılabilir (reusable) bir UVM iskeletinin hazır bulunmasını sağlamaktır. Bu doküman projenin evrimiyle birlikte sürekli güncellenecek **Yaşayan Bir Rehber (Living Document)** olarak tasarlanmıştır.

---

## 1. Neden UVM ve Neyi Doğruluyoruz?

Çip tasarımları büyüdükçe, klasik SystemVerilog yöntemleriyle (initial blokları, statik tasklar) binlerce köşe durumu (corner cases) tespit etmek imkansızlaşır. UVM bize:
*   **Constrained-Random Generation:** Binlerce farklı veri paketi kombinasyonunu sınırlı-rastgele şekilde otonom üretebilmeyi.
*   **Ayrıştırılmış Mimariler (Separation of Concerns):** Üreten (Sequence), fiziksel pin süren (Driver), izleyen (Monitor) ve not veren (Scoreboard) yapıları birbirinden nesne-yönelimli ve bağımsız kılmayı.
*   **Yeniden Kullanılabilirlik (Reusability):** Projeler arası taşınabilir bağımsız IP-Agent'lar üretmeyi sağlar.

### 1.1. Doğrulama Seviyemiz: (Chip/SoC Level)

Endüstri standardı olan kaynaklara (örn: chipverify.com) göre doğrulamalar 4 temel aşamadan oluşur: Unit, Block, Subsystem ve Chip/SoC sevileri.

**Bizim bu projede kurduğumuz yapının kimliği:** **Chip/SoC Level (Top-Level) Verification**'dır.

*   Çünkü RTL sarmalayıcımızın adı `soc_top`'tır; sistemin içindeki alt blokları (Block Level) ayrı ayrı koparıp test etmiyoruz (örneğin SPI modülünün kendi tb'si yok).
*   Testleri çipin Master dış pinlerinden (JTAG pini gibi) başlatıp, çipin derinliklerindeki IP'lere (UART, I2C gibi) ulaşıyor ve işlemi sonuna kadar takip ediyoruz (Pin-to-Register). İşlemciyi (CVA6) bypass etmek yerine UVM ile işlemci register maskelerine "Halt/Resume/SBA (System Bus Access)" işlemlerini göndererek sistemi dışarıdan tam entegrasyon seviyesinde yönetiyoruz.

---

## 2. IP Agent Mimarisi (verif/tb/agents/)

Mevcut projede **6 farklı protokol ajanımız** bulunmaktadır. Standart bir IP Ajanı UVM hiyerarşisi gereği tam 8 dosyadan oluşur.

### Tüm Aktif Ajanların Standart Dosya Yapısı (JTAG, UART, SPI, I2C, GPIO)
Her ajanın klasöründe eksiksiz şekilde şu dosyalar bulunur:
1.  **`<agent>_pkg.sv`**: Bütün klasör bileşenlerini UVM sınıf yapısına derleyen Package.
2.  **`<agent>_if.sv`**: UVM yazılım dünyasından donanım RTL dünyasına köprü kuran Virtual Interface.
3.  **`<agent>_transaction.sv`**: Sürülecek olan paketin OOP mimarideki veri modeli (Örn: UART için 8 bitlik data ve parity_error biti).
4.  **`<agent>_config.sv`**: Ajanı Active (Driver olan) veya Passive (sadece Monitor) yapan yapılandırma nesnesi.
5.  **`<agent>_driver.sv`**: İş bitlerini pin üzerindeki fiziksel zamansal gecikmelere aktaran donanım sürücüsü.
6.  **`<agent>_monitor.sv`**: Pindeki yüksek-alçak gerilim dalgalanmalarını bekleyip tekrar yazılım Transaction türüne toplayan izleyici.
7.  **`<agent>_sequencer.sv`**: İçeriden gelen veri talebini Driver'a ileten aracı (Router).
8.  **`<agent>_agent.sv`**: Yukarıdaki tüm sınıfları instantiate edip birbirlerine bağlayan en üst şemsiye.

*(Not: `axi_agent` sadece 5 dosyadan oluşur; RTL içerisindeki CVA6 AXI veri aktarımını bozmamak için Driver'ı olmayan, salt pasif bir gözlem ajanıdır).*

---

## 3. Coverage (Kapsam) Altyapısının Anatomisi

Projedeki **%46.62 Functional Coverage** oranının anlamı; sistem genel transistörlerinin toggle edilme oranı DEĞİL, özel olarak izlemek üzere tanımladığımız hedeflerin bitirilme oranıdır. UVM Ortamındaki `chs_coverage.sv` (616 satır) dosyamızda tanımlanmış olan **9 Covergroup** ve analizleri şöyledir:

### 3.1. `cg_boot_mode`
*   **Hedef:** Sistemin tetiklenme modlarının takibi.
*   **Binler:** JTAG Boot (`2'b00`), Serial Link Boot (`2'b01`), UART Boot (`2'b10`), Reserved (`2'b11`).

### 3.2. `cg_jtag` (Derinlemesine DMI Kavraması)
*   **Hedef:** JTAG bağlantısının IR/DR komutlarının ve DMI adreslemesinin test edildiğinden emin olmak.
*   **Binler:** JTAG operasyonu (reset, ir_scan, dr_scan, idle), Data Register Uzunluğu (0'dan 64 bite kadar sıklık ölçümleri).
*   **DMI Binleri:** Debug Module Interface'inin NOP, READ, WRITE opsiyonları kullanıldı mı?
*   **Cross Coverage:** Hangi IR Komutu ile hangi JTAG State makinesi komutu kesişti (`cx_op_ir`).

### 3.3. `cg_uart`
*   **Hedef:** Seri iletim veri türlerini ve bilerek enjekte edilen hata testlerini ölçmek.
*   **Binler:** Veri karakter dağılımı (Sıfır, Kontrol Karakterleri, Yazdırılabilir Düşük, Yazdırılabilir Yüksek, Tümü 1'ler), İletim yönü (TX/RX).
*   **Hata Binleri:** Parity Error test edildi mi? Framing Error (Baud sapması) test edildi mi?

### 3.4. `cg_spi` & `cg_i2c`
*   **Hedef:** Haberleşme hatlarındaki burst boyutu ve operasyonel modların ölçümü.
*   **SPI Binleri:** Standart, Dual, Quad modları denendi mi? CS0 ve CS1 hedeflerine transfer yapıldı mı? MOSI boyut ölçümleri.
*   **I2C Binleri:** READ/WRITE, özel adres testleri (general call, sensör range), ve eksik bit (NACK) durumları gönderildi mi?

### 3.5. `cg_gpio`
*   **Hedef:** Evrensel giriş çıkış pinlerinin mantık durumları ve geçişlerinin tespiti.
*   **Binler:** Yön atamaları (all_input, all_output, byte_pattern), Veri patternleri (checkerboard, walking_one), Mantık Geçişleri (Bir önceki state'den sonrakine geçiş - Multi-bit toggle durumu).

### 3.6. `cg_axi` & `cg_axi_region` (Veri Yolu Tıkanıklık Testi)
*   **Hedef:** Sistemin atardamarı olan AXI veri yolundaki burst (paket taşıma) ve gecikmelerin takibi.
*   **Binler:** Read/Write, Burst Type (INCR, WRAP), Size, Latency Cycles (fast, normal, very_slow), Error Reponse Type (OKAY, SLVERR, DECERR).
*   **Region Binleri:** SBA yolu üzerinden istek yapılan farklı bellek maskelerinin takibi: `DEBUG`, `BOOTROM`, `CLINT`, `PLIC`, `PERIPHERALS`, `DRAM`.

---

## 4. SystemVerilog Assertions (SVA) Entegrasyonu

Agent'lar sisteme milisaniyeler (timeout'lar) düzeyinde paket göderirken (Software), SVA modüllerimiz saniyenin milyarda biri düzeyinde (Hardware-Clock tick bazlı) devrede olup, donanımsal glitch'leri engellemektedir. Toplam **3 checker dosyasında**, **112 kural (Assertion)** ve **53 kapsam gözlemi (Cover Property)** bulunmaktadır.

### 4.1. `chs_protocol_checker.sv` (21 Assertion)
*   **Kategoriler:** JTAG, UART, SPI, I2C, GPIO temel donanım sinyalleri.
*   **Örnek Kurallar:**
    *   `a_reset_stable`: RST pini serbest bırakıldıktan sonra 4 clock çevkimi boyunca kararlı kalmak zorundadır (Glitch olamaz).
    *   `a_spi_cs_mutex`: SPI seçici pinlerin (Chip Select) kesinlikle birden fazlası aynı anda HIGH olamaz (Short-circuit koruması).
    *   `a_i2c_od_scl`: I2C Open-Drain çıkış kontrolü - Çıkış izni High ve data Low ise SCL mutlaka sıfırda olmalıdır.

### 4.2. `chs_axi_protocol_checker.sv` (58 Assertion)
*   **Kategoriler:** ARM AXI4 standartları spesifikasyon korumaları.
*   **Örnek Kurallar:**
    *   *Stability Kuralları:* `a_aw_valid_stable`, Pindeki Valid pini High olduysa Ready gelene kadar kesinlikle beklemesi (data droplanmaz).
    *   *Timeout Liveness:* `a_aw_timeout`, Gönderilen komut asla tıkanamaz, en fazla 2000 cycle sonra yanıt vermek zorundadır.
    *   *X/Z Çakışmaları:* Data ve Valid kanallarında tanımsız (X) veri olmasını yasaklar.

### 4.3. `chs_soc_sva_checker.sv` (33 Assertion)
*   **Kategoriler:** İşlemci spesifik (SBA, Interrupt, Bus Error, DMI) donanım uyumluluğu.
*   **Örnek Kurallar:**
    *   `a_sba_to_reg`: JTAG SBA arayüzünden yazılan bilgi, çipin merkezindeki Register Bus arayüzüne kesinlikle en fazla 100 cycle içerisinde ulaşıp işlem yapmalıdır (End-to-End Latency).
    *   `a_boot_mode_stable`: Reset kalktıktan sonra cihazın boot modu asla sonradan değiştirilemez.

---

## 5. Proje Test Senaryoları Arşivi (Timeline)

UVM projelerinde bir test sınıfı `uvm_test`ten kalıtım alır; timeout'unu ve kullanılacak bileşen şalterlerini berliler, ardından ana görevi bir **Sequence (Senaryo)** başlatmaktır. Projemizde aşama aşama kurgulanmış ve başarıyla koşturulan **36 Ana Test** bulunmaktadır.

### Aşama 1–3: Single-Protocol Connectivity & Bring-Up (Basit Erişim)
*Bu testler tek bir ajan kullanarak ortamın yaşayıp yaşamadığını kontrol ederler.*
*   `chs_sanity_test` (10ms): JTAG ve GPIO ayağa kalkıyor mu?
*   `chs_jtag_boot_test` (10ms): JTAG'in Boot işlemi doğrulaması.
*   `chs_uart_test`, `chs_uart_tx_test`, `chs_uart_burst_test` (10ms): Kesintisiz ve rastgele uzunlukta byte gönderimi.
*   `chs_spi_single_test`, `chs_spi_flash_test` (10ms): SPI transfer modeli kontrolü.
*   `chs_i2c_write_test`, `chs_i2c_rd_test` (10ms): Temel I2C ACK/NACK yapısı.
*   `chs_gpio_walk_test`, `chs_gpio_toggle_test` (10ms): Bitişik kayan 1'ler testi.

### Aşama 3–4: SBA System Bus ve Cross-Protocol Tests (Ağ İçi Gezintiler)
*Dışarıdan (JTAG) girip içerideki (AXI-RegBus) üzerinden başka bir modülü (UART/SPI) kontrol etme simülasyonlarıdır.*
*   `chs_jtag_sba_test` (100ms): Çipin içine Memory Access testi.
*   `chs_spi_sba_test`, `chs_i2c_sba_test`, `chs_gpio_deep_test` (50-100ms): SBA üzerinden SPI/I2C/GPIO Register'larına direkt yazım yapıp, pinden çıkan elektriksel dalgayı doğrulayan testler.
*   `chs_stress_test` (100ms): 4 ajan aynı anda sürekli ve rastgele trafik yollarken SBA round-robin denemesi.

### Aşama 5: SVA ve Total Coverage Baskısı
*   `chs_sva_coverage_test` (200ms): Timeout değeri uzatılmış ve kasten uzun süreli veriler pompalayarak tüm Coverage listelerinde "Full 100%" Coverage bulmayı amaçlayan spesifik senaryo.

### Aşama 6: Register Abstraction Layer (RAL) ve Error Enjeksiyonu
*`has_ral=1` flag'i ile doğrudan UVM Register Modeline bağlanır (JTAG Base'den Address Offset girmek yerine doğrudan class tabanlı `.write()` işlemleri).*
*   `chs_ral_access_test` (100ms): JTAG > DMI > SBA veriyolu ağacını, RAL Front-Door seviyesinde otomatik nesne yönelimli test eden senaryo.
*   `chs_interrupt_test` (100ms): İç GPIO registerlarının interrupt tetikleyip tetiklemediğini deneyen yapı.
*   `chs_error_inject_test` (150ms): Sisteme yasadışı talep girip dönen Error flaglerini `UVM_WARNING` düşürerek (Catcher ile) sistemi stres testinde hayatta tutan yapı.

### Aşama 7: SoC-Level Integration ve Reset Kontrolleri
*   `chs_memmap_test` (50ms): Çipin haritasındaki tüm hedeflere (ROM, PLIC vb) sondaj yapar.
*   `chs_boot_seq_test` (50ms): JTAG üzerinden TAP Reset, Debugger Halt/Resume deneme testleri.
*   `chs_reg_reset_test` (50ms): SBA ağından tüm IP modüllerinin POR (Power-on-Reset) değerlerini (Default Values) çeker.

### Aşama 8: AXI Bus Monitoring (Core Traffic)
*   `chs_axi_sanity_test` (10ms): AXI Ajanı aktif edilip CVA6 Boot işlemlerinin pasif olarak doğrulanması.
*   `chs_axi_protocol_test` (3ms), `chs_axi_stress_test` (5ms): Aja ve CVA6 Master'ı eşzamanlı veri tıkanma testi denemeleri.

### Aşama 9: Coverage Boost Testleri (Sınırları Cilasama Testleri)
*Aşama 5'ten farklı olarak Covergroup'lardaki sınır (Boundary / Corner Case) değerleri tetiklemeyi asıl amaç edinen testler.*
*   `chs_cov_jtag_corner_test`, `chs_cov_uart_boundary_test`, `chs_cov_gpio_exhaustive_test`, `chs_cov_axi_region_test` gibi spesifik "Boş bırakılmış maske tırmalama" testleridir. Çipi 200ms gibi uzun bloklar halinde test ederler.

---

## 6. Proje Dizin Mimarisi Referansı (verif/tb/)
Özetle kod evreni şu şekildedir:
*   `agents/`: Tekil birimlerin protokol işlemleri (JTAG, UART, AXI vb.)
*   `env/`: `chs_env.sv`, `chs_scoreboard.sv`, `chs_coverage.sv`. Ve bunların içerisindeki RAL Modellerinin bağlandığı adres (`env/ral/chs_ral_soc_block.sv`).
*   `sequences/`: 5 Adet Base IP Sequence ve **33 Adet Virtual Sequence** (sistem çaplı koordineli testler).
*   `tests/`: Base test + 36 Adet koşan test senaryosu.
*   `top/`: `tb_top.sv` ve içerisine eklenmiş **3 SVA Checker** dosyasının donanım arayüzleri.

---

## 7. Porting Kılavuzu: Yeni Bir Projeye Adaptasyon 

Bugün sahip olduğumuz bu SoC iskeleti, ileride tasarımı tamamen belirsiz bir projeye entegre edileceğinde:
1.  **%100 Aktarılacaklar:** `agents/` içindeki JTAG, SPI, I2C, UART paketi. İletişim standartları küresel sabit olduğundan direkt kopyalanır. Bize aylar kazandırır.
2.  **Kısmen Aktarılacaklar:** `top/` sınıfının isimleri RTL'e göre değiştirilir. SVA parametreleri daraltılır veya genişletilir.
3.  **Baştan Yazılacaklar:** `env/ral/` modülleri yeni çipin dökümanına (IP-XACT, Register Map Docs) göre oto-generate edilir. `sequences/virtual/` içerisine bu modele özel (yeni SoC'deki boot aşamaları gibi) senaryolar yazılır.
