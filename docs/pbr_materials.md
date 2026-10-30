# CHANNEL ZERO — PBR integration

## Result

The source archive contains **23 material sets**. The reusable library contains **25 StandardMaterial3D resources**: those 23 sets, a painted red wood variant, and a local-space burlap variant. Runtime preparation produced **70 textures**: 23 albedos, 23 OpenGL normals, 22 roughness maps, one metallic map, and one AO map.

Only material references and mesh material overrides changed in 28 reachable map/prop/detail scenes. The main scene, environment lighting, player controller, camera controls, project settings, scene connections, transforms, collision shapes, meshes and navigation routes were preserved. The retained hand script changes only the cloth material assignment; the hands remain hidden during ordinary play.

## Material placements

All resources below live in `materials/pbr/`. World-space triplanar projection keeps scale consistent on differently sized primitive and baked meshes. Cloth on the camera-relative hand placeholders uses the separate local-space variant so the texture follows the character.

| Material set | Placement |
| --- | --- |
| `brown_mud_03` | Main fairground soil mesh / muddy carnival ground |
| `dirt` | Natural soil on the service-yard bank |
| `asphalt_02` | Main hub ring, curved branch paths and connecting outdoor walks |
| `cracked_concrete` | Entrance approach and ticket-office pavement |
| `rocks_ground_03` | Rocky perimeter banks and service-yard surroundings |
| `forrest_ground_01` | Alternating overgrown perimeter banks and central soil island; actual pack spelling retained |
| `forest_leaves_02` | Rounded landscape banks between branch routes |
| `weathered_planks` | Ticket-office and stall boards, desk/shelf surfaces and selected layered woodwork |
| `rough_wood` | Structural supports, fences, wall timber and shared wood detail batches |
| `old_wood_floor` | Indoor theatre/stage, office, backstage, ending-room and ticket-office floors |
| `rusty_metal_02` | Shared rusted fixtures, straps, poles and metal detail batches |
| `rusty_metal_04` | Generators, electrical panels, ticket machines, ride spokes/rims and rusted equipment; metallic map enabled |
| `worn_corrugated_iron` | Power Shed roof |
| `roof_07` | Suitable retained building roofs; flat control/office/ending-room ceiling slabs use concrete instead |
| `dirty_concrete` | Foundations, television plinths, service-yard platform and flat room roof/ceiling slabs |
| `concrete_floor_damaged_01` | Power Shed flooring and service ramps |
| `dirty_tiles` | Television Control Room floor, including its supplied AO map |
| `damaged_plaster` | Broadcast Control and Ending Broadcast Room walls |
| `decrepit_wallpaper` | Owner's Office walls |
| `velour_velvet` | Theatre upholstery, curtains, stage drapery and backdrops |
| `hessian_380` | Canvas canopies, ragged cloth and rope detail; local-space variant on retained hidden Scarecrow burlap |
| `leather_red_02` | Available in the library; not forced onto the current character because no suitable leather accessory exists |
| `aerial_beach_02` | Available in the library; beach sand is unsuitable for the current carnival surfaces |

`painted_wood_red.tres` keeps the entrance/counter/sign wood in the existing muted red palette. `hessian_burlap_local.tres` provides camera-relative burlap for the original reveal viewmodel. Decorative glass/screens, claws, straw and surfaces where the downloads were unsuitable retain their previous materials.

## Source inspection and map handling

- Every set was discovered from the actual folders and filenames. The source folder is spelled `forrest_ground_01`, rather than the requested example `forest_ground_01`.
- All 23 albedos and OpenGL normal maps were found. Leather's albedo is the visually inspected `leather_red_02_coll1_4k.png`; forest leaves uses `_diffuse_4k.jpg`.
- `brown_mud_03` has no roughness map. It uses a deliberately matte 0.96 roughness fallback. Its specular map was not misinterpreted as roughness.
- Only `dirty_tiles` includes AO. Other materials do not fabricate AO maps.
- Only the supplied `rusty_metal_04` metallic mask is used. Metallic remains zero for dirt, wood, stone and cloth; other aged metal surfaces use restrained scalar values.
- The cloth packs' specular-IOR, anisotropy, rotation, mask and metal maps are not directly interchangeable with Godot's metallic/roughness and anisotropy-flow inputs, so they are retained in the source archive without blind wiring.
- Displacement maps are retained but unused. No displacement-as-normal, parallax, tessellation or geometry changes were introduced.
- Godot's built-in EXR decoder rejected the source DWAA compression. An **already installed FreeImage 3.18 decoder** successfully decoded the 37 EXRs needed for normal/scalar inputs. They were transcoded without color transforms to temporary ZIP EXRs, then prepared as linear data PNGs. GL normal Y is not inverted. No decoder installation or runtime dependency was added.
- All original downloaded images were verified byte-for-byte unchanged. The archive contains an added `.gdignore` to prevent duplicate 4K/HDR imports. Active materials reference the prepared copies, never the ignored source files.

## Performance and surface scale

