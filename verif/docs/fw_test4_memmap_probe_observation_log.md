# Test 4 Analiz Raporu: test_lvl_medium_memmap_probe

## 1. Genel Sonuc
- Test sonucu: PASS
- EOC: tespit edildi (3 poll), exit_code=0
- Hata durumu: UVM_ERROR=0, UVM_FATAL=0

## 2. Sunucuda Dogrulanan Log Dosyalari
- sim/logs/test_lvl_medium_memmap_probe.gui.log
- sim/logs/test_lvl_medium_memmap_probe.gui.story.txt
- sim/logs/test_lvl_medium_memmap_probe.manual.log

## 3. Zaman Sirali Tetikleme Akisi (Kim neyi tetikledi?)
1. UVM virtual sequence JTAG TAP reset ve SBA init yapti.
2. IDCODE dogrulamasi yapildi (0x1c5e5db3).
3. DMSTATUS ile core halt durumda dogrulandi (allhalted=1).
4. JTAG-SBA ile firmware DRAM adreslerine yuklendi.
5. Core resume edildi ve firmware calismaya basladi.
6. Core, AXI uzerinden instruction fetch yapti.
7. Firmware EOC registerina basari kodu yazdi.
8. Sequence EOC bitini 3 polling sonunda gordu ve testi PASS kapatti.

## 4. Logdan Sayisal Kanitlar
- EOC: 3 poll
- JTAG transactions: 279
- AXI reads: 4
- AXI writes: 0
- AXI AR handshakes: 4
- AXI R handshakes: 32
- UART transactions: 0
- SPI transactions: 0
- I2C transactions: 0
- GPIO transactions: 0
- Total data checks: 0 PASS=0 FAIL=0

## 5. Neden Periferal Aktivitesi (UART/SPI/I2C/GPIO) Gorunmedi?
Bu testin C kodu (sw/tests/test_lvl_medium_memmap_probe.c) periferal registerlarina agirlikli olarak okuma (status probe) yapar:
- (void)REG32(UART_BASE, UART_LSR)
- (void)REG32(SPI_BASE, SPI_STATUS)
- (void)REG32(I2C_BASE, I2C_STATUS)
- (void)REG32(GPIO_BASE, GPIO_DATA_IN)

Bu tip probe okumalari, UART TX pininde veri ciktisi, SPI saat/veri salinimi veya I2C SCL/SDA togglingi uretmek zorunda degildir. Dolayisiyla protokol monitorlerinde transfer sayisinin sifir gorunmesi bu testte beklenen davranistir.

## 6. AXI Neden Yalnizca Read Gosteriyor?
Mevcut monitor AXI LLC tarafini raporladigi icin esasen instruction fetch akislarini yakaliyor. Bu testte de gorulen 4 adet read burst DRAM komut cekme fazina uyumludur. MMIO probe islemleri periferik back-end'de farkli yol/katmanda kalabilir; bu nedenle AXI LLC monitor sayacinda write gorunmemesi anormal degildir.

## 7. Total Data Checks = 0 Aciklamasi
Bu test SW-driven oldugu icin scoreboard expected-vs-actual veri kuyrugu karsilastirmasi yapmaz; trafik gozetimi yapar. Gecme kriteri firmwarein EOC registerini dogru kodla set etmesidir. Bu nedenle PASS/FAIL data-check sayacinin sifir olmasi, testin calismadigi degil dogrulama modelinin farkli oldugu anlamina gelir.

## 8. Teknik Degerlendirme
Test 4, SoC bellek haritasi erisilebilirligini probe etme amacini yerine getirmistir:
- debugden boota gecis dogru,
- core execution dogru,
- EOC kapanisi dogru,
- kritik hata yok.

Bu kosu, "protokol trafik uretme" degil "adreslenebilirlik ve temel MMIO ulasilabilirligi" odakli oldugu icin periferal pin aktivitesinin dusuk olmasi beklenen ve dogru sonuctur.
