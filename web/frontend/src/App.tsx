import { useState } from 'react';
import StowPackagesPage from './pages/StowPackagesPage';
import ConfigSetsPage from './pages/ConfigSetsPage';

const tabs = ['Stow Packages', 'Configuration Sets'] as const;
type Tab = (typeof tabs)[number];

export default function App() {
  const [activeTab, setActiveTab] = useState<Tab>('Configuration Sets');

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      <header className="bg-white border-b border-gray-200 px-6 py-3">
        <h1 className="text-xl font-semibold">Dotfiles Config Manager</h1>
      </header>
      <nav className="bg-white border-b border-gray-200 px-6">
        <div className="flex gap-0">
          {tabs.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
                activeTab === tab
                  ? 'border-blue-600 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {tab}
            </button>
          ))}
        </div>
      </nav>
      <main className="p-6">
        {activeTab === 'Stow Packages' && <StowPackagesPage />}
        {activeTab === 'Configuration Sets' && <ConfigSetsPage />}
      </main>
    </div>
  );
}
