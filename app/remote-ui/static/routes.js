export function routeSlug(label) {
  return label.normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}
export function routeHash(path) {
  const slash = path.indexOf('/');
  if (slash < 0) return path;
  const sub = path.slice(slash + 1);
  if (path.startsWith('plugins/')) return 'plugins/' + encodeURIComponent(sub);
  return path.slice(0, slash) + (sub ? '/' + routeSlug(sub) : '');
}
export function readRoute(hash = location.hash) {
  try { return decodeURIComponent(hash.replace(/^#/, '')); }
  catch (_) { return ''; }
}
