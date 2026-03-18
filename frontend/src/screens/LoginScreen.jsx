import React, { useState } from "react";

import { FormField } from "../components/FormField";
import { Panel } from "../components/Panel";
import { PrimaryButton } from "../components/PrimaryButton";
import { SectionTitle } from "../components/SectionTitle";

const ROLE_CARDS = [
  {
    key: "admin",
    title: "Admin",
    icon: "🛡️",
    authIcon: "🧭",
    description: "Manage events, announcements, and user operations for the platform.",
  },
  {
    key: "alumni",
    title: "Alumni",
    icon: "🤝",
    authIcon: "💼",
    description: "Post internships, mentor students, and build meaningful alumni connections.",
  },
  {
    key: "student",
    title: "Student",
    icon: "📘",
    authIcon: "🎓",
    description: "Discover alumni, apply for internships, and grow your professional network.",
  },
];

export function LoginScreen({ onAuthenticated }) {
  const [role, setRole] = useState("");
  const [passwordResetMode, setPasswordResetMode] = useState(false);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const [resetEmail, setResetEmail] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");

  const selectedRole = ROLE_CARDS.find((item) => item.key === role);
  const showRoleSelection = !role;

  const resetAuthForm = () => {
    setPasswordResetMode(false);
    setEmail("");
    setPassword("");
    setResetEmail("");
    setNewPassword("");
    setConfirmPassword("");
  };

  const handleRoleSelect = (nextRole) => {
    setRole(nextRole);
    resetAuthForm();
  };

  const handleBackToRoles = () => {
    setRole("");
    resetAuthForm();
  };

  const handleRoleLogin = () => {
    if (!email || !password) {
      window.alert("Please enter both email and password.");
      return;
    }

    onAuthenticated({
      user_id: 0,
      full_name: selectedRole?.title || "User",
      role,
      email,
    });
  };

  const handleResetPassword = () => {
    if (!resetEmail || !newPassword || !confirmPassword) {
      window.alert("Please complete all reset password fields.");
      return;
    }

    if (newPassword !== confirmPassword) {
      window.alert("New password and confirm password do not match.");
      return;
    }

    window.alert("Password reset request submitted.");
    setPasswordResetMode(false);
    setEmail(resetEmail);
    setPassword("");
    setNewPassword("");
    setConfirmPassword("");
  };

  if (showRoleSelection) {
    return (
      <div className="login-frame">
        <section className="role-hero">
          <div className="role-badge" aria-hidden="true">
            <span>🎓</span>
          </div>
          <h1 className="role-title">Alumni App</h1>
          <p className="role-subtitle">
            The smart and focused way to connect students, alumni, and campus admins.
          </p>
        </section>

        <section className="role-selector">
          <h2 className="role-selector-title">Select Your Role</h2>
          <div className="role-grid">
            {ROLE_CARDS.map((card) => {
              const active = card.key === role;
              return (
                <button
                  key={card.key}
                  type="button"
                  className={`role-card role-card-${card.key} ${active ? "role-card-active" : ""}`}
                  onClick={() => handleRoleSelect(card.key)}
                >
                  <div className="role-card-icon" aria-hidden="true">
                    {card.icon}
                  </div>
                  <h3>{card.title}</h3>
                  <p>{card.description}</p>
                </button>
              );
            })}
          </div>
        </section>
      </div>
    );
  }

  return (
    <div className="login-frame">
      <Panel tone="warm">
        <div className="auth-step-head">
          <button type="button" className="back-link" onClick={handleBackToRoles}>
            {"<- Change role"}
          </button>
          <SectionTitle
            title={`${selectedRole?.title} Login`}
            subtitle={
              passwordResetMode
                ? `Reset your ${selectedRole?.title?.toLowerCase()} password securely.`
                : `Use your ${selectedRole?.title?.toLowerCase()} email and password to sign in.`
            }
          />
        </div>

        <div className={`role-auth-card role-auth-${role}`}>
          <div className="auth-icon-chip" aria-hidden="true">
            {passwordResetMode ? "🔐" : selectedRole?.authIcon}
          </div>

          {!passwordResetMode ? (
            <>
              <FormField
                label={`${selectedRole?.title} Email`}
                value={email}
                onChange={setEmail}
                placeholder={`${selectedRole?.key}@college.edu`}
                type="email"
              />
              <FormField
                label="Password"
                value={password}
                onChange={setPassword}
                placeholder="Enter password"
                type="password"
              />
              <div className="role-auth-actions">
                <PrimaryButton title="Login" onClick={handleRoleLogin} />
                <button
                  type="button"
                  className="text-link-button"
                  onClick={() => {
                    setPasswordResetMode(true);
                    setResetEmail(email);
                  }}
                >
                  Forgot password?
                </button>
              </div>
            </>
          ) : (
            <>
              <h3 className="panel-heading">Reset Password</h3>
              <FormField
                label={`${selectedRole?.title} Email`}
                value={resetEmail}
                onChange={setResetEmail}
                placeholder={`${selectedRole?.key}@college.edu`}
                type="email"
              />
              <FormField
                label="New Password"
                value={newPassword}
                onChange={setNewPassword}
                placeholder="Enter new password"
                type="password"
              />
              <FormField
                label="Confirm New Password"
                value={confirmPassword}
                onChange={setConfirmPassword}
                placeholder="Re-enter new password"
                type="password"
              />
              <div className="role-auth-actions">
                <PrimaryButton title="Reset Password" onClick={handleResetPassword} />
                <button
                  type="button"
                  className="text-link-button"
                  onClick={() => setPasswordResetMode(false)}
                >
                  Back to login
                </button>
              </div>
            </>
          )}
        </div>
      </Panel>
    </div>
  );
}
