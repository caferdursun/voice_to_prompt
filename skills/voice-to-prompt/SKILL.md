---
name: voice-to-prompt
description: Türkçe + İngilizce karışık teknik ses kayıtlarını temiz prompt metinlerine dönüştürür. whisper-tr CLI ile transkript alır, çıktıyı mantık taramasından geçirir, sistematik hata şüphelerini kullanıcıya doğrulatır, düzeltilmiş sonucu timestamp'li olarak yapılandırılabilir bir output klasörüne kaydeder. Tekrarlayan yanlışları Whisper config'ine (initial_prompt / postproc_dict) önerir. macOS'ta canlı kayıt modu da destekler (whisper-tr --record). Tetikleyiciler: (a) kullanıcı bir ses dosyası (.m4a/.mp3/.wav/.aif/.flac/.ogg) paylaşıp transkript veya prompt istediğinde; (b) "bunu transkript et", "sesten prompt yap", "bu kaydı yazıya çevir" gibi talepler; (c) "kayıt başlat", "şimdi konuşacağım", "yeni ses kaydı al", "mikrofondan kaydet", "hemen söyleyeceğim" gibi canlı kayıt talepleri (macOS).
---

# Voice-to-Prompt Skill

Ses kaydını → temiz, doğrulanmış teknik prompt'a dönüştürür. Arşivli (history) çalışır.

## Önkoşullar

| Bağımlılık | Açıklama |
|---|---|
| `whisper-tr` | Bu repo ile gelen Whisper sarmalayıcı CLI. `~/bin/whisper-tr` veya `PATH`'te olmalı. |
| `~/.config/whisper-tr/initial_prompt.txt` | Whisper'a verilen başlangıç prompt'u (terminoloji rehberi). |
| `~/.config/whisper-tr/postproc_dict.txt` | Çıktıya uygulanan regex post-processing kuralları. |
| `ffmpeg`, `python3`, `openai-whisper` | Kurulum için repo `scripts/bootstrap-whisper.sh` çalıştırılabilir. |

## Yapılandırma

Çıktı klasörü öncelik sırası:

1. `VOICE_PROMPT_OUTPUT_DIR` env değişkeni (set edilmişse)
2. Aksi halde mevcut çalışma dizininin altında `./voice_prompt_outputs/`

Skill çalışmaya başlarken klasör yoksa `mkdir -p` ile oluştur.

## Mod Seçimi

Hangi workflow tetiklenecek?

| Tetikleyici | Mod |
|---|---|
| Kullanıcı bir ses dosyası yolu verdi | **Workflow A — File Mode** |
| "kayıt başlat" / "şimdi konuşacağım" / "mikrofondan kaydet" + macOS | **Workflow B — Record Mode** |
| Linux/WSL + record talebi | Hata: "Record mode sadece macOS. Lütfen kaydı alıp dosya yolu verin." |

Step 2..7 (mantık taraması, AskUserQuestion, slug + timestamp dosya kaydı, config feedback, özet) iki modda da AYNIDIR.

## Workflow A — File Mode

### Step 1 — Transkript al

```bash
whisper-tr "<input_path>" -o /tmp/vtp-raw.txt -q
```

- `-q` (quiet): sadece metin, info satırları yok
- Model otomatik `large-v3`. Kullanıcı "kelime listesi" okuduysa `--list` ekle (small model)
- Kullanıcı özel ad/terim söylediyse `-p "isim1, terim2"` ile prompt zenginleştir

Dosya okunamazsa kullanıcıdan doğru path iste. Uzun dosyalar (>3 dk) için bilgilendirici mesaj ver.

## Workflow B — Record Mode (macOS only)

### Step 0 — Output yolunu hazırla

```bash
OUT_DIR="${VOICE_PROMPT_OUTPUT_DIR:-$(pwd)/voice_prompt_outputs}"
mkdir -p "$OUT_DIR"
TMP_OUT="$(mktemp -t vtp-rec).txt"
```

`TMP_OUT` Step 5'te slug üretildikten sonra final konumuna `mv` edilecek.

### Step 0.1 — Kaydı arka planda başlat

`whisper-tr`'ı **`run_in_background=true`** olan bir Bash tool çağrısı ile başlat:

```bash
whisper-tr --record "$TMP_OUT" --pidfile /tmp/vtp-record.pid -q
```

Kullanıcı özel ad/terim söylediyse `-p "..."` da ekle.

### Step 0.2 — Kullanıcıya bildir

> "Kayıt başladı (sistem default mikrofon, max 15 dk). Konuşmanız bitince **'tamam'**, **'dur'**, **'bitti'** veya benzeri bir mesaj atın — kaydı durdurup transkripte geçeceğim."

