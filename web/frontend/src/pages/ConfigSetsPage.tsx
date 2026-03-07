import { useEffect, useState, useCallback } from 'react';
import { sets, catalog } from '../api/client';
import SetSelector from '../components/sets/SetSelector';
import PackageTable from '../components/sets/PackageTable';

export default function ConfigSetsPage() {
  const [setList, setSetList] = useState<{ name: string; description: string }[]>([]);
  const [activeSet, setActiveSet] = useState<string | null>(null);
  const [compareSets, setCompareSets] = useState<string[]>([]);
  const [comparison, setComparison] = useState<any>(null);
  const [allGroups, setAllGroups] = useState<any[]>([]);
  const [setConfig, setSetConfig] = useState<any>(null);

  const loadSets = useCallback(async () => {
    const list = await sets.list();
    setSetList(list);
    if (!activeSet && list.length > 0) setActiveSet(list[0].name);
  }, [activeSet]);

  const loadGroups = useCallback(async () => {
    setAllGroups(await catalog.groups());
  }, []);

  useEffect(() => { loadSets(); loadGroups(); }, [loadSets, loadGroups]);

  useEffect(() => {
    if (!activeSet) { setComparison(null); setSetConfig(null); return; }
    const allNames = [activeSet, ...compareSets];
    sets.compare(allNames).then(setComparison);
    sets.get(activeSet).then(setSetConfig);
  }, [activeSet, compareSets]);

  const handleCreateSet = async () => {
    const name = prompt('New configuration set name:');
    if (!name) return;
    const desc = prompt('Description (optional):') || '';
    await sets.create({ name, description: desc, stow_packages: [] });
    await loadSets();
    setActiveSet(name);
  };

  const handleDeleteSet = async (name: string) => {
    if (!confirm(`Delete configuration set "${name}"?`)) return;
    await sets.delete(name);
    setCompareSets((prev) => prev.filter((s) => s !== name));
    if (activeSet === name) setActiveSet(null);
    await loadSets();
  };

  const handleAddCompare = (name: string) => {
    if (name !== activeSet && !compareSets.includes(name)) {
      setCompareSets((prev) => [...prev, name]);
    }
  };

  const handleRemoveCompare = (name: string) => {
    setCompareSets((prev) => prev.filter((s) => s !== name));
  };

  const handleToggleGroup = async (setName: string, groupName: string, platform: 'linux' | 'macos_formulae' | 'macos_cask') => {
    const cfg = await sets.get(setName);
    if (platform === 'linux') {
      const groups: string[] = cfg.linux?.groups || [];
      const idx = groups.indexOf(groupName);
      if (idx >= 0) groups.splice(idx, 1);
      else groups.push(groupName);
      cfg.linux = { groups };
    } else if (platform === 'macos_formulae') {
      const groups: string[] = cfg.macos?.formulae_groups || [];
      const idx = groups.indexOf(groupName);
      if (idx >= 0) groups.splice(idx, 1);
      else groups.push(groupName);
      cfg.macos = { ...cfg.macos, formulae_groups: groups };
    } else if (platform === 'macos_cask') {
      const cGroups: string[] = cfg.macos?.cask_groups || [];
      const fGroups: string[] = cfg.macos?.formulae_groups || [];
      const inCask = cGroups.indexOf(groupName);
      const inFormulae = fGroups.indexOf(groupName);
      if (inCask >= 0) {
        // Remove from cask, add to formulae
        cGroups.splice(inCask, 1);
        if (inFormulae < 0) fGroups.push(groupName);
      } else {
        // Move from formulae to cask
        if (inFormulae >= 0) fGroups.splice(inFormulae, 1);
        cGroups.push(groupName);
      }
      cfg.macos = { ...cfg.macos, formulae_groups: fGroups, cask_groups: cGroups };
    }
    await sets.update(setName, cfg);
    // Refresh comparison
    const allNames = [activeSet!, ...compareSets];
    setComparison(await sets.compare(allNames));
    if (setName === activeSet) setSetConfig(await sets.get(setName));
  };

  return (
    <div className="space-y-4">
      <SetSelector
        sets={setList}
        activeSet={activeSet}
        compareSets={compareSets}
        onSelectActive={setActiveSet}
        onAddCompare={handleAddCompare}
        onRemoveCompare={handleRemoveCompare}
        onCreate={handleCreateSet}
        onDelete={handleDeleteSet}
      />
      {comparison && activeSet && (
        <PackageTable
          comparison={comparison}
          activeSet={activeSet}
          onToggleGroup={handleToggleGroup}
        />
      )}
    </div>
  );
}
