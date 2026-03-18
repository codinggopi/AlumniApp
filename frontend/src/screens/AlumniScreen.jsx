import React, { useState } from "react";

import { fetchAlumni } from "../api/client";
import { FormField } from "../components/FormField";
import { Panel } from "../components/Panel";
import { PrimaryButton } from "../components/PrimaryButton";
import { SectionTitle } from "../components/SectionTitle";

export function AlumniScreen() {
  const [department, setDepartment] = useState("");
  const [company, setCompany] = useState("");
  const [city, setCity] = useState("");
  const [jobTitle, setJobTitle] = useState("");
  const [alumni, setAlumni] = useState([]);
  const [loading, setLoading] = useState(false);

  const handleSearch = async () => {
    try {
      setLoading(true);
      const results = await fetchAlumni({ department, company, city, job_title: jobTitle });
      setAlumni(results);
    } catch (error) {
      window.alert(`Search failed: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="screen-stack">
      <Panel tone="warm">
        <SectionTitle title="Alumni Directory" subtitle="Search by department, company, city, or job title." />
        <FormField label="Department" value={department} onChange={setDepartment} placeholder="CSE" />
        <FormField label="Company" value={company} onChange={setCompany} placeholder="Google" />
        <FormField label="City" value={city} onChange={setCity} placeholder="Bengaluru" />
        <FormField label="Job Title" value={jobTitle} onChange={setJobTitle} placeholder="Product Manager" />
        <PrimaryButton title="Search Alumni" onClick={handleSearch} loading={loading} />
      </Panel>

      {alumni.map((item) => (
        <Panel key={item.user_id}>
          <h3 className="card-title">{item.full_name}</h3>
          <p className="meta">{item.job_title || "Role not added"} at {item.company || "Company not added"}</p>
          <p className="meta">{item.department || "Department"} | {item.city || "City"}</p>
          <p className="copy">{item.bio || "No bio yet."}</p>
        </Panel>
      ))}

      {!alumni.length ? <p className="empty-state">Search results will appear here.</p> : null}
    </div>
  );
}
