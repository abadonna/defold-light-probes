
bool rayTriangleIntersect( //scratchapixel.com
	float3 *orig, float3 *dir,
	float3 *v0, float3 *v1, float3 *v2,
	float *t, float *u, float *v)
	{

	const float kEpsilon = 1e-8;
		
	// compute the plane's normal
	float3 v0v1 = *v1 - *v0;
	float3 v0v2 = *v2 - *v0;
	// no need to normalize
	float3 N = cross(v0v1, v0v2); // N
	float denom = dot(N, N);

	// Step 1: finding P

	// check if the ray and plane are parallel.
	float NdotRayDirection = dot(N, *dir);

	if (fabs(NdotRayDirection) < kEpsilon) // almost 0
		return false; // they are parallel so they don't intersect! 

	// compute d parameter using equation 2
	float d = - dot(N, *v0);

	
	// compute t (equation 3)
	*t = -(dot(N, *orig) + d) / NdotRayDirection;

	float T = *t;
	// check if the triangle is behind the ray
	if (T < 0) return false; // the triangle is behind
	
	// compute the intersection point using equation 1
	float3 P = *orig + (float3)(T * dir->x, T * dir->y, T * dir->z);

	// Step 2: inside-outside test
	float3 C; // vector perpendicular to triangle's plane

	// edge 0
	float3 edge0 = *v1 - *v0; 
	float3 vp0 = P - *v0;
	C = cross(edge0, vp0);
	if (dot(N, C) < 0) return false; // P is on the right side

	
	// edge 1
	float3 edge1 = *v2 - *v1; 
	float3 vp1 = P - *v1;
	C = cross(edge1, vp1);
	if ((*u = dot(N, C)) < 0)  return false; // P is on the right side

	
	// edge 2
	float3 edge2 = *v0 - *v2; 
	float3 vp2 = P - *v2;
	C = cross(edge2, vp2);
	if ((*v = dot(N, C)) < 0) return false; // P is on the right side;

	*u /= denom;
	*v /= denom;

	return true; // this ray hits the triangle
}


int intersect(float3 *orig, float3 *dir, int num_faces, __global float3* p, float *dist, float2 *uv) 
{
	int face = -1;

	float u, v, t;
	for (int i = 0; i < num_faces; i ++) {
		int k = i * 3;
		float3 v0 = p[k];
		float3 v1 = p[k + 1];
		float3 v2 = p[k + 2];
		
		if (rayTriangleIntersect(orig, dir, &v0, &v1, &v2, &t, &u, &v) && t < *dist) {
			*dist = t;
			face = i;
			uv->x = u;
			uv->y = v;
		}
	}
	return face;
}


float cast_ray(
				float3 *orig, 
				float3 *dir, 
				int num_faces, 
				__global float3 *p, 
				__global float3* n, 
				int *num_lights,
				__global float3* lights, 
				__global float3* attn
				) 
{
	float result = 0.f;
	float dist = FLT_MAX;
	float2 uv;

	int face = intersect(orig, dir, num_faces, p, &dist, &uv);

	if (face > -1) {
		float3 point = (*orig) + (*dir) * dist;
		float3 normal = (1 - uv.x - uv.y) * n[face * 3] + uv.x * n[face * 3 + 1] + uv.y * n[face * 3 + 2];
		normal = normalize(normal);

		for (int i = 0; i < *num_lights; i++) {
			float color = 1.f;
			float3 light_dir = normalize(lights[i] - point);
			
			float diff = max(0.f, dot(normal, light_dir));
			if (diff == 0.f) {
				continue;
			}
			
			float3 hit = point +  normal * 0.01f; //bias = 0.01
			float d = FLT_MAX;
			float2 uv2;

			int shadow = intersect(&hit, &light_dir, num_faces, p, &d, &uv2);
			if (shadow == -1) 
			{
				d = length(lights[i] - point);			
				float k = 1. / (attn[i].x + attn[i].y * d + attn[i].z * d * d);
				result += color * diff * k;
			}
		}
	}
	return result;
}

float sh(int basis, float3 *dir) {
	if (basis == 0) {return 0.28209479177387814347;}
	if (basis == 1) {return -0.48860251190291992159 * dir->y;}
	if (basis == 2) {return 0.48860251190291992159 * dir->z;}
	if (basis == 3) {return -0.48860251190291992159 * dir->x;}
	if (basis == 4) {return 1.092548430592079 * dir->x * dir->y;}
	if (basis == 5) {return -1.092548430592079 * dir->z * dir->y;}
	if (basis == 6) {return 0.31539156525252 * (3 * dir->z * dir->z - 1);}
	if (basis == 7) {return -1.092548430592079 * dir->z * dir->x;}
	if (basis == 8) {return 0.54627421529604 * (dir->x * dir->x - dir->y * dir->y);}

	return 0.0;
}

float rnd (float s, float t) {
	float f;
	return fract(sin(s * 12.9898f + t * 78.233f) * 43758.5453123, &f);
}

//256 rays
__kernel void calculate(__global float3* p, 
						__global float3* n, 
						__global float3* lights, 
						__global float3* attn, 
						__global float* random,
						const int num_faces,
						const int num_lights,
						__global float3* probes, 
						__global float* res,
						__local float* temp)
{
	const int i = get_global_id(0); // get a unique number identifying the work item in the global pool
	const int probe_idx = get_global_id(1); 

	float3 from = probes[probe_idx];
	
	float a = floor(i / 16.f); // 16 = sqrt(256)
	float b = i - a * 256;
	//float x = (a + random[i * 2]) * 0.0625; // 1/16
	//float y = (b + random[i * 2 + 1]) * 0.0625;
	float x = (a + rnd(from.x + i, from.y * i )) * 0.0625; // 1/16
	float y = (b + rnd(from.z + i, from.x + i)) * 0.0625;

	float theta = 2.0 * acos(sqrt(1.0f - x));
	float phi = 2.0 * M_PI_F * y;
	//convert spherical coords to unit vector
	float3 dir = (float3)(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
	
	//int offset = probe_idx * 256 ;
	
	float value = cast_ray(&from, &dir, num_faces, p, n, &num_lights, lights, attn);
	int k = i * 9;
	for (int j = 0; j < 9; j++) {
		temp[ k + j] = sh(j, &dir) * value;
	}

	
	barrier(CLK_LOCAL_MEM_FENCE);

	
	if (i == 0) {
		int offset = get_group_id(1) * 9;
		for (int k = 0; k < 9; k++) {
			res[offset + k] = 0.f;
			for (int j = 0; j < 256; j++) {
				res[offset + k] += temp[j * 9 + k];
			}
		}

		//scale
		for (int k = 0; k < 9; k++) {
			res[offset + k] = res[offset + k] * 4.f * M_PI_F / 256.f;
		}
	}
	
}
