"use client";

import { type ReactNode, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import {
  Bot,
  Check,
  FileText,
  Home,
  Loader2,
  Menu,
  Paperclip,
  Pin,
  PinOff,
  Plus,
  Search,
  Send,
  Settings,
  ShieldCheck,
  Sparkles,
  Trash2,
  X,
} from "lucide-react";
import { Message, ChatSession, MessageAttachment } from "../../types/chat";
import { ApiHttpError, chatService } from "../../services/chatService";
import { authService } from "../../services/authService";
import { useTranslation } from "../../i18n/useTranslation";
import AuthScreen from "../components/AuthScreen";

type ChatSessionUi = ChatSession & {
  pinned?: boolean;
  preview?: string;
};

const nowTime = () =>
  new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

const today = () =>
  new Date().toLocaleDateString("en-US", { month: "short", day: "numeric" });

export default function ChatPage() {
  const { t } = useTranslation();

  const buildWelcome = (): Message => ({
    id: "welcome",
    role: "ai",
    content: t("chatWelcome"),
    timestamp: nowTime(),
  });

  const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);
  const [authUser, setAuthUser] = useState<{ name?: string; email?: string }>();
  const [input, setInput] = useState("");
  const [recentChats, setRecentChats] = useState<ChatSessionUi[]>([]);
  const [activeChatId, setActiveChatId] = useState("chat-main");
  const [chatMessages, setChatMessages] = useState<Record<string, Message[]>>({
    "chat-main": [
      {
        id: "welcome",
        role: "ai",
        content: t("chatWelcome"),
        timestamp: nowTime(),
      },
    ],
  });
  const [attachments, setAttachments] = useState<MessageAttachment[]>([]);
  const [pendingFiles, setPendingFiles] = useState<File[]>([]);
  const [loading, setLoading] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [threadsError, setThreadsError] = useState("");
  const [threadsLoading, setThreadsLoading] = useState(false);
  const [threadsRetryTick, setThreadsRetryTick] = useState(0);

  const fileInputRef = useRef<HTMLInputElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const messages = useMemo(() => {
    const list = chatMessages[activeChatId] ?? [
      {
        id: "welcome",
        role: "ai" as const,
        content: t("chatWelcome"),
        timestamp: nowTime(),
      },
    ];
    return list.map((message) =>
      message.id === "welcome" && message.role === "ai"
        ? { ...message, content: t("chatWelcome") }
        : message
    );
  }, [activeChatId, chatMessages, t]);

  const sortedChats = useMemo(
    () =>
      [...recentChats].sort((a, b) => Number(Boolean(b.pinned)) - Number(Boolean(a.pinned))),
    [recentChats]
  );

  useEffect(() => {
    let cancelled = false;
    queueMicrotask(() => {
      if (cancelled) return;
      setIsAuthenticated(authService.isAuthenticated());
      setAuthUser(authService.getUser());
    });

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!isAuthenticated) return;

    let cancelled = false;

    const load = async () => {
      setThreadsError("");
      setThreadsLoading(true);
      try {
        await authService.refreshProfileFromApi();
        if (cancelled) return;
        setAuthUser(authService.getUser());

        const sessions = await chatService.fetchRecentChats();
        if (cancelled) return;

        const hydrated = sessions.map((session) => ({
          ...session,
          pinned: false,
          preview: session.title,
        }));

        setRecentChats([
          {
            id: "chat-main",
            title: t("newChat"),
            date: today(),
            pinned: true,
            preview: t("loginBrandTitle"),
          },
          ...hydrated,
        ]);
      } catch (error) {
        if (cancelled) return;
        if (error instanceof ApiHttpError && (error.status === 401 || error.status === 403)) {
          authService.signOut();
          setIsAuthenticated(false);
          return;
        }
        setThreadsError(t("chatLoadError"));
      } finally {
        if (!cancelled) setThreadsLoading(false);
      }
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [isAuthenticated, t, threadsRetryTick]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [messages, loading]);

  const isBackendThread = (id: string) =>
    !id.startsWith("chat-") && !id.startsWith("mock-") && id !== "chat-main";

  const createNewChat = async () => {
    try {
      const created = await chatService.createThread(t("newChat"));
      const newSession: ChatSessionUi = {
        ...created,
        date: today(),
        preview: t("chatComposerPlaceholder").slice(0, 54),
        pinned: false,
      };

      setRecentChats((prev) => [newSession, ...prev]);
      setChatMessages((prev) => ({ ...prev, [newSession.id]: [buildWelcome()] }));
      setActiveChatId(newSession.id);
      setInput("");
      setAttachments([]);
      setPendingFiles([]);
      setSidebarOpen(false);
    } catch {
      window.alert(t("chatLoadError"));
    }
  };

  const openChat = async (id: string) => {
    setActiveChatId(id);
    setChatMessages((prev) => ({
      ...prev,
      [id]: prev[id] ?? [buildWelcome()],
    }));
    setSidebarOpen(false);

    if (!isBackendThread(id)) return;

    try {
      const threadMessages = await chatService.fetchThreadMessages(id);
      if (threadMessages.length) {
        setChatMessages((prev) => ({ ...prev, [id]: threadMessages }));
      }
    } catch {
      window.alert(t("chatLoadError"));
    }
  };

  const deleteChat = async (id: string) => {
    if (id === "chat-main") return;
    if (
      !window.confirm(
        `${t("chatHistoryDeleteConfirmTitle")}\n\n${t("chatHistoryDeleteConfirmBody")}`
      )
    )
      return;

    if (isBackendThread(id)) {
      try {
        await chatService.deleteThread(id);
      } catch {
        window.alert(t("chatHistoryDeleteError"));
        return;
      }
    }

    setRecentChats((prev) => prev.filter((chat) => chat.id !== id));
    setChatMessages((prev) => {
      const next = { ...prev };
      delete next[id];
      return next;
    });

    if (id === activeChatId) {
      const remaining = recentChats.filter((chat) => chat.id !== id);
      const nextId = remaining[0]?.id ?? "chat-main";
      setActiveChatId(nextId);
      setChatMessages((prev) => ({
        ...prev,
        [nextId]: prev[nextId] ?? [buildWelcome()],
      }));
    }
  };

  const togglePin = (id: string) => {
    setRecentChats((prev) =>
      prev.map((chat) => (chat.id === id ? { ...chat, pinned: !chat.pinned } : chat))
    );
  };

  const handleFiles = (files: FileList | null) => {
    if (!files?.length) return;

    const fileArray = Array.from(files);
    const mapped = fileArray.map((file) => ({
      name: file.name,
      type: file.type || "application/octet-stream",
      url: URL.createObjectURL(file),
    }));

    setAttachments((prev) => [...prev, ...mapped]);
    setPendingFiles((prev) => [...prev, ...fileArray]);
  };

  const removeAttachment = (name: string) => {
    setAttachments((prev) => prev.filter((file) => file.name !== name));
    setPendingFiles((prev) => prev.filter((file) => file.name !== name));
  };

  const handleSend = async () => {
    if ((!input.trim() && attachments.length === 0) || loading) return;

    const content = input.trim() || t("chatAttachmentOnly");
    const snapshotAttachments = [...attachments];
    const snapshotPendingFiles = [...pendingFiles];

    let threadId = activeChatId;
    let createdFromMain = false;

    if (!isBackendThread(threadId)) {
      try {
        const created = await chatService.createThread(content.slice(0, 48));
        threadId = created.id;
        createdFromMain = true;

        setRecentChats((prev) => [
          {
            ...created,
            date: today(),
            preview: content.slice(0, 54),
            pinned: false,
          },
          ...prev.filter((chat) => chat.id !== activeChatId),
        ]);

        setChatMessages((prev) => {
          const current = prev[activeChatId] ?? [buildWelcome()];
          const next = { ...prev, [created.id]: current };
          delete next[activeChatId];
          return next;
        });

        setActiveChatId(created.id);
      } catch {
        window.alert(t("chatSendError"));
        return;
      }
    }

    const preSendTitle = recentChats.find((c) => c.id === threadId)?.title;
    const defaultTitle = t("newChat");
    const blandTitles = new Set<string>([defaultTitle, "Untitled legal chat"]);

    const userMessage: Message = {
      id: `msg-${Date.now()}`,
      role: "user",
      content,
      timestamp: nowTime(),
      attachments: snapshotAttachments,
    };

    setChatMessages((prev) => {
      const cur = prev[threadId] ?? [buildWelcome()];
      return { ...prev, [threadId]: [...cur, userMessage] };
    });

    setInput("");
    setAttachments([]);
    setPendingFiles([]);
    setLoading(true);

    setRecentChats((prev) =>
      prev.map((chat) =>
        chat.id === threadId || chat.id === activeChatId
          ? {
              ...chat,
              title: chat.title === defaultTitle ? content.slice(0, 34) : chat.title,
              preview: content.slice(0, 54),
              date: today(),
            }
          : chat
      )
    );

    try {
      if (isBackendThread(threadId) && !createdFromMain && blandTitles.has(preSendTitle ?? "")) {
        await chatService.updateThreadTitle(threadId, content.slice(0, 48));
      }

      const aiMessage = await chatService.sendMessage(
        content,
        snapshotPendingFiles,
        isBackendThread(threadId) ? threadId : undefined
      );
      setChatMessages((prev) => ({
        ...prev,
        [threadId]: [...(prev[threadId] ?? prev[activeChatId] ?? [buildWelcome()]), aiMessage],
      }));
    } catch {
      setChatMessages((prev) => ({
        ...prev,
        [threadId]: [
          ...(prev[threadId] ?? prev[activeChatId] ?? [buildWelcome()]),
          {
            id: `err-${Date.now()}`,
            role: "ai",
            content: t("chatErrorReply"),
            timestamp: nowTime(),
          },
        ],
      }));
    } finally {
      setLoading(false);
    }
  };

  const activeChat = recentChats.find((chat) => chat.id === activeChatId);

  if (isAuthenticated === null) {
    return (
      <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", color: "#1d4ed8", fontWeight: 800 }}>
        {t("chatLoadingWorkspace")}
      </div>
    );
  }

  if (!isAuthenticated) {
    return (
      <AuthScreen
        initialMode="login"
        gateMessage={t("chatGateMessage")}
        onAuthenticated={() => {
          setIsAuthenticated(true);
          setAuthUser(authService.getUser());
        }}
      />
    );
  }

  return (
    <div className="chat-shell">
      <aside className={`chat-sidebar ${sidebarOpen ? "is-open" : ""}`}>
        <div className="sidebar-top">
          <Link href="/" className="chat-logo">
            <img src="/aythiya_logo.png" alt={t("loginBrandTitle")} />
          </Link>
          <div className="sidebar-top-actions">
            <Link href="/settings" className="sidebar-settings" aria-label={t("settingsTitle")}>
              <Settings size={20} />
            </Link>
            <button
              className="sidebar-close"
              onClick={() => setSidebarOpen(false)}
              aria-label={t("chatCloseSidebar")}
            >
              <X size={18} />
            </button>
          </div>
        </div>

        <div className="sidebar-user">
          <span>{authUser?.name ?? authUser?.email ?? t("loginBrandTitle")}</span>
          {authUser?.email && <small>{authUser.email}</small>}
        </div>

        <button className="new-chat-btn" onClick={createNewChat}>
          <Plus size={18} />
          {t("createNewChat")}
        </button>

        {threadsError && (
          <div className="threads-error-bar" role="alert">
            <span>{threadsError}</span>
            <button type="button" onClick={() => setThreadsRetryTick((n) => n + 1)}>
              {t("chatRetry")}
            </button>
          </div>
        )}

        {threadsLoading && <p className="threads-loading-hint">{t("chatLoadingThreads")}</p>}

        <div className="recent-wrap">
          <div className="recent-header">
            <span>{t("drawerRecentChats")}</span>
            <Search size={15} aria-hidden />
          </div>

          <div className="recent-list">
            {sortedChats.map((chat) => (
              <div
                key={chat.id}
                className={`recent-card ${chat.id === activeChatId ? "active" : ""}`}
                onClick={() => openChat(chat.id)}
              >
                <div className="recent-main">
                  <div className="recent-title-row">
                    {chat.pinned && <Pin size={12} />}
                    <span>{chat.title}</span>
                  </div>
                  <p>{chat.preview ?? t("chatComposerPlaceholder").slice(0, 54)}</p>
                  <small>{chat.date}</small>
                </div>

                <div className="recent-actions" onClick={(event) => event.stopPropagation()}>
                  <button
                    onClick={() => togglePin(chat.id)}
                    aria-label={chat.pinned ? t("chatHistoryUnpin") : t("chatHistoryPin")}
                  >
                    {chat.pinned ? <PinOff size={14} /> : <Pin size={14} />}
                  </button>
                  <button onClick={() => deleteChat(chat.id)} aria-label={t("chatHistoryDelete")}>
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>

      </aside>

      <main className="chat-main">
        <div className="chat-bg" />
        <div className="chat-overlay" />

        <header className="chat-topbar">
          <button className="mobile-menu" onClick={() => setSidebarOpen(true)} aria-label={t("chatOpenSidebar")}>
            <Menu size={20} />
          </button>

          <div className="chat-title">
            <div className="bot-mark">
              <Bot size={20} />
            </div>
            <div>
              <h1>{activeChat?.title ?? t("chatTitleDefault")}</h1>
            </div>
          </div>

          <Link href="/" className="home-link">
            <Home size={16} />
            {t("chatHomeLink")}
          </Link>
        </header>

        <section className="messages-panel">
          <div className="messages-list">
            {messages.map((msg, index) => (
              <MessageBubble key={msg.id} msg={msg} index={index} />
            ))}

            {loading && (
              <div className="message-row ai animate-message">
                <div className="ai-avatar">
                  <Bot size={18} />
                </div>
                <div className="typing-bubble glass-card">
                  <span />
                  <span />
                  <span />
                </div>
              </div>
            )}

            <div ref={messagesEndRef} />
          </div>
        </section>

        <section className="composer-wrap">
          {attachments.length > 0 && (
            <div className="attachment-strip">
              {attachments.map((file) => (
                <div key={file.name} className="attachment-chip">
                  <FileText size={14} />
                  <span>{file.name}</span>
                  <button onClick={() => removeAttachment(file.name)} aria-label={t("chatRemoveAttachment")}>
                    <X size={13} />
                  </button>
                </div>
              ))}
            </div>
          )}

          <div className="composer glass-card">
            <input
              ref={fileInputRef}
              type="file"
              multiple
              hidden
              onChange={(event) => handleFiles(event.target.files)}
            />

            <button className="tool-btn" onClick={() => fileInputRef.current?.click()} aria-label={t("chatAttachFile")}>
              <Paperclip size={19} />
            </button>

            <textarea
              value={input}
              onChange={(event) => setInput(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter" && !event.shiftKey) {
                  event.preventDefault();
                  handleSend();
                }
              }}
              rows={1}
              placeholder={t("chatComposerPlaceholder")}
            />

            <button className="send-btn" onClick={handleSend} disabled={loading || (!input.trim() && attachments.length === 0)}>
              {loading ? <Loader2 size={18} className="spin" /> : <Send size={18} />}
            </button>
          </div>
          <p className="legal-disclaimer">{t("chatLegalDisclaimer")}</p>
        </section>
      </main>

      <style>{`
        .chat-shell {
          display: flex;
          height: 100vh;
          overflow: hidden;
          background: #f6f9ff;
          color: #0f172a;
          font-family: Inter, sans-serif;
        }

        .chat-sidebar {
          width: 300px;
          flex: 0 0 300px;
          display: flex;
          flex-direction: column;
          padding: 18px;
          border-right: 1px solid rgba(191, 219, 254, 0.55);
          background: rgba(255, 255, 255, 0.78);
          backdrop-filter: blur(22px);
          box-shadow: 12px 0 40px rgba(15, 23, 42, 0.05);
          z-index: 5;
        }

        .sidebar-top {
          display: flex;
          align-items: center;
          justify-content: space-between;
          margin-bottom: 18px;
          gap: 10px;
        }

        .sidebar-top-actions {
          display: flex;
          align-items: center;
          gap: 6px;
        }

        .sidebar-settings {
          display: grid;
          place-items: center;
          width: 40px;
          height: 40px;
          border-radius: 12px;
          border: 1px solid rgba(191, 219, 254, 0.74);
          background: rgba(239, 246, 255, 0.72);
          color: #1d4ed8;
        }

        .sidebar-settings:hover {
          background: rgba(219, 234, 254, 0.95);
        }

        .threads-error-bar {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 10px;
          padding: 10px 12px;
          margin-bottom: 12px;
          border-radius: 12px;
          background: rgba(254, 226, 226, 0.85);
          border: 1px solid rgba(248, 113, 113, 0.45);
          font-size: 13px;
          font-weight: 700;
          color: #991b1b;
        }

        .threads-error-bar button {
          flex-shrink: 0;
          border: none;
          border-radius: 10px;
          padding: 6px 12px;
          font-weight: 800;
          font-size: 12px;
          cursor: pointer;
          background: #1d4ed8;
          color: #fff;
        }

        .threads-loading-hint {
          margin: 0 0 12px;
          font-size: 12px;
          font-weight: 700;
          color: #64748b;
        }

        .chat-logo img {
          height: 52px;
          width: auto;
          object-fit: contain;
        }

        .sidebar-user {
          margin: -2px 0 18px;
          padding: 12px 14px;
          border-radius: 16px;
          background: rgba(239, 246, 255, 0.72);
          border: 1px solid rgba(191, 219, 254, 0.74);
        }

        .sidebar-user span {
          display: block;
          color: #0f172a;
          font-size: 14px;
          font-weight: 900;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .sidebar-user small {
          display: block;
          margin-top: 3px;
          color: #64748b;
          font-size: 12px;
          font-weight: 600;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .sidebar-close {
          display: none;
        }

        .new-chat-btn {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 10px;
          width: 100%;
          padding: 13px 16px;
          border: 0;
          border-radius: 16px;
          background: linear-gradient(135deg, #1d4ed8, #3b82f6);
          color: #fff;
          font-weight: 800;
          cursor: pointer;
          box-shadow: 0 14px 28px rgba(29, 78, 216, 0.24);
          transition: transform .2s, box-shadow .2s;
        }

        .new-chat-btn:hover {
          transform: translateY(-2px);
          box-shadow: 0 18px 36px rgba(29, 78, 216, 0.32);
        }

        .recent-wrap {
          margin-top: 24px;
          min-height: 0;
          flex: 1;
          display: flex;
          flex-direction: column;
        }

        .recent-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          color: #94a3b8;
          font-size: 12px;
          font-weight: 900;
          letter-spacing: .08em;
          text-transform: uppercase;
          margin-bottom: 12px;
        }

        .recent-list {
          overflow-y: auto;
          display: grid;
          gap: 9px;
          padding-right: 2px;
        }

        .recent-card {
          display: flex;
          gap: 8px;
          justify-content: space-between;
          padding: 12px;
          border-radius: 16px;
          cursor: pointer;
          border: 1px solid transparent;
          background: rgba(255, 255, 255, 0.42);
          transition: background .2s, border-color .2s, transform .2s;
        }

        .recent-card:hover,
        .recent-card.active {
          background: rgba(239, 246, 255, 0.9);
          border-color: rgba(147, 197, 253, 0.7);
          transform: translateX(2px);
        }

        .recent-main {
          min-width: 0;
          flex: 1;
        }

        .recent-title-row {
          display: flex;
          gap: 6px;
          align-items: center;
          color: #0f172a;
          font-weight: 800;
          font-size: 13px;
        }

        .recent-title-row span {
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .recent-main p {
          color: #64748b;
          font-size: 12px;
          line-height: 1.35;
          margin: 4px 0;
        }

        .recent-main small {
          color: #94a3b8;
          font-size: 11px;
        }

        .recent-actions {
          display: flex;
          flex-direction: column;
          gap: 5px;
          opacity: .58;
        }

        .recent-actions button,
        .sidebar-close,
        .mobile-menu {
          border: 0;
          background: transparent;
          color: #64748b;
          cursor: pointer;
          border-radius: 9px;
          padding: 5px;
        }

        .recent-actions button:hover,
        .sidebar-close:hover,
        .mobile-menu:hover {
          background: rgba(219, 234, 254, 0.8);
          color: #1d4ed8;
        }

        .chat-main {
          position: relative;
          flex: 1;
          display: flex;
          flex-direction: column;
          overflow: hidden;
        }

        .chat-bg {
          position: absolute;
          inset: 0;
          background-image: url('/how_aythiya_works_bg.png');
          background-size: cover;
          background-position: center;
          opacity: .46;
          transform: scale(1.05);
        }

        .chat-overlay {
          position: absolute;
          inset: 0;
          background:
            radial-gradient(circle at 20% 10%, rgba(191, 219, 254, .42), transparent 34%),
            linear-gradient(180deg, rgba(255,255,255,.72), rgba(239,246,255,.78));
        }

        .chat-topbar {
          position: relative;
          z-index: 1;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 16px;
          padding: 20px 34px;
        }

        .mobile-menu {
          display: none;
        }

        .chat-title {
          display: flex;
          align-items: center;
          gap: 12px;
          min-width: 0;
        }

        .bot-mark,
        .ai-avatar {
          width: 42px;
          height: 42px;
          border-radius: 14px;
          display: grid;
          place-items: center;
          color: #fff;
          background: linear-gradient(135deg, #1d4ed8, #60a5fa);
          box-shadow: 0 12px 24px rgba(29, 78, 216, .25);
        }

        .chat-title h1 {
          font-size: 17px;
          margin: 0;
          font-weight: 900;
        }

        .chat-title p {
          display: flex;
          align-items: center;
          gap: 5px;
          margin: 4px 0 0;
          color: #64748b;
          font-size: 12px;
          font-weight: 700;
        }

        .home-link {
          display: inline-flex;
          align-items: center;
          gap: 8px;
          padding: 10px 14px;
          border-radius: 999px;
          color: #1d4ed8;
          background: rgba(255,255,255,.72);
          border: 1px solid rgba(191,219,254,.72);
          text-decoration: none;
          font-weight: 800;
          font-size: 13px;
          backdrop-filter: blur(12px);
        }

        .messages-panel {
          position: relative;
          z-index: 1;
          flex: 1;
          display: flex;
          flex-direction: column;
          min-height: 0;
          padding: 0 34px;
        }

        .messages-list {
          flex: 1;
          min-height: 0;
          overflow-y: auto;
          display: flex;
          flex-direction: column;
          gap: 22px;
          padding: 2px 4px 26px;
        }

        .message-row {
          display: flex;
          gap: 13px;
          align-items: flex-end;
          max-width: 100%;
        }

        .message-row.user {
          justify-content: flex-end;
        }

        .message-stack {
          max-width: min(720px, 74%);
        }

        .message-row.user .message-stack {
          max-width: min(640px, 70%);
        }

        .glass-card {
          background: rgba(255,255,255,.66);
          border: 1px solid rgba(255,255,255,.78);
          backdrop-filter: blur(18px);
          box-shadow: 0 18px 46px rgba(15,23,42,.08);
        }

        .bubble {
          position: relative;
          padding: 15px 18px;
          border-radius: 22px;
          color: #1e293b;
          line-height: 1.65;
          font-size: 15px;
        }

        .bubble.ai {
          border-bottom-left-radius: 7px;
        }

        .assistant-markdown {
          display: grid;
          gap: 10px;
        }

        .assistant-markdown h3,
        .assistant-markdown h4,
        .assistant-markdown p,
        .assistant-markdown ul,
        .assistant-markdown ol {
          margin: 0;
        }

        .assistant-markdown h3 {
          font-size: 16px;
          line-height: 1.35;
          color: #0f172a;
        }

        .assistant-markdown h4 {
          font-size: 14px;
          line-height: 1.4;
          color: #1e293b;
        }

        .assistant-markdown ul,
        .assistant-markdown ol {
          padding-left: 20px;
          display: grid;
          gap: 6px;
        }

        .assistant-markdown li {
          padding-left: 2px;
        }

        .assistant-markdown strong {
          font-weight: 850;
          color: #0f172a;
        }

        .assistant-markdown em {
          color: #334155;
        }

        .assistant-markdown code {
          padding: 2px 5px;
          border-radius: 7px;
          background: rgba(226,232,240,.85);
          color: #0f172a;
          font-size: .92em;
        }

        .bubble.user {
          border-bottom-right-radius: 7px;
          color: #082f49;
          background:
            linear-gradient(135deg, rgba(219,234,254,.88), rgba(255,255,255,.62));
          border: 1px solid rgba(147,197,253,.72);
          backdrop-filter: blur(18px);
          box-shadow: 0 18px 42px rgba(29,78,216,.12);
        }

        .bubble-meta {
          display: flex;
          align-items: center;
          gap: 5px;
          margin-top: 7px;
          color: #94a3b8;
          font-size: 11px;
        }

        .message-row.user .bubble-meta {
          justify-content: flex-end;
        }

        .message-attachments {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
          margin-top: 10px;
        }

        .message-attachments span {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          padding: 7px 10px;
          border-radius: 999px;
          background: rgba(255,255,255,.62);
          border: 1px solid rgba(191,219,254,.72);
          font-size: 12px;
          font-weight: 700;
          color: #1d4ed8;
        }

        .guidance-card {
          margin-top: 14px;
          border-radius: 24px;
          padding: 20px;
        }

        .guidance-title {
          display: flex;
          align-items: center;
          gap: 8px;
          color: #1d4ed8;
          font-weight: 900;
          margin-bottom: 16px;
        }

        .guidance-grid {
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          gap: 13px;
        }

        .guidance-box {
          border-radius: 18px;
          padding: 16px;
          background: rgba(248,250,252,.78);
          border: 1px solid rgba(226,232,240,.8);
        }

        .guidance-box h3 {
          display: flex;
          align-items: center;
          gap: 7px;
          margin: 0 0 10px;
          font-size: 13px;
        }

        .guidance-box p,
        .guidance-box li {
          color: #475569;
          font-size: 12px;
          line-height: 1.55;
        }

        .guidance-box ul {
          list-style: none;
          display: grid;
          gap: 8px;
        }

        .guidance-box li {
          display: flex;
          gap: 7px;
        }

        .typing-bubble {
          display: flex;
          gap: 6px;
          padding: 15px 18px;
          border-radius: 20px 20px 20px 6px;
        }

        .typing-bubble span {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: #60a5fa;
          animation: typingPulse 1.1s infinite ease-in-out;
        }

        .typing-bubble span:nth-child(2) {
          animation-delay: .15s;
        }

        .typing-bubble span:nth-child(3) {
          animation-delay: .3s;
        }

        .composer-wrap {
          position: relative;
          z-index: 2;
          padding: 0 34px 28px;
        }

        .attachment-strip {
          max-width: 920px;
          margin: 0 auto 10px;
          display: flex;
          gap: 8px;
          flex-wrap: wrap;
        }

        .attachment-chip {
          display: inline-flex;
          align-items: center;
          gap: 7px;
          padding: 8px 10px;
          border-radius: 999px;
          color: #1d4ed8;
          font-size: 12px;
          font-weight: 800;
          background: rgba(255,255,255,.72);
          border: 1px solid rgba(191,219,254,.78);
          backdrop-filter: blur(12px);
        }

        .attachment-chip button {
          border: 0;
          background: transparent;
          color: #64748b;
          cursor: pointer;
          padding: 1px;
        }

        .composer {
          max-width: 920px;
          margin: 0 auto;
          display: flex;
          align-items: flex-end;
          gap: 10px;
          border-radius: 28px;
          padding: 10px;
        }

        .legal-disclaimer {
          max-width: 860px;
          margin: 10px auto 0;
          color: #64748b;
          font-size: 11px;
          line-height: 1.55;
          text-align: center;
        }

        .composer textarea {
          flex: 1;
          resize: none;
          border: 0;
          outline: none;
          min-height: 42px;
          max-height: 120px;
          padding: 12px 6px;
          background: transparent;
          color: #0f172a;
          font: inherit;
          font-size: 15px;
        }

        .tool-btn,
        .send-btn {
          flex: 0 0 auto;
          width: 44px;
          height: 44px;
          border: 0;
          border-radius: 50%;
          display: grid;
          place-items: center;
          cursor: pointer;
          transition: transform .2s, background .2s, color .2s, box-shadow .2s;
        }

        .tool-btn {
          color: #64748b;
          background: rgba(248,250,252,.9);
          border: 1px solid rgba(226,232,240,.9);
        }

        .tool-btn:hover {
          color: #1d4ed8;
          background: rgba(219,234,254,.86);
          transform: translateY(-1px);
        }



        .send-btn {
          color: #fff;
          background: linear-gradient(135deg, #1d4ed8, #3b82f6);
          box-shadow: 0 12px 24px rgba(29,78,216,.28);
        }

        .send-btn:disabled {
          cursor: not-allowed;
          color: #94a3b8;
          background: #e2e8f0;
          box-shadow: none;
        }

        .send-btn:not(:disabled):hover {
          transform: translateY(-2px) scale(1.02);
        }

        .animate-message {
          animation: messageIn .34s ease-out both;
        }

        .spin {
          animation: spin 1s linear infinite;
        }

        @keyframes messageIn {
          from { opacity: 0; transform: translateY(12px) scale(.98); }
          to { opacity: 1; transform: translateY(0) scale(1); }
        }

        @keyframes typingPulse {
          0%, 80%, 100% { transform: translateY(0); opacity: .45; }
          40% { transform: translateY(-5px); opacity: 1; }
        }



        @keyframes spin {
          to { transform: rotate(360deg); }
        }

        @media (max-width: 980px) {
          .chat-sidebar {
            position: fixed;
            inset: 0 auto 0 0;
            transform: translateX(-102%);
            transition: transform .25s ease;
          }

          .chat-sidebar.is-open {
            transform: translateX(0);
          }

          .sidebar-close,
          .mobile-menu {
            display: inline-grid;
            place-items: center;
          }

          .chat-topbar {
            padding: 16px 18px;
          }

          .messages-panel,
          .composer-wrap {
            padding-left: 18px;
            padding-right: 18px;
          }

          .guidance-grid {
            grid-template-columns: 1fr;
          }

          .message-stack,
          .message-row.user .message-stack {
            max-width: 88%;
          }
        }

        @media (max-width: 640px) {
          .chat-title h1 {
            font-size: 14px;
          }

          .home-link {
            display: none;
          }

          .message-stack,
          .message-row.user .message-stack {
            max-width: 94%;
          }
        }
      `}</style>
    </div>
  );
}

function MessageBubble({ msg, index }: { msg: Message; index: number }) {
  const isUser = msg.role === "user";

  return (
    <div className={`message-row ${isUser ? "user" : "ai"} animate-message`} style={{ animationDelay: `${Math.min(index * 40, 240)}ms` }}>
      {!isUser && (
        <div className="ai-avatar">
          <Bot size={18} />
        </div>
      )}

      <div className="message-stack">
        <div className={`bubble ${isUser ? "user" : "ai glass-card"}`}>
          {isUser ? msg.content : <AssistantMessageContent content={msg.content} />}
          {msg.attachments && msg.attachments.length > 0 && (
            <div className="message-attachments">
              {msg.attachments.map((file) => (
                <span key={file.name}>
                  <FileText size={13} />
                  {file.name}
                </span>
              ))}
            </div>
          )}
        </div>

        {msg.guidance && <GuidanceSummary msg={msg} />}

        <div className="bubble-meta">
          {msg.timestamp}
          {isUser && (
            <>
              <Check size={12} />
              <Check size={12} style={{ marginLeft: -8 }} />
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function AssistantMessageContent({ content }: { content: string }) {
  const normalized = content.replace(/\r\n/g, "\n").trim();
  if (!normalized) return null;

  const lines = normalized.split("\n");
  const blocks: ReactNode[] = [];
  let i = 0;

  while (i < lines.length) {
    const trimmed = lines[i].trim();
    if (!trimmed) {
      i += 1;
      continue;
    }

    const heading = /^(#{1,3})\s+(.+)$/.exec(trimmed);
    if (heading) {
      const Tag = heading[1].length === 1 ? "h3" : "h4";
      blocks.push(
        <Tag key={`h-${i}`}>{renderInlineMarkdown(heading[2])}</Tag>
      );
      i += 1;
      continue;
    }

    const unordered = /^[-*•]\s+(.+)$/.exec(trimmed);
    const ordered = /^\d+[.)]\s+(.+)$/.exec(trimmed);
    if (unordered || ordered) {
      const orderedList = Boolean(ordered);
      const items: string[] = [];
      while (i < lines.length) {
        const line = lines[i].trim();
        const match = orderedList
          ? /^\d+[.)]\s+(.+)$/.exec(line)
          : /^[-*•]\s+(.+)$/.exec(line);
        if (!match) break;
        items.push(match[1]);
        i += 1;
      }
      const ListTag = orderedList ? "ol" : "ul";
      blocks.push(
        <ListTag key={`list-${i}`}>
          {items.map((item, itemIndex) => (
            <li key={itemIndex}>{renderInlineMarkdown(item)}</li>
          ))}
        </ListTag>
      );
      continue;
    }

    const paragraph: string[] = [];
    while (i < lines.length) {
      const line = lines[i].trim();
      if (!line) break;
      if (/^(#{1,3})\s+/.test(line)) break;
      if (/^[-*•]\s+/.test(line) || /^\d+[.)]\s+/.test(line)) break;
      paragraph.push(line);
      i += 1;
    }

    blocks.push(
      <p key={`p-${i}`}>{renderInlineMarkdown(paragraph.join(" "))}</p>
    );
  }

  return <div className="assistant-markdown">{blocks}</div>;
}

function renderInlineMarkdown(text: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  const pattern = /(`[^`]+`|\*\*[^*]+?\*\*|\*[^*\n]+?\*)/g;
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = pattern.exec(text)) !== null) {
    if (match.index > lastIndex) {
      nodes.push(text.slice(lastIndex, match.index));
    }

    const token = match[0];
    const key = `${match.index}-${token.length}`;
    if (token.startsWith("`")) {
      nodes.push(<code key={key}>{token.slice(1, -1)}</code>);
    } else if (token.startsWith("**")) {
      nodes.push(<strong key={key}>{token.slice(2, -2)}</strong>);
    } else {
      nodes.push(<em key={key}>{token.slice(1, -1)}</em>);
    }
    lastIndex = pattern.lastIndex;
  }

  if (lastIndex < text.length) {
    nodes.push(text.slice(lastIndex));
  }

  return nodes;
}

function GuidanceSummary({ msg }: { msg: Message }) {
  const { t } = useTranslation();
  if (!msg.guidance) return null;

  return (
    <div className="guidance-card glass-card">
      <div className="guidance-title">
        <Sparkles size={18} />
        {t("chatGuidanceTitle")}
      </div>

      <div className="guidance-grid">
        <div className="guidance-box">
          <h3>
            <ShieldCheck size={15} color="#1d4ed8" />
            {t("chatGuidanceRights")}
          </h3>
          <ul>
            {msg.guidance.rights.map((right, index) => (
              <li key={index}>
                <Check size={14} color="#1d4ed8" />
                {right.text}
              </li>
            ))}
          </ul>
        </div>

        <div className="guidance-box">
          <h3>
            <Sparkles size={15} color="#1d4ed8" />
            {t("chatGuidanceSteps")}
          </h3>
          <ul>
            {msg.guidance.steps.map((step, index) => (
              <li key={index}>
                <span style={{ color: "#1d4ed8", fontWeight: 900 }}>{index + 1}.</span>
                {step.text}
              </li>
            ))}
          </ul>
        </div>

        <div className="guidance-box">
          <h3>
            <Paperclip size={15} color="#1d4ed8" />
            {t("chatGuidanceDocs")}
          </h3>
          <ul>
            {msg.guidance.suggestedDocs.map((doc) => (
              <li key={doc.name}>
                <FileText size={14} color={doc.type.includes("pdf") ? "#ef4444" : "#1d4ed8"} />
                {doc.name}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  );
}
