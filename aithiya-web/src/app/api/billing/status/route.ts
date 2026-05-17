import { NextRequest, NextResponse } from "next/server";

import {
  billingErrorResponse,
  getConfiguredDodoProduct,
  getUserSubscription,
  requireSupabaseUser,
} from "../../../_lib/billing";

export async function GET(request: NextRequest) {
  try {
    const user = await requireSupabaseUser(request);
    const subscription = await getUserSubscription(user.id);
    const configuredProduct = getConfiguredDodoProduct(
      subscription?.dodo_product_id,
    );

    return NextResponse.json({
      user_id: user.id,
      plan: subscription?.plan ?? "free",
      status: subscription?.status ?? null,
      cycle:
        configuredProduct?.cycle ??
        stringValue(subscription?.metadata?.cycle) ??
        null,
      current_period_end: subscription?.current_period_end ?? null,
      cancel_at_next_billing_date:
        subscription?.cancel_at_next_billing_date ?? false,
      has_billing_customer: Boolean(subscription?.dodo_customer_id),
      dodo_product_id: subscription?.dodo_product_id ?? null,
    });
  } catch (error) {
    return billingErrorResponse(error);
  }
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}
