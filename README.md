# voice_to_prompt — Claude Code Skill

Türkçe + İngilizce karışık teknik ses kayıtlarını **temiz, doğrulanmış prompt metnine** dönüştüren [Claude Code](https://claude.com/claude-code) skill'i.

Whisper `large-v3` ile transkript alır, çıktıyı mantık taramasından geçirir, fonetik/syntax/özel ad şüphelerini sana sorar, düzelttiğini timestamp'li bir dosyaya kaydeder. Tekrar eden hataları Whisper config'ine eklemeyi önerir — yani skill kullandıkça doğruluk artar.

## İçindekiler

- [Özellikler](#özellikler)
- [Kurulum](#kurulum)
- [Kullanım](#kullanım)
- [Yapılandırma](#yapılandırma)
- [Depo Yapısı](#depo-yapısı)
- [Yeni Skill / Katkı](#yeni-skill--katkı)
- [Lisans](#lisans)

## Özellikler

- **Whisper sarmalayıcı** (`whisper-tr`): loudnorm + 16 kHz mono dönüşüm + initial prompt + post-processing regex'leri.
- **Bağlam-farkındalı slug üretimi**: çıktı dosyaları konuya göre adlandırılır (`avans-talebi-ozelligi_2026-04-21_14-30-15.txt`), sıralı arşiv olur.
- **İnteraktif düzeltme**: Whisper'ın sık yaptığı hataları (ör. *Cloud code → Claude Code*) Claude size sorup onaylatır.
- **Self-improving config**: onaylanan düzeltmeler `postproc_dict.txt` ve `initial_prompt.txt`'e eklenir.
- **Türkçe ortografi**: apostrof, büyük harf kısaltma (SGK, BES, AGİ vb.) kontrolü.
- **Yapılandırılabilir output**: `VOICE_PROMPT_OUTPUT_DIR` env değişkeni veya `./voice_prompt_outputs/`.

## Kurulum

> macOS / Linux desteklenir. Windows'ta WSL kullanın.

### Hızlı yol (önerilen)

```bash
git clone https://github.com/caferdursun/voice_to_prompt.git
cd voice_to_prompt
./scripts/bootstrap-whisper.sh   # ffmpeg + venv + openai-whisper + config
./scripts/install.sh --all       # skill + whisper-tr CLI + config (varsa korur)
```

`bootstrap-whisper.sh` şunları yapar:

1. `ffmpeg`'i Homebrew (macOS) ile kurar; Linux için manuel komut önerir.
2. `~/.venv-whisper` Python sanal ortamını oluşturur.
3. İçine `openai-whisper` + `certifi` kurar.
4. `~/.config/whisper-tr/{initial_prompt,postproc_dict}.txt` dosyalarını örnekten kopyalar (varsa dokunmaz).

`install.sh --all` şunları yapar:

1. `skills/voice-to-prompt`'ı `~/.claude/skills/voice-to-prompt`'a **symlink**'ler.
2. `bin/whisper-tr`'ı `~/bin/whisper-tr`'a symlink'ler.
3. Config örneklerini `~/.config/whisper-tr/` altına kopyalar (varsa korur).

Symlink kurulumu sayesinde `git pull` yaptığınızda Claude Code güncel skill'i otomatik görür.

### Sadece skill (whisper-tr siz kuracaksanız)

```bash
./scripts/install.sh             # skill'i symlink'ler, başka şey kurmaz
./scripts/install.sh --copy      # symlink yerine tam kopya
```

### Plugin marketplace (opsiyonel)

```text
/plugin marketplace add caferdursun/voice_to_prompt
/plugin install voice-to-prompt@voice-to-prompt
```

> Marketplace yöntemi **sadece skill dosyasını** kurar; `whisper-tr` ve config'i ayrıca kurmanız gerekir (`./scripts/bootstrap-whisper.sh`).

### Geri alma

```bash
./scripts/install.sh --uninstall   # skill'i ~/.claude/skills'ten kaldırır
```

## Kullanım

### Mod 1 — Mevcut bir ses dosyasını transkript etmek

Claude Code oturumunda bir ses dosyası referansı verin — skill kendiliğinden tetiklenir:

```
Bu kaydı transkript et: ~/Downloads/toplanti.m4a
```

ya da:

```
sesten prompt yap: ~/sesler/avans-talebi.wav
```

### Mod 2 — Mikrofondan canlı kayıt (macOS)

Dosya vermeden de skill'i tetikleyebilirsiniz:

```
kayıt başlat, prompt vereceğim
```

ya da:

```
şimdi konuşacağım, mikrofondan kaydet
```

Skill `whisper-tr --record` ile macOS sistem default mikrofonundan kayıt başlatır, "tamam / dur / bitti" mesajınızla durdurur, otomatik temizleme + transkript yapar. Üst sınır 15 dk (`VTP_MAX_DURATION` ile değiştirilebilir).

> **macOS Mikrofon İzni:** İlk kullanımda Terminal/Claude Code için mikrofon izin popup'ı açılır. Açılmazsa: **System Settings → Privacy & Security → Microphone → Terminal (ve Claude Code)** açın, uygulamayı yeniden başlatın.

### Skill akışı (her iki mod ortak)

1. Transkript al (`whisper-tr` veya `whisper-tr --record`).
2. Çıktıyı **mantık taraması**ndan geçirir (fonetik karışıklık, syntax eksiği, özel ad, ortografi).
3. Şüpheli yerleri **AskUserQuestion** ile size sorar (max 4 soru).
4. Düzeltmeleri uygular ve `${VOICE_PROMPT_OUTPUT_DIR:-$(pwd)/voice_prompt_outputs}/<bağlam-slug>_<timestamp>.txt` olarak kaydeder.
5. Tekrar eden hataları `postproc_dict.txt` / `initial_prompt.txt`'e eklemenizi önerir.
6. Düzeltme listesi + final transkript özeti döner.

### CLI'ı doğrudan kullanmak

```bash
whisper-tr kayit.m4a                          # sade transkript
whisper-tr kayit.mp3 -o /tmp/out.txt          # çıktı dosyasını belirt
whisper-tr kayit.wav --list                   # kelime listesi modu (small)
whisper-tr kayit.mp3 -p "Ahmet Yılmaz, ARGE"  # ek terim ipucu
whisper-tr --record cikti.txt                 # mikrofondan canlı kayıt + transkript
whisper-tr --record --device :1 out.txt       # belirli mic (ör. MacBook Pro Mic)
whisper-tr --record --max-duration 600 out.txt
whisper-tr --help                             # tüm seçenekler
```

`--record` foreground çalışır: kullanıcı `q` tuşuna basarak durdurur. Skill'in arkadan çalıştırması için bkz. SKILL.md (`--pidfile` + FIFO `q` mekanizması).

## Yapılandırma

| Değişken | Varsayılan | Anlamı |
|---|---|---|
| `VOICE_PROMPT_OUTPUT_DIR` | `$(pwd)/voice_prompt_outputs` | Skill'in transkriptleri kaydettiği klasör. |
| `VTP_RECORD_DEVICE` | `:default` | `whisper-tr --record` için avfoundation audio device (`:0`, `:1`, `:default`). |
| `VTP_MAX_DURATION` | `900` | `--record` için maksimum kayıt süresi (saniye). |
| `CLAUDE_SKILLS_DIR` | `~/.claude/skills` | `install.sh`'in skill'i kuracağı yer. |
| `VOICE_PROMPT_BIN_DIR` | `~/bin` | `install.sh`'in `whisper-tr`'ı kuracağı yer. |
| `WHISPER_TR_CONFIG_DIR` | `~/.config/whisper-tr` | `whisper-tr` config klasörü. |
| `WHISPER_TR_VENV` | `~/.venv-whisper` | `bootstrap-whisper.sh`'in venv yolu. |

### `initial_prompt.txt` ve `postproc_dict.txt`

Whisper'ı projenize özel terminolojiye yönlendirmek için bu iki dosyayı düzenleyin:

- **`~/.config/whisper-tr/initial_prompt.txt`** — Whisper'a verilen `--initial_prompt`. Sık geçen modül adları, kişi adları, şirket isimleri, domain kısaltmaları buraya yazılır. Şablon: [`config/initial_prompt.example.txt`](config/initial_prompt.example.txt).
- **`~/.config/whisper-tr/postproc_dict.txt`** — Whisper çıktısına regex post-processing kuralları. Format: `<pattern>|<replacement>`, satır başına bir kural, IGNORECASE. Şablon: [`config/postproc_dict.example.txt`](config/postproc_dict.example.txt).

Skill kullandıkça onayladığınız düzeltmeleri buraya kendisi ekleme önerisi getirir.

## Depo Yapısı

```
voice_to_prompt/
├── .claude-plugin/
│   └── marketplace.json            # /plugin marketplace add ile kurulum için
├── bin/
│   └── whisper-tr                  # Whisper sarmalayıcı CLI (bash)
├── config/
│   ├── initial_prompt.example.txt  # Whisper initial prompt template
│   └── postproc_dict.example.txt   # Regex post-proc kuralları template
├── scripts/
│   ├── install.sh                  # Skill + CLI + config kurulum
│   └── bootstrap-whisper.sh        # ffmpeg + venv + whisper kurulumu
├── docs/
│   └── SKILL_TEMPLATE.md           # Yeni skill başlatma şablonu
├── skills/
│   └── voice-to-prompt/
│       └── SKILL.md                # Skill'in talimat dosyası
├── .gitignore
├── LICENSE                         # MIT
└── README.md
```

## Yeni Skill / Katkı

PR ve issue açın. Yeni bir skill eklerken:

1. `skills/<skill-adı>/SKILL.md` ekleyin (şablon: [`docs/SKILL_TEMPLATE.md`](docs/SKILL_TEMPLATE.md)).
2. `.claude-plugin/marketplace.json` içindeki `plugins` listesine ekleyin.
3. Bu README'deki ilgili tabloya satır ekleyin.

## Lisans

[MIT](LICENSE) © 2026 Cafer Dursun
