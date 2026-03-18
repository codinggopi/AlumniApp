import React from "react";

export function SectionTitle({ title, subtitle }) {
  return (
    <>
      <h2 className="section-title">{title}</h2>
      {subtitle ? <p className="section-subtitle">{subtitle}</p> : null}
    </>
  );
}
