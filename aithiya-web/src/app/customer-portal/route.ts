import { NextRequest, NextResponse } from "next/server";

import {
  billingErrorResponse,
  createDodoClient,
  getUserSubscription,
  requireSupabaseUser,
} from "../_lib/billing";

export async function GET(request: NextRequest) {
  try {
    const user = await requireSupabaseUser(request);
    const subscription = await getUserSubscription(user.id);
    const customerId = subscription?.dodo_customer_id;

    if (!customerId) {
      return NextResponse.json(
        { error: "No Dodo billing customer is linked to this account yet." },
        { status: 404 },
      );
    }

    const sendEmail =
      request.nextUrl.searchParams.get("send_email") === "true";
    const returnUrl =
      process.env.DODO_CUSTOMER_PORTAL_RETURN_URL ??
      process.env.DODO_PAYMENTS_RETURN_URL;
    const session = await createDodoClient().customers.customerPortal.create(
      customerId,
      {
        send_email: sendEmail,
        ...(returnUrl ? { return_url: returnUrl } : {}),
      },
    );

    return NextResponse.json({
      portal_url: session.link,
    });
  } catch (error) {
    return billingErrorResponse(error);
  }
}
