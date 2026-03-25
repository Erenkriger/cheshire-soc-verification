# AI Operator Playbook — Verification Mühendisi İçin Pratik Kılavuz

## 1) Rol Ayrımı
- AI: Hızlı üretim, tarama, taslak kod, alternatif öneri.
- Mühendis: Mimari karar, doğrulama kriteri, risk analizi, son onay.

## 2) Prompt Tasarım İlkeleri
1. Bağlam ver (`DUT`, `toolchain`, `UVM version`, `memory map`).
2. Net çıktı iste (dosya yolu, sınıf adı, acceptance criteria).
3. Doğrulama adımı iste (compile/run/coverage check).
4. Kısıt koy (API değişmesin, minimal patch, no logic in `new()`).

## 3) Kullanıma Hazır Prompt Şablonları

## 3.1 Agent üretimi
"UVM 1.2 uyumlu `<protocol>` agent üret: transaction/config/sequencer/driver/monitor/package. `build/connect/run` fazlarını ayrıştır. VIF `uvm_config_db` ile alınsın."

## 3.2 Coverage closure
"Bu coverage raporundaki boş binleri listele, her bin için en az bir test stimulusu öner, test adlarını ve beklenen hit binlerini ver."

## 3.3 SoC-level vseq
"JTAG üzerinden core halt + SBA program load + DPC set + resume + EOC poll yapan virtual sequence yaz. Timeout, retry ve error handling ekle."

## 3.4 Migration analizi
"Mevcut UVM ortamını başka SoC’ye taşımak için dosyaları `tam taşınabilir/kısmi/yeniden yazılacak` diye sınıflandır."

## 4) AI Çıktı Değerlendirme Checklist
- UVM fazları doğru mu (`build/connect/run/report`)?
- Factory macro’ları var mı?
- VIF config path doğru mu?
- Driver/monitor race olasılığı var mı?
- PASS/FAIL kriteri ölçülebilir mi?
- Coverage hedefi ve test arasında izlenebilirlik var mı?
- SVA kuralı spesifikasyonla tutarlı mı?

## 5) Kırmızı Bayraklar (Reject Kriterleri)
- `new()` içinde ağır logic
- Hardcoded path/clock değerleri
- Unused signal/port artıkları
- Testin assertion veya scoreboard ile doğrulanmaması
- Coverage hedefi olmayan test

## 6) Önerilen Çalışma Döngüsü
1. Plan çıkar
2. Küçük dilimler halinde uygula
3. Her dilimde compile + test
4. Coverage etkisini ölç
5. Dokümante et
6. Commit
