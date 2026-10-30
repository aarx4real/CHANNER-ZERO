"""Build shared Godot PBR resources and apply material-only scene overrides.
Run after prepare_pbr_textures.gd and an editor texture import.
This script never edits transforms, meshes, collision data or scene connections.
"""
from pathlib import Path
import json,re,hashlib
ROOT=Path(__file__).resolve().parents[1]
catalog=json.loads((ROOT/'tools/pbr_texture_catalog.json').read_text())
prepared=json.loads((ROOT/'tools/pbr_preparation_report.json').read_text())
settings={
'brown_mud_03':(3.0,.80,0), 'dirt':(3.0,.82,0), 'asphalt_02':(3.0,.78,0),
'cracked_concrete':(3.0,.8,0), 'rocks_ground_03':(4.0,.8,0),
'forrest_ground_01':(3.5,.72,0), 'forest_leaves_02':(3.0,.7,0),
'weathered_planks':(2.0,.78,0), 'rough_wood':(2.0,.72,0), 'old_wood_floor':(3.0,.76,0),
'rusty_metal_02':(2.0,.76,.18), 'rusty_metal_04':(2.0,.75,.65),
'worn_corrugated_iron':(2.5,.72,.3), 'dirty_concrete':(3.0,.8,0),
'concrete_floor_damaged_01':(3.0,.8,0), 'dirty_tiles':(2.5,.78,0),
'damaged_plaster':(2.5,.78,0), 'decrepit_wallpaper':(2.5,.72,0),
'roof_07':(3.0,.78,.05), 'leather_red_02':(.8,.75,0), 'velour_velvet':(1.2,.72,0),
'hessian_380':(.65,.78,0), 'aerial_beach_02':(8,.8,0)}

def material(name,item,world=True,tint=None):
 tile,shade,metal=settings[item['name']]
 color=tint or (shade,shade*.97,shade*.93)
 if item['name']=='velour_velvet' and tint is None:color=(.65,.3,.28)
 lines=['[gd_resource type="StandardMaterial3D" load_steps=%d format=3]'%(1+len(item['maps']))]
 for kind,info in item['maps'].items():lines.append('[ext_resource type="Texture2D" path="%s" id="%s"]'%(info['output'],kind))
 lines+=['[resource]','resource_name = "%s"'%name,'albedo_color = Color(%s, 1)'%(', '.join(map(str,color))),
         'albedo_texture = ExtResource("albedo")','roughness = %s'%('1.0' if 'roughness' in item['maps'] else '0.96'),
         'metallic = '+str(metal),'metallic_specular = 0.35','texture_filter = 5',
         'uv1_triplanar = true','uv1_world_triplanar = '+str(world).lower(),
         'uv1_triplanar_sharpness = 8.0','uv1_scale = Vector3(%s, %s, %s)'%((1/tile,)*3),'cull_mode = 2']
 if name in ['old_wood_floor','dirty_tiles','concrete_floor_damaged_01']:lines+=['grow = true','grow_amount = 0.008']
 if 'normal' in item['maps']:lines+=['normal_enabled = true','normal_scale = 0.65','normal_texture = ExtResource("normal")']
 if 'roughness' in item['maps']:lines+=['roughness_texture = ExtResource("roughness")','roughness_texture_channel = 0']
 if 'metallic' in item['maps']:lines+=['metallic_texture = ExtResource("metallic")','metallic_texture_channel = 0']
 if 'ao' in item['maps']:lines+=['ao_enabled = true','ao_texture = ExtResource("ao")','ao_texture_channel = 0','ao_light_affect = 0.2']
 (ROOT/'materials/pbr'/ (name+'.tres')).write_text('\n\n'.join(lines[:1])+ '\n'+'\n'.join(lines[1:])+'\n')

