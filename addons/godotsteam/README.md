# GodotSteam runtime

Pinned GodotSteam **4.22.1 GDExtension**, Steamworks **1.65**, built for Godot 4.4+; loaded and API-checked with Godot **4.7 stable**.

Upstream: https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.22.1-gde
Archive: https://codeberg.org/godotsteam/godotsteam/releases/download/v4.22.1-gde/godotsteam-4.22.1-gdextension-plugin-4.4.zip

This project vendors the original x86_64 Windows and Linux release runtime libraries and Steam API libraries. The same release library is used in editor/debug launches and exports. Native files are unchanged. The `.gdextension` descriptor is scoped to these platforms. GodotSteam's optional editor updater is not needed by this project. License: `license.md`.

Steam test App ID is 480. Auto-initialization runs before rendering so Steam can hook the overlay. Callbacks are explicitly pumped from `steam_lobby.gd`.
