# Miku Avatar — Unity/ChatDollKit migration

This directory replaces the failed WebView/three-vrm renderer with a Unity
renderer based on the model-control layer from ChatDollKit 0.8.16.

The migration is deliberately split into two gates:

1. Build `MikuAvatar` as a standalone Android APK and verify the Miku VRM 1.0
   model, blink, emotion and mouth cues on a physical device.
2. Only after gate 1 passes, export Unity as an Android library and replace the
   Flutter `VrmAvatar` widget.

Why there is custom VRM code: ChatDollKit 0.8.16's bundled VRM extension uses
the VRM 0.x `VRMBlendShapeProxy` API. This project model is VRM 1.0, so the
components in `Assets/Mikudayo/Runtime/Vrm10` adapt ChatDollKit's interfaces to
UniVRM10 expressions.

## Pinned upstream versions

- ChatDollKit: 0.8.16 (`eb5ad8f`), Apache-2.0
- UniVRM: 0.127.2, MIT
- UniTask: 2.5.4, MIT
- uLipSync: 3.1.0, MIT
- Unity: 6000.3.3f1 (Built-in Render Pipeline; do not convert this project to
  URP because the pinned UniVRM/ChatDollKit setup is built around Built-in RP)

The small vendored `Assets/ChatdollKit/Scripts/Model` directory is copied
unchanged from ChatDollKit 0.8.16. See `THIRD_PARTY_NOTICES.md` and the adjacent
upstream `LICENSE` file.

## First setup and Android smoke test

1. Install Unity 6000.3.3f1 with Android Build Support, SDK/NDK tools and
   OpenJDK through Unity Hub.
2. Open `unity/MikuAvatar`. Wait for Package Manager to resolve Git packages.
3. Run menu `Mikudayo > Rebuild Miku Avatar Scene`.
4. Open `Assets/Mikudayo/Scenes/MikuAvatar.unity` and press Play. The automatic
   demo cycles emotions and synthetic mouth cues.
5. Run `Mikudayo > Build Android Smoke-Test APK`.

Output (ignored by Git):

`unity/MikuAvatar/Builds/Android/MikuAvatar-debug.apk`

The copied `Assets/Mikudayo/Models/Miku.vrm` must stay private and must not be
distributed as a standalone model. It is present only because the model's
license permits personal use and integration into software.
