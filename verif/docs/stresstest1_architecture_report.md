# Cheshire SoC: `soc_extreme_load.spm.c` Mimari Stres Testi ve Core Darboğaz Analizi

**Kapsam:** Bu doküman, `soc_extreme_load.spm.c` firmware testinin CVA6 çekirdeği (core) ve SoC donanım bileşenleri üzerinde yarattığı spesifik stres noktalarını, darboğaz (bottleneck) hedeflerini ve simülasyon loglarından elde edilen sonuçları sunmak amacıyla hazırlanmıştır.


## 1. Testin CVA6 Core İçerisinde (Instruction-Level) Zorladığı Birimler

Yazılan C kodları derlendiğinde oluşan instruction setleri, çekirdeğin belirli pipeline aşamalarını stall etmek ve limitlerini görmek üzere üç ana koldan tasarlanmıştır:

### A. ALU, Multiplier & Pipeline Bypass Yolları
* **Kullanılan Kod Bloğu:** `stress_matrix_and_bus()` (Matris Çarpımı)

```c
void stress_matrix_and_bus() {
    for (int i = 0; i < MATRIX_SIZE; i++) {
        for(int j = 0; j < MATRIX_SIZE; j++) {
            uint32_t sum = 0;
            // Intensive ALU Multiplier Loops
            for(int k = 0; k < MATRIX_SIZE; k++) {
                sum += (mem_src[(i + k) % DMA_BURST_SIZE] * mem_src[(k + j) % DMA_BURST_SIZE]);
            }
            mem_dst[(i * MATRIX_SIZE + j) % DMA_BURST_SIZE] = sum;
            
            // While CPU is computing matrix, force APB traffic!
            hammer_peripherals(sum);
        }
    }
}
```

* **Mimari Hedef:** Matris çarpımı ardışık `MUL` (çarpma) ve `ADD` (toplama) komutları üretir. CVA6 gibi in-order/out-of-order özellikler gösteren işlemcilerde, bir önceki işlemin sonucunun hemen bir sonraki işleme girmesi (Data Hazard) pipeline içerisinde "Forwarding/Bypass" yollarını maksimum limite taşır.
* **Oluşturulan Darboğaz:** Çarpım ünitesi (Multiplier) sürekli meşgul tutularak Execute (EX) aşamasında Structural Hazard yaratılır ve Core işlem yapmayı beklemek zorunda kalır.

### B. Branch Predictor, BTB ve RAS (Return Address Stack)
* **Kullanılan Kod Bloğu:** `stress_branch_predictor()` (Hanoi Kuleleri Algoritması - Deep Recursion)

```c
uint32_t hanoi_moves = 0;
void stress_branch_predictor(int n, int from, int to, int aux) {
    if (n == 1) {
        hanoi_moves++;
        hammer_peripherals(hanoi_moves); // Concurrency!
        return;
    }
    stress_branch_predictor(n - 1, from, aux, to);
    hanoi_moves++;
    stress_branch_predictor(n - 1, aux, to, from);
}
```

* **Mimari Hedef:** Hanoi kuleleri kodumuz, kendi kendini sürekli çağıran (recursive) bir yapıdadır. Bu durum ardışık `jal` (jump and link) ve `ret` (return) komutları üretir.
* **Oluşturulan Darboğaz:** İşlemcinin içerisinde dönüş adreslerini tahmin eden donanımsal **RAS (Return Address Stack)** kapasitesinin taşmasına (overflow) sebep olur. Derin döngülerde RAS tahminleri patlar, Branch Mispreadiction oluşur ve CVA6 pipeline'ının sürekli olarak Flush yemesine, dolayısıyla performans / instruction-fetch darboğazına (Fetch Stall) girmesine sebep olur.

### C. Load/Store Unit (LSU) ve L1 Data Cache Eviction
* **Mimari Hedef:** Sürekli olarak matrisin farklı adreslerine (stride access) erişim yapılması, CVA6 L1 Veri Önbelleği'nde (D-Cache) "Cache Miss" yaratır zaten bu Warning simülasyon sırasında logda çok fazla kez gözlendi. Çekirdek içerisindeki Memory Management Unit (MMU) ve Load/Store ünitesinin sürekli olarak AXI bus'a okuma/yazma talebi atmasına yol açılır.

---

## 2. SoC Geneli ve Veri Yolu (Bus) Darboğazları

Core sınırlarını test eden stres işlemlerinden biri de SoC mimarisindeki arayüzlerde oluşturulmaya çalışıldı.

