# Zero to Reusable UVM: SoC Doğrulama Rehberi

Bu rehber, baştan sona bir System-on-Chip (SoC) için Universal Verification Methodology (UVM) altyapısının nasıl kurulduğunu, projedeki mimari kararları, hedefleri ve elde edilen sonuçların teknik gerçekliğini detaylandırmak amacıyla hazırlanmıştır. 

En temel amacımız: **Elimizde çipin RTL (Register Transfer Level) kodları varken bu devasa UVM altyapısını kurmak; ileride RTL koduna sahip olmadığımız, sadece dokümanlara (Spec) bakarak doğrulama yapmamız gereken "Kara Kutu" projelerine geçtiğimizde elimizde güçlü, tekrar kullanılabilir (reusable) bir UVM iskeletinin hazır bulunmasını sağlamaktır.**

---

## 1. Neden UVM Kullanırız?

Çip tasarımları büyüdükçe (milyonlarca gate), klasik SystemVerilog `initial / begin` bloklarıyla veya basit task-based testbench'lerle hataları (bug) bulmak imkansızlaşır. UVM bize şu endüstri standartlarını sunar:

*   **Rastgele ancak Kısıtlı Test (Constrained-Random):** Sadece aklımıza gelen senaryoları değil, binlerce farklı kombinasyonu (farklı baud rate, rastgele veri boyutu, rastgele gecikmeler) otomatik üretmemizi sağlar.
*   **Ayrıştırılmış Mimari (Separation of Concerns):** Veri üreten yer (Sequence), veriyi pinlere süren yer (Driver), pinleri izleyen yer (Monitor) ve doğruluğunu kontrol eden yer (Scoreboard) tamamen birbirinden bağımsız modern yazılım (Object-Oriented) mimarisiyle yazılır.
*   **Yeniden Kullanılabilirlik (Reusability):** Bugün Cheshire SoC için yazdığımız UVM UART Agent'ını, yarın Pulsar SoC projesine tek satır kod değiştirmeden kopyalarız. Bu bize devasa bir zaman kazandırır.

---

## 2. Cheshire SoC: Gerçekte Ne Kadarını Doğruladık?

Ekteki mimari görsele (AXI4+ATOP Crossbar ve alt birimler) baktığımızda Cheshire'ın devasa bir çip olduğunu görüyoruz (CVA6 Çekirdekleri, LLC Cache, iDMA, VGA, USB, vb.).

Bizim bu projede kurduğumuz **6 Agent (JTAG, UART, SPI, I2C, GPIO, AXI(Passive))** ile yaptığımız doğrulamanın seviyesi ve sınırları şöyledir:

