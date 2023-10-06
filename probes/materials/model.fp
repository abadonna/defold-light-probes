varying highp vec4 var_position;
varying highp vec4 var_world_position;
varying mediump vec3 var_normal;
varying mediump vec3 var_world_normal;
varying mediump vec2 var_texcoord0;
varying mediump vec4 var_light;

uniform lowp sampler2D tex0;

uniform lowp vec4 tint;
uniform lowp vec4 settings;
uniform lowp vec4 light_attn;
uniform lowp vec4 light_color;

void main()
{

    // Diffuse light calculations
    vec4 color = vec4(0., 0., 0., 1.);
    vec3 result = vec3(1.);
    if (settings.x == 1.) { //direct
        vec3 light_dir = vec3(normalize(var_light.xyz - var_position.xyz));
        float d = distance(var_light.xyz, var_position.xyz);
        float k = 1. / (light_attn.x + d * light_attn.y + d * d * light_attn.z);
        float diffuse = max(dot(var_normal, light_dir), 0.0)  * k;

        result = light_color.xyz * diffuse;
        color = vec4(1.);
    }
    
   
    vec4 tint_pm = vec4(tint.xyz * tint.w, tint.w);

    if (settings.w == 1.) { //textures
        color = texture2D(tex0, var_texcoord0.xy) * tint_pm;
    }

    
    gl_FragColor =vec4(color.xyz * result , 1.0);

    vec3 rgb_normal = var_world_normal * 0.5 + 0.5;
    gl_FragData[1] = vec4(rgb_normal, 1.0);
    gl_FragData[2] = var_world_position;
    
}