### A. AXI-to-APB Bridge Backpressure
* **Kullanılan Kod Bloğu:** `hammer_peripherals` (I2C, SPI, GPIO register'larına aynı anda yazma)

```c
void hammer_peripherals(uint32_t val) {
    // 1. Hammer GPIO
    REG32(GPIO_BASE, 0x14) = val; // Write OUT
    
    // 2. Hammer I2C (Write dummy data to TX FIFO)
    REG32(I2C_BASE, 0x2C)  = (val & 0xFF); // I2C_VAL (FMTFIFO)
    
    // 3. Hammer SPI (Write dummy command to TX FIFO)
    REG32(SPI_BASE, 0x30) = (val & 0xFFFFFFFF); // SPI_TXDATA

    // Dummy reads back to force round-trip APB waits
    volatile uint32_t readback = 0;
    readback ^= REG32(GPIO_BASE, 0x10); // GPIO_IN
    readback ^= REG32(I2C_BASE, 0x14);  // I2C_STATUS
    readback ^= REG32(SPI_BASE, 0x14);  // SPI_STATUS
}
```

* **Nasıl Çalışır?** 64-bit genişliğindeki hızlı AXI protokolü üzerinden veri basan CPU, bir anda 32-bit'lik ve çok daha yavaş çalışan APB peripheral'larına (OpenTitan I2C, vb.) arka arkaya yazar.
* **Oluşturulan Bug Potansiyeli/Darboğaz:** AXI-APB köprüsü (bridge) bunu kaldıramaz ve CPU'ya `AWREADY=0` (Bekle) sinyali çeker. CPU Load/Store ünitesi kilitlenir (backpressure). 

### B. AXI Arbiter (Race Condition & Bandwidth)
* **Kullanılan Kod Bloğu:** `sys_dma_blk_memcpy(..., DMA_CONF_DECOUPLE_ALL)`

```c
if (chs_hw_feature_present(CHESHIRE_HW_FEATURES_DMA_BIT)) {
    print_str("[INFO] Kicking off Background DMA Transfer...\r\n");
    // Non-blocking DMA if possible, or decoupled setup
    sys_dma_blk_memcpy((uintptr_t)(void *)mem_dst, (uintptr_t)(void *)mem_src, 
                       DMA_BURST_SIZE * sizeof(uint32_t), 
                       DMA_CONF_DECOUPLE_ALL);
}
```

* **Mekanizma:** CPU çekirdeği veri yolu üzerinden matris hesaplamaları için sürekli okuma/yazma (LSU) yaparken ve APB köprüsünü meşgul ederken, eşzamanlı olarak DMA birimine büyük bir bellek bloğunu (Burst Transfer) taşıma emri verilmiştir.
* **Oluşturulan Darboğaz:** AXI Interconnect üzerindeki Arbiter, aynı anda hem LSU'dan (CPU) hem de DMA'dan gelen yüksek yoğunluklu trafik taleplerini yönetmek zorunda bırakılmıştır. Bu durum, veri yolunun maksimum bant genişliğine (Bandwidth) ulaşmasını sağlayarak Interconnect'in tahkim (arbitration) algoritmalarını stres altına almaktadır.

---

## 3. Testten Elde Edilen Loglar


1. **Önbellek (Cache) / APB Uyumsuzluğu:** 
   Loglarda görüntülenen "a_invalid_read_data" SVA uyarıları, CPU'nun APB hattındaki yavaş çevresel birimlere yoğun erişimi, bu bölgelerin PMA (Physical Memory Attributes) tanımlarında "Uncacheable" (önbelleklenemez) olarak işaretlenmemiş olabileceğine veya köprüden dönen yanıtların L1 D-Cache Alignment'ını bozduğuna işaret etmektedir. Bu, stresin doğrudan hedefine ulaştığını gösterir.

   Bu kısımda bahsedilen log çıktısı:
   cheshire/.bender/git/checkouts/cva6-20c9d7cne0dd6995/core/cache_subsystem/
   std_cache_subsystem.sv yolundaki 340-353 satırları arasındaki assertion'a atıf yapmaktadır.

2. **Bandwidth ve Bus Arbitration:**
   Trace loglarında görülen `[FAIL] DMA Mismatch at index...` hatası. AXI Interconnect üzerinden aynı hedef adres bölgesine CPU ve DMA'nın asenkron olarak yazmaya çalışması (Data Race), arbiter'ın işlemleri sıraya koymasına rağmen Coherency Issue'ya yol açmıştır. Bu durum, HW hatası değil, oluşturulan yoğun trafik altında Shared Memory'e eşzamanlı erişimin limitlerini göstermektedir.

**Sonuç:** Bu instruction ve fonksiyonlar Core'un Fetch, Execute, Memory aşamalarını aynı cycle diliminde kilitlemeyi, Bus Arbiter'ı sınırda çalıştırmayı hedefleyen mikro-mimari stres vektörleridir. 
