varying highp vec4 var_position;
varying highp vec4 var_world_position;
varying mediump vec3 var_normal;
varying mediump vec3 var_world_normal;
varying mediump vec2 var_texcoord0;
varying mediump vec4 var_light;

uniform lowp sampler2D tex0;
uniform lowp sampler2D tex1;
uniform lowp vec4 tint;

uniform lowp vec4 bounds;
uniform lowp vec4 step;
uniform highp vec4 size;

#include "/main/utils.glsl"

vec4 get_probe(ivec3 i) {
    vec2 st = vec2((i.y * bounds.w + i.x) *  size.x , i.z * size.y);
    return texture2D(tex1, st);
}

vec3 get_probe_position(ivec3 i) {
    return bounds.xyz + vec3(i.x * step.x, i.y * step.y, i.z * step.z);
}

vec4 interpolate(vec4 data1, vec4 data2, float k) {
    if (data1.x == 999.) {
        return data2;
    }

    if (data2.x == 999.) {
        return data1;
    }
    
    return mix(data1, data2, k); //data1 * (1. - k) + data2 * k;
}

void main()
{
    //indirect light

    //find nearest probe to var_world_position
    vec3 v = var_world_position.xyz - bounds.xyz;
    ivec3 origin = ivec3( 
        int(v.x / step.x + 0.5),
        int(v.y / step.y + 0.5),
        int(v.z / step.z + 0.5)
    );

    ivec3 probes_per_row = ivec3(int(bounds.w) - 1);
    ivec3 zero = ivec3(0);
    origin = min(probes_per_row, max(zero, origin));
   

    //find 8 probes around the point

    vec3 pos = get_probe_position(origin);
    int dx = pos.x < var_world_position.x ? 1 : -1;
    int dy = pos.y < var_world_position.y ? 1 : -1;
    int dz = pos.z < var_world_position.z ? 1 : -1;

    
    vec4 probes[8] = vec4[8](vec4(0.), vec4(0.), vec4(0.), vec4(0.), vec4(0.), vec4(0.), vec4(0.), vec4(0.));

    int count = -1;
    for (int i = 0; i < 2;  i++) {
        for (int j = 0; j < 2; j++) {
            for (int k = 0; k < 2; k++) {

                count++;

                ivec3 diff = ivec3(i * dx, j * dy, k * dz);
                ivec3 index = min(probes_per_row, max(zero, origin + diff));
                
                pos = get_probe_position(index);
                vec3 dir = normalize(pos - var_world_position.xyz);

                if (dot(var_world_normal, dir) < 0.) { //bad probe,todo - depth check
                    probes[count].x = 999.; //bad probe flag
                    continue;
                }
            
                probes[count] = get_probe(index);
            }
        }
    }

    /*
    0 [ix][iy][iz]
    1 [ix][iy][iz+1]
    2 [ix][iy+1][iz]
    3 [ix][iy+1][iz+1]
    4 [ix+1][iy][iz]
    5 [ix+1][iy][iz+1]
    6 [ix+1][iy+1][iz]
    7 [ix+1][iy+1][iz+1]
    */
    

    
    //interpolate along the x-axis for each of the four front and back faces
    //float x = mod(var_world_position.x - bounds.x, step.x) / step.x;
    float x = mod(var_world_position.x - bounds.x, step.x) / step.x;
    if (dx < 0.) { x = 1. - x; }
        
    vec4 data00 = interpolate(probes[0], probes[4], x);
    vec4 data01 = interpolate(probes[1], probes[5], x);
    vec4 data10 = interpolate(probes[2], probes[6], x);
    vec4 data11 = interpolate(probes[3], probes[7], x);

    //interpolate along the y-axis for the two front faces
    float y = mod(var_world_position.y - bounds.y, step.y) / step.y;
    if (dy < 0.) { y = 1. - y; }
    vec4 data0 = interpolate(data00, data10, y);
    vec4 data1 = interpolate(data01, data11, y);

    //interpolate along the z-axis for the front face
    float z = mod(var_world_position.z - bounds.z, step.z) / step.z;
    if (dz < 0.) { z = 1. - z; }
    vec4 probe = interpolate(data0, data1, z);
    
    //probe = get_probe(origin);
  
    vec3 dir = var_world_normal;
    //vec3 p = bounds.xyz + vec3(ix * step.x, iy * step.y, iz * step.z); //probe world position
    //vec3 dir = normalize( var_world_position.xyz - p);


    float radiance = sh(0, dir) * probe.x 
        + sh(1, dir) * probe.y 
        + sh(2, dir) * probe.z
        + sh(3, dir) * probe.w;


    vec3 indirect = vec3(radiance, radiance, radiance);

   
   
    gl_FragColor = vec4(radiance, radiance, radiance, 1.0); 


    //gl_FragColor = vec4(get_probe(origin).xyz, 1.);

    
    // Pre-multiply alpha since all runtime textures already are
    vec4 tint_pm = vec4(tint.xyz * tint.w, tint.w);
    vec4 color = texture2D(tex0, var_texcoord0.xy) * tint_pm;

    // Diffuse light calculations
    vec3 diff_light = vec3(normalize(var_light.xyz - var_position.xyz));
    diff_light = max(dot(var_normal,diff_light), 0.0) + indirect;

    /*
    dir = -var_world_normal;
   
    radiance = sh(0, dir) * probe.x 
    + sh(1, dir) * probe.y 
    + sh(2, dir) * probe.z
    + sh(3, dir) * probe.w;

    diff_light = vec3(radiance) + indirect;
    */
    
    diff_light = clamp(diff_light, 0.0, 1.0);
    
    //gl_FragColor =vec4(color.xyz * diff_light ,1.0);
    
}