for item in prepared:
 material(item['name'],item)
 for kind,info in item['maps'].items():
  path=info['output']; cache='res://.godot/imported/'+Path(path).name+'-'+hashlib.md5(path.encode()).hexdigest()+'.ctex'
  # Explicit VRAM BCn compression, mipmaps and GL normal orientation.
  params='''compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=%d
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=%d
detect_3d/compress_to=0
'''%(1 if kind=='normal' else 2,2048 if kind=='albedo' else 1024)
  sidecar='[remap]\nimporter="texture"\ntype="CompressedTexture2D"\npath="%s"\nmetadata={"vram_texture": true}\n\n[deps]\nsource_file="%s"\ndest_files=["%s"]\n\n[params]\n%s'%(cache,path,cache,params)
  (ROOT/path.removeprefix('res://')).with_suffix('.png.import').write_text(sidecar)
by_name={x['name']:x for x in prepared}
material('painted_wood_red',by_name['weathered_planks'],tint=(.42,.13,.095))
material('hessian_burlap_local',by_name['hessian_380'],world=False,tint=(.45,.42,.32))

aliases={'wood':'rough_wood','rust':'rusty_metal_02','steel':'rusty_metal_04','canvas':'hessian_380','curtain':'velour_velvet','seat':'velour_velvet','ground':'brown_mud_03','path':'asphalt_02','blockout_soil':'dirt','blockout_path':'asphalt_02','blockout_bank':'forrest_ground_01','dirt':'dirt','rope':'hessian_380'}
# Only scenes reachable from the current main scene are edited. Old assemblies
# remain intact and reuse their original resources when opened independently.
reachable=set()
def collect(path):
 if path in reachable:return
 reachable.add(path)
 text=(ROOT/path).read_text()
 for m in re.finditer(r'\[ext_resource[^\]]*type="PackedScene"[^\]]*path="res://([^"]+)"[^\]]*\]',text):collect(m[1])
