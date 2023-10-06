varying highp vec4 var_position;
varying mediump vec3 var_normal;

uniform mediump vec4 red[3];
uniform mediump vec4 green[3];
uniform mediump vec4 blue[3];

uniform highp vec4 tint;

#include "/probes/materials/probes.glsl"

void main()
{
    vec4 radiance = vec4(0., 0., 0., 1.);
    
    float[9] r = float[](red[0].x, red[0].y, red[0].z, red[0].w, 
        red[1].x, red[1].y, red[1].z, red[1].w,
        red[2].x
    );

    float[9] g = float[](green[0].x, green[0].y, green[0].z, green[0].w, 
        green[1].x, green[1].y, green[1].z, green[1].w,
        green[2].x
    );

    float[9] b = float[](blue[0].x, blue[0].y, blue[0].z, blue[0].w, 
        blue[1].x, blue[1].y, blue[1].z, blue[1].w,
        blue[2].x
    );    
         
    for (int i = 0; i < 9; i++) {
        float k = sh(i, var_normal);
        radiance.x +=  k * r[i];
        radiance.y +=  k * g[i];
        radiance.z +=  k * b[i];
    }
    
    gl_FragColor = radiance;
    //gl_FragColor = vec4(red[0].xyz, 1);
}

