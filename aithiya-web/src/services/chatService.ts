import { ChatSession, Message, MessageAttachment } from "../types/chat";
import { getValidAccessToken } from "./authSession";

const DEFAULT_API_BASE_URL = "/api/backend";
const API_BASE_URL = envOrDefault(process.env.NEXT_PUBLIC_API_BASE_URL, DEFAULT_API_BASE_URL);
const STATIC_AUTH_TOKEN = trimmedEnv(process.env.NEXT_PUBLIC_AUTH_TOKEN);

type ApiRecord = Record<string, unknown>;

export class ApiHttpError extends Error {
  readonly status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiHttpError";
    this.status = status;
  }
}

const nowTime = () =>
  new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

function getAuthToken() {
  if (typeof window === "undefined") return STATIC_AUTH_TOKEN;

  return getValidAccessToken();
}

async function authHeaders(path: string): Promise<Record<string, string>> {
  const token = (await getAuthToken()) ?? STATIC_AUTH_TOKEN;
  if (!token && path !== "/health") {
    throw new ApiHttpError("Authentication required.", 401);
  }
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const headers = new Headers(init?.headers);
  Object.entries(await authHeaders(path)).forEach(([key, value]) => headers.set(key, value));

  const response = await fetch(joinUrl(API_BASE_URL, path), {
    ...init,
    headers,
  });

  if (!response.ok) {
    throw new ApiHttpError(`API ${response.status}: ${response.statusText}`, response.status);
  }

  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

function envOrDefault(value: string | undefined, fallback: string) {
  const trimmed = trimmedEnv(value);
  return trimmed ? trimmed.replace(/\/+$/, "") : fallback;
}

function trimmedEnv(value: string | undefined) {
  return value?.trim() ?? "";
}

function joinUrl(baseUrl: string, path: string) {
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return `${baseUrl}${normalizedPath}`;
}

function asRecord(value: unknown): ApiRecord {
  return typeof value === "object" && value !== null ? (value as ApiRecord) : {};
}

function getArrayPayload(value: unknown) {
  if (Array.isArray(value)) return value;
  const record = asRecord(value);
  const possible = record.items ?? record.data ?? record.threads ?? record.messages ?? record.results;
  return Array.isArray(possible) ? possible : [];
}

function formatDate(value: unknown) {
  if (typeof value !== "string") return "Today";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return value;
  return parsed.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function normalizeThread(raw: unknown): ChatSession {
  const record = asRecord(raw);
  const id = String(record.id ?? record.thread_id ?? record.uuid ?? `thread-${Date.now()}`);
  const title = String(record.title ?? record.name ?? "Untitled legal chat");
  const date = formatDate(record.updated_at ?? record.created_at ?? record.date);

  return { id, title, date };
}

function normalizeAttachment(raw: unknown): MessageAttachment {
  const record = asRecord(raw);
  return {
    name: String(record.name ?? record.filename ?? record.title ?? "Attachment"),
    type: String(record.type ?? record.content_type ?? "application/octet-stream"),
    url: String(record.url ?? record.file_url ?? "#"),
  };
}

function normalizeMessage(raw: unknown): Message {
  const record = asRecord(raw);
  const role = record.role === "user" ? "user" : "ai";
  const content = String(
    record.content ??
      record.message ??
      record.answer ??
      record.response ??
      record.text ??
      ""
  );
  const attachments = getArrayPayload(record.attachments).map(normalizeAttachment);

  return {
    id: String(record.id ?? record.message_id ?? `msg-${Date.now()}`),
    role,
    content,
    timestamp: formatDate(record.created_at ?? record.timestamp ?? nowTime()),
    attachments: attachments.length ? attachments : undefined,
  };
}

export const chatService = {
  get baseUrl() {
    return API_BASE_URL;
  },

  async healthCheck(): Promise<{ status: string }> {
    return request<{ status: string }>("/health", { method: "GET" });
  },

  async getMe() {
    return request<ApiRecord>("/auth/me", { method: "GET" });
  },

  async createThread(title?: string): Promise<ChatSession> {
    const thread = await request<unknown>("/threads", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(title ? { title } : {}),
    });

    return normalizeThread(thread);
  },

  async fetchRecentChats(limit = 50, offset = 0): Promise<ChatSession[]> {
    const payload = await request<unknown>(`/threads?limit=${limit}&offset=${offset}`, {
      method: "GET",
    });
    return getArrayPayload(payload).map(normalizeThread);
  },

  async updateThreadTitle(threadId: string, title: string): Promise<ChatSession> {
    const thread = await request<unknown>(`/threads/${threadId}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title }),
    });

    return normalizeThread(thread);
  },

  async deleteThread(threadId: string): Promise<void> {
    await request<void>(`/threads/${threadId}`, { method: "DELETE" });
  },

  async fetchThreadMessages(threadId: string, limit = 200, offset = 0): Promise<Message[]> {
    const payload = await request<unknown>(
      `/threads/${threadId}/messages?limit=${limit}&offset=${offset}`,
      { method: "GET" }
    );
    return getArrayPayload(payload).map(normalizeMessage);
  },

  async uploadDocument(file: File): Promise<MessageAttachment> {
    return {
      name: file.name,
      type: file.type || "application/octet-stream",
      url: URL.createObjectURL(file),
    };
  },

  async sendMessage(
    text: string,
    attachments: File[] = [],
    threadId?: string,
    options?: { ragTopK?: number; onlyInEffect?: boolean }
  ): Promise<Message> {
    const formData = new FormData();
    formData.append("message", text);
    formData.append("rag_top_k", String(options?.ragTopK ?? 5));
    formData.append("only_in_effect", String(options?.onlyInEffect ?? true));
    if (threadId) formData.append("thread_id", threadId);
    attachments.forEach((file) => formData.append("files", file));

    const payload = await request<unknown>("/chat", {
      method: "POST",
      body: formData,
    });

    return normalizeMessage(payload);
  },

  admin: {
    async listDocuments(limit = 50, offset = 0) {
      return request<unknown>(`/admin/documents?limit=${limit}&offset=${offset}`, {
        method: "GET",
      });
    },

    async deleteDocument(docId: string) {
      return request<void>(`/admin/documents/${docId}`, { method: "DELETE" });
    },

    async ingestPdf(file: File, titlePrefix?: string, metadata?: ApiRecord) {
      const formData = new FormData();
      formData.append("file", file);
      if (titlePrefix) formData.append("title_prefix", titlePrefix);
      if (metadata) formData.append("metadata_json", JSON.stringify(metadata));

      return request<unknown>("/admin/ingest", {
        method: "POST",
        body: formData,
      });
    },
  },
};
