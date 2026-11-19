# The suites' stand-in ACP agent, on the SDK's agent side: argv names its session and, optionally, a behaviour; otherwise the prompt picks the answer.
# It leaves traces in $XDG_RUNTIME_DIR for the cases: `<session>-log` (initialize, load), and `trapped` when a turn is cancelled.
import asyncio
import os
import sys

import acp
from acp.schema import (
    AgentCapabilities,
    InitializeResponse,
    LoadSessionResponse,
    NewSessionResponse,
    PermissionOption,
    PromptResponse,
    ToolCallUpdate,
)

SESSION = sys.argv[1]
BEHAVIOUR = sys.argv[2] if len(sys.argv) > 2 else ""
RUN = os.environ["XDG_RUNTIME_DIR"]


def trace(line):
    with open(f"{RUN}/{SESSION}-log", "a") as log:
        log.write(line + "\n")


def write(name, line):
    with open(f"{RUN}/{name}", "w") as file:
        file.write(line + "\n")


class Agent:
    def on_connect(self, conn):
        self.conn = conn
        self.cancelled = asyncio.Event()

    async def initialize(
        self, protocol_version, client_capabilities=None, client_info=None, **kwargs
    ):
        trace("initialize")
        return InitializeResponse(
            protocol_version=acp.PROTOCOL_VERSION,
            agent_capabilities=AgentCapabilities(load_session=True),
        )

    async def new_session(self, cwd, mcp_servers=None, **kwargs):
        return NewSessionResponse(session_id=SESSION)

    async def load_session(self, cwd, session_id, mcp_servers=None, **kwargs):
        trace("load " + session_id)
        await self.say(session_id, "from before")
        return LoadSessionResponse()

    async def say(self, session_id, text):
        await self.conn.session_update(session_id, acp.update_agent_message_text(text))

    async def prompt(self, prompt, session_id, **kwargs):
        text = " ".join(
            block.text for block in prompt if getattr(block, "type", "") == "text"
        )
        if BEHAVIOUR == "approve":
            options = [
                PermissionOption(option_id="allow", name="Allow", kind="allow_once"),
                PermissionOption(option_id="deny", name="Deny", kind="reject_once"),
            ]
            answer = await self.conn.request_permission(
                session_id=session_id,
                tool_call=ToolCallUpdate(tool_call_id="t1", title="rm"),
                options=options,
            )
            await self.say(
                session_id, getattr(answer.outcome, "option_id", "cancelled")
            )
        elif BEHAVIOUR == "work":
            await self.conn.session_update(
                session_id, acp.start_tool_call("t1", "thinking")
            )
            await self.cancelled.wait()
            write("trapped", "stopped")
            return PromptResponse(stop_reason="cancelled")
        elif text.startswith("pick"):
            await self.say(session_id, "Qual?\n1. a\n2. b")
        elif "table" in text:
            await self.say(session_id, "| dia | o quê |\n|---|---|\n| seg | Café |\n")
        elif text == "stream":
            for part in ("one ", "two ", "three"):
                await self.say(session_id, part)
                await asyncio.sleep(0.4)
        elif text == "tool":
            await self.conn.session_update(
                session_id, acp.start_tool_call("t1", "mcp__agenda__add_event")
            )
            await self.say(session_id, "added")
        else:
            await self.say(session_id, text)
        if text == "bye":
            asyncio.get_running_loop().call_later(0.2, os._exit, 0)
        return PromptResponse(stop_reason="end_turn")

    async def cancel(self, session_id, **kwargs):
        self.cancelled.set()


asyncio.run(acp.run_agent(Agent()))