Albedo copies are limited to 2048 pixels; normal, roughness, metallic and AO copies are limited to 1024. Original downloads are untouched. Explicit VRAM compression, high-quality BCn/BPTC import, mipmaps and anisotropic material filtering are enabled. Automatic 3D import overrides are disabled so a first render cannot switch the textures to VRAM-uncompressed storage. Materials share their texture resources instead of duplicating them.

Texture tiles use physical dimensions suited to each surface, typically 2–4 metres for environment surfaces and 0.65–1.2 metres for burlap/velvet. Tints and specular strengths are restrained for the existing moonlit scene. World projection avoids stretched one-tile UVs on oversized blockout walls and floors.

The original indoor floor slabs are coplanar with the fairground floor. The floor PBR materials use Godot's material `grow` feature with an **8 mm render-only normal offset**, avoiding z-fighting while leaving stored meshes, collision, scene transforms and navigation unchanged. This is not displacement mapping.

## Files

Created:

- `materials/pbr/*.tres` — 25 shared material resources.
- `assets/textures/pbr_ready/<set>/*.png` — 70 prepared runtime textures and their `.import` settings.
- `assets/textures/downloaded_pbr/.gdignore` — source-only archive marker.
- `tools/pbr_texture_catalog.json` — exact source inventory.
- `tools/pbr_preparation_report.json` — source/output paths, dimensions, formats and source samples.
- `tools/pbr_material_assignments.json` — exact scene/node assignment manifest.
- `tools/transcode_pbr_exr.py`, `tools/prepare_pbr_textures.gd`, `tools/integrate_pbr.py` — offline conversion/integration tools.
- `tests/pbr_material_validation.gd` — resource, map-path, resolution, compression and assignment checks.
- `docs/pbr_materials.md` — this report.

Modified existing files:

- `scripts/player/hand_viewmodel.gd` — cloth material only.
- `tools/build_hub_ground.gd` — future baked terrain material references only.
- `README.md` — current PBR notes and validation command.

Modified scene resources, with material-only changes:

- `scenes/detail/crate_detail.tscn`
- `scenes/detail/entrance_detail.tscn`
- `scenes/detail/lamp_detail.tscn`
- `scenes/detail/office_detail.tscn`
- `scenes/detail/shed_detail.tscn`
- `scenes/detail/theatre_detail.tscn`
- `scenes/maps/backstage_elbow.tscn`
- `scenes/maps/broadcast_control_blockout.tscn`
- `scenes/maps/carnival_entrance.tscn`
- `scenes/maps/carnival_hub_layout.tscn`
- `scenes/maps/carnival_story_quarter.tscn`
- `scenes/maps/ending_broadcast_room.tscn`
- `scenes/maps/final_theatre_foundation.tscn`
- `scenes/maps/funhouse_grounds.tscn`
- `scenes/maps/hub_distant_scenery.tscn`
- `scenes/maps/hub_ground.tscn`
- `scenes/maps/main_carnival_stage.tscn`
- `scenes/maps/owners_office_blockout.tscn`
- `scenes/maps/power_fuse_foundation.tscn`
- `scenes/maps/power_shed.tscn`
- `scenes/maps/prize_courtyard.tscn`
- `scenes/maps/puppet_theatre.tscn`
- `scenes/maps/theatre_office_doorway.tscn`
- `scenes/maps/ticket_booth.tscn`
- `scenes/props/crate.tscn`
- `scenes/props/lamp.tscn`
- `scenes/props/open_stall_blockout.tscn`
- `scenes/props/television_placeholder.tscn`

Godot generates `.gd.uid` metadata for new GDScript tools/tests. Generated import cache, conversion scratch files and capture logs are confined to ignored `.godot/` data. Temporary ZIP EXRs were removed after preparation to avoid retaining another large texture archive.

## Reproducing the offline preparation

The runtime textures are already committed as normal project files; no preparation tool or external library is needed to run the game. To rebuild from source, supply an existing compatible FreeImage DLL to:

```powershell
python tools/transcode_pbr_exr.py --freeimage-dll "<existing FreeImage.dll path>"
godot --headless --path . --script res://tools/prepare_pbr_textures.gd
python tools/integrate_pbr.py
godot --headless --path . --editor --import --quit
```

Run the integration step again after rebuilding an older decorative scene or terrain bake if its node overrides were regenerated. It edits only the reachable scene material assignments.

## Validation and remaining limits

```powershell
godot --headless --path . --script res://tests/pbr_material_validation.gd
godot --headless --path . --fixed-fps 60 --script res://tests/channel_zero_validation.gd
```

The first validates all 25 material resources, every prepared texture path, resolution limits, VRAM compression/mipmaps, important scene assignments and the hidden viewmodel. The second validates the playable hub, all three branches, story route, ending room and return route. Run the existing carnival validation without `--headless` for movement/look/capture checks.

These surfaces add real texture detail, but the existing blockout still has hard silhouettes, thin roof slabs, simple curtain geometry, flat terrain patches and sharp material boundaries. Detailed bevels, wall thickness, terrain blending, natural cloth folds and broken silhouettes require better meshes or terrain work in a later phase. No downloaded set was used as a background image or to disguise missing 3D geometry.
