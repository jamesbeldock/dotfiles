const BASE = '/api';

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(body.detail || res.statusText);
  }
  return res.json();
}

// --- Catalog ---
export const catalog = {
  get: () => request<any>('/catalog/'),
  groups: () => request<any[]>('/catalog/groups'),
  getGroup: (name: string) => request<any>(`/catalog/groups/${name}`),
  updateGroup: (name: string, data: any) =>
    request<any>(`/catalog/groups/${name}`, { method: 'PUT', body: JSON.stringify(data) }),
  createGroup: (data: any) =>
    request<any>('/catalog/groups', { method: 'POST', body: JSON.stringify(data) }),
  deleteGroup: (name: string) =>
    request<any>(`/catalog/groups/${name}`, { method: 'DELETE' }),
  validate: () =>
    request<{ valid: boolean; errors: string[] }>('/catalog/validate', { method: 'POST' }),
};

// --- Sets ---
export const sets = {
  list: () => request<{ name: string; description: string }[]>('/sets/'),
  get: (name: string) => request<any>(`/sets/${name}`),
  resolved: (name: string) => request<any>(`/sets/${name}/resolved`),
  compare: (names: string[]) => request<any>(`/sets/compare?sets=${names.join(',')}`),
  create: (data: any) =>
    request<any>('/sets/', { method: 'POST', body: JSON.stringify(data) }),
  update: (name: string, data: any) =>
    request<any>(`/sets/${name}`, { method: 'PUT', body: JSON.stringify(data) }),
  delete: (name: string) =>
    request<any>(`/sets/${name}`, { method: 'DELETE' }),
};

// --- Stow ---
export const stow = {
  packages: () => request<any[]>('/stow/packages'),
  createPackage: (name: string) =>
    request<any>('/stow/packages', { method: 'POST', body: JSON.stringify({ name }) }),
  deletePackage: (name: string) =>
    request<any>(`/stow/packages/${encodeURIComponent(name)}`, { method: 'DELETE' }),
  files: (pkg: string) =>
    request<{ name: string; files: any[] }>(`/stow/packages/${encodeURIComponent(pkg)}/files`),
  readFile: (pkg: string, path: string) =>
    request<{ path: string; content: string }>(
      `/stow/packages/${encodeURIComponent(pkg)}/files/${path}`
    ),
  writeFile: (pkg: string, path: string, content: string) =>
    request<any>(`/stow/packages/${encodeURIComponent(pkg)}/files/${path}`, {
      method: 'PUT',
      body: JSON.stringify({ content }),
    }),
  deleteFile: (pkg: string, path: string) =>
    request<any>(`/stow/packages/${encodeURIComponent(pkg)}/files/${path}`, {
      method: 'DELETE',
    }),
};
