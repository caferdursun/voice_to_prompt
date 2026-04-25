# Skill Şablonu

Bu belge, bu depoya yeni bir skill eklerken izlenecek yapıyı gösterir.

## Dosya Düzeni

```
skills/<skill-adı>/
├── SKILL.md           # zorunlu — YAML frontmatter + talimatlar
├── references/        # opsiyonel — skill içinden okutulacak uzun referans dosyaları
├── scripts/           # opsiyonel — skill'in çalıştıracağı yardımcı script'ler
└── assets/            # opsiyonel — şablonlar, örnek çıktılar, vb.
```

### İsimlendirme kuralları

- Skill klasör adı: `kebab-case`, sadece `[a-z0-9-]`. Örn: `voice-to-prompt`.
- `_` ile başlayan klasörler (ör. `_template`) install script tarafından atlanır — WIP/şablonlar için kullanın.

## SKILL.md Frontmatter

Her `SKILL.md`, YAML frontmatter ile başlamak zorundadır. Claude, skill'i **sadece `description` alanına bakarak** tetikleyip tetiklemeyeceğine karar verir — bu yüzden açıklamayı spesifik ve tetikleyici yazın.

```yaml
---
name: voice-to-prompt
description: Türkçe + İngilizce karışık teknik ses kayıtlarını temiz prompt metinlerine dönüştürür. "Bu kaydı transkript et", "sesten prompt yap" gibi taleplerde tetiklenir.
---
```

### Frontmatter alanları

| Alan | Zorunlu | Açıklama |
|---|---|---|
| `name` | evet | Klasör adı ile aynı olmalı. |
| `description` | evet | **Ne yaptığını + ne zaman tetikleneceğini** bir arada anlatın. En az bir cümle tetikleyici örnek içersin ("şu talepler geldiğinde devreye girer..."). |
| `allowed-tools` | hayır | Skill içinden çağrılabilecek tool listesini daraltır. Örn: `Read, Edit, Bash(git:*)`. |

## Gövde (İçerik)

Frontmatter'dan sonra skill'in talimatları gelir. Yazım ipuçları:

- **İkinci şahıs, emir kipinde yazın** ("Önce transkripti al", "Sonra…").
- **Adım adım bir iş akışı** verin — Claude'un sırayla uygulayacağı madde listesi.
- **Kaçınılacak durumları açıkça söyleyin** ("X dosyasını *asla* düzenleme, bunun yerine…").
- Uzun referansları (örn. tablolar) ayrı `references/*.md` dosyalarına koyup gövdede "Detay için `references/x.md` dosyasını oku" diye işaret edin. Bu, Claude'un context bütçesini korur.
- Kod örnekleri fenced code block içinde ve dil etiketli olsun (```python, ```bash, vb.).

## Kontrol Listesi (PR Öncesi)

- [ ] `SKILL.md` frontmatter'ındaki `name`, klasör adı ile birebir aynı.
- [ ] `description`, tetikleyici kelimeler içeriyor.
- [ ] Uzun referanslar ayrı dosyalara taşındı.
- [ ] `skills/<skill-adı>/` yerel olarak `./scripts/install.sh` ile kuruldu ve Claude Code tarafından tanındı.
- [ ] `README.md` skill tablosu güncellendi.
- [ ] `.claude-plugin/marketplace.json` içinde skill bir plugin olarak listelendi.
