shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.2, 0.1, 0.05, 1.0);
uniform float grain = 1.0;
uniform float roughness_value = 0.9;
// 0 general, 1 wood, 2 paint, 3 oxidized metal, 4 cloth, 5 earth, 6 paving.
uniform int surface_kind = 0;
varying vec3 world_position;
float hash(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.yzx + 33.33); return fract((p.x + p.y) * p.z); }
float noise(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec3 p=world_position;
 float wear=noise(p*7.0*grain), dirt=noise(p*0.9);
 vec3 color=base_color.rgb*(0.6+wear*0.35+dirt*0.3);
 float rough=roughness_value;
 if (surface_kind==1 || surface_kind==2) {
  float fibers=noise(p*vec3(38.0,1.4,38.0));
  vec3 timber=vec3(0.19,0.125,0.067)*(0.86+fibers*0.25);
  color=surface_kind==1 ? mix(color,timber,0.35) : mix(color,timber,smoothstep(0.65,0.79,noise(p*18.0))*0.65);
  rough=mix(0.98,rough,wear);
 } else if (surface_kind==3) {
  color=mix(color,vec3(0.20,0.065,0.023),smoothstep(0.5,0.75,wear)*0.28);
  rough=mix(0.55,0.98,wear);
 } else if (surface_kind==4) {
  float weave=sin(p.x*210.0)*sin(p.y*210.0)*0.03;
  color *= 0.86+weave+wear*0.2;
 } else if (surface_kind==6) {
  vec2 uv=p.xz/1.3;
  vec2 edge=abs(fract(uv+0.06*sin(uv.yx*2.5))-0.5);
  float joint=smoothstep(0.475,0.493,max(edge.x,edge.y));
  color*=1.0-joint*0.63;
  rough=clamp(0.72+dirt*0.22,0.0,1.0);
 }
 ALBEDO=color;
 ROUGHNESS=rough;
}
