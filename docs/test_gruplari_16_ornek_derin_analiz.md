# Cheshire UVM: Test Gruplarından 16 Örnek ile Derin Analiz

Bu doküman, mevcut projedeki test yapısını **"hangi kod hangi IP/Core/Bus'a nasıl gidiyor"** sorusuna cevap verecek şekilde hazırlanmıştır.

Kapsam:
- 8 test grubunun her birinden 2 örnek (toplam 16 test)
- Her örnekte:
  - Test–Sequence eşleşmesi
  - Çağrılan ana fonksiyon/task’lar
  - İşlem yolu (pin → agent → sequencer → bus → IP/core)
  - Doğru yere gidildiğinin kanıtları
  - Bu testin neden bu şekilde yazıldığı
  - Testi yazarken hangi kaynağa bakıldığı

---

## 0) Temel Mekanizma

### 0.1 Test → Virtual Sequence → IP Sequence hiyerarşisi
- Test sınıfı: senaryo seçer ve başlatır.
  - Referans: [verif/tb/tests/chs_base_test.sv](verif/tb/tests/chs_base_test.sv)
- Virtual sequence: çoklu IP adımlarını orkestre eder.
  - Referans: [verif/tb/sequences/chs_seq_pkg.sv](verif/tb/sequences/chs_seq_pkg.sv)
- IP base sequence: protokol primitiflerini uygular (`do_ir_scan`, `sba_read32`, `send_byte`, vb.).
  - Referans: [verif/tb/sequences/ip/jtag_base_seq.sv](verif/tb/sequences/ip/jtag_base_seq.sv)

### 0.2 Virtual sequencer tam olarak ne yapar?
Virtual sequencer, alt sequencer handle’larını tutar (`m_jtag_sqr`, `m_uart_sqr`, `m_spi_sqr`, ...). Kendi başına pin sürmez; sadece ilgili alt sequencer’a işi yönlendirir.
- Referans: [verif/tb/env/chs_virtual_sequencer.sv](verif/tb/env/chs_virtual_sequencer.sv)
- Handle ataması: [verif/tb/env/chs_env.sv](verif/tb/env/chs_env.sv)

### 0.3 "Doğru yere gitti" nasıl anlarız? (5 Kanıt)
1. **Adres kanıtı:** Register map’e uygun base/offset kullanımı.
2. **Yol kanıtı:** JTAG/DMI/SBA veya ilgili IP driver yolu çağrılıyor mu?
3. **Gözlem kanıtı:** İlgili monitor transaction üretiyor mu?
4. **Davranış kanıtı:** Readback/status/interrupt/pattern sonucu doğru mu?
5. **Kapsam/SVA kanıtı:** İlgili coverpoint/assertion tetikleniyor mu?

### 0.4 Mimariye göre fiziksel bağ nerede doğrulanıyor?
- DUT pin/interface bağları: [verif/tb/top/tb_top.sv](verif/tb/top/tb_top.sv)
- Agent->scoreboard/coverage bağlantıları: [verif/tb/env/chs_env.sv](verif/tb/env/chs_env.sv)
- Sonuç toplama: [verif/tb/env/chs_scoreboard.sv](verif/tb/env/chs_scoreboard.sv), [verif/tb/env/chs_coverage.sv](verif/tb/env/chs_coverage.sv)
- Regresyon çalışma listesi: [verif/sim/run_all_tests.tcl](verif/sim/run_all_tests.tcl)

---

## 1) 1–13: Temel IP Testleri (2 örnek)

## Örnek 1A: `chs_sanity_test` + `chs_smoke_vseq`
- Test: [verif/tb/tests/chs_sanity_test.sv](verif/tb/tests/chs_sanity_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_smoke_vseq.sv](verif/tb/sequences/virtual/chs_smoke_vseq.sv)
- IP seq çağrıları:
  - `jtag_base_seq.do_reset()`
  - `jtag_base_seq.do_ir_scan(IR_IDCODE)`
  - `jtag_base_seq.do_dr_scan(...)`
  - `gpio_base_seq.drive_all(...)`

### Yol
`test_body()` → `vseq.start(m_env.m_virt_sqr)` → `p_sequencer.m_jtag_sqr` ve `p_sequencer.m_gpio_sqr` üzerinden agent driver’lara gider.

