"""A1 Voiceflow subclass of pipecat's Gemini Live Vertex AI LLM service.

Diamond inheritance: combines the A1 Voiceflow engine-integration overrides from
:class:`A1 VoiceflowGeminiLiveLLMService` with the Vertex-specific tweaks from
upstream's :class:`GeminiLiveVertexLLMService` (no history config,
``NON_BLOCKING`` tools disabled, service-account credentials).

MRO::

    A1 VoiceflowGeminiLiveVertexLLMService
      -> A1 VoiceflowGeminiLiveLLMService
      -> GeminiLiveVertexLLMService
      -> GeminiLiveLLMService
      -> LLMService
      -> ...
"""

from api.services.pipecat.realtime.gemini_live import A1 VoiceflowGeminiLiveLLMService
from pipecat.services.google.gemini_live.vertex.llm import (
    GeminiLiveVertexLLMService,
)


class A1 VoiceflowGeminiLiveVertexLLMService(
    A1 VoiceflowGeminiLiveLLMService,
    GeminiLiveVertexLLMService,
):
    """Vertex AI variant of Gemini Live with A1 Voiceflow integration quirks."""

    pass


# Guard against MRO regressions: a future refactor that flips inheritance
# order or breaks the diamond would silently bypass the A1 Voiceflow overrides.
_mro = A1 VoiceflowGeminiLiveVertexLLMService.__mro__
assert _mro[1] is A1 VoiceflowGeminiLiveLLMService, (
    f"Expected A1 VoiceflowGeminiLiveLLMService at MRO[1], got {_mro[1]}"
)
assert _mro[2] is GeminiLiveVertexLLMService, (
    f"Expected GeminiLiveVertexLLMService at MRO[2], got {_mro[2]}"
)
del _mro
