export interface ChatSession {
  id: string;
  title: string;
  date: string;
}

export interface MessageAttachment {
  name: string;
  type: string;
  url: string;
}

export interface GuidanceStep {
  text: string;
}

export interface GuidanceRight {
  text: string;
}

export interface GuidanceSummary {
  rights: GuidanceRight[];
  steps: GuidanceStep[];
  suggestedDocs: MessageAttachment[];
}

export interface Message {
  id: string;
  role: "user" | "ai";
  content: string;
  timestamp: string;
  attachments?: MessageAttachment[];
  guidance?: GuidanceSummary; // Only for AI messages that return the complex UI card
}
