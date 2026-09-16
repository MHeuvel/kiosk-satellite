// Replacing a focused editor can fire change as focus moves. Preserve its
// draft without turning a device update into an unintended settings write.
export function preserveDraft(root = document, attribute = 'data-key') {
  const active = document.activeElement;
  const key = active?.closest(`[${attribute}]`)?.getAttribute(attribute);
  if (!key || !root.contains(active) || !(active.tagName === 'TEXTAREA'
    || (active.tagName === 'INPUT' && !['checkbox', 'range'].includes(active.type)))) return () => {};
  const draft = { value: active.value, start: active.selectionStart, end: active.selectionEnd };
  const suppress = event => event.stopImmediatePropagation();
  active.addEventListener('change', suppress, { capture: true });
  return () => {
    try {
      const row = [...root.querySelectorAll(`[${attribute}]`)]
        .find(row => row.getAttribute(attribute) === key);
      const control = row?.querySelector('input, textarea');
      if (control) {
        control.value = draft.value;
        control.focus({ preventScroll: true });
        if (draft.start != null) control.setSelectionRange(draft.start, draft.end);
      }
    } finally {
      active.removeEventListener('change', suppress, { capture: true });
    }
  };
}
