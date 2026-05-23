import { useEffect, useState, useCallback } from 'react';
import { stow } from '../api/client';
import PackageList from '../components/stow/PackageList';
import FileBrowser from '../components/stow/FileBrowser';
import FileEditor from '../components/stow/FileEditor';

export default function StowPackagesPage() {
  const [packages, setPackages] = useState<any[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [files, setFiles] = useState<any[]>([]);
  const [editingFile, setEditingFile] = useState<{ path: string; content: string } | null>(null);

  const loadPackages = useCallback(async () => {
    setPackages(await stow.packages());
  }, []);

  const loadFiles = useCallback(async (pkg: string) => {
    const data = await stow.files(pkg);
    setFiles(data.files);
  }, []);

  useEffect(() => { loadPackages(); }, [loadPackages]);
  useEffect(() => {
    if (selected) {
      loadFiles(selected);
      setEditingFile(null);
    }
  }, [selected, loadFiles]);

  const handleCreatePackage = async () => {
    const name = prompt('New stow package name:');
    if (!name) return;
    await stow.createPackage(name);
    await loadPackages();
    setSelected(name);
  };

  const handleDeletePackage = async (name: string) => {
    if (!confirm(`Delete stow package "${name}" and all its files?`)) return;
    await stow.deletePackage(name);
    if (selected === name) { setSelected(null); setFiles([]); setEditingFile(null); }
    await loadPackages();
  };

  const handleOpenFile = async (path: string) => {
    if (!selected) return;
    const data = await stow.readFile(selected, path);
    setEditingFile({ path: data.path, content: data.content });
  };

  const handleSaveFile = async (path: string, content: string) => {
    if (!selected) return;
    await stow.writeFile(selected, path, content);
    setEditingFile({ path, content });
    await loadFiles(selected);
  };

  const handleDeleteFile = async (path: string) => {
    if (!selected) return;
    if (!confirm(`Delete file "${path}"?`)) return;
    await stow.deleteFile(selected, path);
    if (editingFile?.path === path) setEditingFile(null);
    await loadFiles(selected);
  };

  const handleCreateFile = async () => {
    if (!selected) return;
    const path = prompt('New file path (relative to package root):');
    if (!path) return;
    await stow.writeFile(selected, path, '');
    await loadFiles(selected);
    setEditingFile({ path, content: '' });
  };

  return (
    <div className="flex gap-6 h-[calc(100vh-8rem)]">
      <PackageList
        packages={packages}
        selected={selected}
        onSelect={setSelected}
        onCreate={handleCreatePackage}
        onDelete={handleDeletePackage}
      />
      <div className="flex-1 flex flex-col gap-4 min-w-0">
        {selected ? (
          <>
            <FileBrowser
              packageName={selected}
              files={files}
              activeFile={editingFile?.path ?? null}
              onOpen={handleOpenFile}
              onDelete={handleDeleteFile}
              onCreate={handleCreateFile}
            />
            {editingFile && (
              <FileEditor
                path={editingFile.path}
                content={editingFile.content}
                onSave={handleSaveFile}
              />
            )}
          </>
        ) : (
          <div className="flex items-center justify-center h-full text-gray-400">
            Select a stow package to browse its files
          </div>
        )}
      </div>
    </div>
  );
}
