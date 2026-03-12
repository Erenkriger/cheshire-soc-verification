# Zero to Reusable UVM: Kapsamlı SoC Doğrulama ve Entegrasyon Rehberi

Bu rehber, baştan sona bir System-on-Chip (SoC) mimarisinin Universal Verification Methodology (UVM) ile nasıl doğrulandığını uçtan uca anlatmaktadır. Hazırlanan altyapı, açık kaynaklı **Cheshire SoC** projesi baz alınarak kurulmuş olup; nihai amacımız bu mimariyi test etmekten ziyade, "Gelecekte karşımıza çıkacak, tasarımı tamamen kapalı kutu (Black Box) olan herhangi bir çipin doğrulaması için **saniyeler içinde taşınabilir (reusable)** endüstri standardı bir test ortamı/iskeleti üretmek"tir.

Bu doküman teknik sunumlar, mimari savunmalar ve jüri soruları düşünülerek **"Yaşayan Bir Doğrulama Raporu (Living Document)"** olarak dizayn edilmiştir.

---

## 1. Mimari Sınırlarımız: Neyi Doğruladık, Neyi Doğrulamadık?

SoC tasarımları (Cheshire dahil) devasa yapılardır. Doğrulama planlamasında (Verification Plan) ilk iş **"Sınırları çizmektir."** Ekte sunulan Cheshire Architecture şeması üzerinden doğrulama ufkumuzu tanımladık.

### 1.1. Doğrulama Seviyemiz: (Chip/SoC Level Verification)
Bizim yaklaşımımız endüstri tabiriyle **Chip/SoC Level (Top-Level)** bir doğrulamadır.
Bunun sebebi: İçerideki modülleri (Örn: UART modülünü) dışarıya koparıp, ona özel basit bir testbench (`tb_uart.sv`) yazmadık. Biz projeyi en üstten `soc_top.sv` olarak bir bütün halinde sarmaladık ve sanal elektrik sinyallerini çipin **en dış pinlerinden (Pad / Bump)** enjekte ettik.

### 1.2. Mimari Üzerinde "Neyi Başardık?" (In-Scope)
*   **Outside-In (Dışarıdan İçeriye) Stimulus:** Biz çipi kalbinden (CVA6) değil, dış pininden (JTAG) kontrol ettik. `JTAG Agent`'ımız ile JTAG pinlerine DMI (Debug Module Interface) komutları yollayıp, tasarımı **Halt (Durdurma)** durumuna soktuk.
*   **System Bus Access (SBA) Hakimiyeti:** JTAG üzerinden "SBA" protokolü ile şemadaki yeşil omurga olan **AXI4+ATOP Crossbar**'a eriştik. Bu crossbar'dan geçerek sağdaki **Regbus Demux** üzerinden çipin en uçtaki çevrebirimlerine (UART, I2C, SPI, GPIO) komut yazdık.
*   **Uçtan Uca Pin Gözlemi:** SBA ile içeriden "UART üzerinden A harfi yolla" komutunu verdiğimizde, dışarıdaki diğer UVM modülümüz (`UART Monitor`) pinden "A" harfinin çıktığını başarıyla Scoreboard'a raporladı. Bu sayede tüm iletişim omurgasının kusursuzluğunu ispatladık.

### 1.3. Doğrulamadığımız ve Dışarıda Bıraktığımız Alanlar (Out-of-Scope)
*Sunumlarda şeffaf olunması gereken alanlar:*
*   **İçeriden Dışarıya (Inside-Out) Akış Uygulanmadı:** CVA6 çekirdekleri (BootROM üzerinden kendi başına komut alıp (C/Assembly instruction fetch)) sistemi ayağa kaldırmadı. İşlemciler tamamen pasif tutulup çevre donanımlar test edildi.
*   **Karmaşık IP'ler Kapsam Dışı:** Şemadaki `USB 1.1`, `VGA`, `Serial Link` ve `iDMA` yapıları için spesifik Agent'lar/Senaryolar yazılmadı. Trafik yaratmamaları için bypass edildiler.
*   **DRAM Controller:** Last Level Cache üzeinden Memory'ye (DRAM) sadece SBA bypass ile pasif paket atıldı, aktif bellek testleri (Memory BIST) uygulanmadı.

---

## 2. Temel Doğrulama Kavramları ve Projemizdeki Kodlu Örnekleri

Sunumlarda "Biz UVM kullandık" demek yetersizdir. Altındaki modüler yazılım mühendisliğini göstermek elzemdir. UVM altyapımız 6 ajanlı bir ordudan oluşur. İşte temel terimler ve `verif/tb/` altındaki varlıkları:

