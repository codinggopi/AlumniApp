import { API_BASE_URL } from "./config";

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
    ...options,
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    throw new Error(data?.detail || "Request failed");
  }

  return data;
}

export async function sendOtp(email) {
  return request("/send-otp", {
    method: "POST",
    body: JSON.stringify({ email }),
  });
}

export async function verifyOtp(payload) {
  return request("/verify-otp", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function fetchAlumni(filters = {}) {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value) {
      query.append(key, value);
    }
  });
  const queryString = query.toString();
  return request(`/alumni${queryString ? `?${queryString}` : ""}`);
}

export async function fetchInternships(filters = {}) {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value) {
      query.append(key, value);
    }
  });
  const queryString = query.toString();
  return request(`/internships${queryString ? `?${queryString}` : ""}`);
}

export async function createInternship(payload) {
  return request("/internships", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function applyToInternship(payload) {
  return request("/applications", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function fetchEvents() {
  return request("/events");
}

export async function createEvent(payload) {
  return request("/events", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}
