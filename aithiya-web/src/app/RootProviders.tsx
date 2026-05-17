"use client";

import { LocaleProvider } from "../i18n/LocaleProvider";

export default function RootProviders({ children }: { children: React.ReactNode }) {
  return <LocaleProvider>{children}</LocaleProvider>;
}
