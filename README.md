# PCA9685 Custom Chip for Velxio

A [Velxio](https://github.com/davidmonterocrespo24/velxio) **custom chip** that models the
**PCA9685 16-channel 12-bit PWM driver** (the ubiquitous I2C servo driver board),
so you can simulate real multi-servo projects — quadrupeds, hexapods, robot arms —
entirely in the browser before touching hardware.

Neither Velxio nor Wokwi ships a PCA9685 in its component catalog. This chip fills
that gap for Velxio, with a **behaviorally verified** register model compatible
with the Adafruit `Adafruit_PWMServoDriver` Arduino library.

![pins](https://img.shields.io/badge/channels-16-blue)
![protocol](https://img.shields.io/badge/protocol-I2C%20%40%200x40-gold)
![license](https://img.shields.io/badge/license-MIT-green)

## Features

- **I2C slave at `0x40`** with register pointer + auto-increment (honors `MODE1` AI bit)
- **Full phase-register model** — `LEDn_ON` / `LEDn_OFF` 12-bit registers (`0x06–0x45`),
  `ALL_LED_ON/OFF` broadcast registers (`0xFA–0xFD`), `PRESCALE`, `MODE1/MODE2`
- **MODE1 sleep behavior** — outputs hold LOW while the SLEEP bit is set (so the
  Adafruit `begin()` → sleep → prescale → wake sequence behaves like real hardware)
- **Full-ON / Full-OFF** special cases (`ON_H`/`OFF_H` bit 4)
- **Real 50 Hz PWM edges** on 16 output pins — canvas servos see proper pulse widths
  (400-tick frame at 50 µs/tick ≈ ±2° quantization)
- **Verified against a simulated Adafruit_PWMServoDriver transaction sequence**
  (see `test_chip.py` — replicates `begin()`, `setPWMFreq(50)`, and per-channel
  `setPWM()` bursts and asserts the resulting duty cycles)

## Quick start (in Velxio)

1. Open [velxio.dev](https://velxio.dev) or your self-hosted instance
   ([one-command Docker](https://github.com/davidmonterocrespo24/velxio#option-a-docker-prebuilt-image)).
2. Click **Add Component** → search **Custom Chip** → select it.
3. In the Custom Chip Designer, load `pca9685.c` and `pca9685.chip.json`
   (paste or upload).
4. Click **Compile** → **Save & Place**.
5. Wire it up: `SCL`/`SDA` to your board's I2C pins, `PWM0–15` to servo signal pins,
   `VCC`/`GND` to the logic rail.
6. Drive it with `Adafruit_PWMServoDriver` exactly like real hardware:

```cpp
#include <Adafruit_PWMServoDriver.h>
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver(); // 0x40

void setup() {
  pwm.begin();
  pwm.setPWMFreq(50);          // 50 Hz servo frame
  pwm.setPWM(0, 0, 300);       // channel 0, ~1.5 ms pulse
}
```

A ready-to-import `.vlx` demo project (ESP32-S3 + this chip + 8 servos) lives in the
[sesame-robot PCA9685 fork](https://github.com/levkropp/sesame-robot) — see
`simulation/` there.

## Building the WASM yourself

The repo includes a prebuilt `dist/pca9685.wasm`, but building is one command
with [WASI-SDK](https://github.com/WebAssembly/wasi-sdk):

```bash
$WASI_SDK/bin/clang \
  --target=wasm32-unknown-wasip1 -O2 -nostartfiles \
  -Wl,--import-memory -Wl,--export-table -Wl,--no-entry \
  -Wl,--export=chip_setup -Wl,--allow-undefined \
  -I /path/to/velxio/backend/sdk \
  pca9685.c -o dist/pca9685.wasm
```

(these are exactly the flags Velxio's own backend uses — see its
[build & test guide](https://github.com/davidmonterocrespo24/velxio/blob/master/docs/wiki/custom-chips-build-and-test.md))

## Behavioral test

`test_chip.py` instantiates the compiled WASM under
[wasmtime](https://wasmtime.dev/) with a stubbed Velxio host, drives the same
I2C transaction sequence `Adafruit_PWMServoDriver` generates, fires 400 frame
ticks, and asserts the duty cycles:

```
PWM0 HIGH ticks: 14/400  (OFF=150 counts ≈ 732 µs — expected ~14)
PWM1 HIGH ticks: 29/400  (OFF=300 counts ≈ 1465 µs — expected ~29)
ALL TESTS PASSED
```

Run it with `pip install wasmtime` then `python3 test_chip.py` (edit the `WASM`
path constant if you rebuilt).

## Register model

| Register | Implemented | Notes |
|---|---|---|
| `0x00` MODE1 | ✅ | SLEEP bit gates outputs; AI bit controls pointer auto-increment |
| `0x01` MODE2 | ✅ stored | |
| `0x02–0x05` SUBADR/ALLCALLADR | ✅ stored | not otherwise acted on |
| `0x06–0x45` LEDn_ON/OFF_L/H | ✅ | full 12-bit phase model, per channel |
| `0xFA–0xFD` ALL_LED_ON/OFF | ✅ | broadcast to all channels |
| `0xFE` PRE_SCALE | ✅ stored | sim frame is fixed at 20 ms (50 Hz) |
| Read-back | ✅ | all registers readable |

## Limitations (v1)

- **Fixed 0x40 address** (no A0–A5 address-jumper attribute yet)
- **OE pin not modeled** — outputs are always enabled
- **Frame rate fixed at 50 Hz** — PRESCALE is stored but doesn't change the frame
  (canvas servos only care about pulse widths within a 20 ms frame anyway)
- **No external-clock mode**, no SUBADR/ALLCALL addressing behavior

PRs welcome for any of these.

## Related work

- [`bonnyr/wokwi-pca9685-custom-chip`](https://github.com/bonnyr/wokwi-pca9685-custom-chip) —
  the only other PCA9685 sim chip we're aware of, written against Wokwi's Chips API
  (different runtime; this repo is an independent implementation against Velxio's
  `velxio-chip.h` SDK)
- [Velxio custom chips guide](https://github.com/davidmonterocrespo24/velxio/blob/master/docs/CUSTOM_CHIPS.md)
- [Adafruit PCA9685 library](https://github.com/adafruit/Adafruit-PWM-Servo-Driver-Library)
- [NXP PCA9685 datasheet](https://www.nxp.com/docs/en/data-sheet/PCA9685.pdf)

## License

MIT (same as the `velxio-chip.h` SDK it builds against). See [LICENSE](LICENSE).