### Hangi IP’ye gidiyor?
- JTAG adımı: doğrudan JTAG TAP/IDCODE
- GPIO adımı: GPIO interface giriş sürüşü (TB tarafı)

### Doğru yere gittiğini nasıl anlarız?
- JTAG’de `IDCODE` dönüşü var.
- GPIO transaction monitor’da görünür.
- Scoreboard sayaçları artar.

### Neden bu şekilde yazıldı?
Bu test “ilk bağlantı testi”dir: SoC içindeki karmaşık fonksiyonlardan önce pin/protokol bağlantılarının canlı olduğu doğrulanır.

---

## Örnek 1B: `chs_spi_flash_test` + `chs_spi_flash_vseq`
- Test: [verif/tb/tests/chs_spi_flash_test.sv](verif/tb/tests/chs_spi_flash_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_spi_flash_vseq.sv](verif/tb/sequences/virtual/chs_spi_flash_vseq.sv)
- IP seq çağrıları:
  - `spi_base_seq.send_byte(0x9F)`
  - `spi_base_seq.read_bytes(3)`
  - `spi_base_seq.send_cmd_addr(0x03, 24'h0)`
  - `spi_base_seq.read_bytes(8)`

### Yol
`m_spi_sqr` üzerinden SPI agent driver’a; driver SPI pinlerini sürer/örnekler.

### Hangi IP’ye gidiyor?
SPI Host pin/protokol düzeyi.

### Doğru yere gittiğini nasıl anlarız?
- SPI monitor’da MOSI/MISO transaction oluşur.
- `csb/sck/sd` aktivitesi dalga şeklinde gözlenir.

### Kaynak/Spec
SPI flash temel komut akışı (JEDEC ID + read) model alınmıştır.

---

## 2) 14–20: SBA Derin ve Çapraz Protokol (2 örnek)

## Örnek 2A: `chs_jtag_sba_test` + `chs_jtag_sba_vseq`
- Test: [verif/tb/tests/chs_jtag_sba_test.sv](verif/tb/tests/chs_jtag_sba_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_jtag_sba_vseq.sv](verif/tb/sequences/virtual/chs_jtag_sba_vseq.sv)
- Ana çağrılar:
  - `sba_init()`
  - `sba_write32(GPIO_*, ...)`, `sba_read32(GPIO_*, ...)`
  - `sba_write32(UART_*, ...)`, `sba_read32(UART_*, ...)`

### Yol (kritik)
JTAG pin → TAP → DMI (`DMCONTROL/SBCS/SBDATA/SBADDRESS`) → SBA bus access → SoC crossbar/regbus → UART/GPIO CSR.

### Neden doğru IP’ye gittiğini biliyoruz?
- Adresler doğrudan peripheral map’e denk (`0x0300_2000` UART, `0x0300_5000` GPIO).
- UART LSR/THR gibi register-specific davranışları test ediyor.
- GPIO output readback ve pin etkisi görülüyor.

### Bu testi nasıl yazdık?
- JTAG debug spec mantığı + Cheshire memory map birleşimi.
- `jtag_base_seq` içinde DMI BUSY/ERROR temizleme mekanizması kullanıldı.

---

## Örnek 2B: `chs_cross_protocol_test` + `chs_cross_protocol_vseq`
- Test: [verif/tb/tests/chs_cross_protocol_test.sv](verif/tb/tests/chs_cross_protocol_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_cross_protocol_vseq.sv](verif/tb/sequences/virtual/chs_cross_protocol_vseq.sv)
- Ana çağrılar:
  - GPIO kısmı: `sba_write32(GPIO_DIRECT_OE/OUT)`
  - UART kısmı: UART init + `sba_write32(UART_THR)`
  - SPI kısmı: `SPI_CONTROL/CONFIGOPTS/COMMAND/TXDATA` akışı
  - Scoreboard expected API: `expect_uart_byte()`, `expect_spi_transfer()`

### Yol
JTAG/SBA ile register programlama + fiziksel pin aktivitelerinin monitor ve scoreboard üzerinden doğrulanması.

### Neden önemli?
Tek testte birden fazla protokolün birlikte kullanımı ile bus/paylaşım kaynaklı yan etkiler yakalanır.

---

## 3) 21–24: İleri Senaryo (2 örnek)

