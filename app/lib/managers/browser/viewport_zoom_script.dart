/// A zoom level as a viewport-meta scale — what desktop browser zoom
/// actually is — NOT CSS zoom on the document root. CSS zoom breaks
/// imperatively positioned overlays (issue #259): Home Assistant's menus
/// and dialogs measure their anchor with getBoundingClientRect(), which
/// under standardized CSS zoom returns visually scaled coordinates, then
/// write them back as px that the zoomed root scales AGAIN — landing every
/// dropdown at anchor-times-zoom, off screen at 1.35x on a small tablet.
///
/// A viewport scale has no such mismatch: with `initial-scale=z` and
/// `width` set to visible-width/z, the layout viewport is exactly that
/// wide and is rendered scaled to fill the screen — one consistent CSS px
/// space. The width is written out rather than left to the spec's
/// extend-to-zoom rule: a WebView on Android TV fills a missing width with
/// its 980px television default, which pins the scale near 1 and leaves
/// every level below 1x with no effect (the NVIDIA Shield). Rotation
/// changes the visible width, so a resize listener rewrites it. Chromium
/// only honors initial-scale at navigation though; a live change applies
/// through the min/max clamp, so both are pinned to z. With pinch to zoom
/// enabled the clamp is relaxed a frame later — the forced scale sticks,
/// pinching stays free.
///
/// The page's own meta (HA declares one) is saved in data-ks-orig and its
/// non-scale keys — viewport-fit=cover above all, edge-to-edge depends on
/// it — are carried into the rewritten content. Idempotent and reversible:
/// 1x with pinching off restores the original meta, or removes one this
/// script created. 1x with pinching on still rewrites: the page's own meta
/// is what says user-scalable=no (HA's does), and the WebView's zoom flags
/// do not override it, so leaving it alone at 1x left the setting dead
/// until the slider moved (issue #443).
///
/// Shared by the dashboard WebView (the Browser zoom level) and the website
/// screensaver (its own zoom level): the rewritten meta dies with each
/// document, so both run it after every navigation and again on a live
/// change of the setting.
String viewportZoomJs({required num zoom, required bool pinch}) {
  return '''
    (function () {
      var z = $zoom;
      var ms = document.querySelectorAll('meta[name=viewport]');
      var m = ms.length ? ms[ms.length - 1] : null;
      if (z === 1 && !$pinch) {
        window.__ksZoomApply = null;
        if (m && m.hasAttribute('data-ks-zoom')) {
          var orig = m.getAttribute('data-ks-orig');
          if (orig === null) { m.remove(); return; }
          m.setAttribute('content', orig);
          m.removeAttribute('data-ks-orig');
          m.removeAttribute('data-ks-zoom');
        }
        return;
      }
      if (!m) {
        m = document.createElement('meta');
        m.name = 'viewport';
        (document.head || document.documentElement).appendChild(m);
        m.setAttribute('data-ks-zoom', '1');
      } else if (!m.hasAttribute('data-ks-zoom')) {
        var c0 = m.getAttribute('content');
        if (c0 !== null) m.setAttribute('data-ks-orig', c0);
        m.setAttribute('data-ks-zoom', '1');
      }
      var scaleKeys =
          ['width', 'height', 'initial-scale', 'minimum-scale',
           'maximum-scale', 'user-scalable'];
      var keep = [];
      (m.getAttribute('data-ks-orig') || '').split(',').forEach(
        function (part) {
          var k = part.split('=')[0].trim().toLowerCase();
          if (k && scaleKeys.indexOf(k) < 0) keep.push(part.trim());
        },
      );
      // The visible width at scale 1, whatever scale the page sits at
      // right now (visualViewport.width shrinks as the scale grows).
      var visible = function () {
        var v = window.visualViewport;
        return v ? v.width * v.scale : window.innerWidth;
      };
      var apply = function () {
        var w = Math.round(visible() / z);
        var base = keep.concat(['width=' + w, 'initial-scale=' + z]);
        m.setAttribute('content', base.concat(
          ['minimum-scale=' + z, 'maximum-scale=' + z, 'user-scalable=no'],
        ).join(', '));
        if ($pinch) {
          requestAnimationFrame(function () {
            m.setAttribute('content', base.concat(
              ['minimum-scale=0.25', 'maximum-scale=5', 'user-scalable=yes'],
            ).join(', '));
          });
        }
      };
      apply();
      // Rotation: the visible width changes, so the layout width must
      // follow. One listener per document, re-pointed at the latest run.
      window.__ksZoomApply = apply;
      if (!window.__ksZoomResize) {
        window.__ksZoomResize = true;
        window.addEventListener('resize', function () {
          if (window.__ksZoomApply) window.__ksZoomApply();
        });
      }
    })();
  ''';
}