### Ne Yaptık? Seviyemiz Nedir?
Bizim yaptığımız doğrulama **Subsystem-Level / SoC Integration Level** bir doğrulamadır.
1.  **Pin-to-Register (Top-Down):** İşlemciye assembly komutu verip koşturmak yerine, SoC'ye "dışarıdan" (JTAG üzerinden) bağlandık. JTAG -> Debug Module -> AXI Crossbar -> Regbus Demux üzerinden SoC'nin derinliklerindeki IP'lerin (UART, I2C vb.) registerlarına ulaştık ve konfigüre ettik.
2.  **IP-Level Protocol Check:** Çipin dışarı sarkan pinlerini (UART Tx/Rx, SPI Mosi/Miso vb.) dinleyen agent'lar ile çipin dış dünyayla olan iletişim standartlarını doğruladık.
3.  **AXI Bus Monitoring:** Çipin kalbini oluşturan AXI4 yolunu pasif olarak dinleyip (AXI Protocol Checker SVA'ları ile) içerideki veri trafiğinde (DRAM erişimi) kilitlenme olmadığını ispatladık.

### Ne Yapamadık?
*   **Core-Driven Senaryolar:** CVA6 çekirdeklerini kullanarak içeriden dışarıya karmaşık C kodları koşturmadık.
*   **Tam Kapsam:** USB, VGA, iDMA, Serial Link gibi karmaşık modüller için Agent geliştirmedik. Onlar şimdilik doğrulama kapsamımızın dışında bırakıldı.

### Coverage (Kapsam) Gerçeği: %46.62 Ne İfade Ediyor?
HTML dosyamızda geçen **%46.62 Total Cumulative Covergroup Coverage** oranı, tüm SoC'nin transistör bazında test edilme oranı **DEĞİLDİR**. 
Bu oran; bizim kendi yazdığımız ve planladığımız **9 adet Covergroup'un (JTAG ihtimalleri, UART sınır değerleri, GPIO geçişleri vb.) hedeflerine ulaşma oranıdır.** Biz sadece kendi "Doğrulama Planımız" içindeki hedeflerin %46'sına ulaştık (Henüz iDMA, VGA vs. coverage hedefleri tanımlanmadığı için paydada bile yoklar). Sunumlarda bunun *Functional Coverage of Targetted IPs* olduğunu belirtmek hayati önem taşır.

---

## 3. UVM Ortamının Mimarisi (`verif/tb/` Klasör Analizi)

Proje hiyerarşimiz UVM standartlarına sıkı sıkıya bağlıdır. 5 temel klasörün işlevi, içerdikleri ve örnek kod blokları aşağıdadır:

### 3.1. `agents/` Klasörü
**İşlevi:** Belirli bir protokolün (UART, SPI vb.) dış dünya ile konuşmasını sağlayan bağımsız paketlerdir. Her agent kendi içinde Sequencer, Driver, Monitor ve SystemVerilog Interface'ini barındırır.
**Örnek (UART Monitor Seçimi):** UART hattını pasif olarak dinleyen ve bit bit gelen sinyalleri anlamlı 8-bitlik UVM Transaction paketlerine çeviren modüldür.

```systemverilog
// Örnek: uart_monitor.sv içindeki sinyal yakalama/örnekleme mantığı
task uart_monitor::run_phase(uvm_phase phase);
    uart_transaction tr;
    forever begin
        // Start bitini (düşen kenar) bekle
        @(negedge vif.rx);
        tr = uart_transaction::type_id::create("tr");
        
        // Bir baud periyodu kadar bekle (Start bitinin ortası)
        #(m_cfg.baud_delay_ns);
        
        // 8 bitlik veriyi topla
        for (int i = 0; i < 8; i++) begin
            #(m_cfg.baud_delay_ns);
            tr.data[i] = vif.rx;
        end
        
        // Stop biti için bekle
        #(m_cfg.baud_delay_ns);
        
        // Paketi başarılı şekilde okuduk, Scoreboard/Coverage'a yolla
        ap.write(tr);
    end
endtask
```

### 3.2. `env/` Klasörü
**İşlevi:** Agent'ların birleştiği, birbirine bağlandığı ve verilerin işlendiği "Ev"dir. Scoreboard, Coverage Collector ve Register Model (RAL) burada Instantiate edilir (yaratılır) ve birbirine bağlanır.
**Örnek (Scoreboard Comparator Seçimi):** `chs_scoreboard.sv`. Dışarıdan veya içeriden beklenen (Expected) veriyi kuyruğa alır. Monitor'lerden fiziksel gerçekleşen (Actual) veriyi alır ve eşleşip eşleşmediğine bakar. Eğer eşleşmezse testi hata ile durdurur.

```systemverilog
// Örnek: chs_scoreboard.sv içinde UART verisi doğrulama
// uart_imp (Monitor'den tetiği alan fonksiyon)
virtual function void write_uart(uart_transaction tr);
    bit [7:0] expected_data;
    
    // Test tarafından önceden kuyruğa atılmış veri var mı?
    if (expected_uart_data.size() > 0) begin
        expected_data = expected_uart_data.pop_front();
        
        // Gelen veri ile beklenen veriyi karşılaştır
        if (tr.data === expected_data) begin
            uart_match_count++;
            `uvm_info("SCB_UART", $sformatf("PASS! Gelen: %h | Beklenen: %h", tr.data, expected_data), UVM_HIGH)
        end else begin
            uart_mismatch_count++;
            `uvm_error("SCB_UART_ERR", $sformatf("FAIL! Gelen: %h | Beklenen: %h", tr.data, expected_data))
        end
    end
endfunction
```

### 3.3. `sequences/` Klasörü
**İşlevi:** Sistemi test edecek senaryoların (trafik bilgisinin) üretildiği yerdir. UVM'de testler kodlanmaz, senaryolar (sequences) kodlanır; testler sadece bu senaryoları çağırır. System-level (Virtual) ve IP-level diziler içerir.
**Örnek (Virtual Sequence Seçimi):** `chs_cov_axi_region_vseq.sv`. SoC içindeki belleklere (BootRom, PLIC, DRAM vb.) sırasıyla paket yollayarak hedef bölgelerdeki adres dekoderlerini (AXI Crossbar -> Regbus Demux) test eder.

```systemverilog
// Örnek: Tüm cihazlara JTAG-SBA üzerinden sinyal basma senaryosu
virtual task body();
    jtag_base_seq j_seq;
    bit [31:0] rdata;
    
    j_seq = jtag_base_seq::type_id::create("j_seq");
    
    // Virtual Sequencer üzerindeki JTAG sequencera bağlanarak DMI okuma/yazma taskları çağırılır
    `uvm_info("SEQ", "SBA üzerinden UART TX registerına 'A' harfi yazılıyor (Adres: 0x0300_2000)", UVM_LOW)
    j_seq.do_sba_write(32'h0300_2000, 32'h0000_0041, p_sequencer.m_jtag_sqr);
    
    `uvm_info("SEQ", "SBA üzerinden SPI konfigürasyon registerı okunuyor", UVM_LOW)
    j_seq.do_sba_read(32'h0300_4004, rdata, p_sequencer.m_jtag_sqr);
endtask
```

### 3.4. `tests/` Klasörü
**İşlevi:** Simülasyonu başlatan en üst seviye UVM sınıflarıdır. Mimariye hangi özelliklerin açılıp kapanacağını söyler (Örn: "Has_UART=1, Has_VGA=0"). Ortamı ayağa kaldırır (Config DB) ve spesifik bir sequence'ı tetikler.
**Örnek (Base Test Config Seçimi):** `chs_base_test.sv`. Factory metodolojisi kullanılarak tüm ortamın konfigürasyonu buradan dağıtılır.

```systemverilog
// Örnek: chs_base_test.sv Environment ayarları
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Ortam ayarları objesi oluşturulur
    m_env_cfg = chs_env_config::type_id::create("m_env_cfg");
    
    // Testbench'e özel ayarlamalar
    m_env_cfg.has_jtag_agent = 1;
    m_env_cfg.has_uart_agent = 1;
    m_env_cfg.has_ral = 1; // Register Abstaction Layer kullanımını aç
    
    // Bu ayarlar Database'e konularak Env sınıfının çekmesi sağlanır
    uvm_config_db#(chs_env_config)::set(this, "m_env*", "m_env_cfg", m_env_cfg);
    
    // Tüm ortamın yaratılması
    m_env = chs_env::type_id::create("m_env", this);
endfunction
```

### 3.5. `top/` Klasörü
**İşlevi:** UVM'nin yazılım tarafı (class tabanlı) ile Çipin donanım tarafının (SystemVerilog Modülleri, RTL) birbiriyle fiziksel elektrik kablolarıyla bağlandığı en üst (Tb_top) dosyalarıdır.
**Örnek (Protocol Checker):** `chs_protocol_checker.sv`. Bu UVM sınıfı değil, bir SystemVerilog Assertion (SVA) modülüdür. Çipin pinlerine donanımsal olarak bağlanıp UVM'den bağımsız protokol hatalarını milisaniye kilitlenmeden yakalar.

```systemverilog
// Örnek: JTAG TRST Sinyal Davranışı Doğrulaması (SVA)
module chs_protocol_checker(
    input logic clk,
    input logic rst_n
);

    // Kural: Reset kalktıktan sonra en az 4 clock boyunca tertemiz kalmalı (Glitch olmamalı)
    property p_reset_stable_after_deassert;
        @(posedge clk)
        $rose(rst_n) |-> ##[1:4] rst_n;
    endproperty
    
    // Assert komutu: Kural ihlal edilirse simülasyona hata at!
    a_reset_stable: assert property (p_reset_stable_after_deassert) 
        else $error("SVA ERROR: System Reset (rst_n) glitch tespit edildi!");

endmodule
```

---

## 4. "Zero to Reusable UVM": Başka Bir SoC'ye Geçiş (Porting)

Bu projenin en büyük artısı, elimizde RTL olmayan sadece "Kağıt üzerindeki Mimari Specten" ibaret olan yepyeni bir çip tasarımına bu yapıyı saniyeler içinde taşıyabilme özgürlüğüdür. Yeni bir projeye geçerken izlenecek yol:

### 🟢 1. Aynen Kopyalanacaklar (%100 Reusable)
*   **Tüm IP Agent'ları:** `verif/tb/agents/` (UART, I2C, SPI vb.). İletişim protokolleri global standarttır (IEEE, TI, I2C Philips). Yeni çipin UART'ı da aynı standartta olacağı için bu klasör hiçbir kod değişikliği olmadan direkt kopyalanır.

### 🟡 2. Üzerinde Küçük Değişiklikler Yapılacaklar (Modify)
*   **Testbench Top (`tb_top.sv`):** Eski SoC'nin ismi (`cheshire_soc`) silinip yeni SoC (`new_chip_soc`) instantiate edilir. Sinyaller ajanın Virtual Interface'lerine yeni pin isimleriyle yeniden bağlanır.
*   **Scoreboard & Coverage:** Yeni çipteki bellek büyüklüklerine ve UART modülü sayısına (örn: yeni çipte 3 UART varsa) göre Covergroup limitleri genişletilir.

### 🔴 3. Tamamen Baştan Oluşturulacaklar (Re-write)
*   **Register Model (RAL):** Her donanımın register map'i, adres offsetleri ve interrupt uçları benzersizdir. Bu yüzden `tb/env/ral` klasörü taşınmaz. Yeni SoC'nin dokümanlarından (CSV, IP-XACT formatında) yeni bir UVM RAL modeli otomatik generate ettirilip ortama konulur.
*   **Virtual Sequences:** `tb/sequences/virtual/` içindeki spesifik test akışları değişir. Yeni çipteki sensörlere uyan yeni "Memory-to-Memory DMA okumaları", "Boot senaryoları" için yep yeni senaryolar yazılır.

**Sonuç olarak:** Projede temel altyapının %80'ini (`Agentlar`, `Driver`, `SVA altyapısı`, `Tb hiyerarşisi`) tamamen kurtarıp, sadece yeni çipin ruhuna göre Sequence ve Scoreboard'ı yönlendiririz. Bu da bir "Verification Engineer"ı sıfırdan ortam kurma zahmetinden aylarca kurtarır.
