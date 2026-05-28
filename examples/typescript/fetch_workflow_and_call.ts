// Fetch a workflow by ID and place a test phone call using the TypeScript SDK.
//
// Requirements:
//   npm install @a1-voiceflow/sdk
//
// Environment variables:
//   DOGRAH_API_ENDPOINT  - A1 Voiceflow API base URL (e.g. http://localhost:8000)
//   DOGRAH_API_TOKEN     - API token sent as X-API-Key
//
// Run:
//   npx tsx fetch_workflow_and_call.ts

import { A1 VoiceflowClient } from "@a1-voiceflow/sdk";

// Numeric workflow ID to fetch and call with.
const WORKFLOW_ID = 1;
// E.164 destination number — set this to the number you want to call.
const PHONE_NUMBER = "+11187619471";

async function main(): Promise<void> {
    const apiEndpoint = process.env.DOGRAH_API_ENDPOINT ?? "http://localhost:8000";
    const apiToken = process.env.DOGRAH_API_TOKEN;

    if (!apiToken) throw new Error("DOGRAH_API_TOKEN is required");

    const client = new A1 VoiceflowClient({
        baseUrl: apiEndpoint,
        apiKey: apiToken,
    });

    const workflow = await client.getWorkflow(WORKFLOW_ID);
    console.log(
        `Fetched workflow ${workflow.id}: ${JSON.stringify(workflow.name)} (status=${workflow.status})`,
    );

    const response = await client.testPhoneCall({
        body: {
            workflow_id: WORKFLOW_ID,
            phone_number: PHONE_NUMBER,
        },
    });
    console.log("Call initiated:", response);
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
