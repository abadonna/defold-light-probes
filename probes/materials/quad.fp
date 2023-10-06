varying mediump vec2 var_texcoord0;
uniform sampler2D tex0;


uniform sampler2D tex_normal;
uniform sampler2D tex_position;

uniform lowp vec4 settings;
uniform highp mat4 mtx_proj;
uniform highp mat4 mtx_view;

#include "/probes/materials/probes.glsl"


vec3 calculate(mat3 red, mat3 green, mat3 blue, vec3 dir) {
	vec3 result = vec3(0.);
	for (int i = 0; i < 3; i++) {
		for (int j = 0; j < 3; j++) {
			float k = sh(3 * i + j, dir);
			result.x += k * red[i][j];
			result.y += k * green[i][j];
			result.z += k * blue[i][j];
		}
	}


	return result;
}

mat3 get_probe_data(ivec3 i, int channel) {
	float offset = i.y * bounds.w + i.x + channel * 3 * size.z;
	float y = i.z * size.y;

	vec2 st = vec2((offset) * size.x, y);
	vec4 v1 = texture2D(tex_probes, st);

	st = vec2((offset + size.z) * size.x, y);
	vec4 v2 = texture2D(tex_probes, st);

	st = vec2((offset + 2 * size.z) * size.x, y);
	vec4 v3 = texture2D(tex_probes, st);


	return mat3(v1.xyz, v2.xyz, v3.xyz);
}

vec3 get_probe_position(ivec3 i) 
{
	return bounds.xyz + vec3(i.x * step.x, i.y * step.y, i.z * step.z);
}


vec3 interpolate(vec3 data1, vec3 data2, float k) {
	if (data1.x == 999.) {
		return data2;
	}

	if (data2.x == 999.) {
		return data1;
	}

	return mix(data1, data2, k);
}

vec2 get_uv(vec3 position)
{
	vec4 p = vec4(position, 1.0);
	p = mtx_proj * p;
	p.xy /= p.w; // perspective divide
	p.xy  = p.xy * 0.5 + 0.5; // transform to range 0.0 - 1.0  
	return p.xy;
}

void main()
{
	vec3 world_position = texture2D(tex_position, var_texcoord0).xyz;
	vec3 world_normal = texture2D(tex_normal, var_texcoord0).xyz;
	world_normal = normalize(world_normal * 2.0 - 1.0);
	vec3 look = world_normal;
	if (settings.z == 1.) { //direct
		look = - world_normal;
	}
	
	vec3 v = world_position - bounds.xyz;
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
	int dx = pos.x < world_position.x ? 1 : -1;
	int dy = pos.y < world_position.y ? 1 : -1;
	int dz = pos.z < world_position.z ? 1 : -1;

	vec3[8] values = vec3[8](vec3(999.), vec3(999.), vec3(999.), vec3(999.), vec3(999.), vec3(999.),vec3(999.),vec3(999.));

	int count = -1;
	for (int i = 0; i < 2;  i++) {
		for (int j = 0; j < 2; j++) {
			for (int k = 0; k < 2; k++) {

				count++;

				ivec3 diff = ivec3(i * dx, j * dy, k * dz);
				ivec3 index = min(probes_per_row, max(zero, origin + diff));

				pos = get_probe_position(index);
				vec3 dir = normalize(pos - world_position);

				if (dot(world_normal, dir) < 0.) { //bad probe, todo: depth check
					continue;
				}

				/*
				//this simple depth check is not really working:
				
				vec4 view_pos = mtx_view * vec4(pos, 1.);
				vec2 uv = get_uv(view_pos.xyz);
				vec4 occluder = texture2D(tex_position, uv);
				occluder = mtx_view * vec4(occluder.xyz, 1.);
				
				if ( occluder.z > view_pos.z) { //depth check 
					continue;
				}
				*/

				mat3 red = get_probe_data(index, 0); 
				mat3 green = get_probe_data(index, 1);
				mat3 blue = get_probe_data(index, 2);

				values[count] = calculate(red, green, blue, look);

				//more correct to use direction to intersection point, 
				//but it requires raytrace and buffer depth
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


	float x = mod(world_position.x - bounds.x, step.x) / step.x;
	if (dx < 0.) { x = 1. - x; }
	float y = mod(world_position.y - bounds.y, step.y) / step.y;
	if (dy < 0.) { y = 1. - y; }
	float z = mod(world_position.z - bounds.z, step.z) / step.z;
	if (dz < 0.) { z = 1. - z; }


	//interpolate along the x-axis for each of the four front and back faces
	vec3 data00 = interpolate(values[0], values[4], x);
	vec3 data01 = interpolate(values[1], values[5], x);
	vec3 data10 = interpolate(values[2], values[6], x);
	vec3 data11 = interpolate(values[3], values[7], x);

	//interpolate along the y-axis for the two front faces
	vec3 data0 = interpolate(data00, data10, y);
	vec3 data1 = interpolate(data01, data11, y);

	//interpolate along the z-axis for the front face
	vec3 probe = interpolate(data0, data1, z);
	
	
	
	vec4 color = texture2D(tex0, var_texcoord0);
	

	if ( (settings.y == 1.) || (settings.z == 1.)) { //indirect
		color.xyz += probe.xyz;
	}

	color = clamp(color, 0.0, 1.0);

	gl_FragColor = color;

	
}