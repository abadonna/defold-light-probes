varying highp vec4 var_position;
varying highp vec4 var_world_position;
varying mediump vec3 var_normal;
varying mediump vec3 var_world_normal;
varying mediump vec2 var_texcoord0;
varying mediump vec4 var_light;

uniform lowp sampler2D tex0;
uniform lowp sampler2D tex1;
uniform lowp vec4 tint;
uniform lowp vec4 settings;
uniform lowp vec4 light_attn;

uniform lowp vec4 bounds;
uniform lowp vec4 step;
uniform highp vec4 size;

#include "/materials/utils.glsl"

struct Probe {
    float[9] data;
};

float[9] get_probe(ivec3 i) {
    vec2 st = vec2((i.y * bounds.w + i.x) * size.x, i.z * size.y);
    vec4 v = texture2D(tex1, st);

    float result [9] = float[9](v.x, v.y, v.z, 0., 0., 0., 0., 0., 0.);

    st = vec2((i.y * bounds.w + i.x + 0.333333333333333) * size.x, i.z * size.y);
    v = texture2D(tex1, st);
    result[3] = v.x;
    result[4] = v.y;
    result[5] = v.z;
    
    st = vec2((i.y * bounds.w + i.x + 0.666666666666667) * size.x, i.z * size.y);
    v = texture2D(tex1, st);
    result[6] = v.x;
    result[7] = v.y;
    result[8] = v.z;
    
    return result;
}

vec3 get_probe_position(ivec3 i) {
    return bounds.xyz + vec3(i.x * step.x, i.y * step.y, i.z * step.z);
}

float[9] interpolate(float[9] data1, float[9] data2, float k) {
    if (data1[0] == 999.) {
        return data2;
    }

    if (data2[0] == 999.) {
        return data1;
    }
    
    return float[9](
        data1[0] * (1. - k) + data2[0] * k,
        data1[1] * (1. - k) + data2[1] * k,
        data1[2] * (1. - k) + data2[2] * k,
        data1[3] * (1. - k) + data2[3] * k,
        data1[4] * (1. - k) + data2[4] * k,
        data1[5] * (1. - k) + data2[5] * k,
        data1[6] * (1. - k) + data2[6] * k,
        data1[7] * (1. - k) + data2[7] * k,
        data1[8] * (1. - k) + data2[8] * k);
}

void main()
{
    vec4 color = vec4(1., 1., 1., 1.);
    vec4 tint_pm = vec4(tint.xyz * tint.w, tint.w);

    if (settings.w == 1.) { //textures
        color = texture2D(tex0, var_texcoord0.xy) * tint_pm;
    }

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

    Probe probes[8] = Probe[8](
        Probe(float[9](0., 0., 0., 0., 0., 0., 0., 0., 0.)),
        Probe(float[9](0., 0., 0., 0., 0., 0., 0., 0., 0.)),
        Probe(float[9](0., 0., 0., 0., 0., 0., 0., 0., 0.)),
        Probe(float[9](0., 0., 0., 0., 0., 0., 0., 0., 0.)),
        Probe(float[9](0., 0., 0., 0., 0., 0., 0., 0., 0.)),
        Probe(float[9](0., 0., 0., 0., 0., 0., 0., 0., 0.)),
        Probe(float[9](0., 0., 0., 0., 0., 0., 0., 0., 0.)),
        Probe(float[9](0., 0., 0., 0., 0., 0., 0., 0., 0.))
    );


    int count = -1;
    for (int i = 0; i < 2;  i++) {
        for (int j = 0; j < 2; j++) {
            for (int k = 0; k < 2; k++) {

                count++;

                ivec3 diff = ivec3(i * dx, j * dy, k * dz);
                ivec3 index = min(probes_per_row, max(zero, origin + diff));

                pos = get_probe_position(index);
                vec3 dir = normalize(pos - var_world_position.xyz);

                if (dot(var_world_normal, dir) < 0.) { //bad probe, todo: depth check
                    probes[count].data[0] = 999.; //bad probe flag
                    continue;
                }

                probes[count].data = get_probe(index);
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
    float x = mod(var_world_position.x - bounds.x, step.x) / step.x;
    if (dx < 0.) { x = 1. - x; }

    float[9] data00 = interpolate(probes[0].data, probes[4].data, x);
    float[9] data01 = interpolate(probes[1].data, probes[5].data, x);
    float[9] data10 = interpolate(probes[2].data, probes[6].data, x);
    float[9] data11 = interpolate(probes[3].data, probes[7].data, x);

    //interpolate along the y-axis for the two front faces
    float y = mod(var_world_position.y - bounds.y, step.y) / step.y;
    if (dy < 0.) { y = 1. - y; }
    
    float[9] data0 = interpolate(data00, data10, y);
    float[9] data1 = interpolate(data01, data11, y);

    //interpolate along the z-axis for the front face
    float z = mod(var_world_position.z - bounds.z, step.z) / step.z;
    if (dz < 0.) { z = 1. - z; }
    
    float[9] probe = interpolate(data0, data1, z);
    
    //float[9] probe = get_probe(origin);
    
    // Diffuse light calculations
    vec3 light_dir = vec3(normalize(var_light.xyz - var_position.xyz));
    float d = distance(var_light.xyz, var_position.xyz);
    float k = 1. / (light_attn.x + d * light_attn.y + d * d * light_attn.z);
    float diffuse = max(dot(var_normal, light_dir), 0.0)  * k;

    float result = 0.;
    if (settings.x == 1.) { //direct
        result = diffuse;
    }

    if (settings.y == 1.) { //indirect
        float indirect = 0.;
        for (int i = 0; i < 9; i++) {
            indirect += sh(i, var_world_normal) * probe[i];
        }
        result += indirect;
    }

    if (settings.z == 1.) { //direct from probes
        float direct = 0.;
        for (int i = 0; i < 9; i++) {
            direct += sh(i, - var_world_normal) * probe[i];
        }
        result += direct;
    }

    result = clamp(result, 0.0, 1.0);

    gl_FragColor =vec4(color.xyz * result , 1.0);
    
}

