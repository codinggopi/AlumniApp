import React, { useEffect, useState } from "react";

import { createEvent, fetchEvents } from "../api/client";
import { FormField } from "../components/FormField";
import { Panel } from "../components/Panel";
import { PrimaryButton } from "../components/PrimaryButton";
import { SectionTitle } from "../components/SectionTitle";

export function EventsScreen({ session }) {
  const [events, setEvents] = useState([]);
  const [title, setTitle] = useState("");
  const [date, setDate] = useState("");
  const [location, setLocation] = useState("");
  const [description, setDescription] = useState("");
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const loadEvents = async () => {
    try {
      setLoading(true);
      const data = await fetchEvents();
      setEvents(data);
    } catch (error) {
      window.alert(`Load failed: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadEvents();
  }, []);

  const handleCreate = async () => {
    try {
      setSubmitting(true);
      await createEvent({
        created_by: session.user_id,
        title,
        date,
        location,
        description,
      });
      setTitle("");
      setDate("");
      setLocation("");
      setDescription("");
      await loadEvents();
      window.alert("Event created");
    } catch (error) {
      window.alert(`Create failed: ${error.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  const isAdmin = session.role === "admin";

  return (
    <div className="screen-stack">
      {isAdmin ? (
        <Panel tone="warm">
          <SectionTitle title="Post Event" subtitle="Admins can publish meetups, workshops, and announcements." />
          <FormField label="Title" value={title} onChange={setTitle} placeholder="Alumni Meetup 2026" />
          <FormField label="Date" value={date} onChange={setDate} placeholder="2026-04-02" />
          <FormField label="Location" value={location} onChange={setLocation} placeholder="Main Auditorium" />
          <FormField label="Description" value={description} onChange={setDescription} placeholder="Event details" multiline />
          <PrimaryButton title="Create Event" onClick={handleCreate} loading={submitting} />
        </Panel>
      ) : null}

      <Panel>
        <SectionTitle
          title="Events and Announcements"
          subtitle={loading ? "Loading latest posts..." : "Updates visible to all users."}
        />
      </Panel>

      {events.map((item) => (
        <Panel key={item.event_id}>
          <h3 className="card-title">{item.title}</h3>
          <p className="meta">{item.date || "Date TBA"} | {item.location || "Location TBA"}</p>
          <p className="copy">{item.description || "No description yet."}</p>
        </Panel>
      ))}

      {!events.length ? <p className="empty-state">No events yet. Admins can post the first announcement.</p> : null}
    </div>
  );
}
