"use client";

import { useLocaleContext } from "./LocaleProvider";
import type { TranslationKey } from "./types";

export function useTranslation() {
  const { t, locale, setLocale } = useLocaleContext();
  return { t, locale, setLocale };
}

export type { TranslationKey };
