# Sunum Rehberi — Cheshire ile Sıfırdan SoC-Level UVM Verification + AI Operator Yaklaşımı

## 1) Sunumun Ana Mesajı

Bu proje ile yapılan şey:
1. Upstream Cheshire SoC üzerine sıfırdan UVM doğrulama katmanı kurmak
2. IP-level + Subsystem-level + SoC-level doğrulamayı tek bir regresyon akışında birleştirmek
3. SW-driven verification (bare-metal firmware) ile işlemci perspektifinden sistem test etmek
4. AI’ı “kod yazan asistan” değil, “mühendis tarafından yönetilen operatör hızlandırıcısı” olarak kullanmak

---

## 2) Proje Sınırı ve Mimari Konumlandırma

### 2.1 Upstream (değiştirmediğimiz temel)
- `cheshire/` klasörü: DUT, RTL ve referans build ekosistemi

### 2.2 Üstüne eklediğimiz katman
- `verif/tb/agents/`  -> Protokol ajanları
- `verif/tb/env/`     -> env, scoreboard, coverage, virtual sequencer, RAL bağlantısı
- `verif/tb/sequences/` -> ip-level ve virtual sequence’lar
- `verif/tb/tests/`   -> test sınıfları
- `verif/tb/top/tb_top.sv` -> DUT + interface + checker + run_test
- `verif/sim/`        -> compile list, regression TCL, coverage akışı
- `verif/sw/`         -> bare-metal C test altyapısı

---

## 3) Doğrulama Katmanları

## 3.1 IP-Level
Amaç: Her protokol/IP davranışının temel doğrulanması.
Örnek testler:
- `chs_jtag_idcode_test`
- `chs_uart_tx_test`
- `chs_spi_single_test`
- `chs_i2c_write_test`
- `chs_gpio_walk_test`

## 3.2 Subsystem-Level
Amaç: Birden fazla bloğun entegrasyon davranışı.
Örnek testler:
- `chs_jtag_sba_test` (JTAG->DMI->SBA zinciri)
- `chs_ral_access_test` (RAL frontdoor)
- `chs_axi_protocol_test` (AXI checker odaklı)

## 3.3 SoC-Level
Amaç: Uçtan uca sistem davranışı ve gerçek kullanım senaryosu.
Örnek testler:
- `chs_boot_seq_test`
- `chs_memmap_test`
- `chs_concurrent_test`
- `chs_stress_test`
- `chs_sw_hello_test`, `chs_sw_gpio_test` (SW-driven)

---

## 4) UVM Mimarisi Kısa Özet

## 4.1 `tb_top`
- DUT instantiate
- Virtual interface wiring
- `uvm_config_db` üzerinden interface dağıtımı
- SVA checker instantiate
- `run_test()` çağrısı

## 4.2 Agent
- Driver: pin sürer
- Monitor: pin gözler
- Sequencer: transaction akışı
- AP: scoreboard/coverage yayın

## 4.3 Environment
- Tüm agent’ları kurar
- Scoreboard + Coverage + Virtual Sequencer içerir
- RAL modelini sequencer’a bağlar

## 4.4 Sequence/Test ayrımı
- Sequence: stimulus mantığı
- Test: sequence seçimi + timeout/config

---

## 5) Coverage ve SVA Stratejisi

## 5.1 Functional Coverage
Ana prensip: “protokol semantiğini ölçen coverpoint”.
Örnek:
- JTAG: op, ir, dmi_op, dmi_addr
- UART: data range, dir, parity/frame errors
- AXI: rw, burst, size, len, resp, latency, region

## 5.2 Assertion-Based Verification
- `chs_protocol_checker.sv`: JTAG/SPI/UART/I2C/GPIO kuralları
- `chs_soc_sva_checker.sv`: SBA/DMI/interrupt/register bus seviyeleri
- `chs_axi_protocol_checker.sv`: AXI4 kuralları

## 5.3 Coverage Closure Prensibi
1. Boş binleri rapordan çıkar
2. Her boş bin için hedef stimulus yaz
3. Gerçekten gereksizse waiver ver
4. Waiver’ı dokümante et

---

## 6) SW-Driven Verification (C Testleri)

## 6.1 Neden gerekli?
SV/UVM ile dıştan protokol doğrularsın.
C testleri ile işlemci gerçekten kod çalıştırırken sistemin davranışını doğrularsın.

