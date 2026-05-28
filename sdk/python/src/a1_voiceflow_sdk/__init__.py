"""A1 Voiceflow SDK — typed builder for voice-AI workflows.

Runtime SDK: fetches the spec catalog from the A1 Voiceflow backend at session
start and validates every `Workflow.add()` call against it. LLMs don't
need to import per-node-type classes — the `type` argument is a string
keyed against the fetched spec catalog.

    from a1_voiceflow_sdk import A1 VoiceflowClient, Workflow

    with A1 VoiceflowClient(base_url="http://localhost:8000", api_key=...) as client:
        wf = Workflow(client=client, name="loan_qualification")
        start = wf.add(type="startCall", name="greeting", prompt="...")
        qualify = wf.add(type="agentNode", name="qualify", prompt="...")
        wf.edge(start, qualify, label="interested", condition="...")
        client.save_workflow(workflow_id=123, workflow=wf)

For typed IDE autocomplete, generate per-node dataclasses via the SDK
codegen (Phase 6) — the runtime and typed SDKs share this same core.
"""

from .client import A1 VoiceflowClient
from .errors import ApiError, A1 VoiceflowSdkError, SpecMismatchError, ValidationError
from .typed._base import TypedNode
from .workflow import NodeRef, Workflow

__all__ = [
    "ApiError",
    "A1 VoiceflowClient",
    "A1 VoiceflowSdkError",
    "NodeRef",
    "SpecMismatchError",
    "TypedNode",
    "ValidationError",
    "Workflow",
]