### 2.1. Agent, Driver ve Monitor nedir?
*   **Kavram:** Agent, spesifik tek bir dili konuşan (örn: I2C) ekiptir. Yazılımsal veri (Transaction) ile Elektriksel sinyal (Pin) arasında çevirmenlik yapar.
*   **Projedeki Karşılığı:** Klasörümüzdeki (`agents/uart_agent/`).
*   **Nasıl Çalışır (Monitor Örneği):** Sistemden gelen bitleri (Low/High voltajı) toplayıp yazılımsal klasöre çevirir. `uart_monitor.sv` dosyası rx pinini izler, stop bitini görünce Scoreboard'a paslar.

```systemverilog
// verif/tb/agents/uart_agent/uart_monitor.sv içindeki sinyal yakalama mantığı
task uart_monitor::run_phase(uvm_phase phase);
    uart_transaction tr;
    forever begin
        @(negedge vif.rx); // Start bitini bekle
        tr = uart_transaction::type_id::create("tr");
        #(m_cfg.baud_delay_ns); // 1 Baud Periyodu kadar (Start bit ortasına) gel
        for (int i = 0; i < 8; i++) begin
            #(m_cfg.baud_delay_ns); // Sinyali bekle
            tr.data[i] = vif.rx;    // Voltajı Data klasörüne kaydet
        end
        ap.write(tr); // Karara (Scoreboard) veya Analize (Coverage) ilet!
    end
endtask
```

### 2.2. Scoreboard nedir?
*   **Kavram:** Testin Başarılı (PASS) veya Başarısız (FAIL) olduğunu belirleyen hakimdir. Bir taraftan beklediği veriyi (Expected) kuyruğa alır, diğer taraftan devreden çıkan (Actual) veriyi dinler.
*   **Projedeki Karşılığı:** `env/chs_scoreboard.sv`. Dışarıdan veya içeriden beklenen (Expected) veriyi kuyruğa alır. Eşleşmezse testi Fatal hatasıyla çökertir.

```systemverilog
// verif/tb/env/chs_scoreboard.sv içinde UART verisi doğrulama
virtual function void write_uart(uart_transaction tr);
    bit [7:0] expected_data;
    if (expected_uart_data.size() > 0) begin
        expected_data = expected_uart_data.pop_front();
        if (tr.data === expected_data) begin
            `uvm_info("SCB_UART", $sformatf("PASS! Gelen: %h | Beklenen: %h", tr.data, expected_data), UVM_HIGH)
        end else begin
            `uvm_error("SCB_UART_ERR", $sformatf("FAIL! Gelen: %h | Beklenen: %h", tr.data, expected_data))
        end
    end
endfunction
```

### 2.3. SVA (SystemVerilog Assertion) Nedir? Neden UVM'ye yetinmedik?
*   **Kavram:** Assertion, donanım mimarisinde "Kesinlikle Olması veya Olmaması Gereken" katı elektriksel kuralları, saniyenin milyarda biri ($1ns) hassasiyetinde donanım bazında kontrol eden denetleyicilerdir.
*   **Neden Monitor Kullanmadık?** Çünkü UVM yazılım tabanlıdır, saat vuruşundaki (Clock Tick) anlık bir voltaj sıçramasını (Glitch) yazılım yakalayamaz, assertion donanımsal olarak anında yakalar.
*   **Projedeki Karşılığı:** Projede toplam **3 Checker modülü ve 112 Assertion** yazdık.

```systemverilog
// verif/tb/top/chs_protocol_checker.sv örneği: SPI Chip-Select Koruması (Short-Circuit önlemi)
module chs_protocol_checker(input clk, input [1:0] spi_csb);
    // Kural: CSB hatlarının ikisi aynı anda ASLA "Aktif (Low/0)" olamaz!
    property p_spi_cs_mutex;
        @(posedge clk)
        ~($countones(~spi_csb) > 1); // Sıfır olan pinlerin sayısı 1'den büyük olamaz
    endproperty
    
    a_spi_cs_mutex: assert property (p_spi_cs_mutex) 
        else $error("SVA HATASI: SPI'da iki hedefe aynı anda tetik verildi! Çip Yanar!");
endmodule
```

### 2.4. RAL (Register Abstraction Layer) Nedir?
*   **Kavram:** Çipin içindeki IP'lerin on binlerce register'ı (Adres uzayları) vardır. Test yazan kişinin SPI'ın konfigürasyon adresinin "0x0300_4004" olduğunu ezberlemesi veya sürekli dökümana bakması hamallıktır. RAL otomasyondur.
*   **Projedeki Karşılığı:** Biz `env/ral/` klasöründe RAL modelimizi kurduk. Artık JTAG SBA üzerinden SPI adresine paket yollarken `do_sba_write(32'h03004004, data)` yazmak yerine OOP kullanarak `soc_rm.spi.config.write(data)` diyebiliyoruz.

