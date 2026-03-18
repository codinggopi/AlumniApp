import React, { useMemo, useState } from "react";

import { AppHeader } from "./components/AppHeader";
import { BottomTabs } from "./components/BottomTabs";
import { DashboardScreen } from "./screens/DashboardScreen";
import { LoginScreen } from "./screens/LoginScreen";
import { AlumniScreen } from "./screens/AlumniScreen";
import { InternshipsScreen } from "./screens/InternshipsScreen";
import { EventsScreen } from "./screens/EventsScreen";

const AUTH_TAB = "auth";
const DASHBOARD_TAB = "dashboard";
const ALUMNI_TAB = "alumni";
const INTERNSHIPS_TAB = "internships";
const EVENTS_TAB = "events";

export default function App() {
  const [activeTab, setActiveTab] = useState(AUTH_TAB);
  const [session, setSession] = useState(null);

  const tabs = useMemo(() => {
    if (!session) {
      return [{ key: AUTH_TAB, label: "Login" }];
    }

    return [
      { key: DASHBOARD_TAB, label: "Home" },
      { key: ALUMNI_TAB, label: "Alumni" },
      { key: INTERNSHIPS_TAB, label: "Internships" },
      { key: EVENTS_TAB, label: "Events" },
    ];
  }, [session]);

  const handleLogin = (user) => {
    setSession(user);
    setActiveTab(DASHBOARD_TAB);
  };

  const handleLogout = () => {
    setSession(null);
    setActiveTab(AUTH_TAB);
  };

  const renderScreen = () => {
    if (!session) {
      return <LoginScreen onAuthenticated={handleLogin} />;
    }

    if (activeTab === ALUMNI_TAB) {
      return <AlumniScreen />;
    }

    if (activeTab === INTERNSHIPS_TAB) {
      return <InternshipsScreen session={session} />;
    }

    if (activeTab === EVENTS_TAB) {
      return <EventsScreen session={session} />;
    }

    return <DashboardScreen session={session} onLogout={handleLogout} />;
  };

  return (
    <div className="app-shell">
      {session ? <AppHeader session={session} /> : null}
      <main className="app-content">{renderScreen()}</main>
      {session ? <BottomTabs tabs={tabs} activeTab={activeTab} onTabChange={setActiveTab} /> : null}
    </div>
  );
}
