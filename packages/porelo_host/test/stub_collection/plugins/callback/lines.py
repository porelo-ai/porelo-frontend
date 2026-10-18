# One JSON line per task for porelo_host, as F131's contract says. A stand-in for porelo-host's own.
import json

from ansible.plugins.callback import CallbackBase

DOCUMENTATION = """
name: lines
type: stdout
short_description: one JSON line per task
description: One JSON line per task, and the stop for the person, as porelo_host reads them.
"""


class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "stdout"
    CALLBACK_NAME = "porelo.host.lines"

    def __init__(self):
        super().__init__()
        self._play = None

    def _say(self, **fields):
        self._display.display(json.dumps(dict(v=1, **fields)))

    def v2_playbook_on_play_start(self, play):
        self._play = play.get_name()

    def v2_playbook_on_task_start(self, task, is_conditional):
        self._say(play=self._play, task=task.get_name(), state="started")

    def _done(self, result, state):
        self._say(play=self._play, task=result._task.get_name(), state=state)

    def v2_runner_on_ok(self, result):
        self._done(result, "changed" if result._result.get("changed") else "ok")

    def v2_runner_on_skipped(self, result):
        self._done(result, "skipped")

    def v2_runner_on_failed(self, result, ignore_errors=False):
        needs = result._task.vars.get("porelo_host_needs")
        if needs:
            self._say(state="waiting", needs=list(needs), msg=result._result.get("msg", ""))
        else:
            self._say(play=self._play, task=result._task.get_name(), state="failed", msg=result._result.get("msg", ""))

    def v2_runner_on_unreachable(self, result):
        self._say(play=self._play, task=result._task.get_name(), state="failed", msg="unreachable")
