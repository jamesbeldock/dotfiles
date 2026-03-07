interface Props {
  sets: { name: string; description: string }[];
  activeSet: string | null;
  compareSets: string[];
  onSelectActive: (name: string) => void;
  onAddCompare: (name: string) => void;
  onRemoveCompare: (name: string) => void;
  onCreate: () => void;
  onDelete: (name: string) => void;
}

export default function SetSelector({
  sets, activeSet, compareSets, onSelectActive, onAddCompare, onRemoveCompare, onCreate, onDelete,
}: Props) {
  const availableForCompare = sets.filter(
    (s) => s.name !== activeSet && !compareSets.includes(s.name)
  );

  return (
    <div className="bg-white border border-gray-200 rounded-lg p-4">
      <div className="flex items-center gap-4 flex-wrap">
        <div className="flex items-center gap-2">
          <label className="text-sm font-medium text-gray-600">Active Set:</label>
          <select
            value={activeSet ?? ''}
            onChange={(e) => onSelectActive(e.target.value)}
            className="border border-gray-300 rounded px-3 py-1.5 text-sm bg-white"
          >
            {sets.map((s) => (
              <option key={s.name} value={s.name}>{s.name}</option>
            ))}
          </select>
        </div>

        {compareSets.length > 0 && (
          <div className="flex items-center gap-2">
            <span className="text-sm text-gray-500">Comparing:</span>
            {compareSets.map((name) => (
              <span key={name} className="inline-flex items-center gap-1 bg-purple-100 text-purple-700 px-2 py-0.5 rounded text-xs font-medium">
                {name}
                <button onClick={() => onRemoveCompare(name)} className="hover:text-purple-900">✕</button>
              </span>
            ))}
          </div>
        )}

        {availableForCompare.length > 0 && (
          <select
            value=""
            onChange={(e) => { if (e.target.value) onAddCompare(e.target.value); }}
            className="border border-gray-300 rounded px-2 py-1.5 text-xs bg-white text-gray-500"
          >
            <option value="">+ Compare with...</option>
            {availableForCompare.map((s) => (
              <option key={s.name} value={s.name}>{s.name}</option>
            ))}
          </select>
        )}

        <div className="ml-auto flex gap-2">
          <button
            onClick={onCreate}
            className="text-xs bg-blue-600 text-white px-3 py-1.5 rounded hover:bg-blue-700"
          >
            + New Set
          </button>
          {activeSet && (
            <button
              onClick={() => onDelete(activeSet)}
              className="text-xs bg-red-50 text-red-600 px-3 py-1.5 rounded hover:bg-red-100 border border-red-200"
            >
              Delete Set
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
