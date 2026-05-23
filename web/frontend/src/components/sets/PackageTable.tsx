import { useState } from 'react';

interface PkgSetInfo {
  linux: boolean;
  macos: string | false; // "formula" | "cask" | false
}

interface Package {
  name: string;
  sets: Record<string, PkgSetInfo>;
}

interface Group {
  name: string;
  description: string;
  packages: Package[];
}

interface Comparison {
  sets: string[];
  groups: Group[];
}

interface Props {
  comparison: Comparison;
  activeSet: string;
  onToggleGroup: (setName: string, groupName: string, platform: 'linux' | 'macos_formulae' | 'macos_cask') => void;
}

export default function PackageTable({ comparison, activeSet, onToggleGroup }: Props) {
  const [collapsed, setCollapsed] = useState<Record<string, boolean>>({});

  const toggleCollapse = (group: string) => {
    setCollapsed((prev) => ({ ...prev, [group]: !prev[group] }));
  };

  // Determine per-group platform status for each set
  const groupPlatforms = (group: Group, setName: string) => {
    const pkgs = group.packages;
    if (pkgs.length === 0) return { linux: false, macos: false as string | false };
    // Use first base package to determine group-level platform status
    const first = pkgs[0];
    const info = first.sets[setName];
    if (!info) return { linux: false, macos: false as string | false };
    return { linux: info.linux, macos: info.macos };
  };

  return (
    <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 border-b border-gray-200">
              <th className="text-left px-3 py-2 font-medium text-gray-600 w-48">Group</th>
              <th className="text-left px-3 py-2 font-medium text-gray-600 w-48">Package</th>
              {comparison.sets.map((setName) => (
                <th key={setName} colSpan={2} className="text-center px-1 py-2 font-medium text-gray-600 border-l border-gray-200">
                  <span className={setName === activeSet ? 'text-blue-600' : 'text-purple-600'}>
                    {setName}
                  </span>
                </th>
              ))}
            </tr>
            <tr className="bg-gray-50 border-b border-gray-200 text-xs text-gray-500">
              <th></th>
              <th></th>
              {comparison.sets.map((setName) => (
                <Fragment key={setName}>
                  <th className="px-1 py-1 font-medium border-l border-gray-200 w-24 text-center">Linux</th>
                  <th className="px-1 py-1 font-medium w-28 text-center">macOS</th>
                </Fragment>
              ))}
            </tr>
          </thead>
          <tbody>
            {comparison.groups.map((group) => {
              const isCollapsed = collapsed[group.name];
              return (
                <GroupRows
                  key={group.name}
                  group={group}
                  sets={comparison.sets}
                  activeSet={activeSet}
                  isCollapsed={isCollapsed}
                  onToggleCollapse={() => toggleCollapse(group.name)}
                  onToggleGroup={onToggleGroup}
                  groupPlatforms={groupPlatforms}
                />
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

// Need Fragment import
import { Fragment } from 'react';

interface GroupRowsProps {
  group: Group;
  sets: string[];
  activeSet: string;
  isCollapsed: boolean;
  onToggleCollapse: () => void;
  onToggleGroup: (setName: string, groupName: string, platform: 'linux' | 'macos_formulae' | 'macos_cask') => void;
  groupPlatforms: (group: Group, setName: string) => { linux: boolean; macos: string | false };
}

function GroupRows({ group, sets, activeSet, isCollapsed, onToggleCollapse, onToggleGroup, groupPlatforms }: GroupRowsProps) {
  return (
    <>
      {/* Group header row */}
      <tr className="bg-gray-100 border-t border-gray-200 cursor-pointer hover:bg-gray-150" onClick={onToggleCollapse}>
        <td className="px-3 py-1.5 font-medium text-gray-700 text-xs" colSpan={2}>
          <span className="mr-1 text-gray-400">{isCollapsed ? '▸' : '▾'}</span>
          {group.name}
          <span className="ml-2 text-gray-400 font-normal">{group.description}</span>
          <span className="ml-2 text-gray-400 font-normal">({group.packages.length})</span>
        </td>
        {sets.map((setName) => {
          const plat = groupPlatforms(group, setName);
          return (
            <Fragment key={setName}>
              <td className="px-1 py-1.5 text-center border-l border-gray-200">
                <button
                  onClick={(e) => { e.stopPropagation(); onToggleGroup(setName, group.name, 'linux'); }}
                  className={`w-5 h-5 rounded text-xs ${
                    plat.linux
                      ? 'bg-green-100 text-green-700 hover:bg-green-200'
                      : 'bg-gray-200 text-gray-400 hover:bg-gray-300'
                  }`}
                  title={plat.linux ? 'Remove group from Linux' : 'Add group to Linux'}
                >
                  {plat.linux ? '✓' : '·'}
                </button>
              </td>
              <td className="px-1 py-1.5 text-center">
                <div className="flex items-center justify-center gap-1">
                  <button
                    onClick={(e) => { e.stopPropagation(); onToggleGroup(setName, group.name, 'macos_formulae'); }}
                    className={`w-5 h-5 rounded text-xs ${
                      plat.macos
                        ? 'bg-green-100 text-green-700 hover:bg-green-200'
                        : 'bg-gray-200 text-gray-400 hover:bg-gray-300'
                    }`}
                    title={plat.macos ? 'Remove group from macOS' : 'Add group to macOS as formulae'}
                  >
                    {plat.macos ? '✓' : '·'}
                  </button>
                  {plat.macos && (
                    <button
                      onClick={(e) => { e.stopPropagation(); onToggleGroup(setName, group.name, 'macos_cask'); }}
                      className={`text-[10px] px-1 rounded ${
                        plat.macos === 'cask'
                          ? 'bg-amber-100 text-amber-700 hover:bg-amber-200'
                          : 'bg-gray-100 text-gray-400 hover:bg-gray-200'
                      }`}
                      title={plat.macos === 'cask' ? 'Switch to formula' : 'Switch to cask'}
                    >
                      cask
                    </button>
                  )}
                </div>
              </td>
            </Fragment>
          );
        })}
      </tr>
      {/* Package rows */}
      {!isCollapsed && group.packages.map((pkg) => (
        <tr key={pkg.name} className="border-t border-gray-50 hover:bg-gray-50">
          <td className="px-3 py-1 text-gray-300 text-xs"></td>
          <td className="px-3 py-1 font-mono text-xs text-gray-700">{pkg.name}</td>
          {sets.map((setName) => {
            const info = pkg.sets[setName];
            if (!info) return (
              <Fragment key={setName}>
                <td className="px-1 py-1 text-center border-l border-gray-100"></td>
                <td className="px-1 py-1 text-center"></td>
              </Fragment>
            );
            return (
              <Fragment key={setName}>
                <td className={`px-1 py-1 text-center border-l border-gray-100 font-mono text-xs ${
                  info.linux ? 'text-gray-600' : 'text-gray-200'
                }`}>
                  {info.linux ? pkg.name : ''}
                </td>
                <td className={`px-1 py-1 text-center font-mono text-xs ${
                  info.macos ? 'text-gray-600' : 'text-gray-200'
                }`}>
                  {info.macos ? (
                    <span>
                      {pkg.name}
                      {info.macos === 'cask' && (
                        <span className="ml-1 text-[9px] text-amber-600 font-sans">cask</span>
                      )}
                    </span>
                  ) : ''}
                </td>
              </Fragment>
            );
          })}
        </tr>
      ))}
    </>
  );
}