## Örnek 3A: `chs_ral_access_test` + `chs_ral_access_vseq`
- Test: [verif/tb/tests/chs_ral_access_test.sv](verif/tb/tests/chs_ral_access_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_ral_access_vseq.sv](verif/tb/sequences/virtual/chs_ral_access_vseq.sv)
- İlgili RAL dosyaları: [verif/tb/env/ral/chs_ral_pkg.sv](verif/tb/env/ral/chs_ral_pkg.sv)

### Ana fikir
`uvm_reg` adresini RAL’den alıp gerçek erişimi `sba_write32/sba_read32` ile yapıyor; sonra `predict()` ile mirror güncelliyor.

### Neden bu teknik?
Bu projede bus erişimi çok-adımlı (JTAG→DMI→SBA). Bazı doğrudan frontdoor kullanım senaryolarında asılı kalma riski olduğundan kontrollü akış seçilmiş.

### Doğrulama
- HW readback eşleşmesi
- RAL mirror eşleşmesi

---

## Örnek 3B: `chs_error_inject_test` + `chs_error_inject_vseq`
- Test: [verif/tb/tests/chs_error_inject_test.sv](verif/tb/tests/chs_error_inject_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_error_inject_vseq.sv](verif/tb/sequences/virtual/chs_error_inject_vseq.sv)

### Ana çağrılar
- Unmapped adrese `sba_read32`
- RO register yazma denemesi
- SPI hata register ayarı
- I2C NAK tolerans senaryosu

### Özel nokta
Beklenen hata durumları için `uvm_report_catcher` ile severity demotion uygulanmış.

### Neden doğru?
Amaç başarısızlık üretmek değil, sistemin hata sonrası toparlanma kabiliyetini görmek.

---

## 4) 25–28: SoC-Level Entegrasyon (2 örnek)

## Örnek 4A: `chs_boot_seq_test` + `chs_boot_seq_vseq`
- Test: [verif/tb/tests/chs_boot_seq_test.sv](verif/tb/tests/chs_boot_seq_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_boot_seq_vseq.sv](verif/tb/sequences/virtual/chs_boot_seq_vseq.sv)

### Ana çağrılar
- `dmi_write(DMCONTROL)` dmactive/haltreq/resumereq
- `dmi_read(DMSTATUS/HARTINFO/SBCS)`
- `sba_read32(BOOTROM_BASE)`

### Yol
JTAG Debug Module üzerinden core kontrol + BootROM erişim doğrulaması.

### "Nereden anlıyoruz?"
- `DMSTATUS` bitleri (`allhalted`, `allrunning`) doğrudan core debug durumunu raporlar.
- BootROM adresinden SBA okuma, memory map doğrulamasıdır.

### Neden gerekli?
Bu test, boot kontrol akışını debug perspektifinden uçtan uca doğrular.

---

## Örnek 4B: `chs_memmap_test` + `chs_memmap_vseq`
- Test: [verif/tb/tests/chs_memmap_test.sv](verif/tb/tests/chs_memmap_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_memmap_vseq.sv](verif/tb/sequences/virtual/chs_memmap_vseq.sv)

### Ana çağrılar
- Çoklu base/boundary adrese `sba_read32`
- `dmi_read(SBCS)` ile `sberror` kontrolü

### Amaç
Address decode ve peripheral erişilebilirlik doğrulaması.

### Kanıt
Doğru adresler erişilebilir, unmapped/yanlış alanlar beklenen hata davranışını verir.

---

## 5) 29–31: AXI Testleri (2 örnek)

## Örnek 5A: `chs_axi_protocol_test`
- Test: [verif/tb/tests/chs_axi_protocol_test.sv](verif/tb/tests/chs_axi_protocol_test.sv)
- AXI checker: [verif/tb/top/chs_axi_protocol_checker.sv](verif/tb/top/chs_axi_protocol_checker.sv)

### Nasıl çalışır?
JTAG SBA ile farklı regionlara read/write üreterek AXI LLC portunda trafik oluşturur.

### Nerede gözlenir?
- AXI passive agent monitor
- AXI SVA checker assertion/cover
- Scoreboard AXI sayaçları

---

## Örnek 5B: `chs_axi_stress_test`
- Test: [verif/tb/tests/chs_axi_stress_test.sv](verif/tb/tests/chs_axi_stress_test.sv)

