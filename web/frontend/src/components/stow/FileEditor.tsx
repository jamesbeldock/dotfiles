import { useEffect, useRef, useState } from 'react';
import { EditorState } from '@codemirror/state';
import { EditorView, keymap, lineNumbers, highlightActiveLine, highlightActiveLineGutter } from '@codemirror/view';
import { defaultKeymap, indentWithTab } from '@codemirror/commands';
import { searchKeymap, highlightSelectionMatches } from '@codemirror/search';
import { bracketMatching } from '@codemirror/language';

interface Props {
  path: string;
  content: string;
  onSave: (path: string, content: string) => void;
}

export default function FileEditor({ path, content, onSave }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<EditorView | null>(null);
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    if (!containerRef.current) return;

    const state = EditorState.create({
      doc: content,
      extensions: [
        lineNumbers(),
        highlightActiveLine(),
        highlightActiveLineGutter(),
        bracketMatching(),
        highlightSelectionMatches(),
        keymap.of([...defaultKeymap, indentWithTab, ...searchKeymap]),
        EditorView.updateListener.of((update) => {
          if (update.docChanged) setDirty(true);
        }),
        EditorView.theme({
          '&': { height: '100%', fontSize: '13px' },
          '.cm-scroller': { overflow: 'auto' },
          '.cm-content': { fontFamily: 'ui-monospace, monospace' },
        }),
      ],
    });

    const view = new EditorView({ state, parent: containerRef.current });
    viewRef.current = view;
    setDirty(false);

    return () => { view.destroy(); };
  }, [path, content]);

  const handleSave = () => {
    if (!viewRef.current) return;
    onSave(path, viewRef.current.state.doc.toString());
    setDirty(false);
  };

  return (
    <div className="bg-white border border-gray-200 rounded-lg flex-1 flex flex-col min-h-0">
      <div className="p-3 border-b border-gray-200 flex items-center justify-between">
        <span className="text-sm font-mono text-gray-600">
          {path}
          {dirty && <span className="ml-2 text-amber-500 text-xs">(unsaved)</span>}
        </span>
        <button
          onClick={handleSave}
          disabled={!dirty}
          className={`text-xs px-3 py-1 rounded ${
            dirty
              ? 'bg-blue-600 text-white hover:bg-blue-700'
              : 'bg-gray-100 text-gray-400 cursor-not-allowed'
          }`}
        >
          Save
        </button>
      </div>
      <div ref={containerRef} className="flex-1 min-h-0 overflow-hidden" />
    </div>
  );
}
