import React from "react";

export function FormField({
  label,
  value,
  onChange,
  placeholder,
  type = "text",
  multiline = false,
}) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      {multiline ? (
        <textarea
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder={placeholder}
          className="field-input field-textarea"
        />
      ) : (
        <input
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder={placeholder}
          type={type}
          className="field-input"
        />
      )}
    </label>
  );
}
