varying mediump vec2 var_texcoord0;
uniform sampler2D tex0;


void main()
{
	vec4 color = texture2D(tex0, var_texcoord0);

	gl_FragColor = color;
}