# The suites' stand-in ACP agent, on the SDK's agent side: argv names its session and, optionally, a behaviour; otherwise the prompt picks the answer.
# It leaves traces in $XDG_RUNTIME_DIR for the cases: `<session>-log` (initialize, load, resume, a permission's outcome), and `trapped` when a turn is cancelled; it lists two conversations, a page each, and a load replays one exchange, but of `gone`, which fails.
import asyncio
import os
import sys

import acp
from acp.schema import (
    AgentCapabilities,
    InitializeResponse,
    ListSessionsResponse,
    LoadSessionResponse,
    NewSessionResponse,
    PermissionOption,
    PromptResponse,
    ResumeSessionResponse,
    SessionCapabilities,
    SessionInfo,
    SessionListCapabilities,
    SessionResumeCapabilities,
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
            # `resume` resumes but cannot load.
            agent_capabilities=AgentCapabilities(
                load_session=BEHAVIOUR != "resume",
                session_capabilities=SessionCapabilities(
                    list=SessionListCapabilities(),
                    resume=SessionResumeCapabilities()
                    if BEHAVIOUR == "resume"
                    else None,
                ),
            ),
        )

    async def new_session(self, cwd, mcp_servers=None, **kwargs):
        return NewSessionResponse(session_id=SESSION)

    async def load_session(self, cwd, session_id, mcp_servers=None, **kwargs):
        trace("load " + session_id)
        if session_id == "gone":
            raise acp.RequestError.resource_not_found(session_id)
        await self.conn.session_update(
            session_id, acp.update_user_message_text("what was it?")
        )
        await self.say(session_id, "from before")
        return LoadSessionResponse()

    async def resume_session(self, cwd, session_id, mcp_servers=None, **kwargs):
        trace("resume " + session_id)
        return ResumeSessionResponse()

    async def list_sessions(self, cwd=None, cursor=None, **kwargs):
        # A page each, as an agent paging at one would list them.
        if cursor == "2":
            return ListSessionsResponse(
                sessions=[SessionInfo(session_id="older", cwd=cwd or "/")]
            )
        return ListSessionsResponse(
            sessions=[
                SessionInfo(
                    session_id="old",
                    cwd=cwd or "/",
                    title="An old question",
                    updated_at="2026-11-01T10:00:00Z",
                )
            ],
            next_cursor="2",
        )

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
            outcome = getattr(answer.outcome, "option_id", "cancelled")
            trace("permission " + outcome)
            await self.say(session_id, outcome)
        elif BEHAVIOUR == "twice":
            # Two at once, the second offering to allow only for good.
            asked = [
                ("one", [("allow", "allow_once"), ("deny", "reject_once")]),
                ("two", [("always", "allow_always"), ("deny", "reject_once")]),
            ]
            answers = await asyncio.gather(
                *(
                    self.conn.request_permission(
                        session_id=session_id,
                        tool_call=ToolCallUpdate(tool_call_id=title, title=title),
                        options=[
                            PermissionOption(option_id=id, name=id, kind=kind)
                            for id, kind in options
                        ],
                    )
                    for title, options in asked
                )
            )
            await self.say(
                session_id,
                " ".join(
                    getattr(answer.outcome, "option_id", "cancelled")
                    for answer in answers
                ),
            )
        elif BEHAVIOUR in ("late", "deaf") and text == "slow":
            # `late` still speaks after a cancel, `deaf` never answers it.
            await self.conn.session_update(
                session_id, acp.start_tool_call("t1", "thinking")
            )
            if BEHAVIOUR == "deaf":
                await asyncio.sleep(30)
            await self.cancelled.wait()
            await asyncio.sleep(0.5)
            await self.say(session_id, "late")
            return PromptResponse(stop_reason="cancelled")
        elif BEHAVIOUR == "late":
            # Slower than the stopped turn's last words, so they would land in it.
            await asyncio.sleep(1)
            await self.say(session_id, text)
        elif BEHAVIOUR == "work":
            await self.conn.session_update(
                session_id, acp.start_tool_call("t1", "thinking")
            )
            await self.cancelled.wait()
            write("trapped", "stopped")
            return PromptResponse(stop_reason="cancelled")
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


asyncio.run(acp.run_agent(Agent(), use_unstable_protocol=True))
