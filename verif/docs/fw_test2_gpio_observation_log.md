# Test 2 Analiz Raporu: test_lvl_easy_gpio_basic

## 1. Genel Durum (Verdict)
* **Sonuç**: PASS
* **EOC (End-of-Computation)**: Başarıyla algılandı (exit_code=0).
* **Scoreboard Özeti**: JTAG=263, AXI reads=5/writes=0, GPIO transactions=6, UART/SPI/I2C=0.

## 2. Kritik Soru ve Yanıt
**Soru 1: `Total data checks : 0 PASS=0 FAIL=0` neden görülüyor?**

**Yanıt:** Bu sonuç, testin çalışmadığını değil test mimarisinin SW-driven olduğunu gösterir. Bu seviyede stimulus UVM data-sequence tarafından değil işlemci üzerinde koşan firmware tarafından üretilir. UVM scoreboard bu nedenle expected-vs-actual paket kıyasından çok trafik gözlemi yapar. Geçme kriteri, firmware'in EOC register'ına başarı kodu yazmasıdır (`exit_code=0`).

**Soru 2: SPI/I2C sinyalleri neden çok az veya hiç tetiklenmedi?**

**Yanıt:** `test_lvl_easy_gpio_basic` yalnızca GPIO yolunu hedefler. SPI ve I2C kontrol register'larına firmware tarafında erişim yapılmadığı için ilgili pinler idle durumda kalır. Waveformda `spih_sck_o`, `spih_csb_o`, `i2c_scl_o`, `i2c_sda_o` hatlarının sabit görünmesi bu test için beklenen ve doğru davranıştır.

## 3. Test 1 - Test 2 Karşılaştırmalı Tetikleme Zinciri
1. **Test 1 (`test_lvl_easy_uart_hello`)**
   * JTAG -> RAM yükleme trafiği yoğun (1575 transaction).
   * Core -> AXI üzerinden komut fetch (7 read burst).
   * Core -> UART TX aktif (47 frame).
   * EOC polling daha uzun sürer (292 poll).
2. **Test 2 (`test_lvl_easy_gpio_basic`)**
   * JTAG -> RAM yükleme daha kısa (263 transaction).
   * Core -> AXI fetch daha az (5 read burst).
   * Core -> GPIO register erişimi aktif (6 transaction, örnek değer `0x00001234`).
   * UART/SPI/I2C yolunda işlem yok (hedef dışı alt-sistemler idle).
   * EOC daha hızlı tamamlanır (7 poll).

## 4. Waveform Tabanlı Aktivite Analizi (Test 2)
1. **AXI_IC grubu**
   * Beklenen aktivite: AR/R kanallarında burst tabanlı fetch.
   * Gözlem: Read odaklı trafik mevcut, write yok. Bu, firmware komut okumaya odaklı erken faz ile uyumlu.
2. **UART_GPIO grubu**
   * Beklenen aktivite: `gpio_en_o` ile pin yönü açılması, `gpio_o` ile output pattern sürülmesi.
   * Gözlem: `gpio_en_o=0x0000ffff` ve `gpio_o=0x00001234` seviyeleri görülüyor. GPIO kontrol zinciri doğru tetiklenmiş.
3. **SPI_I2C grubu**
   * Beklenen aktivite: Bu testte yok veya ihmal edilebilir düzey.
   * Gözlem: Saat/veri hatları idle. Test hedefi dışında kaldığı için doğru durum.
4. **CORE_INTERNAL grubu**
   * Beklenen aktivite: Komut icrası boyunca yoğun iç durum değişimi.
   * Gözlem: Çekirdek iç register/sinyal hareketliliği mevcut; periferal yazmalarıyla zaman hizası tutarlı.

## 5. Çalışma Akışı (Kim Kimi Tetikliyor?)
1. **JTAG => RAM (Firmware Yükleme Aşaması)**
   * **Ne oldu?**: `chs_sw_driven_vseq` JTAG üzerinden System Bus Access (SBA) komutlarıyla RAM'e C derlemesinden gelen kodları yazdı. 
   * **Kanıt**: Monitor raporundaki `JTAG transactions: 263`. Önceki testten daha az transaction var çünkü bu testteki GPIO C kodu `printf` kullanan UART testine göre çok daha az satır Assembly komutuna derlenmiştir.

2. **Core => AXI Fabrik => RAM (Komut Getirme - Instruction Fetch)**
   * **Ne oldu?**: İşlemci resetlenip RAM adresinden (`0x80000000`) okumaya başlayarak komutlarını çekti. 
   * **Kanıt**: AXI Monitor loglarında sadece `Read transactions: 5` görülüyor. Yazılım AXI fabrik üzerinden 5 döngüde kod okumasını (instruction fetch) bitirip işlemeye geçmiş.

3. **Core => Peripheral Bus => GPIO (Sinyal Sürme ve Okuma)**
   * **Ne oldu?**: İşlemci (Core), C yazılımında GPIO pinlerini kontrol eden memory-mapped register adreslerine (örn: GPIO yön/output kaydı) değerler (`0x00001234` vb.) yazıp okumalar yaptı. 
   * **Kanıt**: Scoreboard'un yakaladığı `[SCB_GPIO] GPIO TR #6: op=READ_OUTPUT data=0x00001234 mask=0x0000edcb ...` satırı. Yine rapordaki `GPIO transactions : 6 (match=0 mismatch=0)`. Waveform üzerinde `UART_GPIO` grubunda `gpio_o` (çıkış değerleri) ve yön sinyallerinde (`gpio_en_o`) bu oynamaları birebir izliyoruz. Ek olarak `GPIO Protocol : 45.0%` Coverage yakalanmıştır.

4. **Core => System Registers => EOC Polling (Simülasyon Bitişi)**
   * **Ne oldu?**: GPIO üzerinden döngüsünü bitiren yazılım, başarılı çıkış vermek için yine EOC register'ına `0` hatasızlık koduyla başvurdu.
   * **Kanıt**: `[chs_sw_driven_vseq] EOC detected after 7 polls` logu. Sanal sequence (vseq) çok daha hızlı bir şekilde `1` bayrağını ve `exit_code=0` ibaresini görüp testi başarılı sonlandırdı.

## 6. Mimari Değerlendirme ve Sonuç
**Senaryo Başarılı**: SoC, JTAG arayüzünden hatasız ve daha düşük yüklemeyle (`263 tx`) programlanmıştır. İşlemci çekirdeği veri yolu (AXI) üzerinden komut okumasını hatasız tamamlamış, GPIO çevresel bloğuyla doğru register konfigürasyonlarını gerçekleştirmiştir (`6 transactions`). Sistemi sürükleyen kontrol yazılımı (Firmware) hedeflendiği gibi çıkış registerına ulaşıp testi eksiksiz (0 hata) sonlandırmıştır. Donanım ve entegrasyon GPIO bazlı kontrollerde düzgün çalışmaktadır.