### 2.5. Functional Coverage, Coverpoint ve Bin Nedir? (%46.62 Efsanesi)
*   **Kavram:** Çipi ne kadar test ettik? Transistörlerin hepsinden 1/0 geçti mi? Bu *Code Coverage*'dır. UVM'de asıl aradığımız *Functional Coverage*'dır. Yani, "Veri protokolünün tüm ihtimallerini test ettik mi?"
*   *Coverpoint:* Gözlemlemek istenen hedeftir.
*   *Bin:* O hedefin sepetleridir. (Örn: Zar atışında 1. Zar coverpoint'tir. Zardaki 1,2,3...6 rakamları Bin'lerdir. 6'sı da geldiğinde coverage %100 olur.)
*   **%46.62 Açıklaması (Çok Önemli):** Bizim projede elde ettiğimiz %46.62 oranı, sistemin tamamının değil, *Kendi yazdığımız Covergroup'ların tetiklenme oranının ortalamasıdır.* Sistem çok büyüktür, ama biz odaklandığımız ajanların fonksiyonlarını derinlemesine test ettik.

```systemverilog
// verif/tb/env/chs_coverage.sv -> uart covergroup örneği
covergroup cg_uart;
    cp_uart_data: coverpoint sampled_uart_data {
        bins zero          = {8'h00};
        bins printable_low = {[8'h20 : 8'h3f]};
        bins all_ones      = {8'hff}; // Eğer testlerimizde sisteme hiç "FF" (255) verisi atılmazsa, bu bin boş kalır, coverage %100 olamaz.
    }
endgroup
```

---

## 3. SoC Test Senaryo Arşivi (36 Testin Anatomisi)

Sequence'lar veriyi üretir, Test'ler bu üretimi hangi modda kullanacağını seçer (Boot Modu, Timeout Modu vb). Aşağıda, sistemi gitgide daha agresif zorlayan aşamalı akışımız bulunmaktadır.

### Aşama 1–3: Tekil Protokol Kontrolleri (Basic Connect & Bring-Up)
*(Amaç: Dış arayüz konfigürasyonlarının elektriksel tepkisi var mı? - Timeout: 10ms)*
1. `chs_sanity_test`: Dürtükleme. JTAG ve GPIO pinleri stabilite testi.
2. `chs_jtag_boot_test`: Çipin JTAG Mode=0 pinleriyle düzgün boot edişi.
3. `chs_uart_test`, `chs_uart_tx_test`, `chs_uart_burst_test`: Tekli byte'tan kesintisiz UART iletişim senaryoları.
4. `chs_spi_single_test`, `chs_spi_flash_test`: Flash okuma davranışı.
5. `chs_i2c_write_test`, `chs_i2c_rd_test`: SDA/SCL hatlarında ACK zorlamaları.
6. `chs_gpio_walk_test`, `chs_gpio_toggle_test`: Ardışık pattern ve walking 1 denemeleri.

### Aşama 3–4: SBA Veriyolu Entegrasyonu ve Çapraz IP Testleri
*(Amaç: Ağacı kurmak. Dışarıdan girip içeriden çıkmak - Timeout: 100ms)*
7. `chs_jtag_sba_test`: AXI omurgasında sadece boş okuma/yazma (Memory Access).
8. `chs_spi_sba_test`, `chs_i2c_sba_test`, `chs_gpio_deep_test`: SBA ile hedef IP'lerin Control/Config Registerlarına direkt yazılıp, pinden veri çıkışının doğrulanması.
9. `chs_stress_test`: Tüm ajanların AXI üzerinde birbirini keserek (Round-Robin) çakışma (Arbiter kilitlenme) denemesi.

### Aşama 5 & 6: RAL ve Error Yakalama (Error Injection)
*(Amaç: Kuralları çiğnediğimizde sistem çöküyor mu, koruma yapıyor mu?)*
10. `chs_ral_access_test`: Tamamen OOP tabanlı register map yazımları.
11. `chs_interrupt_test`: İç GPIO/UART registerlarından CVA6'ya veya PLIC'e kesme (interrupt) gidip gitmediğinin doğrulanması.
12. `chs_sva_coverage_test`: Çok uzun süreli (200ms) full trafik ile Coverage bind'lerini doldurma çabası.
13. `chs_error_inject_test`: Sisteme adreslenmeyen bölgeden veri çekme talebi. (Bu aşamada UVM Catcher kullanarak normalde FATAL olup dönecek sistemi UVM_WARNING'e düşürüp devam ettik).

### Aşama 7 & 8: SoC RegBus Resetleri ve AXI Monitörizasyonu
*(Amaç: CVA6 Boot oluyorken pasif dinleme - Timeout: 3-50ms)*
14. `chs_memmap_test`, `chs_reg_reset_test`: Reset kalktıktan sonra (Power-On-Reset) SoC içindeki yüzlerce register varsayılan (Default) değerinde mi diye saniyesinde sondaj yapar.
15. `chs_axi_sanity_test`, `chs_axi_protocol_test`, `chs_axi_stress_test`: Boot ROM/CLINT trafiği CVA6 tarafından basılırken, AXI Agent'ımız pasif dinleyerek AXI4 kurallarına 58 adet SVA kuralı ile uyulduğunu kesinleştirir.

### Aşama 9: Coverage Kurtarma (Corner Case) Testleri
*(Amaç: Boş kalan Bin'lere nokta atışı veri yollamak. - Timeout: En uzun / 200ms)*
16. `chs_cov_uart_boundary_test`: UART hedefine sadece normal harf değil, DELETE harfi, Kontrol Karakterleri, Hex `FF` atar.
17. `chs_cov_gpio_exhaustive_test`, `chs_cov_axi_region_test`: Yüzlerce megabaytlık adres uzayını boş bırakmamak için her bölgeden (Unmapped dram, spm, vs.) birer byte okuyarak Coverage Topolojisini büyütür.

---

## 4. Porting: Başka Çipe Geçiş Nasıl Yapılır? (Reusable UVM)

Bu iskeleti hiç bilmediğimiz, "Kara Kutu" bir projeye entegre ederken süreç aylarca sıfırdan yazım gerektirmez:
1. **%100 Kurtarılanlar (Aynen Kopyalananlar):** `verif/tb/agents/*`. UART, I2C, SPI standartları dünyanın her yerinde ve her çipinde aynı IEEE standartına bağlıdır. Klasörler direkt kopyalanır.
2. **Kısmen Değişecekler:** `tb_top.sv` ve içerisindeki `chs_protocol_checker.sv` gibi yapılar çipin pin isimlerine ve sayısına göre güncellenir.
3. **Tekrar Üretilecekler (Auto-Generated):** `env/ral/*` (Register Abstraction Layer). Her çipin offset haritası farklı olduğu için bu yapı çip dökümanlarından (IP-XACT formatında) yeni baştan generate edilir (Birkaç saniyelik otomasyon).

---

## 5. Sunum Performansı: Muhtemel Kritik Jüri Soruları ve Savunmaları

**Soru 1: "Siz bu SoC'nin işlemci çekirdeklerini (CVA6) hiç test etmemişsiniz. Bu durumda "SoC Verification" yapmış oluyor musunuz?"**
*Savunma:* "Evet, SoC verification yapıyoruz. Çünkü SoC verification, işlemcinin komut seti (ALU vs.) hesaplama doğruluğu (Unit Level) veya sadece UART'ın çalışması (Block Level) değil; işlemci veriyollarının (AXI), DMA'ların ve tüm IP'lerin bir arada aynı adreste tıkanmadan "Entegre" (Integration) olarak haberleşebilmesini sağlamaktır. Biz işlemciyi JTAG-Debug Module-SBA üzerinden sanal olarak yöneterek tüm bus tıkanıklıklarını (AXI Arbiter) uçtan uca simüle ettik. Biz CPU tasarımı yapmadığımız için işlemcinin Assembly Instruction Fetch performansını kapsam dışında (Out-of-scope) tuttuk."

**Soru 2: "Raporunuzdaki Coverage oranınız %46 çıkmış. Demek ki çipin yarısı hatalı veya bozuk olamaz mı?"**
*Savunma:* "Oradaki %46 Code Coverage (Transistör tetiklenme oranı) değil, tanımladığımız hedeflerin Functional Coverage ölçümüdür. Kalan %54'lük kısım test edilmeyen/hatalı kısım değil, kasten kapsam dışı bırakılan hedef kümesidir. Örneğin BootMode covergroup'unda JTAG Mode test edilmişken, Serial_Link mode test edilmediği için o Bin boş kalmış ve o grupta puan düşmüştür. Bizim hedefimiz odaklandığımız Modüllerin hata payını kapatmaktı."

**Soru 3: "Ajanların iletişimi doğrularken aynı zamanda SVA (Assertion) kullanmanıza ne gerek vardı? Monitörler zaten sinyali okumuyor mu?"**
*Savunma:* "Monitörlerin kalbi UVM task tabanlıdır (Software Time). $ns dalgalarında gerçekleşen ve hemen kaybolan donanımsal glitch'leri, örneğin "Reset sinyalinin ilk 2 clock'ta titremesini" ya da AXI Read_Valid pinindeki "X veya Z (Tanımsız Volt)" düşüşlerini UVM monitörleri örnekleyemez ve kaçırabilir. SVA, SystemVerilog mimarisine Hard-Coded (Hardware Clock tick) gömülü çalıştığı için binde bir cycle'lık protokol ihlalini anında yakalayıp simülasyonu Fatal ile çökertir. İkisi birbirinin alternatifi değil koruma katmanlarıdır."
