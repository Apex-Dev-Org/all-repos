import { NextRequest, NextResponse } from "next/server";
import DodoPayments, { type ClientOptions } from "dodopayments";

export type BillingCycle = "monthly" | "yearly";
export type PaidPlanCode = "pro" | "ultra";
export type SubscriptionStatus =
  | "pending"
  | "active"
  | "on_hold"
  | "cancelled"
  | "expired"
  | "failed";

export type DodoProductMatch = {
  plan: PaidPlanCode;
  cycle: BillingCycle;
  productId: string;
};

export type SupabaseUser = {
  id: string;
  email?: string;
  user_metadata?: Record<string, unknown>;
};

export type UserSubscription = {
  user_id: string;
  dodo_customer_id: string | null;
  dodo_subscription_id: string | null;
  dodo_product_id: string | null;
  plan: "free" | PaidPlanCode;
  status: SubscriptionStatus;
  current_period_end: string | null;
  cancel_at_next_billing_date: boolean;
  metadata?: Record<string, unknown>;
};

type SupabaseConfig = {
  url: string;
  anonKey: string;
  serviceRoleKey?: string;
};

type DodoWebhookPayload = {
  type: string;
  timestamp?: Date | string;
  data?: unknown;
};

export class BillingRouteError extends Error {
  constructor(
    message: string,
    readonly status = 500,
  ) {
    super(message);
    this.name = "BillingRouteError";
  }
}

export function billingErrorResponse(error: unknown) {
  if (error instanceof BillingRouteError) {
    return NextResponse.json({ error: error.message }, { status: error.status });
  }

  console.error("Billing route failed", error);
  return NextResponse.json({ error: "Billing request failed." }, { status: 500 });
}

export function getDodoEnvironment(): NonNullable<ClientOptions["environment"]> {
  const value = process.env.DODO_PAYMENTS_ENVIRONMENT?.trim();
  if (!value || value === "test_mode") return "test_mode";
  if (value === "live_mode") return "live_mode";

  throw new BillingRouteError(
    "DODO_PAYMENTS_ENVIRONMENT must be test_mode or live_mode.",
  );
}

export function getDodoBearerToken() {
  return process.env.DODO_PAYMENTS_API_KEY?.trim();
}

export function getDodoWebhookSecret() {
  return (
    process.env.DODO_WEBHOOK_SECRET ??
    process.env.DODO_PAYMENTS_WEBHOOK_KEY
  )?.trim();
}

export function createDodoClient() {
  const bearerToken = getDodoBearerToken();
  if (!bearerToken) {
    throw new BillingRouteError("Dodo Payments API key is not configured.");
  }

  return new DodoPayments({
    bearerToken,
    environment: getDodoEnvironment(),
  });
}

export function getConfiguredDodoProduct(productId: string | null | undefined) {
  if (!productId) return undefined;

  return getConfiguredDodoProducts().find((item) => item.productId === productId);
}

export function getConfiguredDodoProducts(): DodoProductMatch[] {
  const products: DodoProductMatch[] = [
    {
      plan: "pro",
      cycle: "monthly",
      productId: process.env.NEXT_PUBLIC_DODO_PRO_MONTH_ID?.trim() ?? "",
    },
    {
      plan: "pro",
      cycle: "yearly",
      productId: process.env.NEXT_PUBLIC_DODO_PRO_YEAR_ID?.trim() ?? "",
    },
    {
      plan: "ultra",
      cycle: "monthly",
      productId: process.env.NEXT_PUBLIC_DODO_ULTRA_MONTH_ID?.trim() ?? "",
    },
    {
      plan: "ultra",
      cycle: "yearly",
      productId: process.env.NEXT_PUBLIC_DODO_ULTRA_YEAR_ID?.trim() ?? "",
    },
  ];

  return products.filter((item) => item.productId);
}

export async function requireSupabaseUser(request: NextRequest) {
  const config = getSupabaseConfig();
  const token = getBearerToken(request);

  if (!token) {
    throw new BillingRouteError("Authentication required.", 401);
  }

  const response = await fetch(`${config.url}/auth/v1/user`, {
    headers: {
      apikey: config.anonKey,
      Authorization: `Bearer ${token}`,
    },
    cache: "no-store",
  });

  if (!response.ok) {
    throw new BillingRouteError("Invalid or expired session.", 401);
  }

  const data = (await response.json()) as Record<string, unknown>;
  const id = stringValue(data.id);
  if (!id) {
    throw new BillingRouteError("Could not resolve the signed-in user.", 401);
  }

  return {
    id,
    email: stringValue(data.email),
    user_metadata: asRecord(data.user_metadata),
  } satisfies SupabaseUser;
}