### Ana çağrılar
- DRAM bölgesine burst `sba_write32/sba_read32`
- Periyodik progress raporu: scoreboard AXI sayaçları

### Amaç
Ağır yükte protokol/latency/RAW tutarlılığı.

### Kanıt
`axi_raw_match/axi_raw_mismatch`, `axi_error_count`, checker ihlal durumu.

---

## 6) 32–36: Coverage Booster (2 örnek)

## Örnek 6A: `chs_cov_jtag_corner_test` + `chs_cov_jtag_corner_vseq`
- Test: [verif/tb/tests/chs_cov_jtag_corner_test.sv](verif/tb/tests/chs_cov_jtag_corner_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_cov_jtag_corner_vseq.sv](verif/tb/sequences/virtual/chs_cov_jtag_corner_vseq.sv)

### Ne yapar?
IR değerleri, DR uzunluk aralıkları, DMI op ve addr kombinasyonlarını sistematik tarar.

### Neden bu şekilde?
Fonksiyonel coverage’da eksik binleri hedefli kapatmak için.

---

## Örnek 6B: `chs_cov_axi_region_test` + `chs_cov_axi_region_vseq`
- Test: [verif/tb/tests/chs_cov_axi_region_test.sv](verif/tb/tests/chs_cov_axi_region_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_cov_axi_region_vseq.sv](verif/tb/sequences/virtual/chs_cov_axi_region_vseq.sv)

### Ne yapar?
8 AXI regiona erişim dener (debug, bootrom, clint, plic, peripherals, spm, dram, unmapped).

### Özel nokta
Unmapped erişimde beklenen hata logları catcher ile warning’e çevrilir.

---

## 7) 37–42: Out-of-Scope IP Testleri (2 örnek)

## Örnek 7A: `chs_usb_test` + `chs_usb_vseq`
- Test: [verif/tb/tests/chs_usb_test.sv](verif/tb/tests/chs_usb_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_usb_vseq.sv](verif/tb/sequences/virtual/chs_usb_vseq.sv)

### Çağrılar
- OHCI register read/write (`HcControl`, `HcCommandStatus`, port status)
- USB agent: `device_connect()`, `bus_reset()`, `device_disconnect()`

### Yol
SBA ile host controller konfigürasyonu + USB pin davranışının USB agent üzerinden simülasyonu.

---

## Örnek 7B: `chs_idma_test` + `chs_idma_vseq`
- Test: [verif/tb/tests/chs_idma_test.sv](verif/tb/tests/chs_idma_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_idma_vseq.sv](verif/tb/sequences/virtual/chs_idma_vseq.sv)

### Çağrılar
- iDMA source/destination/length/stride/reps register yazımları
- `NEXT_ID` okuması ile launch
- `DONE_ID` polling
- SPM dst data verify

### Kanıt
Transfer tamamlanması (`DONE_ID`) ve veri eşleşmesi.

---

## 8) 43–44: SW-Driven (2 örnek)

## Örnek 8A: `chs_sw_hello_test` + `chs_sw_driven_vseq`
- Test: [verif/tb/tests/chs_sw_hello_test.sv](verif/tb/tests/chs_sw_hello_test.sv)
- Vseq: [verif/tb/sequences/virtual/chs_sw_driven_vseq.sv](verif/tb/sequences/virtual/chs_sw_driven_vseq.sv)

### Akış
1. JTAG/SBA init
2. Core halt
3. Program DRAM’e yükleme
4. PC ayarlama (`DPC` abstract command)
5. Core resume
6. `SCRATCH[2]` poll (EOC)

### Sonuç yorumu
`SCRATCH[2]` LSB=1 ise bitmiş, üst bitler exit code.

---

## Örnek 8B: `chs_sw_gpio_test` + `chs_sw_driven_vseq`
- Test: [verif/tb/tests/chs_sw_gpio_test.sv](verif/tb/tests/chs_sw_gpio_test.sv)

### Farkı
Program image’i test içinde elle kuruluyor (`build_gpio_program`), CPU gerçek firmware gibi bunu çalıştırıyor.

### Neden önemli?
“C testi gibi davranan SV testi”nin doğrudan örneği: firmware davranışını UVM gözlem altyapısıyla birlikte doğrular.

