class_name BeatDetector
extends RefCounted
## Offline beat/tempo detection (our own, no third-party code) for in-world dance routines.
## Energy-flux onsets: mono samples -> 1024-sample frames (hop 512) -> energy -> positive flux
## against a ~1 s moving average -> peaks = onsets. Tempo: autocorrelation of the onset envelope over
## 60-180 BPM. Beat grid: phase-aligned to the strongest onsets.
## Input: AudioStreamWAV (16-bit or 8-bit PCM) or a PackedFloat32Array of mono samples.

const FRAME := 1024
const HOP := 512
const BPM_MIN := 60.0
const BPM_MAX := 180.0

## Mono float samples (-1..1) from a PCM AudioStreamWAV. Other formats return empty.
static func samples_from_wav(w: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if w == null: return out
	var d := w.data
	var ch := 2 if w.stereo else 1
	match w.format:
		AudioStreamWAV.FORMAT_16_BITS:
			var n := d.size() / (2 * ch)
			out.resize(n)
			for i in n:
				var acc := 0.0
				for c in ch: acc += d.decode_s16((i * ch + c) * 2) / 32768.0
				out[i] = acc / ch
		AudioStreamWAV.FORMAT_8_BITS:
			var n := d.size() / ch
			out.resize(n)
			for i in n:
				var acc := 0.0
				for c in ch: acc += d.decode_s8(i * ch + c) / 128.0
				out[i] = acc / ch
	return out

static func energy_envelope(s: PackedFloat32Array) -> PackedFloat32Array:
	var env := PackedFloat32Array()
	var i := 0
	while i + FRAME <= s.size():
		var e := 0.0
		for k in FRAME: e += s[i + k] * s[i + k]
		env.append(e / FRAME)
		i += HOP
	return env

## Onset strength per frame (positive energy flux).
static func flux(env: PackedFloat32Array) -> PackedFloat32Array:
	var f := PackedFloat32Array(); f.resize(env.size())
	for i in range(1, env.size()): f[i] = maxf(env[i] - env[i - 1], 0.0)
	return f

## Analyze. Returns {"bpm", "beats": [sec...], "onsets": [sec...], "duration", "confidence"}.
static func analyze_samples(s: PackedFloat32Array, mix_rate := 44100.0, sensitivity := 1.5) -> Dictionary:
	var dur := s.size() / maxf(mix_rate, 1.0)
	var env := energy_envelope(s)
	var fl := flux(env)
	var fps := mix_rate / HOP
	var res := {"bpm": 0.0, "beats": [], "onsets": [], "duration": dur, "confidence": 0.0}
	if fl.size() < 8: return res
	# onsets: local peaks above sensitivity x the ~1 s moving mean
	var win := maxi(int(fps), 4)
	var onsets: Array = []
	var last := -999
	for i in range(1, fl.size() - 1):
		var a := maxi(0, i - win); var b := mini(fl.size(), i + win)
		var mean := 0.0
		for k in range(a, b): mean += fl[k]
		mean /= (b - a)
		if fl[i] > mean * sensitivity and fl[i] >= fl[i - 1] and fl[i] >= fl[i + 1] and fl[i] > 1e-6 and i - last > int(fps * 0.1):
			onsets.append(i); last = i
	res["onsets"] = onsets.map(func(i): return i / fps)
	# tempo: autocorrelation of the flux over lags for 60-180 BPM
	var lo := int(fps * 60.0 / BPM_MAX); var hi := int(fps * 60.0 / BPM_MIN)
	var ac := {}
	var best_lag := 0; var best := 0.0; var total := 0.0
	for lag in range(maxi(lo - 1, 1), mini(hi + 1, fl.size() - 1) + 1):
		var acc := 0.0
		for i in range(lag, fl.size()): acc += fl[i] * fl[i - lag]
		acc /= float(fl.size() - lag)   # unbiased: longer lags have fewer terms
		ac[lag] = acc
		if lag >= lo and lag <= hi:
			total += acc
			if acc > best: best = acc; best_lag = lag
	if best_lag == 0: return res
	# octave check: a steady beat also correlates at 2x its period (half tempo). Prefer the faster
	# tempo when its lag (+-1 frame) is nearly as strong.
	var half := int(round(best_lag / 2.0))
	if half >= lo:
		var hb := 0.0; var hl := half
		for c in [half - 1, half, half + 1]:
			if ac.has(c) and ac[c] > hb: hb = ac[c]; hl = c
		if hb >= 0.6 * best: best_lag = hl; best = hb
	# parabolic interpolation around the peak lag (frame resolution is coarse: ~23 ms)
	var l := best_lag as float
	if ac.has(best_lag - 1) and ac.has(best_lag + 1):
		var y0: float = ac[best_lag - 1]; var y2: float = ac[best_lag + 1]
		var den := y0 - 2.0 * best + y2
		if absf(den) > 1e-12: l += clampf(0.5 * (y0 - y2) / den, -0.5, 0.5)
	var bpm := 60.0 * fps / l
	res["bpm"] = snappedf(bpm, 0.1)
	res["confidence"] = clampf(1.0 - (total / maxf(hi - lo + 1, 1)) / maxf(best, 1e-12), 0.0, 1.0)   # peak vs mean
	# beat grid aligned to the first strong onset
	var period := 60.0 / bpm
	var t0: float = res["onsets"][0] if not res["onsets"].is_empty() else 0.0
	while t0 - period >= 0.0: t0 -= period
	var beats: Array = []
	var t := t0
	while t < dur: beats.append(snappedf(t, 0.001)); t += period
	res["beats"] = beats
	return res

static func analyze_wav(w: AudioStreamWAV, sensitivity := 1.5) -> Dictionary:
	return analyze_samples(samples_from_wav(w), float(w.mix_rate) if w else 44100.0, sensitivity)

## Test/demo helper: a click track (short decaying noise bursts) at `bpm`.
static func click_track(bpm: float, seconds: float, mix_rate := 22050.0) -> PackedFloat32Array:
	var s := PackedFloat32Array(); s.resize(int(seconds * mix_rate))
	var period := int(mix_rate * 60.0 / bpm)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var i := 0
	while i < s.size():
		for k in mini(int(mix_rate * 0.03), s.size() - i):
			s[i + k] = rng.randf_range(-1.0, 1.0) * exp(-k / (mix_rate * 0.006))
		i += period
	return s
