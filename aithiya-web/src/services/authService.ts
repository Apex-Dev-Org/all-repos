"use client";

import { ApiHttpError, chatService } from "./chatService";
import {
  clearAuthStorage,
  getStoredAccessToken,
  getStoredUser,
  getValidAccessToken,
  pickStoredUser,
  setStoredUser,
  storeAuthSession,
  type StoredUser,
  type SupabaseAuthPayload,
} from "./authSession";

type AuthPayload = {
  email: string;
  password: string;
  name?: string;
};

type ResetPasswordPayload = {
  email: string;
};

type UpdatePasswordPayload = {
  accessToken: string;
  password: string;
};

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null ? (value as Record<string, unknown>) : {};
}

async function postAuth(path: string, payload: AuthPayload) {
  const response = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    throw new Error(data.error ?? `Auth failed: ${response.status}`);
  }

  return response.json() as Promise<SupabaseAuthPayload>;
}

async function postJson<TPayload extends Record<string, unknown>>(
  path: string,
  payload: TPayload
) {
  const response = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    throw new Error(data.error ?? `Request failed: ${response.status}`);
  }

  return response.json();
}

export const authService = {
  getToken() {
    return getStoredAccessToken();
  },

  setToken(token: string) {
    storeAuthSession({ access_token: token });
  },

  setUser(user: StoredUser) {
    setStoredUser(user);
  },

  getUser(): StoredUser | undefined {
    return getStoredUser();
  },

  clearToken() {
    clearAuthStorage();
  },

  signOut() {
    this.clearToken();
  },

  signInWithGoogle(next = "/chat") {
    if (typeof window === "undefined") return;

    const path = getSafeNextPath(next) ?? "/chat";
    const target = new URL("/api/auth/google", window.location.origin);
    target.searchParams.set("next", path);
    window.location.assign(target.toString());
  },

  isAuthenticated() {
    return Boolean(this.getToken());
  },

  async completeOAuthSession(payload: SupabaseAuthPayload) {
    const token = storeAuthSession(payload);
    if (!token) throw new Error("No token returned from auth provider.");
    await this.refreshProfileFromApi();
  },

  async refreshProfileFromApi() {
    try {
      const me = await chatService.getMe();
      mergeUserFromMe(asRecord(me));
    } catch (e) {
      if (e instanceof ApiHttpError && (e.status === 401 || e.status === 403)) {
        this.signOut();
        throw e;
      }
      console.warn("Could not sync /auth/me", e);
    }
  },

  async login(payload: AuthPayload) {
    const data = await postAuth("/api/auth/login", payload);
    const token = storeAuthSession(data, payload);
    if (!token) throw new Error("No token returned from auth provider.");
    await this.refreshProfileFromApi();
    return data;
  },

  async register(payload: AuthPayload) {
    const data = await postAuth("/api/auth/register", payload);
    const token = storeAuthSession(data, payload);
    if (!token) {
      throw new Error(
        "Account created, but no session token was returned. Please confirm the email and sign in."
      );
    }
    await this.refreshProfileFromApi();
    return data;
  },

  async requestPasswordReset(payload: ResetPasswordPayload) {
    return postJson("/api/auth/forgot-password", payload);
  },

  async updatePassword(payload: UpdatePasswordPayload) {
    return postJson("/api/auth/reset-password", payload);
  },

  async updateDisplayName(name: string) {
    const token = await getValidAccessToken();
    if (!token) throw new Error("Not signed in.");

    const response = await fetch("/api/auth/update-profile", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ name }),
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      if (response.status === 401 || response.status === 403) {
        this.signOut();
      }
      throw new Error(
        typeof data.error === "string" ? data.error : "Could not update profile."
      );
    }

    const userPayload =
      typeof data === "object" && data !== null && "user" in data
        ? (data as { user?: unknown }).user
        : data;

    this.setUser(
      pickStoredUser({ user: userPayload } as SupabaseAuthPayload, {
        email: this.getUser()?.email ?? "",
        password: "",
      })
    );

    await this.refreshProfileFromApi().catch(() => {});
  },
};

function getSafeNextPath(next: string) {
  if (!next || !next.startsWith("/") || next.startsWith("//")) {
    return undefined;
  }

  return next;
}

function mergeUserFromMe(me: Record<string, unknown>) {
  const existing = authService.getUser() ?? {};

  const nested =
    typeof me.user === "object" && me.user !== null
      ? asRecord(me.user)
      : me;

  const email = String(nested.email ?? me.email ?? existing.email ?? "");

  const meta =
    typeof nested.user_metadata === "object" && nested.user_metadata !== null
      ? asRecord(nested.user_metadata)
      : {};

  const name = String(
    nested.full_name ??
      nested.name ??
      nested.display_name ??
      meta.full_name ??
      meta.name ??
      existing.name ??
      (email || "Aythiya User")
  );

  authService.setUser({ name, email });
}