---

## 9) Teknik terimler (sunumda hızlı anlatım için)

- `IDCODE`: JTAG üzerinden okunan, cihaz kimlik/versiyon bilgisini taşıyan register.
- `DMI`: Debug Module Interface; debug register erişim protokolü.
- `SBA`: System Bus Access; debug modülünden sistem bus’ına memory-mapped erişim kapısı.
- `Virtual Sequence`: Çoklu IP adımını orkestre eden senaryo katmanı.
- `Virtual Sequencer`: Alt sequencer handle’larını tutan orkestratör.

---

## 10) Bu dokümandaki analizler için kullanılan ana dosyalar

- Topoloji/bağlantı: [verif/tb/top/tb_top.sv](verif/tb/top/tb_top.sv)
- Environment: [verif/tb/env/chs_env.sv](verif/tb/env/chs_env.sv)
- Scoreboard/Coverage: [verif/tb/env/chs_scoreboard.sv](verif/tb/env/chs_scoreboard.sv), [verif/tb/env/chs_coverage.sv](verif/tb/env/chs_coverage.sv)
- JTAG/SBA çekirdek API: [verif/tb/sequences/ip/jtag_base_seq.sv](verif/tb/sequences/ip/jtag_base_seq.sv)
- Test listesi: [verif/sim/run_all_tests.tcl](verif/sim/run_all_tests.tcl)
- Regresyon sonucu: [verif/sim/regression_results.log](verif/sim/regression_results.log)

---

Bu doküman mevcut projeyi öğrenme amacıyla hazırlanmıştır; yeni SoC için metodoloji çıkarımı yapılırken önce bu dosyadaki 5 kanıt yaklaşımı (adres, yol, gözlem, davranış, kapsam) birebir uygulanmalıdır.


---

## EK: SoC-Level Testlerde Transaction Noktası ve Kod Yazım Mantığı (Detaylı Teknik Açıklama)

### SoC Testlerinde Doğru Yere Doğru Transaction Nasıl Gönderilir?

#### 1. Hangi Bilgiye Dayanıyorum?
  - **Memory Map:** Hangi IP/register hangi adreste? Transaction’ın hedef adresi burada belirlenir.
  - **RTL (soc_top.sv, IP modülleri):** IP’lerin bus’a nasıl bağlandığı, register offset’leri, port isimleri.
  - **Register Model (RAL):** Register’lara isimle erişim, offset ve erişim tipleri.
  - **Verification Plan/Spec:** Hangi fonksiyonun, corner case’in test edileceği.

#### 2. Transaction Noktasını ve Kodunu Nasıl Seçiyorum?
  - **Hedef IP veya register’ın adresini** Memory Map’ten veya RAL’den buluyorum.
  - **RTL’den** bağlantı ve offset doğrulaması yapıyorum.
  - **UVM sequence** içinde, ilgili agent’ın sequencer’ına uygun transaction objesi gönderiyorum (örn. `axi_transaction`, `spi_transaction`).
  - Transaction’ın adres, data, komut (read/write) gibi alanlarını Memory Map ve protokol gereksinimine göre dolduruyorum.
  - Transaction, agent’ın driver’ı üzerinden fiziksel interface’e gider ve RTL’deki IP’ye ulaşır.
  - Monitor ve scoreboard ile transaction’ın doğru yere ulaşıp ulaşmadığını, response’un beklenen şekilde gelip gelmediğini kontrol ediyorum.

#### 3. Kodda Çağırdığım Her Yapının Mantığı
  - **RAL register access:** `regmodel.spi_ctrl_reg.write(status, data);` → RAL modeli, SPI controller’ın register’ına doğru adresten erişir.
  - **AXI write:** `axi_seq.start_address = SPI_BASE_ADDR;` → AXI agent, bu adrese bir write transaction başlatır.
  - **Virtual sequence:** Birden fazla IP’ye veya bus’a aynı anda transaction göndermek için kullanılır.
  - **Scoreboard:** Monitor’lerden gelen transaction’ları beklenen golden model ile karşılaştırır.

---

### Örnek: SoC Level Test 2 ve 4

#### SoC Level Test 2: SPI Flash Write/Read

