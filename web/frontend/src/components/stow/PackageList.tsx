interface Props {
  packages: { name: string; file_count: number; in_catalog: boolean }[];
  selected: string | null;
  onSelect: (name: string) => void;
  onCreate: () => void;
  onDelete: (name: string) => void;
}

export default function PackageList({ packages, selected, onSelect, onCreate, onDelete }: Props) {
  return (
    <div className="w-56 shrink-0 bg-white border border-gray-200 rounded-lg flex flex-col">
      <div className="p-3 border-b border-gray-200 flex items-center justify-between">
        <span className="text-sm font-medium text-gray-700">Stow Packages</span>
        <button
          onClick={onCreate}
          className="text-xs bg-blue-600 text-white px-2 py-1 rounded hover:bg-blue-700"
        >
          + New
        </button>
      </div>
      <div className="overflow-y-auto flex-1">
        {packages.map((pkg) => (
          <div
            key={pkg.name}
            className={`group flex items-center justify-between px-3 py-2 cursor-pointer text-sm border-l-2 ${
              selected === pkg.name
                ? 'bg-blue-50 border-blue-600 text-blue-700'
                : 'border-transparent hover:bg-gray-50'
            }`}
          >
            <div className="flex-1 min-w-0" onClick={() => onSelect(pkg.name)}>
              <div className="truncate">{pkg.name}</div>
              <div className="text-xs text-gray-400">
                {pkg.file_count} file{pkg.file_count !== 1 ? 's' : ''}
                {!pkg.in_catalog && <span className="ml-1 text-amber-500">(not in catalog)</span>}
              </div>
            </div>
            <button
              onClick={(e) => { e.stopPropagation(); onDelete(pkg.name); }}
              className="opacity-0 group-hover:opacity-100 text-red-400 hover:text-red-600 text-xs ml-2"
              title="Delete package"
            >
              ✕
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
