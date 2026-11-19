# A canned ACP agent for the docs' images: every prompt gets the same answer, streamed in.
import asyncio

import acp
from acp.schema import AgentCapabilities, InitializeResponse, NewSessionResponse, PromptResponse

REPLY = "Tomorrow: team standup at 09:30, then lunch with Ana at 13:00 (Time Out Market).\n\nFriday is free after 15:00, a good slot for the **dentist**."


class Agent:
    def on_connect(self, conn):
        self.conn = conn

    async def initialize(self, protocol_version, client_capabilities=None, client_info=None, **kwargs):
        return InitializeResponse(protocol_version=acp.PROTOCOL_VERSION, agent_capabilities=AgentCapabilities(load_session=False))

    async def new_session(self, cwd, mcp_servers=None, **kwargs):
        return NewSessionResponse(session_id="docs")

    async def prompt(self, prompt, session_id, **kwargs):
        for i in range(0, len(REPLY), 12):
            await self.conn.session_update(session_id, acp.update_agent_message_text(REPLY[i : i + 12]))
            await asyncio.sleep(0.02)
        return PromptResponse(stop_reason="end_turn")


asyncio.run(acp.run_agent(Agent()))
