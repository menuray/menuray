import type { Component } from 'svelte';
import MinimalLayout from './minimal/MenuPage.svelte';
import GridLayout from './grid/MenuPage.svelte';
import type { PublishedMenu, TemplateId } from '$lib/types/menu';

// Every template layout consumes the same `data` prop ({ menu, lang }) so the
// registry uses a single shared component type. Concrete MenuPage.svelte
// files declare equivalent prop shapes inline; this alias just gives the
// registry a name to reference.
export type TemplateData = { menu: PublishedMenu; lang: string };
export type TemplateComponent = Component<{ data: TemplateData }>;

// Registry maps every TemplateId to a layout component. Bistro / Izakaya /
// Street fall back to MinimalLayout until the designer delivers them; once
// the new MenuPage.svelte files exist, swap the import here and flip
// is_launch=true on the matching row in the templates table.
export const TEMPLATES: Record<TemplateId, TemplateComponent> = {
  minimal: MinimalLayout as TemplateComponent,
  grid: GridLayout as TemplateComponent,
  bistro: MinimalLayout as TemplateComponent,
  izakaya: MinimalLayout as TemplateComponent,
  street: MinimalLayout as TemplateComponent,
};

// Defensive resolver — accepts unknown ids (DB tampering, future templates
// rolled out before the client redeploys) and returns MinimalLayout instead
// of crashing.
export function resolveTemplate(id: string | null | undefined): TemplateComponent {
  if (id == null) return TEMPLATES.minimal;
  return (TEMPLATES as Record<string, TemplateComponent>)[id] ?? TEMPLATES.minimal;
}
