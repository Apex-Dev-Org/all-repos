import { Checkout } from "@dodopayments/nextjs";
import { NextRequest, NextResponse } from "next/server";

import {
  BillingRouteError,
  billingErrorResponse,
  getConfiguredDodoProduct,
  getDodoBearerToken,
  getDodoEnvironment,
  requireSupabaseUser,
} from "../_lib/billing";

export async function GET(request: NextRequest) {
  try {
    const bearerToken = requireDodoBearerToken();
    const user = await requireSupabaseUser(request);
    const checkoutUrl = new URL(request.url);
    const product = getConfiguredDodoProduct(
      checkoutUrl.searchParams.get("productId"),
    );

    if (!product) {
      return NextResponse.json(
        { error: "Unknown or unconfigured Dodo product." },
        { status: 400 },
      );
    }

    checkoutUrl.searchParams.set("metadata_user_id", user.id);
    checkoutUrl.searchParams.set("metadata_plan", product.plan);
    checkoutUrl.searchParams.set("metadata_cycle", product.cycle);
    if (user.email) {
      checkoutUrl.searchParams.set("email", user.email);
    }

    const handler = Checkout({
      bearerToken,
      returnUrl: process.env.DODO_PAYMENTS_RETURN_URL,
      environment: getDodoEnvironment(),
      type: "static",
    });

    return handler(
      new NextRequest(checkoutUrl, {
        method: "GET",
        headers: request.headers,
      }),
    );
  } catch (error) {
    return billingErrorResponse(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const bearerToken = requireDodoBearerToken();
    const user = await requireSupabaseUser(request);
    const body = await readJsonBody(request);
    const product = getConfiguredDodoProduct(resolveProductId(body));

    if (!product) {
      return NextResponse.json(
        { error: "Unknown or unconfigured Dodo product." },
        { status: 400 },
      );
    }

    const enrichedBody = enrichCheckoutSessionBody(body, user, product);
    const headers = new Headers(request.headers);
    headers.set("content-type", "application/json");

    const handler = Checkout({
      bearerToken,
      returnUrl: process.env.DODO_PAYMENTS_RETURN_URL,
      environment: getDodoEnvironment(),
      type: "session",
    });

    return handler(
      new NextRequest(request.url, {
        method: "POST",
        headers,
        body: JSON.stringify(enrichedBody),
      }),
    );
  } catch (error) {
    return billingErrorResponse(error);
  }
}

function requireDodoBearerToken() {
  const bearerToken = getDodoBearerToken();
  if (!bearerToken) {
    throw new BillingRouteError("Dodo Payments API key is not configured.");
  }

  return bearerToken;
}

async function readJsonBody(request: NextRequest) {
  try {
    const body = await request.json();
    return typeof body === "object" && body !== null
      ? (body as Record<string, unknown>)
      : {};
  } catch {
    return {};
  }
}

function resolveProductId(body: Record<string, unknown>) {
  if (typeof body.product_id === "string") return body.product_id;

  const cart = Array.isArray(body.product_cart) ? body.product_cart : [];
  const firstItem = cart[0];
  if (typeof firstItem !== "object" || firstItem === null) return undefined;

  const productId = (firstItem as Record<string, unknown>).product_id;
  return typeof productId === "string" ? productId : undefined;
}

function enrichCheckoutSessionBody(
  body: Record<string, unknown>,
  user: { id: string; email?: string; user_metadata?: Record<string, unknown> },
  product: { plan: string; cycle: string },
) {
  const metadata =
    typeof body.metadata === "object" && body.metadata !== null
      ? (body.metadata as Record<string, string>)
      : {};
  const customer =
    typeof body.customer === "object" && body.customer !== null
      ? (body.customer as Record<string, unknown>)
      : {};
  const fullName =
    stringValue(user.user_metadata?.full_name) ??
    stringValue(user.user_metadata?.name);

  return {
    ...body,
    metadata: {
      ...metadata,
      user_id: user.id,
      plan: product.plan,
      cycle: product.cycle,
    },
    customer: {
      ...customer,
      ...(user.email && !customer.email ? { email: user.email } : {}),
      ...(fullName && !customer.name ? { name: fullName } : {}),
    },
  };
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}
