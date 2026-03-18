import React from "react";

export function BottomTabs({ tabs, activeTab, onTabChange }) {
  return (
    <nav className="tabs">
      {tabs.map((tab) => {
        const active = tab.key === activeTab;
        return (
          <button
            key={tab.key}
            type="button"
            className={`tab ${active ? "tab-active" : ""}`}
            onClick={() => onTabChange(tab.key)}
          >
            {tab.label}
          </button>
        );
      })}
    </nav>
  );
}
