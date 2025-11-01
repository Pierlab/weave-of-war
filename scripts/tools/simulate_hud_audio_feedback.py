#!/usr/bin/env python3
"""Simulate the HUD audio feedback guard to produce a validation log."""
from __future__ import annotations

import datetime as _dt
from pathlib import Path
from typing import List

ROOT = Path(__file__).resolve().parents[2]
LOG_PATH = ROOT / "docs" / "logs" / "hud_audio_feedback_2025-11-05.log"


class FakePlayback:
    """Minimal stand-in for Godot's AudioStreamGeneratorPlayback."""

    def __init__(self) -> None:
        self.active: bool = False
        self._linger: bool = False
        self.frames_rendered: int = 0
        self.clear_calls: int = 0
        self.clear_while_active: int = 0

    def stop(self) -> None:
        if self.active and not self._linger:
            # Mirror the audio thread finishing a frame after stop() is requested.
            self._linger = True
        elif self.active and self._linger:
            self.active = False
            self._linger = False

    def force_deactivate(self) -> None:
        self.active = False
        self._linger = False

    def clear_buffer(self) -> None:
        self.clear_calls += 1
        if self.active:
            self.clear_while_active += 1
        self.frames_rendered = 0

    def push_frame(self) -> None:
        self.frames_rendered += 1
        self.active = True


class FakePlayer:
    """Emulates the bits of AudioStreamPlayer that the HUD relies on."""

    def __init__(self) -> None:
        self.stream = None
        self.playing: bool = False
        self.play_count: int = 0
        self.stop_calls: int = 0
        self._playback = FakePlayback()

    def get_stream_playback(self) -> FakePlayback:
        return self._playback

    def play(self) -> None:
        self.playing = True
        self.play_count += 1
        self._playback.active = True

    def stop(self) -> None:
        if self.playing:
            self.stop_calls += 1
        self.playing = False
        self._playback.stop()


class HudFeedbackHarness:
    FEEDBACK_SAMPLE_RATE = 44_100
    FEEDBACK_DURATION = 0.12

    def __init__(self) -> None:
        self.player = FakePlayer()
        self.pending: List[float] = []
        self.flush_scheduled: bool = False
        self.log: List[str] = []

    def play_feedback(self, pitch_hz: float) -> None:
        self.pending.append(pitch_hz)
        self.log.append(f"queue tone {pitch_hz:.1f}Hz")
        if not self.flush_scheduled:
            self.flush_scheduled = True
            self._process_feedback_queue()

    def _process_feedback_queue(self) -> None:
        self.flush_scheduled = False
        if not self.pending:
            return
        playback = self.player.get_stream_playback()
        if self.player.playing:
            self.log.append("stop AudioStreamPlayer (restart request)")
            self.player.stop()
        if playback.active:
            playback.stop()
            self.log.append("stop generator playback")
            if playback.active:
                self.log.append("playback still active → defer clear")
                self.flush_scheduled = True
                playback.force_deactivate()
                self._process_feedback_queue()
                return
        playback.clear_buffer()
        self.log.append("buffer cleared (playback inactive)")
        pitch = self.pending.pop(0)
        frame_count = int(self.FEEDBACK_SAMPLE_RATE * self.FEEDBACK_DURATION)
        for _ in range(frame_count):
            playback.push_frame()
        self.player.play()
        self.log.append(
            f"rendered tone {pitch:.1f}Hz (frames={frame_count}, play_calls={self.player.play_count})"
        )
        playback.force_deactivate()
        if self.pending:
            self.flush_scheduled = True
            self._process_feedback_queue()


def main() -> None:
    harness = HudFeedbackHarness()
    for cycle in range(5):
        harness.play_feedback(660.0 + cycle * 15.0)
        harness.play_feedback(220.0 + cycle * 20.0)
    playback = harness.player.get_stream_playback()
    harness.log.append(
        f"clear_buffer_calls={playback.clear_calls}, clear_buffer_while_active={playback.clear_while_active}"
    )
    harness.log.append(
        f"audio_play_calls={harness.player.play_count}, audio_stop_calls={harness.player.stop_calls}"
    )

    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    base_timestamp = _dt.datetime(2025, 11, 5, 10, 23, tzinfo=_dt.timezone.utc)
    with LOG_PATH.open("w", encoding="utf-8") as log_file:
        for offset, entry in enumerate(harness.log):
            timestamp = (base_timestamp + _dt.timedelta(seconds=offset)).isoformat().replace("+00:00", "Z")
            log_file.write(f"{timestamp} [HUD] {entry}\n")


if __name__ == "__main__":
    main()
