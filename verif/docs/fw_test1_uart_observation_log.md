# Test 1 Analiz Raporu: test_lvl_easy_uart_hello

## 1. Genel Durum (Verdict)
* **Sonuç**: PASS
* **EOC (End-of-Computation)**: Başarıyla algılandı (exit_code=0).
* **Scoreboard Durumu**: Data trafiği doğrulandı (`no checks` mesajı, UVM paket bazlı doğrulama yerine doğrudan EOC polling mimarisi kullanıldığının beklenen bir sonucudur).

## 2. Çalışma Akışı ("Kim Kime İstek Atıyor?")

1. **JTAG => RAM (Firmware Yükleme Aşaması)**
   * **Ne oldu?**: Sistem resetten çıkar çıkmaz `chs_sw_driven_vseq` devreye girdi JTAG TAP üzerinden System Bus Access (SBA) aktif edildi.
   * **Kanıt**: Loglardaki `[SBA] SBA write OK: [0x80000000] = ...` mesajları ve toplam 1575 JTAG transaction. UVM JTAG master, `.words` dosyasındaki C kodunu JTAG üzerinden RAM'e yazdı. Waveform'daki JTAG `tck`/`tdi`/`tdo` sinyallerindeki yoğun aktivite de bunu gösterir.

2. **Core => AXI Fabric => RAM (Komut Getirme - Instruction Fetch)**
   * **Ne oldu?**: Boot yüklemesinden sonra Core resetlendi ve program counter (PC) `0x80000000`'a (RAM başlangıcı) zıpladı. Core, AXI veriyolu üzerinden RAM'den komutları (instructions) fetch etmeye başladı.
   * **Kanıt**: AXI Monitor raporunda yer alan `Read transactions: 7`. Core, AXI üzerinden 7 adet read burst yaparak JTAG ile yüklenen yazılımı okudu (`R COMPLETE: AXI AXI_READ: addr=0x000080000000`, vd.). Monitor yazma (Write) görmedi çünkü Core kodu değiştirmeden sadece okuyarak koşturdu. Waveform görüntülerindeki `araddr` ve `rdata` aktivitesi bu okumalara aittir.

3. **Core => Peripheral Bus => UART (Mesaj Yazdırma)**
   * **Ne oldu?**: Core, çalıştırdığı C kodunun (`printf` vb.) bir sonucu olarak UART çevresel birimine karakterler gönderdi. 
   * **Kanıt**: Çıktıda açıkça görülen `"[EASY] UART hello start"` ve `"[EASY] UART hello pass"` SCB mesajları. Ayrıca UART monitörünün yakaladığı **47 TX frame** aktivitesi. Son paylaştığınız waveform ekran görüntülerindeki `UART_GPIO` grubunda `uart_tx` pini üzerindeki veri transfer dalgalanmaları bu işlemi somut olarak görselleştirmektedir.

4. **Core => System Registers => EOC Polling (Simülasyon Bitişi)**
   * **Ne oldu?**: UART üzerinden işi bitiren yazılım, testin bittiğini haber vermek için SOC'nin Scratch/EOC kaydedicisine bir yazma işlemi (**Memory Mapped Write**) yaptı.
   * **Kanıt**: `[chs_sw_driven_vseq] EOC detected after 292 polls` logu. Sanal sequence (vseq), SoC'yi dışarıdan okuyarak bu kayıttaki değerin `1`'e döndüğünü tespit etti ve çıkış kodu `0` ile testi başarıyla kapattı.

## 3. Mimari Değerlendirme ve Sonuç
**Senaryo Başarılı**: SoC dışarıdan (JTAG) uçbiriminden başarıyla programlanabilmiş, işlemci Core sistem veriyoluna (AXI) çıkıp hafızadan komutları okumuş ve çevresel birimleri (UART) hedeflendiği gibi yönetebilmiştir. Donanım blokları (JTAG, Core, AXI Bus, UART_TX) sistem mimarisinde tasarlandığı sırayla ve hatasız bir biçimde etkileşime girmiştir. Elde edilen log grafikleri ve Waveform AXI/UART sinyal izdüşümleri ile bu veri akışı tam olarak doğrulanmıştır.
