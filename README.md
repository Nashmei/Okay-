# EOSignal Probe

Read-only first-stage probe for EO Broker 86.1.0 (`com.eoservices.eobrokerios`).

This build intentionally does **not** place trades, click trade buttons, intercept credentials, or modify market data. It only verifies that an injected dylib loads, shows a movable HUD, and inventories runtime Objective-C classes whose names suggest market/chart/asset/candle/rate/timeframe functionality.

## Build on Linux with Theos

```bash
cd EOSignal
export THEOS=/path/to/theos
make clean
make FINALPACKAGE=1
```

Expected library (path can vary by Theos version):

```text
.theos/obj/debug/EOSignal.dylib
```

or under `.theos/obj/` for a final build.

## Important: non-jailbroken signed IPA

A normal Theos `.deb` will not load on a non-jailbroken phone. Your IPA injection/signing tool must:

1. Copy `EOSignal.dylib` into the app bundle (commonly `Frameworks/`).
2. Add an `LC_LOAD_DYLIB` load command to the main EO Broker executable using the path chosen by your injector, e.g. `@executable_path/Frameworks/EOSignal.dylib`.
3. Re-sign the injected dylib, nested frameworks, and the application with your certificate/provisioning profile.

The exact injection/signing commands depend on the tool you use, so this project does not assume one.

## First test

After installing the re-signed IPA, launch EO Broker. A movable HUD should appear:

```text
EOSignal • Probe
EO Broker detected ✓
Runtime classes: ...
Plot-like: YES/NO
...
```

If the app crashes before UI appears, inspect the device crash log first; do not add market hooks until dylib loading is stable.

## Next stage

Once this probe loads successfully, capture the HUD output / device log while opening SMARTY and BTC/USD. The next build can instrument confirmed runtime objects read-only and map asset/rate/candle/timeframe values before implementing the signal engine.
