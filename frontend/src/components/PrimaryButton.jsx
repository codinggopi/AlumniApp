import React from "react";

export function PrimaryButton({
  title,
  onClick,
  loading = false,
  disabled = false,
  tone = "primary",
  type = "button",
}) {
  const inactive = disabled || loading;

  return (
    <button
      type={type}
      className={`button button-${tone}`}
      onClick={onClick}
      disabled={inactive}
    >
      {loading ? "Please wait..." : title}
    </button>
  );
}
