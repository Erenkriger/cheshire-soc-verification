# Test 3 Analiz Raporu: test_lvl_easy_mem_smoke

## 1. Genel Durum
- Sonuc: PASS
- EOC: Tespit edildi, exit_code=0
- Simulasyon bitis zamani: 787130000 ps

## 2. Dosya Adi ve Komut Notu
Bu testte story dosyasi asagidaki adla uretilmistir:
- sim/logs/test_lvl_easy_mem_smoke.gui.story.txt

Asagidaki ad bulunamadigi icin cat hatasi olmustur:
- sim/logs/test_lvl_easy_mem_smoke.story.txt

Bu farkin nedeni, extract scriptinin giris dosya adini oldugu gibi koruyup sonuna .story.txt eklemesidir.

## 3. Kronolojik Tetikleme Zinciri (Kim neyi tetikledi?)
1. Testbench Virtual Sequence JTAG debug kanalini ayaga kaldirdi.
2. IDCODE dogrulamasi yapildi: 0x1c5e5db3.
3. DMSTATUS kontrolu ile cekirdegin halt durumda oldugu dogrulandi (allhalted=1).
4. JTAG SBA ile firmware DRAM bolgesine parca parca yazildi.
5. Cekirdek resume edildi, DMSTATUS ile allrunning=1 dogrulandi.
6. Core, AXI uzerinden komut fetch yaparak kodu icra etti.
7. Firmware EOC registerini 1 yapti, sequence 3 poll sonra EOC yakaladi.
8. Test PASS olarak sonlandirildi.

## 4. Kanit Satirlari (Ozet)
- EOC: EOC detected after 3 polls, raw=0x00000001, exit_code=0
- Pass: SW TEST PASSED: test_lvl_easy_mem_smoke (exit_code=0)
- DMSTATUS baslangic: 0x000c0382 (allhalted=1)
- DMSTATUS resume sonrasi: 0x000f0c82 (allrunning=1, resumeack=1)
- JTAG transaction sayisi: 251
- AXI ozet: writes=0, reads=5, errors=0
- AXI handshake: AR=5, R=40
- UART/SPI/I2C/GPIO transaction: 0
- Total data checks: 0 PASS=0 FAIL=0 (SW-driven akista beklenen davranis)

## 5. Waveform ile Iliskilendirme
### 5.1 AXI_IC grubu
- Gorulen aktivite AR ve R kanallarinda.
- AW/W/B yok; bu da write transaction olmadigini dogruluyor.
- Bu testte ana trafik instruction fetch oldugu icin read agirlikli akis beklenir.

### 5.2 JTAG grubu
- Simulasyonun erken fazinda yogun toggle vardir.
- Bu, firmware yukleme ve debug kontrol (SBA read/write, DMSTATUS polling) fazina karsilik gelir.

### 5.3 UART_GPIO ve SPI_I2C gruplari
- Hemen hemen sabit/idle gorunur.
- Bunun nedeni test hedefinin bellek/smoke akisinin dogrulanmasi olmasi; UART/SPI/I2C/GPIO fonksiyonel senaryosu bu testte hedeflenmemistir.

### 5.4 CORE_INTERNAL grubu
- Program sayaci ve ic register hareketleri kod icrasi ile uyumludur.
- Resume sonrasi cekirdegin calistigi dalga formundan okunur.

## 6. Neden Total Data Checks 0?
Bu test SW-driven oldugu icin scoreboard expected-vs-actual veri karsilastirma kuyruklari dolmaz. Dolayisiyla data-check sayaci 0 kalir. Basari kriteri, firmwarein EOC yazmasi ve exit_code=0 donmesidir. Bu nedenle 0 PASS/0 FAIL bu test yapilmadi demek degil, dogrulama mekanizmasi farkli demektir.

## 7. Teknik Sonuc
test_lvl_easy_mem_smoke, JTAG yukleme + AXI instruction fetch + EOC kapanis zincirini hatasiz tamamlamistir. Sistem butunlugu acisindan debugden boota gecis, core resume ve bellekten kod icrasi adimlari dogru calismistir. Bu testte periferal protokollerin (UART/SPI/I2C/GPIO) idle kalmasi beklenen ve dogru davranistir.