export async function getUserSubscription(userId: string) {
  const rows = await supabaseServiceJson<UserSubscription[]>(
    "user_subscriptions",
    {
      search: {
        user_id: `eq.${userId}`,
        select:
          "user_id,dodo_customer_id,dodo_subscription_id,dodo_product_id,plan,status,current_period_end,cancel_at_next_billing_date,metadata",
        limit: "1",
      },
    },
  );

  return rows[0];
}

export async function recordDodoWebhookPayload(payload: DodoWebhookPayload) {
  const eventType = payload.type;

  if (!eventType.startsWith("payment.") && !eventType.startsWith("subscription.")) {
    return;
  }

  const facts = await extractWebhookFacts(payload);
  if (!facts.userId) {
    console.warn("Dodo webhook could not be linked to a Supabase user", {
      eventType,
      customerId: facts.customerId,
      subscriptionId: facts.subscriptionId,
      paymentId: facts.paymentId,
    });
    return;
  }

  await upsertUserSubscription({
    user_id: facts.userId,
    dodo_customer_id: facts.customerId,
    dodo_subscription_id: facts.subscriptionId,
    dodo_product_id: facts.productId,
    plan: facts.plan,
    status: facts.status,
    current_period_end: facts.currentPeriodEnd,
    cancel_at_next_billing_date: facts.cancelAtNextBillingDate,
    metadata: removeUndefined({
      dodo_event_type: eventType,
      dodo_event_timestamp: toIsoString(payload.timestamp),
      dodo_payment_id: facts.paymentId,
      dodo_customer_email: facts.customerEmail,
      cycle: facts.cycle,
    }),
  });
}

async function extractWebhookFacts(payload: DodoWebhookPayload) {
  const data = asRecord(payload.data);
  const metadata = asRecord(data.metadata);
  const customer = asRecord(data.customer);
  const customerMetadata = asRecord(customer.metadata);
  const productId = extractProductId(data);
  const configuredProduct = getConfiguredDodoProduct(productId);
  const customerId = stringValue(customer.customer_id ?? data.customer_id);
  const subscriptionId = stringValue(data.subscription_id);
  const paymentId = stringValue(data.payment_id);

  const metadataUserId = stringValue(
    metadata.user_id ??
      metadata.userId ??
      metadata.metadata_user_id ??
      customerMetadata.user_id ??
      customerMetadata.userId ??
      customerMetadata.metadata_user_id,
  );

  return {
    userId:
      metadataUserId ??
      (await findUserIdForDodoIds({
        customerId,
        subscriptionId,
      })),
    customerId,
    subscriptionId,
    productId,
    paymentId,
    customerEmail: stringValue(customer.email),
    plan: configuredProduct?.plan ?? parsePlan(metadata.plan ?? metadata.metadata_plan),
    cycle:
      configuredProduct?.cycle ??
      parseCycle(metadata.cycle ?? metadata.metadata_cycle),
    status: subscriptionStatusForEvent(payload.type, data),
    currentPeriodEnd:
      toIsoString(data.next_billing_date) ?? toIsoString(data.expires_at),
    cancelAtNextBillingDate:
      typeof data.cancel_at_next_billing_date === "boolean"
        ? data.cancel_at_next_billing_date
        : undefined,
  };
}

async function upsertUserSubscription(row: {
  user_id: string;
  dodo_customer_id?: string;
  dodo_subscription_id?: string;
  dodo_product_id?: string;
  plan?: PaidPlanCode;
  status?: SubscriptionStatus;
  current_period_end?: string;
  cancel_at_next_billing_date?: boolean;
  metadata?: Record<string, unknown>;
}) {
  await supabaseServiceJson<UserSubscription[]>("user_subscriptions", {
    method: "POST",
    search: { on_conflict: "user_id" },
    headers: { Prefer: "resolution=merge-duplicates,return=representation" },
    body: removeUndefined(row),
  });
}

async function findUserIdForDodoIds({
  customerId,
  subscriptionId,
}: {
  customerId?: string;
  subscriptionId?: string;
}) {
  if (subscriptionId) {
    const bySubscription = await findUserIdByBillingColumn(
      "dodo_subscription_id",
      subscriptionId,
    );
    if (bySubscription) return bySubscription;
  }

  if (customerId) {
    return findUserIdByBillingColumn("dodo_customer_id", customerId);
  }

  return undefined;
}

