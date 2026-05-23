interface FileEntry {
  path: string;
  target: string;
  size: number;
}

interface Props {
  packageName: string;
  files: FileEntry[];
  activeFile: string | null;
  onOpen: (path: string) => void;
  onDelete: (path: string) => void;
  onCreate: () => void;
}

export default function FileBrowser({ packageName, files, activeFile, onOpen, onDelete, onCreate }: Props) {
  return (
    <div className="bg-white border border-gray-200 rounded-lg flex-shrink-0 max-h-[40%] flex flex-col">
      <div className="p-3 border-b border-gray-200 flex items-center justify-between">
        <span className="text-sm font-medium text-gray-700">
          Files in <span className="font-mono text-blue-600">{packageName}/</span>
        </span>
        <button
          onClick={onCreate}
          className="text-xs bg-green-600 text-white px-2 py-1 rounded hover:bg-green-700"
        >
          + New File
        </button>
      </div>
      <div className="overflow-y-auto flex-1">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-xs text-gray-500 border-b border-gray-100">
              <th className="text-left px-3 py-1.5 font-medium">Source</th>
              <th className="text-left px-3 py-1.5 font-medium">Target</th>
              <th className="w-8"></th>
            </tr>
          </thead>
          <tbody>
            {files.map((f) => (
              <tr
                key={f.path}
                className={`group cursor-pointer border-b border-gray-50 ${
                  activeFile === f.path ? 'bg-blue-50' : 'hover:bg-gray-50'
                }`}
                onClick={() => onOpen(f.path)}
              >
                <td className="px-3 py-1.5 font-mono text-xs">{f.path}</td>
                <td className="px-3 py-1.5 font-mono text-xs text-gray-400">{f.target}</td>
                <td className="px-1">
                  <button
                    onClick={(e) => { e.stopPropagation(); onDelete(f.path); }}
                    className="opacity-0 group-hover:opacity-100 text-red-400 hover:text-red-600 text-xs"
                    title="Delete file"
                  >
                    ✕
                  </button>
                </td>
              </tr>
            ))}
            {files.length === 0 && (
              <tr>
                <td colSpan={3} className="px-3 py-4 text-center text-gray-400 text-xs">
                  Empty package. Click "+ New File" to add files.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
