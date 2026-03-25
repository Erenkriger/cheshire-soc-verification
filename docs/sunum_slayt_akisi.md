# Sunum Slayt Akışı — SoC-Level UVM Verification + AI Operator

## Slayt 1 — Başlık
- Cheshire tabanlı SoC-Level UVM Verification
- Sıfırdan kurulum + AI ile hızlandırılmış mühendislik

## Slayt 2 — Problem Tanımı
- SoC doğrulama karmaşıklığı
- IP-level testlerin entegrasyon hatalarını kaçırması

## Slayt 3 — Hedef
- Reusable UVM platformu
- Cheshire üzerinde katmanlı doğrulama
- Başka SoC’ye taşınabilir mimari

## Slayt 4 — Mimari Sınır
- Upstream: `cheshire/`
- Verification katmanı: `verif/`
- Neden legacy flow kaldırıldı

## Slayt 5 — UVM Topoloji
- `tb_top` + agent + env + sequences + tests
- `uvm_config_db` ile VIF dağıtımı

## Slayt 6 — Agent Yapısı
- Driver/Monitor/Sequencer
- Analysis portlar
- Scoreboard ve coverage bağlantıları

## Slayt 7 — Verification Katmanları
- IP-Level
- Subsystem-Level
- SoC-Level

## Slayt 8 — Test Portföyü
- 44 test seti
- Protokol, memmap, stress, interrupt, AXI, out-of-scope IP

## Slayt 9 — SW-Driven Verification
- JTAG→DMI→SBA→DRAM load
- DPC set, resume, EOC poll
- `chs_sw_hello_test`, `chs_sw_gpio_test`

## Slayt 10 — Coverage Stratejisi
- Functional coverage (covergroup/coverpoint/cross)
- Assertion coverage (SVA)
- Coverage closure döngüsü

## Slayt 11 — Kritik Teknik Düzeltmeler
- DMI coverage root-cause ve driver-side çözüm
- SPM erişim yerine DRAM tabanlı SW load kararı

## Slayt 12 — Sonuçlar
- Regression: 44/44 PASS
- Instance coverage: 62.28%
- Covergroups: 52.08%
- `cp_dmi_op`/`cp_dmi_addr`: 100%

## Slayt 13 — Reusability Matrix
- Tam taşınabilir
- Kısmi taşınabilir
- SoC’ye özel yeniden yazılacak

## Slayt 14 — AI Operator Modeli
- AI = hızlandırıcı, mühendis = karar verici
- Prompt standardizasyonu
- Çıktı doğrulama checklist’i

## Slayt 15 — Demo
- Tek test + full regression + coverage report
- Beklenen log imzaları

## Slayt 16 — Yol Haritası
- Boot mode coverage artırımı
- AXI error-path genişletme
- CI nightly regression
