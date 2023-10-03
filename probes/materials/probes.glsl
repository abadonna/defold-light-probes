uniform lowp vec4 bounds;
uniform lowp vec4 step;
uniform highp vec4 size;

uniform lowp sampler2D tex_probes;

float sh(int basis, highp vec3 dir) {
	if (basis == 0) {return 0.28209479177387814347;}
	if (basis == 1) {return -0.48860251190291992159 * dir.y;}
	if (basis == 2) {return 0.48860251190291992159 * dir.z;}
	if (basis == 3) {return -0.48860251190291992159 * dir.x;}
	if (basis == 4) {return 1.092548430592079 * dir.x * dir.y;}
	if (basis == 5) {return -1.092548430592079 * dir.z * dir.y;}
	if (basis == 6) {return 0.31539156525252 * (3 * dir.z * dir.z - 1);}
	if (basis == 7) {return -1.092548430592079 * dir.z * dir.x;}
	if (basis == 8) {return 0.54627421529604 * (dir.x * dir.x - dir.y * dir.y);}

	return 0.0;
}

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


vec3 get_light_from_probes(vec3 world_position, vec3 world_normal, vec3 look) {
	//find nearest probe to var_world_position

	vec3 v = world_position.xyz - bounds.xyz;
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
				vec3 dir = normalize(pos - world_position.xyz);

				if (dot(world_normal, dir) < 0.) { //bad probe, todo: depth check
					continue;
				}

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
	vec3 result = interpolate(data0, data1, z);


	return result;
}