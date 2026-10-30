"""Offline DWAA -> ZIP EXR conversion using an already-installed FreeImage DLL.
No installation, color transform, normal-channel flip or source modification.
The temporary ZIP files are consumed by prepare_pbr_textures.gd, not the game.
"""
from pathlib import Path
import argparse,ctypes,json
parser=argparse.ArgumentParser()
parser.add_argument('--freeimage-dll',required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
lib=ctypes.WinDLL(str(Path(args.freeimage_dll).resolve()))
lib.FreeImage_LoadU.argtypes=[ctypes.c_int,ctypes.c_wchar_p,ctypes.c_int]
lib.FreeImage_LoadU.restype=ctypes.c_void_p
lib.FreeImage_SaveU.argtypes=[ctypes.c_int,ctypes.c_void_p,ctypes.c_wchar_p,ctypes.c_int]
lib.FreeImage_SaveU.restype=ctypes.c_int
lib.FreeImage_Unload.argtypes=[ctypes.c_void_p]
output=root/'.godot/pbr_exr_zip'; output.mkdir(parents=True,exist_ok=True)
count=0
for item in json.loads((root/'tools/pbr_texture_catalog.json').read_text())['sets']:
 for kind,source in item['maps'].items():
  if not source.endswith('.exr'):continue
  if kind=='metallic' and item['name']!='rusty_metal_04':continue
  target=output/(item['name']+'_'+kind+'.exr')
  bitmap=lib.FreeImage_LoadU(29,str(root/source.removeprefix('res://')),0)
  if not bitmap:raise RuntimeError('EXR decode failed: '+source)
  try:
   if not lib.FreeImage_SaveU(29,bitmap,str(target),4):raise RuntimeError('EXR ZIP export failed: '+source)
  finally:lib.FreeImage_Unload(bitmap)
  count+=1
  print('EXR decoded:',item['name'],kind,flush=True)
print('EXR DECODE COMPLETE:',count,flush=True)
