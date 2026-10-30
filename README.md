# CHANNEL ZERO

*The audience is still watching.*

Open `project.godot` in Godot 4.7.1 / Forward+ and press F5. WASD moves, Shift sprints, mouse looks, Escape toggles capture, and click recaptures it. Scarecrow hands remain hidden; their original scene and controller are preserved.

## Phase 1 — The First Broadcast

Start with **Investigate the Ticket Booth**. From the outer arch, follow the ticket-office sign left. Go inside, approach its TV and look directly at it within 2.4 metres. **Press E to Interact** appears only while the camera ray reaches that TV without an obstruction. Press E once to display **GUEST NO. 001 — ADMITTED** on the screen.

The nearby lights briefly flicker and restore, and the admission gate opens. This working gate is at the inner edge of the existing entrance court, so the TV remains accessible while it is locked; no existing buildings or paths were moved. Follow **Enter the Carnival** and pass through the middle of the open checkpoint. The objective becomes **Restore Power to the Carnival**. That is the end of this phase; power/fuse gameplay is not implemented yet.

The admission event is once per play session and resets when the scene is restarted. Scarecrow hands remain hidden. No enemies, reveal, new art assets, map rebuild or further material integration is included.

Quick gameplay check:

```powershell
godot --headless --path . --fixed-fps 60 --script res://tests/first_broadcast_validation.gd
```

Run without `--headless` to also test the physical E input and on-screen interaction prompt. The full-map test automatically activates the broadcast before checking the existing routes.

## Active carnival layout

The main scene now instances `scenes/maps/carnival_hub_layout.tscn`. The older map assemblies and all earlier assets remain available, but are not layered underneath the new map.

A roughly 50 × 44 metre open midway surrounds a curved walking loop. Three separate routes branch from it and return by different approaches:

- **A — west:** staggered mirror grounds and Fuse 1.
- **B — east:** a broad prize courtyard, spaced stalls, static mannequin stands and Fuse 2.
- **C — north:** a raised maintenance yard, two gentle ramps, the reused power shed and Fuse 3.

Visit the ticket office after the entrance, explore the hub in any order, then approach the separate outdoor stage on the northwest side. Follow the west path into Broadcast Control, turn through the L-shaped Backstage passage, cross the larger Owner's Office, and enter the retained indoor theatre through its side doorway. The theatre's rear exit connects directly to the new **Ending Broadcast Room**, with its own final television and choice marker.

The hub, branch loops, angled structures, low landscape banks and irregular fairground perimeter replace the previous narrow rectangular layout. Large ride silhouettes and tents are outside the playable boundary. Sky, moon, fog and atmospheric lighting remain in use. No enemies, interactions, story scripting or progression locks have been added.

See [layout notes, dimensions and exact file manifest](docs/hub_layout.md). The overview image is an authoring view with fog temporarily disabled for legibility; this does not change game lighting.

## Validation

```powershell
godot --headless --path . --fixed-fps 60 --script res://tests/channel_zero_validation.gd
```

Use the installed executable's full path if Godot is not on PATH. The test walks the actual player capsule from spawn through every branch loop and to the ending room, then back to the entrance. It also checks raised-yard and stage access, wall collision, hidden hands and retained markers. Run without `--headless` to additionally validate movement, sprint, mouse look and mouse capture. `tests/carnival_validation.gd` is the same test's shared entry point.

The ground and path meshes are baked static assets. Edit `tools/hub_layout_ground.json` and run `--headless --script res://tools/build_hub_ground.gd` to rebake them. No map generation runs during gameplay.

This is a navigable blockout for a future 12–15 minute game. Free exploration alone has no scripted duration. Models, mirror behavior, fuse interactions and television systems remain placeholders.


## PBR materials

The downloaded source packs are integrated into `materials/pbr/`, with 23 base sets and two reusable variants. Prepared textures in `assets/textures/pbr_ready/` use 2K albedo and 1K data maps, VRAM compression, mipmaps and physical-scale projection. Original downloads are preserved as a source-only archive. Layout, lighting, controls and collision remain unchanged.

See [the complete material placement, file and compatibility report](docs/pbr_materials.md). Validate the material library with:

```powershell
godot --headless --path . --script res://tests/pbr_material_validation.gd
```