### Step 0.3 — Bitirme komutu yorumla ve durdur

Kullanıcının sonraki mesajı net bir bitirme sinyali mi (örn. "tamam", "dur", "bitti", "kayıt bitti", "stop", "bitirdim", "yeter")? Belirsizse **AskUserQuestion** ile teyit et: "Kaydı durdurayım mı?".

Onay gelince — graceful stop (FIFO'ya `q`):

```bash
FIFO="$(cat /tmp/vtp-record.pid.fifo 2>/dev/null)"
PID="$(cat /tmp/vtp-record.pid 2>/dev/null)"

if [ -n "$FIFO" ] && [ -p "$FIFO" ]; then
    printf 'q' > "$FIFO"
elif [ -n "$PID" ]; then
    kill -TERM "$PID" 2>/dev/null || true
fi

# 5 sn bekle, hala canlıysa SIGKILL
for _ in 1 2 3 4 5; do
    [ -z "$PID" ] && break
    kill -0 "$PID" 2>/dev/null || break
    sleep 1
done
[ -n "$PID" ] && kill -0 "$PID" 2>/dev/null && kill -KILL "$PID" 2>/dev/null || true
```

### Step 0.4 — Background bash output'u al

`whisper-tr` aynı process içinde temizleme + whisper transkriptini yapıp `TMP_OUT`'a yazar. Background bash tool'unun complete olmasını bekle, çıktıyı oku.

`TMP_OUT` boş veya yoksa: kullanıcıya hata mesajı (mikrofon izni / kayıt iptali olabilir). Kayıt geri yüklenebilirliği için ham WAV `mktemp -d` ile silinir — yeniden başlatma gerekebilir.

### Step 0.5 — Workflow A'nın Step 2..7'sine akıt

`TMP_OUT` artık dolu bir transkript dosyası. Aşağıdaki Step 2..7'yi normal çalıştır. Step 5'te dosya rename'i:

```bash
mv "$TMP_OUT" "${OUT_DIR}/${SLUG}_${STAMP}.txt"
OUT="${OUT_DIR}/${SLUG}_${STAMP}.txt"
```

(Workflow A'da Step 5 dosyayı sıfırdan yazar; Workflow B'de zaten `TMP_OUT` var, onu rename ediyoruz.)

### Step 2 — Mantık Taraması

Çıktıyı kelime kelime oku ve ŞÜPHELİ noktaları topla. Aşağıdaki kategorilerden hangisi tetiklendiğini not et:

**2.1 Fonetik karıştırma (Whisper'ın sık hatası):**
- Sayılı kısaltmalar (`xyz2/xyz3` gibi) yanlış konsonantla yazılmış olabilir
- `cloud code` → muhtemelen `Claude Code`
- `product deploy` → muhtemelen `prod deploy`
- `b↔v`, `p↔b`, `c↔ç` karışımı olabilecek isim/kısaltmalar

**2.2 Bağlamsal tutarsızlık:**
- Konu belirli bir teknoloji/proje ama cümlede o bağlama uymayan kelime
- Aynı paragrafta aynı terimin farklı yazılması ("aktif" ve "active" birbirine karışmış)
- Sözlük dışı bir kelime ("Transit Model" → "TransientModel")

**2.3 Syntax eksiği:**
- Kod bekleyen yerde space var ama underscore olmalı (`hr payslip py` → `hr_payslip.py`)
- Decorator/method noktası eksik (`api depends` → `api.depends`)
- CLI flag eksik dash (`U module name` → `-u module_name`)

**2.4 Özel ad / proje bağlamı:**
- Kişi/şirket/modül adları yanlış yazılmış olabilir (kullanıcının `initial_prompt.txt`'sindeki terimleri referans al)

**2.5 Türkçe ortografi:**
- Apostrof eksik (özel ad → özel ad'ın/özel ad'da)
- Kısaltmaların büyük harf doğruluğu (SGK, BES, AGİ vb. proje bağlamına göre)

Şüpheli bulunan her nokta için bir "düzeltme önerisi" oluştur.

### Step 3 — Kullanıcıya Doğrulama Soruları

**AskUserQuestion** ile maksimum 4 soru sor. Her soruda şüpheli cümleyi göster ve seçenekler ver:

- Seçenek 1: Tahmin ettiğin doğru versiyon
- Seçenek 2: Aynen kalsın (belki doğruydu)
- Seçenek 3 (opsiyonel): Başka bir alternatif

**Önceliklendirme:** Eğer 4'ten fazla şüphe varsa, önceliği şuna göre belirle:
1. Finansal/sayısal/teknik kritik hatalar (yanlış path, yanlış sayısal değer)
2. Tekrar eden sistematik hatalar (4 kez "Cloud code" geçiyorsa 1 soruda topla)
3. Bağlamsal belirsiz kelimeler

4 şüpheden azsa hepsini sor.

### Step 4 — Düzeltme Uygula

Kullanıcı onayladığı her düzeltmeyi uygula. Onaylanmayanları aynen koru. Tüm düzeltmeleri tek bir "düzeltmeler" listesi olarak sakla — son özete kullanılacak.

### Step 5 — Kaydet (Bağlamlı + Timestamp'li Dosya)

Çıktı dosyası adı formatı:
```
{context_slug}_{YYYY-MM-DD_HH-MM-SS}.txt
```

**`context_slug`** — input dosya adı yerine, transkriptin içeriğinden çıkarılan **kısa, anlamlı bir bağlam etiketi**. `untitled`, `kayit`, `recording-001` gibi generic adları kullanma.

#### Slug Üretme Kuralları

1. **Transkriptin ilk 2-3 cümlesini ve en sık geçen anahtar terimleri analiz et** → ana konuyu/niyeti tespit et
2. **2-5 kelimelik bir Türkçe ifade** kur (ana eylem + ana konu)
3. **ASCII'ye çevir** (Türkçe karakterler):
   - ş→s, ç→c, ğ→g, ü→u, ö→o, ı→i, İ→i
   - Tüm harfleri küçült
4. **Boşlukları `-` ile değiştir**
5. **Alfanumerik + `-` dışındaki karakterleri sil**
6. Maksimum **40 karakter** (uzun olursa kısalt)

#### Örnek Slug'lar

| Transkript Konusu | Slug |
|---|---|
| "Uygulamamıza avans talebi özelliği eklenecek..." | `avans-talebi-ozelligi` |
| "Bugün bordro modülüne compute field ekleyeceğim..." | `bordro-compute-field` |
| "Yeni RFQ wizard tasarlanacak..." | `rfq-wizard-tasarim` |
| "Whisper transkript performansını test ediyorum..." | `whisper-test` |
| "Claude Code övgüsü, kayıt testi" | `claude-code-test` |
| (Konu çok genel, çıkaramıyorsun) | `{input_stem}` (fallback) |

#### Implementasyon

```bash
OUT_DIR="${VOICE_PROMPT_OUTPUT_DIR:-$(pwd)/voice_prompt_outputs}"
mkdir -p "$OUT_DIR"
STAMP=$(date +%Y-%m-%d_%H-%M-%S)

# context_slug'ı sen (Claude) belirle — transkripti okuyup karar ver.
# Örnek: SLUG="avans-talebi-ozelligi"

OUT="${OUT_DIR}/${SLUG}_${STAMP}.txt"
```

Aynı slug + farklı timestamp birden fazla kayıt için sorun değil (history). Aynı saniyede 2 kayıt zaten olamaz; çakışma riski yok.

**Önemli:** Slug'ı Python `re.sub(r'[^a-z0-9-]+', '', text.lower())` gibi sterilize ederek garantile — özellikle Türkçe karakterleri ASCII'ye çevirmeyi unutma.

### Step 6 — Config Feedback (Koşullu)

Kullanıcının onayladığı düzeltmeleri analiz et:

**6.1 `postproc_dict.txt`'e eklenmesi gereken durum:**
- Yanlış yazım bir **kalıp** (ör. "Cloud Code" → "Claude Code" benzeri fonetik ikame)
- Gelecek transkriptlerde de tekrar edebilecek bir hata
- Regex olarak ifade edilebilir

Formatı:
```
<regex_pattern>|<replacement>
```
Case-insensitive olarak eklenir (IGNORECASE flag default).

**6.2 `initial_prompt.txt`'e eklenmesi gereken durum:**
- Daha önce prompt'ta olmayan yeni bir özel ad / modül adı
- Sık kullanılacak teknik terim
- Kişi adı, şirket adı, projeye özel isim

**AskUserQuestion** ile kullanıcıya sor:
> "Bu düzeltme gelecekte de tekrar olur mu? Öyleyse config'e ekleyeyim mi?"
> - `postproc_dict.txt`'e regex ekle
> - `initial_prompt.txt`'e terim ekle
> - İkisine de ekle
> - Hayır, tek seferlik

Onay gelirse ilgili dosyaya satır ekle (append).

### Step 7 — Özet

Kullanıcıya yaz:

```
✅ Transkript hazır: <output_path>

Düzeltmeler (N adet):
  - "<yanlış>" → "<doğru>"
  - ...

Config güncellemeleri:
  - postproc_dict.txt: 2 yeni regex
  - initial_prompt.txt: 1 yeni terim
```

Son olarak transkriptin tamamını blok halinde göster.

## Karar Kılavuzu

### Model Seçimi (whisper-tr `-m` / `--list`)

| Durum | Seçim |
|---|---|
| Doğal konuşma (cümle yapısı var) | default `large-v3` |
| Kelime/kısaltma listesi (virgüllerle sayma) | `--list` (small) |
| Kullanıcı hızlı test istedi | `-m tiny` |

**İpucu:** Ses dosyası isminde "liste", "terim", "kelime" varsa `--list` kullan.

### Ekstra Prompt (`-p`)

Kullanıcı mesajında özel adlar veya teknik bağlam varsa:
- "Ahmet Yılmaz hakkında konuştum" → `-p "Ahmet Yılmaz"`
- "ARGE teşvikini anlattım" → `-p "ARGE teşvik, 4691, 5746"`

### Post-processing Atlama (`--no-postproc`)

- Kullanıcı "ham transkript" / "original çıktı" istiyorsa
- Debugging için ham Whisper çıktısını görmek gerekiyorsa

## Örnek Çalışma

### Workflow A — File Mode

Kullanıcı: "Bu kaydı prompt et: ~/Downloads/yeni_plan.m4a"

1. `whisper-tr ~/Downloads/yeni_plan.m4a -o /tmp/vtp-raw.txt -q` çalıştır
2. Çıktıyı oku → "Cloud code", "tcv4", "hr underscore payslip" tespit
3. AskUserQuestion:
   - "Cloud code → Claude Code mı?" (seç)
   - "tcv4 → tcb4 mi?" (seç)
   - "hr underscore payslip → hr_payslip mi?" (seç)
4. Düzeltmeleri uygula
5. Slug üret (ör. transkript "avans talebi modülü" hakkında) → `${VOICE_PROMPT_OUTPUT_DIR:-./voice_prompt_outputs}/avans-talebi-modulu_2026-04-21_14-30-15.txt`
6. AskUserQuestion: "tcv4 → tcb4 sistematik mi? postproc_dict'e ekle?"
7. Config'e satır ekle: `\btcv(\d)\b|tcb\1`
8. Özet ve final metin göster.

### Workflow B — Record Mode

Kullanıcı: "kayıt başlat, prompt vereceğim"

1. `OUT_DIR` ve `TMP_OUT` hazırla
2. `whisper-tr --record "$TMP_OUT" --pidfile /tmp/vtp-record.pid -q` (background)
3. Kullanıcıya: "Kayıt başladı, bitince 'tamam' yazın"
4. Kullanıcı 30 sn sonra "tamam, durdur" yazar
5. `printf 'q' > /tmp/vtp-record.pid.fifo` → ffmpeg graceful kapanır → temizleme + transkript otomatik
6. Background bash complete olur → `TMP_OUT` okunur
7. Step 2..7 (mantık taraması, AskUserQuestion, slug, mv `TMP_OUT` → final, özet)

## Hata Durumları

| Durum | Davranış |
|---|---|
| Ses dosyası path'i yok | Kullanıcıdan açık path iste, dinle |
| Dosya bulunamadı | Hata mesajı + kontrol önerisi |
| whisper-tr executable değil | `chmod +x ~/bin/whisper-tr` öner |
| Venv yok | Repo `scripts/bootstrap-whisper.sh` çalıştırmasını öner |
| ffmpeg yok | `brew install ffmpeg` öner |
| Çıktı boş | Ses kalitesi kontrol et (ffmpeg volumedetect), -30 dB altıysa uyar |
| Ses dosyası >3 dk | Bilgilendirici mesaj ("transkript 1-2 dakika sürebilir") |
| Record mode + Linux/WSL | "Sadece macOS, lütfen kayıt alıp dosya yolu verin" |
| Mikrofon izni reddi (`OSStatus -1719`) | "System Settings → Privacy & Security → Microphone → Terminal/Claude Code'a izin verin, yeniden deneyin" |
| Stale PID file (önceki kayıt çakılmış) | `rm /tmp/vtp-record.pid*` öner |
| Kayıt çok kısa (<2 sn) | Uyar ama yine de transkript dene |
| Kullanıcı bitirme komutu vermiyor (15 dk geçti) | ffmpeg `-t 900` ile otomatik durur, normal akışa geç |

## Kapsam Dışı

- Fine-tuning veya custom model eğitimi
- Gerçek zamanlı (streaming) transkript — kayıt durunca transkript başlar
- Çoklu konuşmacı ayırma (diarization)
- Çeviri (sadece Türkçe transkript)
- Linux / Windows canlı mikrofon kaydı (macOS avfoundation'a bağımlı)