## 6.2 Akış
1. JTAG TAP reset
2. DMI ile core halt
3. SBA ile program load (DRAM)
4. DPC set
5. resume
6. SCRATCH[2] EOC poll
7. exit code kontrol

## 6.3 Neyi doğrular?
- Debug module işleyişi
- JTAG->DMI->SBA zinciri
- Bellek erişim yolu
- Core execute path
- Peripheral register erişimi (ör. GPIO)

---

## 7) Sonuç Metrikleri (Bu Proje)

- Regression: **44/44 PASSED**
- Instance Coverage: **62.28%**
- Covergroups: **52.08%**
- Covergroup bins: **42.03%**
- `cp_dmi_op`: **100%**
- `cp_dmi_addr`: **100%**

---

## 8) Reusability — Başka SoC’ye Ne Kadar Taşınır?

## 8.1 Doğrudan taşınabilir (yüksek)
- Agent iskeletleri (`driver/monitor/sequencer/transaction/config`)
- Base test mimarisi (`base_test`, objection, timeout pattern)
- Coverage framework şablonu
- Regression TCL altyapısı

## 8.2 Kısmen taşınabilir (orta)
- Virtual sequence mantığı (adresler/protokol komutları değişir)
- Scoreboard kuralları (SoC’ye özel expected kısımlar değişir)
- RAL adapter (bus yoluna göre güncelleme)

## 8.3 Baştan üretilecek (SoC’ye özel)
- `tb_top` pin wiring
- Memory map sabitleri
- SoC-specific SVA checker hiyerarşik path’leri
- Register model (RAL package)

---

## 9) AI ile UVM Geliştirme — Operatör Mühendis Modeli

## 9.1 AI’ın doğru rolü
AI = hızlandırıcı.
Mühendis = karar verici, doğrulayıcı, sistem sahibi.

## 9.2 Etkili prompt şablonları

### Şablon A — Agent üretimi
"UVM 1.2 uyumlu `<protocol>` agent üret: transaction, config, sequencer, driver, monitor, package. `build/connect/run` fazlarını ayır. `new()` içinde logic olmasın."

### Şablon B — Coverage closure
"Bu coverage raporuna göre boş binleri çıkar, her boş bin için 1 hedef test öner, gerçekçi stimulus üret, gereksiz binler için waiver gerekçesi yaz."

### Şablon C — SoC-level vseq
"JTAG üzerinden core halt, SBA ile memory load, DPC set, resume, EOC poll yapan virtual sequence yaz; timeout ve error path’leri ekle."

### Şablon D — Migration
"Bu UVM ortamını yeni SoC’ye taşımak için dosyaları taşınabilir/kısmi/yeniden yazılacak diye sınıflandır."

## 9.3 AI çıktısını değerlendirme checklist
- UVM fazları doğru mu?
- Factory registration var mı?
- `uvm_config_db` ve virtual interface düzgün mü?
- Driver/monitor yarış koşulu var mı?
- Test gerçekten ölçülebilir PASS/FAIL üretiyor mu?
- Coverage hedefi ile stimulus arasında traceability var mı?
- SVA kuralı spesifikasyonla uyumlu mu?

---

## 10) Sunum Akışı (Öneri)

1. Problem: SoC doğrulama karmaşıklığı
2. Hedef: Cheshire üzerinde reusable UVM platformu
3. Mimari: tb_top/env/agent/sequence/test
4. Katmanlı doğrulama: IP/Subsys/SoC
5. Coverage + Assertion stratejisi
6. SW-driven verification
7. Sonuç metrikleri (44/44, coverage)
8. Reusability matrix
9. AI operator yöntemi ve prompt standardı
10. Lessons learned + next steps

---

## 11) Sonraki İyileştirme Yol Haritası

- Boot mode coverage artırımı (`serial_link`, `uart`, `reserved`)
- AXI response çeşitliliği için fault-injection testleri
- Assertion coverage için ek cover property
- SW testlerinde gerçek ELF/memh parser entegrasyonu
- CI pipeline: nightly regression + coverage trend grafiği

---

## 12) Bu Rehberin Yardımcı Dokümanları

- Slayt akışı: `docs/sunum_slayt_akisi.md`
- Canlı demo komut planı: `docs/demo_runbook.md`
- AI operator prompt/checklist kılavuzu: `docs/ai_operator_playbook.md`
