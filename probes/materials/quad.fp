varying mediump vec2 var_texcoord0;
uniform sampler2D tex0;

uniform lowp vec4 bounds;
uniform lowp vec4 step;
uniform highp vec4 size;

uniform lowp sampler2D tex_probes;

void main()
{
	vec4 dummy = bounds + step + size;
	
	vec4 color = texture2D(tex0, var_texcoord0);
	vec4 color2 = texture2D(tex_probes, var_texcoord0);

	gl_FragColor = color2;
}