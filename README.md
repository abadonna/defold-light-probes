# Light probes for Defold

An attempt to implement irradiance probes for global illumination in Defold.

## Workflow
* collect geometry for raytraycing
* create uniform 3d grid of probes, for each probe we trace rays in number of directions to find irradiance
* approximate irradiance with spherical harmonics and save result in texture. We use 9 SH coefficients, so it's 3 rgb pixels for each channel per probe in texture image. We need 3х3 pixels (r, g and b channels) per probe, but in this demo it's just 1 channel for simplicity.
* In shader - read 8 nearest probes ("cell" of probes grid that contains the point we want to find light for) and trilinear interpolate result.

Defold (1.5.0) doesn't support compute shaders, so raytracing is performed on CPU, that makes this approach suitable only for static geometry and lights. And to be honest, lightmaps will give you better results in this situation. But my goal was to understand SH, light probes and passing data via textures.

![lightprobes](https://github.com/abadonna/defold-light-probes/blob/main/sample.jpg)


## How to achieve better results
Read textures while raycasting, use light color and save irradiance per RGB channel per probe.
Calculate lighting on second render pass, so we can discard invisible probes by checking depth in depth buffer.


## Reference
[scratchapixel.com has nice ray traycing tutorials](https://www.scratchapixel.com) 

[nice light probes and SH article](https://handmade.network/p/75/monter/blog/p/7288-engine_work__global_illumination_with_irradiance_probes)

[Spherical Harmonic Lighting: The Gritty Details](https://3dvar.com/Green2003Spherical.pdf) 

