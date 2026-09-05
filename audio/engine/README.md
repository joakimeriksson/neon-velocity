Drop recorded engine loops here to replace the synthesised ones. Mono 16-bit WAV, 44.1 kHz,
seamless loop, about 1 s. Filenames and reference pitch (the game pitch-shifts from here):

- drone.wav        55 Hz   low hover hum, always on
- turbine.wav      220 Hz  engine note; pitched 0.45x (idle) to 2x (top speed), +boost
- exhaust_low.wav  dark noise rumble, fades in with throttle
- exhaust_high.wav bright noise; throttle/boost, also used for airbrake hiss

Bounce from Logic: Bounce > PCM, WAV, 16-bit, 44100, mono, no dither, then trim to a whole number of cycles.
