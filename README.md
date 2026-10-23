# Hover Build

Hover Build is a fork of [Mouse-over Construction](https://codeberg.org/raiguard/MouseOverConstruction) by raiguard, a Factorio mod easing the process of building blueprints before construction bots have been researched.

## New in Hover Build

This fork adds automatic item insertion on top of the original mod:

- **Module insertion** — fills module requests attached to ghosts as they are built, and fulfills pending module changes on existing entities (for example, from upgrade planners or pasted blueprint settings). Removed modules are returned to your inventory. Enabled by default.
- **Ammo insertion** — fills ammo requests from your inventory. Disabled by default.
- **Fuel insertion** — fills fuel requests from your inventory. Disabled by default.

All three are controlled by per-player runtime settings, so they can be toggled without restarting the game. Hover Build cannot be enabled alongside the original MouseOverConstruction mod.

## Features

When mouse-over construction is enabled via the shortcut button or hotkey (default `Shift + Y`), the following features are available for entities within your reach range:

### Construction

Ghosts within range will be automatically revived if you have the proper materials in your inventory.

![](resources/construction.gif)

### Item insertion

While mouse-over construction is active, module requests attached to ghosts are filled from your inventory as the ghost is built. Pending item requests on existing entities are also filled when you hover over them, including module changes made by upgrade planners or by pasting blueprint settings over existing entities. Items removed from existing entities are returned to your inventory.

Module insertion is enabled by default. Ammo and fuel insertion can be enabled separately in the mod settings.

### Upgrading

Entities within range that are marked for upgrade will be automatically upgraded if you have the proper materials in your inventory.

![](resources/upgrading.gif)

### Repairing

Entities within range that have less than full health will be automatically repaired if you are holding a repair pack.

![](resources/repairing.gif)

### Deconstruction

Entities within range that are marked for deconstruction will be automatically mined.

![](resources/deconstruction.gif)