1. **Hangi bilgiye dayanıyorum?**
  - SPI controller’ın base adresi: Memory Map’ten (örn. 0x4000_0000)
  - SPI register offset’leri: RAL modelinden veya datasheet’ten
  - Bağlantı: soc_top.sv’de SPI controller’ın hangi bus’a bağlı olduğunu ve hangi adres aralığında olduğunu kontrol ediyorum

2. **Kodda ne yapıyorum?**
  - SPI’ye veri yazmak için: AXI agent üzerinden, SPI controller’ın data register’ına bir write transaction gönderiyorum. Adres: SPI_BASE_ADDR + DATA_REG_OFFSET
  - SPI’den veri okumak için: Aynı şekilde, AXI agent ile read transaction gönderiyorum.
  - Monitor, bu transaction’ı yakalıyor ve scoreboard ile beklenen değeri karşılaştırıyor.

3. **Kodda çağırdığım yapılar**
  - `spi_reg_model.data_reg.write(status, value);` → RAL üzerinden register’a yaz
  - `axi_seq.start_address = SPI_BASE_ADDR + DATA_REG_OFFSET;` → AXI transaction başlat
  - `spi_agent.monitor.analysis_port.connect(scoreboard.spi_export);` → Monitor’dan scoreboard’a coverage ve checking için bağlantı

4. **Neye göre yazıyorum?**
  - Memory Map: Adresleri belirler
  - RTL: Register’ların isim ve offset’lerini doğrularım
  - Spec: Transaction’ın sırası ve protokol gereksinimleri

---

#### SoC Level Test 4: AXI-to-GPIO Transaction

1. **Hangi bilgiye dayanıyorum?**
  - GPIO controller’ın base adresi: Memory Map’ten
  - GPIO register offset’leri: RAL modelinden
  - AXI bus’ın bağlantısı: soc_top.sv’den, AXI master’ın GPIO’ya erişip erişemeyeceğini kontrol ediyorum

2. **Kodda ne yapıyorum?**
  - AXI üzerinden GPIO’ya write: AXI agent ile, GPIO controller’ın output register’ına bir write transaction gönderiyorum. Adres: GPIO_BASE_ADDR + OUTPUT_REG_OFFSET
  - GPIO’dan read: AXI agent ile read transaction gönderiyorum. Monitor, transaction’ı yakalıyor ve scoreboard ile karşılaştırıyor.

3. **Kodda çağırdığım yapılar**
  - `gpio_reg_model.output_reg.write(status, value);` → RAL ile register’a yaz
  - `axi_seq.start_address = GPIO_BASE_ADDR + OUTPUT_REG_OFFSET;` → AXI transaction başlat
  - `gpio_agent.monitor.analysis_port.connect(scoreboard.gpio_export);` → Monitor’dan scoreboard’a bağlantı

4. **Neye göre yazıyorum?**
  - Memory Map: Hedef adresi belirler
  - RTL: Register offset ve bağlantı doğrulaması
  - Spec: GPIO fonksiyonelliği ve protokol gereksinimleri

---

### Genel Prensip: Test Kodunu Yazarken Hangi Bilgiye Nasıl Bakıyorum?

1. **Memory Map:** Hedef IP/register adresini bulmak için
2. **RTL:** Bağlantı, register offset, interrupt hatları, bus mapping
3. **RAL Model:** Register erişimini kolaylaştırmak için
4. **UVM Agent/Sequence:** Transaction’ı doğru interface’e göndermek için
5. **Monitor/Scoreboard:** Transaction’ın doğru yere ulaşıp ulaşmadığını ve response’un doğruluğunu kontrol etmek için
6. **Spec/Verification Plan:** Testin coverage ve fonksiyonel gereksinimlerini sağlamak için

---

### Bu Bilgilerle Test Kodunu Nasıl Yazabilirsin?

- **Spec veya Memory Map varsa:** Adresleri ve register offset’lerini oradan al, RAL modelini oluştur.
- **RTL varsa:** Bağlantıları, register isimlerini ve offset’lerini oradan doğrula.
- **UVM testini yazarken:** Transaction’ı, agent’ın sequencer’ına gönder, adres ve data alanlarını Memory Map’e göre doldur.
- **Monitor ve scoreboard ile:** Transaction’ın doğru yere ulaşıp ulaşmadığını ve response’un doğruluğunu kontrol et.

---
