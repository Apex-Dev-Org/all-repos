import { Webhooks } from "@dodopayments/nextjs";
import { NextRequest, NextResponse } from "next/server";

import {
  getDodoWebhookSecret,
  recordDodoWebhookPayload,
} from "../../../_lib/billing";

export async function POST(request: NextRequest) {
  const webhookKey = getDodoWebhookSecret();
  if (!webhookKey) {
    return NextResponse.json(
      { error: "Dodo webhook secret is not configured." },
      { status: 500 },
    );
  }

  const handler = Webhooks({
    webhookKey,
    onPayload: async (payload) => {
      console.log("Dodo webhook received:", {
        type: payload.type,
        timestamp: payload.timestamp,
      });
      await recordDodoWebhookPayload(payload);
    },
  });

  return handler(request);
}
