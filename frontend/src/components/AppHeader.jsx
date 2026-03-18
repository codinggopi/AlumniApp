import React from "react";

export function AppHeader({ session }) {
  return (
    <header className="header">
      <p className="eyebrow">Institution Network</p>
      <h1 className="header-title">Alumni App</h1>
      <p className="header-subtitle">
        {session
          ? `${session.full_name} | ${session.role}`
          : "Mentorship, internships, and alumni connections"}
      </p>
    </header>
  );
}
