import { cmd } from './core.js';
import { esphomeText, messageLanguage } from './localization.js';
import { modalShell } from './widgets.js';

export function openEspHomeEntityPicker(current) {
  return new Promise((resolve) => {
    const selected = new Set(current);
    let active = true;
    let entities = null;
    let failed = false;
    let language = messageLanguage();
    const shell = modalShell({
      title: esphomeText('Excluded entities'),
      width: 560,
      onDismiss: () => close(null),
    });
    const close = (value) => {
      active = false;
      document.removeEventListener('ks-settings-cached', onLanguage);
      shell.close();
      resolve(value);
    };
    shell.card.style.minWidth = '0';
    const note = document.createElement('p');
    note.className = 'desc';
    const search = document.createElement('input');
    search.type = 'search';
    search.className = 'field';
    const list = document.createElement('div');
    shell.body.append(note, search, list);
    const clear = document.createElement('button');
    clear.className = 'btn-text';
    clear.disabled = true;
    const selectAll = document.createElement('button');
    selectAll.className = 'btn-text';
    selectAll.disabled = true;
    const cancel = document.createElement('button');
    cancel.className = 'btn-text';
    cancel.addEventListener('click', () => close(null));
    const save = document.createElement('button');
    save.className = 'btn-primary';
    save.disabled = true;
    save.addEventListener('click', () => close([...selected].sort()));
    shell.foot.style.flexWrap = 'wrap';
    shell.foot.append(selectAll, clear, cancel, save);

    const detail = (entity) => entity.unavailable
      ? esphomeText('Currently unavailable')
      : [entity.category, entity.type].filter(Boolean).map(esphomeText).join(' · ');
    const render = () => {
      if (!active) return;
      const focused = list.contains(document.activeElement) ? document.activeElement?.dataset.entityId : null;
      const scroll = shell.body.scrollTop;
      list.replaceChildren();
      if (failed) {
        list.textContent = esphomeText('Could not load entities. Close the picker and try again.');
        return;
      }
      if (!entities) {
        list.textContent = esphomeText('Loading entities…');
        return;
      }
      const query = search.value.trim().toLowerCase();
      for (const entity of entities) {
        const displayDetail = detail(entity);
        if (!`${entity.name} ${entity.id} ${displayDetail} ${entity.category || ''} ${entity.type || ''}`.toLowerCase().includes(query)) continue;
        const row = document.createElement('label');
        row.className = 'row';
        const box = document.createElement('input');
        box.type = 'checkbox';
        box.dataset.entityId = entity.id;
        box.checked = selected.has(entity.id);
        box.addEventListener('change', () => {
          if (box.checked) selected.add(entity.id);
          else selected.delete(entity.id);
        });
        const info = document.createElement('div');
        info.className = 'info';
        const name = document.createElement('div');
        name.className = 'name';
        name.textContent = entity.name;
        const type = document.createElement('div');
        type.className = 'desc';
        type.textContent = displayDetail;
        info.append(name, type);
        row.append(box, info);
        list.append(row);
        if (entity.id === focused) box.focus({ preventScroll: true });
      }
      if (!list.childElementCount) list.textContent = esphomeText('No matching entities');
      shell.body.scrollTop = scroll;
    };
    const labels = () => {
      shell.head.textContent = esphomeText('Excluded entities');
      note.textContent = esphomeText('Pick entities to exclude from Home Assistant. All other available entities are exposed. Saving reconnects ESPHome.');
      search.placeholder = esphomeText('Search entities');
      search.setAttribute('aria-label', esphomeText('Search entities'));
      clear.textContent = esphomeText('Clear');
      selectAll.textContent = esphomeText('Select all');
      cancel.textContent = esphomeText('Cancel');
      save.textContent = esphomeText('Save');
      render();
    };
    const onLanguage = () => {
      if (language === messageLanguage()) return;
      language = messageLanguage();
      labels();
    };
    document.addEventListener('ks-settings-cached', onLanguage);
    search.addEventListener('input', render);
    clear.addEventListener('click', () => { selected.clear(); render(); });
    selectAll.addEventListener('click', () => {
      entities.forEach((entity) => selected.add(entity.id));
      render();
    });
    labels();
    (async () => {
      try {
        const result = await cmd('getEspHomeEntities');
        if (!active) return;
        if (!result.ok || !Array.isArray(result.data)) throw new Error('Could not load entities');
        entities = result.data.map((entity) => ({
          id: entity.objectId, name: entity.name,
          category: entity.categoryLabel, type: entity.type.replaceAll('_', ' '),
        }));
        const available = new Set(entities.map((entity) => entity.id));
        for (const id of selected) {
          if (!available.has(id)) entities.push({ id, name: id, unavailable: true });
        }
        entities.sort((a, b) => a.name.localeCompare(b.name));
        clear.disabled = false;
        selectAll.disabled = false;
        save.disabled = false;
      } catch (_) {
        failed = true;
      }
      render();
    })();
  });
}
