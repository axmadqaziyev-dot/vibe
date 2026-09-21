// Veb yığımından sonra işə salınır: main.dart.js faylına məzmun damğası vurur.
//
// Niyə lazımdır:
//   main.dart.js təxminən 1 MB-dır və adı heç vaxt dəyişmir. Ona görə onu
//   "no-cache" ilə verirdik — yoxsa yeni versiya çıxanda köhnə fayl qalardı.
//   Nəticədə brauzer onu HƏR açılışda tam yenidən yükləyirdi (0.5-1.4 san).
//
//   Ada damğa vurulanda fayl əbədi keşlənə bilər: yeni yığımda ad dəyişir,
//   flutter_bootstrap.js (o, keşlənmir) yeni ada işarə edir, köhnəsi özü
//   yararsız olur. İkinci açılışdan sonra o 1 MB ümumiyyətlə yüklənmir.
//
// İşə salmaq:  node tools/hash_build.mjs

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, renameSync, existsSync, readdirSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';

const dir = 'build/web';
const entry = join(dir, 'main.dart.js');

if (!existsSync(entry)) {
  console.error('main.dart.js tapilmadi — evvelce "flutter build web" isle.');
  process.exit(1);
}

// Köhnə yığımdan qalan damğalı fayllar silinsin, qovluq şişməsin.
for (const name of readdirSync(dir)) {
  if (/^main\.[0-9a-f]{10}\.dart\.js$/.test(name)) unlinkSync(join(dir, name));
}

const body = readFileSync(entry);
const hash = createHash('sha256').update(body).digest('hex').slice(0, 10);
const hashed = `main.${hash}.dart.js`;

renameSync(entry, join(dir, hashed));

// İstinadları yeniləyirik.
let patched = 0;
for (const name of ['flutter_bootstrap.js', 'index.html']) {
  const path = join(dir, name);
  if (!existsSync(path)) continue;

  const text = readFileSync(path, 'utf8');
  if (!text.includes('main.dart.js')) continue;

  writeFileSync(path, text.replaceAll('main.dart.js', hashed));
  patched++;
}

// Brauzer faylı flutter_bootstrap.js-i oxuyana qədər gözləməsin —
// yükləmə səhifə açılan kimi paralel başlasın.
const indexPath = join(dir, 'index.html');
const index = readFileSync(indexPath, 'utf8');
const preload = `<link rel="preload" as="script" href="${hashed}">`;

if (!index.includes(preload)) {
  writeFileSync(
    indexPath,
    index.replace('</head>', `  ${preload}\n</head>`),
  );
}

// Yayimdan xeber vermek ucun kicik bir fayl.
//
// Tetbiq onu vaxtasiri oxuyur: icindeki damga ise dusen versiyadan
// ferqlidirse, demeli yeni yayim var. Onsuz istifadeci yeniliyi
// yalniz tetbiqi tam bagladiqdan sonra gorurdu — iOS-da bu, gunlerle
// cekile bilir.
writeFileSync(
  join(dir, 'version.json'),
  JSON.stringify({ build: hash, at: Date.now() }),
);

// Ise dusen versiyanin damgasi sehifenin ozunde saxlanilir ki,
// muqayise ucun elave sorgu lazim olmasin.
const marked = readFileSync(indexPath, 'utf8');
if (!marked.includes('window.vibeBuild')) {
  writeFileSync(
    indexPath,
    marked.replace(
      '</head>',
      `  <script>window.vibeBuild = "${hash}";</script>
</head>`,
    ),
  );
}

console.log(`${hashed} (${Math.round(body.length / 1024)} KB), ${patched} fayl yenilendi`);
