# Announcer lines

`scripts/voice.gd` (autoload `Voice`) plays `<line>.ogg` (or `.wav`) from this folder: the
countdown, pickups, "final lap", finishing places, the circuit's name over the flyover.
Every file is optional; a missing line is simply not said.

The lines are spoken by VoxCPM2 (Apache-2.0) running on the Spark, in a voice designed from a
text description, so they can be committed and shipped. `VOICE` names the voice installed here.

    tools/voice/make_voice.sh audition          # six voices read one line
    tools/voice/make_voice.sh bank <voice>      # every line of tools/voice/lines.txt, 3 takes each
    tools/voice/make_voice.sh render <voice>    # Whisper picks the takes; trimmed and levelled
    tools/voice/make_voice.sh page              # tools/voice/out/audition.html, to choose by ear
    tools/voice/make_voice.sh install <voice>   # into this folder

To add or change a line, edit `tools/voice/lines.txt` and run `bank`, `render` and `install`
again for the installed voice (`REDO=<line>` makes one line again). The voice descriptions and
the line styles are at the top of `tools/voice/spark_voice.py`.
