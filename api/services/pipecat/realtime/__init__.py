"""A1 Voiceflow-specific subclasses of pipecat realtime LLM services.

Each subclass wires A1 Voiceflow engine integration quirks (user-mute gating,
TTSSpeakFrame greeting trigger, node-transition handling, function-call
deferral, etc.) onto the corresponding pipecat realtime service.

The pipecat fork's services stay close to upstream — A1 Voiceflow behavior lives
here.
"""
