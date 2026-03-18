import React from "react";

export function Panel({ children, tone = "light" }) {
  return <section className={`panel ${tone === "warm" ? "panel-warm" : ""}`}>{children}</section>;
}
