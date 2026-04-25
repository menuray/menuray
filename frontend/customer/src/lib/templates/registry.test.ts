import { describe, it, expect } from 'vitest';
import { TEMPLATES, resolveTemplate } from './registry';
import MinimalLayout from './minimal/MenuPage.svelte';
import GridLayout from './grid/MenuPage.svelte';

describe('template registry', () => {
  it('exposes all five known TemplateIds', () => {
    expect(Object.keys(TEMPLATES).sort()).toEqual([
      'bistro',
      'grid',
      'izakaya',
      'minimal',
      'street',
    ]);
  });

  it('maps minimal and grid to their dedicated layouts', () => {
    expect(TEMPLATES.minimal).toBe(MinimalLayout);
    expect(TEMPLATES.grid).toBe(GridLayout);
  });

  it('falls back to MinimalLayout for designer-pending templates', () => {
    expect(TEMPLATES.bistro).toBe(MinimalLayout);
    expect(TEMPLATES.izakaya).toBe(MinimalLayout);
    expect(TEMPLATES.street).toBe(MinimalLayout);
  });
});

describe('resolveTemplate', () => {
  it('returns the registered component for known ids', () => {
    expect(resolveTemplate('minimal')).toBe(MinimalLayout);
    expect(resolveTemplate('grid')).toBe(GridLayout);
  });

  it('returns MinimalLayout for designer-pending templates', () => {
    expect(resolveTemplate('bistro')).toBe(MinimalLayout);
    expect(resolveTemplate('izakaya')).toBe(MinimalLayout);
    expect(resolveTemplate('street')).toBe(MinimalLayout);
  });

  it('returns MinimalLayout for unknown ids (DB tampering / future templates)', () => {
    expect(resolveTemplate('xyz')).toBe(MinimalLayout);
    expect(resolveTemplate('')).toBe(MinimalLayout);
  });

  it('returns MinimalLayout for null / undefined', () => {
    expect(resolveTemplate(null)).toBe(MinimalLayout);
    expect(resolveTemplate(undefined)).toBe(MinimalLayout);
  });
});