async function findUserIdByBillingColumn(column: string, value: string) {
  const rows = await supabaseServiceJson<Array<{ user_id?: string }>>(
    "user_subscriptions",
    {
      search: {
        [column]: `eq.${value}`,
        select: "user_id",
        limit: "1",
      },
    },
  );

  return stringValue(rows[0]?.user_id);
}

async function supabaseServiceJson<T>(
  path: string,
  init: {
    method?: string;
    search?: Record<string, string>;
    headers?: Record<string, string>;
    body?: unknown;
  } = {},
) {
  const config = getSupabaseConfig({ requireServiceRole: true });
  const url = new URL(`${config.url}/rest/v1/${path}`);

  Object.entries(init.search ?? {}).forEach(([key, value]) => {
    url.searchParams.set(key, value);
  });

  const response = await fetch(url, {
    method: init.method ?? "GET",
    headers: {
      apikey: config.serviceRoleKey!,
      Authorization: `Bearer ${config.serviceRoleKey}`,
      "Content-Type": "application/json",
      ...init.headers,
    },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
    cache: "no-store",
  });

  if (!response.ok) {
    const message = await response.text().catch(() => "");
    throw new BillingRouteError(
      `Supabase billing request failed: ${response.status}${message ? ` ${message}` : ""}`,
    );
  }

  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

function getSupabaseConfig(options?: { requireServiceRole?: boolean }) {
  const rawUrl = (
    process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL
  )?.trim();
  const anonKey = (
    process.env.SUPABASE_ANON_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  )?.trim();
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

  if (!rawUrl || !anonKey) {
    throw new BillingRouteError("Supabase is not configured.");
  }

  if (options?.requireServiceRole && !serviceRoleKey) {
    throw new BillingRouteError("Supabase service role key is not configured.");
  }

  return {
    url: normalizeHttpUrl(rawUrl),
    anonKey,
    serviceRoleKey,
  } satisfies SupabaseConfig;
}

function getBearerToken(request: NextRequest) {
  const header = request.headers.get("authorization")?.trim();
  if (!header) return undefined;

  const match = /^Bearer\s+(.+)$/i.exec(header);
  return match?.[1]?.trim();
}

function extractProductId(data: Record<string, unknown>) {
  const productId = stringValue(data.product_id);
  if (productId) return productId;

  const cart = Array.isArray(data.product_cart) ? data.product_cart : [];
  const firstItem = asRecord(cart[0]);
  return stringValue(firstItem.product_id);
}

function subscriptionStatusForEvent(
  eventType: string,
  data: Record<string, unknown>,
): SubscriptionStatus {
  const status = parseStatus(data.status);
  if (status) return status;

  switch (eventType) {
    case "payment.succeeded":
    case "subscription.active":
    case "subscription.renewed":
    case "subscription.plan_changed":
    case "subscription.updated":
      return "active";
    case "subscription.on_hold":
      return "on_hold";
    case "subscription.cancelled":
      return "cancelled";
    case "subscription.expired":
      return "expired";
    case "payment.failed":
    case "subscription.failed":
      return "failed";
    default:
      return "pending";
  }
}

function parseStatus(value: unknown): SubscriptionStatus | undefined {
  if (
    value === "pending" ||
    value === "active" ||
    value === "on_hold" ||
    value === "cancelled" ||
    value === "expired" ||
    value === "failed"
  ) {
    return value;
  }

  return undefined;
}

function parsePlan(value: unknown): PaidPlanCode | undefined {
  const normalized = stringValue(value)?.toLowerCase();
  if (normalized === "pro" || normalized === "ultra") return normalized;
  return undefined;
}

function parseCycle(value: unknown): BillingCycle | undefined {
  const normalized = stringValue(value)?.toLowerCase();
  if (normalized === "monthly" || normalized === "yearly") return normalized;
  return undefined;
}

function toIsoString(value: unknown) {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString();
  }

  if (typeof value === "string" && value.trim()) {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? value : parsed.toISOString();
  }

  return undefined;
}

function normalizeHttpUrl(raw: string) {
  const withProtocol = /^[a-z][a-z\d+.-]*:\/\//i.test(raw) ? raw : `https://${raw}`;
  const parsed = new URL(withProtocol);

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new BillingRouteError("Supabase URL must use http or https.");
  }

  parsed.pathname = parsed.pathname.replace(/\/+$/, "");
  parsed.search = "";
  parsed.hash = "";
  return parsed.toString().replace(/\/+$/, "");
}

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null
    ? (value as Record<string, unknown>)
    : {};
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function removeUndefined<T extends Record<string, unknown>>(record: T) {
  return Object.fromEntries(
    Object.entries(record).filter(([, value]) => value !== undefined),
  ) as Partial<T>;
}
