
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