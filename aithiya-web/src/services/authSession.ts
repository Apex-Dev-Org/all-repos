"use client";

const ACCESS_TOKEN_KEYS = ["auth_token", "authToken", "token"];
const REFRESH_TOKEN_KEY = "auth_refresh_token";
const EXPIRES_AT_KEY = "auth_expires_at";
const USER_KEY = "auth_user";
const REFRESH_WINDOW_MS = 60_000;

export type StoredUser = {
  name?: string;
  email?: string;
};

export type AuthPayloadFallback = {
  email?: string;
  password?: string;
  name?: string;
};

export type SupabaseAuthPayload = {
  access_token?: string;
  token?: string;
  jwt?: string;
  refresh_token?: string;
  expires_in?: number;
  expires_at?: number;
  user?: unknown;
};

let refreshPromise: Promise<string | undefined> | undefined;

function storage() {
  if (typeof window === "undefined") return null;
  return window.localStorage;
}

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null ? (value as Record<string, unknown>) : {};
}

function stringOrUndefined(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

export function pickAccessToken(data: SupabaseAuthPayload) {
  return data.access_token ?? data.token ?? data.jwt;
}

export function pickStoredUser(
  data: SupabaseAuthPayload,
  fallback?: AuthPayloadFallback
): StoredUser {
  const user = asRecord(data.user);
  const metadata = asRecord(user.user_metadata);
  const email = stringOrUndefined(user.email) ?? fallback?.email ?? "";
  const name =
    stringOrUndefined(metadata.full_name) ??
    stringOrUndefined(metadata.name) ??
    fallback?.name ??
    (email || "Aythiya User");

  return { name, email };
}

function resolveExpiresAtMs(data: SupabaseAuthPayload) {
  if (typeof data.expires_at === "number" && Number.isFinite(data.expires_at)) {
    return data.expires_at > 1_000_000_000_000 ? data.expires_at : data.expires_at * 1000;
  }

  if (typeof data.expires_in === "number" && Number.isFinite(data.expires_in)) {
    return Date.now() + data.expires_in * 1000;
  }

  return undefined;
}

function setAccessToken(token: string) {
  storage()?.setItem(ACCESS_TOKEN_KEYS[0], token);
}

export function getStoredAccessToken() {
  const localStorage = storage();
  if (!localStorage) return undefined;

  for (const key of ACCESS_TOKEN_KEYS) {
    const token = localStorage.getItem(key);
    if (token) return token;
  }

  return undefined;
}

export function getStoredRefreshToken() {
  return storage()?.getItem(REFRESH_TOKEN_KEY) ?? undefined;
}

export function setStoredUser(user: StoredUser) {
  storage()?.setItem(USER_KEY, JSON.stringify(user));
}

export function getStoredUser(): StoredUser | undefined {
  const raw = storage()?.getItem(USER_KEY);
  if (!raw) return undefined;

  try {
    return JSON.parse(raw) as StoredUser;
  } catch {
    return undefined;
  }
}

export function clearAuthStorage() {
  const localStorage = storage();
  if (!localStorage) return;

  ACCESS_TOKEN_KEYS.forEach((key) => localStorage.removeItem(key));
  localStorage.removeItem(REFRESH_TOKEN_KEY);
  localStorage.removeItem(EXPIRES_AT_KEY);
  localStorage.removeItem(USER_KEY);
}

export function storeAuthSession(
  data: SupabaseAuthPayload,
  fallback?: AuthPayloadFallback
) {
  const localStorage = storage();
  const token = pickAccessToken(data);
  if (!localStorage || !token) return token;

  setAccessToken(token);

  if (data.refresh_token) {
    localStorage.setItem(REFRESH_TOKEN_KEY, data.refresh_token);
  }

  const expiresAtMs = resolveExpiresAtMs(data);
  if (expiresAtMs) {
    localStorage.setItem(EXPIRES_AT_KEY, String(expiresAtMs));
  }

  if (data.user || fallback) {
    setStoredUser(pickStoredUser(data, fallback));
  }

  return token;
}

function getExpiresAtMs() {
  const raw = storage()?.getItem(EXPIRES_AT_KEY);
  if (!raw) return undefined;

  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : undefined;
}

function shouldRefreshSession() {
  const expiresAtMs = getExpiresAtMs();
  return Boolean(expiresAtMs && Date.now() + REFRESH_WINDOW_MS >= expiresAtMs);
}

async function refreshAuthSession() {
  const refreshToken = getStoredRefreshToken();
  if (!refreshToken) {
    if (Date.now() >= (getExpiresAtMs() ?? Number.POSITIVE_INFINITY)) {
      clearAuthStorage();
      return undefined;
    }
    return getStoredAccessToken();
  }

  const response = await fetch("/api/auth/refresh", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken }),
  });

  const data = (await response.json().catch(() => ({}))) as SupabaseAuthPayload & {
    error?: string;
  };

  if (!response.ok) {
    clearAuthStorage();
    throw new Error(data.error ?? "Could not refresh Supabase session.");
  }

  const token = storeAuthSession(data);
  if (!token) {
    clearAuthStorage();
    throw new Error("Refresh response did not include an access token.");
  }

  return token;
}

export async function getValidAccessToken() {
  const token = getStoredAccessToken();
  if (!token) return undefined;
  if (!shouldRefreshSession()) return token;

  refreshPromise ??= refreshAuthSession().finally(() => {
    refreshPromise = undefined;
  });

  try {
    return await refreshPromise;
  } catch {
    return undefined;
  }
}
