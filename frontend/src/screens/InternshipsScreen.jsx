import React, { useEffect, useState } from "react";

import { applyToInternship, createInternship, fetchInternships } from "../api/client";
import { FormField } from "../components/FormField";
import { Panel } from "../components/Panel";
import { PrimaryButton } from "../components/PrimaryButton";
import { SectionTitle } from "../components/SectionTitle";

export function InternshipsScreen({ session }) {
  const [internships, setInternships] = useState([]);
  const [roleTitle, setRoleTitle] = useState("");
  const [company, setCompany] = useState("");
  const [location, setLocation] = useState("");
  const [stipend, setStipend] = useState("");
  const [description, setDescription] = useState("");
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const loadInternships = async () => {
    try {
      setLoading(true);
      const data = await fetchInternships();
      setInternships(data);
    } catch (error) {
      window.alert(`Load failed: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadInternships();
  }, []);

  const handleCreate = async () => {
    try {
      setSubmitting(true);
      await createInternship({
        posted_by: session.user_id,
        role_title: roleTitle,
        company,
        location,
        stipend,
        description,
      });
      setRoleTitle("");
      setCompany("");
      setLocation("");
      setStipend("");
      setDescription("");
      await loadInternships();
      window.alert("Internship created");
    } catch (error) {
      window.alert(`Create failed: ${error.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleApply = async (internshipId) => {
    try {
      await applyToInternship({
        internship_id: internshipId,
        student_id: session.user_id,
        cover_note: "Interested in contributing and learning through this opportunity.",
      });
      window.alert("Your application has been submitted.");
    } catch (error) {
      window.alert(`Apply failed: ${error.message}`);
    }
  };

  const isAlumni = session.role === "alumni";
  const isStudent = session.role === "student";

  return (
    <div className="screen-stack">
      {isAlumni ? (
        <Panel tone="warm">
          <SectionTitle title="Post Internship" subtitle="Alumni can publish new opportunities from the web app." />
          <FormField label="Role Title" value={roleTitle} onChange={setRoleTitle} placeholder="Frontend Intern" />
          <FormField label="Company" value={company} onChange={setCompany} placeholder="Microsoft" />
          <FormField label="Location" value={location} onChange={setLocation} placeholder="Hybrid" />
          <FormField label="Stipend" value={stipend} onChange={setStipend} placeholder="15000 / month" />
          <FormField label="Description" value={description} onChange={setDescription} placeholder="Role details" multiline />
          <PrimaryButton title="Create Internship" onClick={handleCreate} loading={submitting} />
        </Panel>
      ) : null}

      <Panel>
        <div className="button-stack">
          <SectionTitle title="Open Internships" subtitle="Pulled directly from your backend API." />
          <PrimaryButton title={loading ? "Loading..." : "Refresh"} onClick={loadInternships} disabled={loading} tone="secondary" />
        </div>
      </Panel>

      {internships.map((item) => (
        <Panel key={item.internship_id}>
          <h3 className="card-title">{item.role_title}</h3>
          <p className="meta">{item.company} | {item.location || "Location TBA"}</p>
          <p className="meta">Stipend: {item.stipend || "Not specified"}</p>
          <p className="copy">{item.description || "No description added yet."}</p>
          {isStudent ? (
            <div className="button-row">
              <PrimaryButton title="Apply" onClick={() => handleApply(item.internship_id)} />
            </div>
          ) : null}
        </Panel>
      ))}

      {!internships.length ? <p className="empty-state">No internships yet. Alumni can post the first one.</p> : null}
    </div>
  );
}
