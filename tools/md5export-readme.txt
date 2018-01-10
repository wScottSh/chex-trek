Md5Exporter script for 3dsmax4, 5 and 6
=======================================

Exports animated characters and cameras from 3dsmax to MD5 (Doom3 engine format)
Copyright (C) 2004 der_ton, tom-(at)gmx.de,
                   "der_ton" on www.doom3world.org
Feel free to contact me, any feedback is welcome.
If you use this to make anything that you think is worth taking a look at,
then please tell me. :)
If you plan to use this for commercial productions, contact me.



Where to get tech support and the latest version:
=================================================
http://home.tiscali.de/der_ton/3dsmax-md5exporter.zip
http://www.doom3world.org/phpbb2/viewtopic.php?t=1914
http://www.doom3world.org/



Some notes on the usage:
========================

MESH EXPORT:

Use an editable_mesh, modified by a skin modifer. Other modifiers can be
present, but I cannot guarantee that the output will be as you see it in
3dsmax, due to the variety of modifiers and strange situations that can result
from that.

The original bindpose is not retrievable, so one of the frames has to be used
as the bindpose.

Flipping normals is usually not necessary, but i encountered one badly designed
model where it was necessary (apparently the whole thing was modelled with
"twosided" material, and all the faces faced inwards)

Flipping vertical texcoord is usually necessary, because apparently doom3
treats them differently.

FPS for the md5anim export (mesh and camera anim):
The exporter exports the FPS setting that was set in 3dsmax (default is 30 fps,
you might want to change it to "film" (24 fps) in the time configuration dialog
of 3dsmax).



ORGANIZING OF THE MESH:

Only the selected object gets exported. To have multiple sub-objects, you have
to "attach" them and have them use different submaterials of the object´s
material (which ofcourse has to be a "multimaterial" then). If you use 3dsmax´s
"attach" button, this will be handled correctly by 3dsmax.

The shader names of the submeshes in the md5 are the names of the texture that
is applied to the diffuse component of the material/submaterial, or, if it has
no texture, it is the name of the material itself.



CAMERA EXPORT:

In this version (0.92), there is no way to tell the exporter where cuts are placed.
Cuts are frame-indices, where the camera apruptly moves from one place to another,
and the engine reads the cuts-list so that it knows when not to apply interpolation.
If you have cuts in your camera animation, then you have to write them into the 
md5camera file by hand, with a text editor. Here is an example of how it should 
look like:

numCuts 5

cuts {
	96
	148
	198
	290
	324
}

Do not forget to edit the numCuts line!




Have fun!

