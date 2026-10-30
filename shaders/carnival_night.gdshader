shader_type sky;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7))) * 43758.5453); }
float noise(vec3 p) {
 vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void sky() {
 vec3 direction = normalize(EYEDIR);
 vec3 moon_direction = normalize(vec3(0.26,0.48,-0.84));
 float distance_to_moon = length(direction-moon_direction);
 float disk = 1.0-smoothstep(0.063,0.065,distance_to_moon);
 float halo = exp(-distance_to_moon*12.0)*0.13;
 float horizon = pow(1.0-max(direction.y,0.0),3.0);
 vec3 color = mix(vec3(0.009,0.016,0.033),vec3(0.065,0.085,0.115),horizon);
 float craters = noise(direction*210.0)*0.38 + noise(direction*75.0)*0.35;
 color += vec3(0.45,0.58,0.82)*halo;
 color = mix(color,vec3(0.68,0.76,0.9)*(0.6+craters),disk);
 vec2 cloud_uv = direction.xz / max(direction.y+0.3,0.2);
 float warp = sin(cloud_uv.x*2.1+sin(cloud_uv.y*1.8));
 float clouds = sin(cloud_uv.y*4.0+warp*2.0)*0.5 + sin(cloud_uv.x*5.0-cloud_uv.y*3.0)*0.18;
 float cloud_cover = smoothstep(-0.25,0.65,clouds)*smoothstep(0.02,0.25,direction.y);
 color = mix(color,vec3(0.021,0.031,0.048)+halo*0.15,cloud_cover*0.68);
 COLOR = color;
}
