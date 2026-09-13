// Builds the remote admin UI: remote-ui/ (readable sources, tracked) into
// assets/remote-ui/ (minified, gitignored, bundled by Flutter). Gradle runs
// this before every APK build; run `npm run build` from app/ by hand before
// `flutter test`, since the tests that serve the admin read the bundle.
//
// Minification only: every module stays its own file with its relative
// imports untouched, so the server's ?v= stamping and the tests that walk
// the import graph see the same shape as the sources. Exports keep their
// names, local identifiers are shortened, whitespace and comments go.
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const app = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const src = path.join(app, 'remote-ui');
const out = path.join(app, 'assets', 'remote-ui');

async function esbuild() {
  try {
    return await import('esbuild');
  } catch {
    // First build on a fresh checkout: install the pinned esbuild.
    const npm = spawnSync('npm', ['ci', '--no-audit', '--no-fund', '--loglevel=error'], {
      cwd: app,
      stdio: 'inherit',
      shell: process.platform === 'win32',
    });
    if (npm.status !== 0) process.exit(npm.status ?? 1);
    return import('esbuild');
  }
}

const { build } = await esbuild();
rmSync(out, { recursive: true, force: true });
mkdirSync(path.join(out, 'static'), { recursive: true });
cpSync(path.join(src, 'index.html'), path.join(out, 'index.html'));

const files = readdirSync(path.join(src, 'static')).sort();
const minified = files.filter((f) => /\.(js|css)$/.test(f));
for (const f of files) {
  if (!minified.includes(f)) cpSync(path.join(src, 'static', f), path.join(out, 'static', f));
}
const options = {
  outdir: path.join(out, 'static'),
  bundle: false,
  minify: true,
  format: 'esm',
  target: 'es2020',
  charset: 'utf8',
  legalComments: 'inline',
  logLevel: 'warning',
};
// The vendored modules open with their copyright banner. DOMPurify marks
// its own as a legal comment and esbuild keeps it, marked does not, so
// each vendor file is built alone with its banner put back on top. The
// license texts sit beside them as .txt files either way.
const vendors = minified.filter((f) => f.startsWith('vendor-') && f.endsWith('.js'));
const own = minified.filter((f) => !vendors.includes(f));
await build({ ...options, entryPoints: own.map((f) => path.join(src, 'static', f)) });
for (const f of vendors) {
  const banner = readFileSync(path.join(src, 'static', f), 'utf8').match(/^\/\*[\s\S]*?\*\//)?.[0] ?? '';
  await build({
    ...options,
    entryPoints: [path.join(src, 'static', f)],
    legalComments: 'none',
    banner: { js: banner },
  });
}

const size = (dir, names) => names.reduce((n, f) => n + statSync(path.join(dir, f)).size, 0);
const before = size(path.join(src, 'static'), minified);
const after = size(path.join(out, 'static'), minified);
console.log(`remote-ui: ${minified.length} files minified, ${(before / 1024).toFixed(0)} KB -> ${(after / 1024).toFixed(0)} KB`);