collect('scenes/main.tscn')
assignments=[];changed=[]
for path in sorted(reachable):
 if path.startswith('scenes/player/') or path=='scenes/main.tscn':continue
 p=ROOT/path;original=p.read_text();text=original;new_ext={}
 # Redirect shared material references without touching mesh or shape payloads.
 def redirect(m):
  line=m[0];old=re.search(r'path="res://materials/([^/"]+)\.tres"',line)
  if not old or old[1] not in aliases:return line
  result=re.sub(r' uid="[^"]+"','',line)
  result=result.replace('res://materials/'+old[1]+'.tres','res://materials/pbr/'+aliases[old[1]]+'.tres')
  assignments.append({'scene':path,'target':'shared '+old[1],'material':aliases[old[1]]})
  return result
 text=re.sub(r'\[ext_resource[^\]]+\]',redirect,text)
 blocks=re.split(r'(?=\[node\b)',text)
 for i,block in enumerate(blocks):
  header=block.split('\n',1)[0]
  if 'type="MeshInstance3D"' not in header:continue
  node=re.search(r'name="([^"]+)"',header)[1]
  parent=re.search(r'parent="([^"]+)"',header)
  parent=parent[1] if parent else '.'
  context=(parent+'/'+node).lower(); chosen=None
  filename=p.name
  if node=='Soil':chosen='brown_mud_03'
  elif node=='RoundedBanks':chosen='forest_leaves_02'
  elif 'boundarybank' in context:
   digits=re.findall(r'\d+',node)
   chosen='forrest_ground_01' if digits and int(digits[-1])%4==2 else 'rocks_ground_03'
  elif 'servicebank' in context:
   digits=re.findall(r'\d+',node)
   chosen='dirt' if digits and int(digits[-1])==0 else 'rocks_ground_03' 
  elif 'hubsoilisland' in context:chosen='forrest_ground_01'
  elif 'serviceyard' in context:chosen='dirty_concrete'
  elif 'servicem' in context or 'servicesouthramp' in context or 'servicewestramp' in context:chosen='concrete_floor_damaged_01'
  elif any(x in context for x in ['curtain','valance','backdrop','seatbatch']):chosen='velour_velvet'
  elif 'roof' in context and node=='Mesh':
   chosen='worn_corrugated_iron' if filename=='power_shed.tscn' else ('dirty_concrete' if filename in ['broadcast_control_blockout.tscn','owners_office_blockout.tscn','ending_broadcast_room.tscn'] else 'roof_07')
  elif any(x in context for x in ['tentcap','tentcanopy','canvascanopy','tentpeak','tentskirt','carouselroof']):chosen='hessian_380'
  elif 'floor' in context and node=='Mesh':
   if 'control' in filename:chosen='dirty_tiles'
   elif filename=='power_shed.tscn':chosen='concrete_floor_damaged_01'
   elif any(x in filename for x in ['office','backstage','theatre','stage','ending','ticket']):chosen='old_wood_floor'
  elif 'wall' in context and node=='Mesh':
   if filename=='owners_office_blockout.tscn':chosen='decrepit_wallpaper'
   elif filename in ['broadcast_control_blockout.tscn','ending_broadcast_room.tscn']:chosen='damaged_plaster'
   elif filename in ['ticket_booth.tscn','open_stall_blockout.tscn']:chosen='weathered_planks'
  elif 'stage' in context and node=='Mesh':chosen='old_wood_floor'
  elif any(x in context for x in ['counter','signboard','ticketcounter','arch/','back/','desktop','desk/','shelf']):
   chosen='painted_wood_red' if any(x in context for x in ['counter','signboard','arch/']) else 'weathered_planks'
  elif any(x in context for x in ['generator','panel/','ticketmachine','sealedgate','ironbar','wheel','spoke','gondola','rim','coaster']):chosen='rusty_metal_04'
  elif any(x in context for x in ['foundation','plinth']):chosen='dirty_concrete'
  # Cracked concrete applies to the entrance plaza ramp/paving, retaining asphalt
  # on the main hub and its curved loops.
  if node in ['EntranceWalk','TicketWalk']:chosen='cracked_concrete'
  if not chosen:continue
  rid='PBR_'+chosen
  new_ext[rid]=chosen
  # Idempotent replacement of this node's material-only override.
  block=re.sub(r'^material_override = [^\n]+\n?','',block,flags=re.M)
  lines=block.splitlines();lines.insert(1,'material_override = ExtResource("'+rid+'")');blocks[i]='\n'.join(lines)+'\n'
  assignments.append({'scene':path,'target':parent+'/'+node,'material':chosen})
 text=''.join(blocks)
 declarations=''.join('[ext_resource type="Material" path="res://materials/pbr/%s.tres" id="%s"]\n\n'%(mat,rid) for rid,mat in new_ext.items() if 'id="'+rid+'"' not in text)
 count=declarations.count('[ext_resource')
 if declarations:
  where=text.index('[sub_resource') if '[sub_resource' in text else text.index('[node')
  text=text[:where]+declarations+text[where:]
  if 'load_steps=' in text:text=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+count),text,count=1)
 if text!=original:p.write_text(text);changed.append(path)
# Material-only replacement in the retained, hidden reveal viewmodel.
p=ROOT/'scripts/player/hand_viewmodel.gd';text=p.read_text();text=text.replace('var cloth := _material(Color(0.13, 0.15, 0.115), 1.0)','var cloth: Material = preload("res://materials/pbr/hessian_burlap_local.tres")');p.write_text(text)
# Keep future offline terrain bakes on the same PBR resources.
p=ROOT/'tools/build_hub_ground.gd';text=p.read_text().replace('res://materials/blockout_soil.tres','res://materials/pbr/brown_mud_03.tres').replace('res://materials/blockout_path.tres','res://materials/pbr/asphalt_02.tres').replace('res://materials/blockout_bank.tres','res://materials/pbr/forest_leaves_02.tres');p.write_text(text)
(ROOT/'tools/pbr_material_assignments.json').write_text(json.dumps({'changed_scenes':changed,'assignments':assignments,'material_sets':len(prepared),'material_resources':len(prepared)+2,'reserved_unassigned':['aerial_beach_02','leather_red_02']},indent=2))
print('Created',len(prepared),'PBR sets + 2 variants; material-only edits to',len(changed),'reachable scenes.')

