varying highp vec4 var_position;
varying mediump vec3 var_normal;

uniform mediump vec4 coefs[3];

uniform highp vec4 tint;

#include "/materials/utils.glsl"

void main()
{
    highp float radiance = 0.;
    float[9] k = float[](coefs[0].x, coefs[0].y, coefs[0].z, coefs[0].w, 
        coefs[1].x, coefs[1].y, coefs[1].z, coefs[1].w,
        coefs[2].x);
         
    for (int i = 0; i < 9; i++) {
        radiance += sh(i, var_normal) * k[i];
    }
    
    
    //gl_FragColor =  coefs[0];
    gl_FragColor = vec4(radiance, radiance, radiance, 1.0);
}

