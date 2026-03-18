import React from "react";

import { Panel } from "../components/Panel";
import { PrimaryButton } from "../components/PrimaryButton";
import { SectionTitle } from "../components/SectionTitle";

export function DashboardScreen({ session, onLogout }) {
  return (
    <div className="screen-stack">
      <Panel tone="warm">
        <SectionTitle
          title={`Welcome, ${session.full_name}`}
          subtitle="This first web version is wired to your FastAPI backend and ready for the main MVP flows."
        />
        <p className="copy">Role: {session.role}</p>
        <p className="copy">Use the tabs below to browse alumni, internships, and events.</p>
      </Panel>

      <Panel>
        <h3 className="panel-heading">MVP Modules</h3>
        <div className="metrics-grid">
          <article className="metric-box"><strong>3</strong><span>Roles</span></article>
          <article className="metric-box"><strong>8</strong><span>Tables</span></article>
          <article className="metric-box"><strong>5</strong><span>Flows</span></article>
        </div>
      </Panel>

      <Panel>
        <h3 className="panel-heading">Next Frontend Areas</h3>
        <p className="copy">Connection requests and chat</p>
        <p className="copy">Profile editing and resume upload</p>
        <p className="copy">Admin posting workflows with forms</p>
        <div className="button-row">
          <PrimaryButton title="Logout" onClick={onLogout} tone="secondary" />
        </div>
      </Panel>
    </div>
  );
}
