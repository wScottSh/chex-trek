Md5Importer script for 3dsmax4, 5, 6 and gMax
=============================================

Version 0.94
Imports characters and camera animations from MD5 (Doom3 engine format)
Copyright (C) 2004 der_ton, tom-(at)gmx.de,
                   "der_ton" on www.doom3world.org
Feel free to contact me, any feedback is welcome.
If you use this to make anything that you think is worth taking a look at,
then please tell me. :)
If you plan to use this for commercial productions, contact me.



Where to report bugs, get tech support and the latest version:
==============================================================
http://home.tiscali.de/der_ton/3dsmax-md5importer.zip
http://www.doom3world.org discussion forums, 3dMax section and
Modelling & Animations section



Some notes on the usage:
========================

The result of the import will be one object, with a skin modifier applied and
bound to the imported skeleton. All submeshes of the MD5 will be in the one
object, using different submaterials.
The mesh object will be "see-through" by default, because you will want to work
with the skeleton. You can set that property for any mesh anytime within the
object properties, though (right-click object -> properties, under display 
properties).
In order to see textures, you will have to disable "see-through", and load the
diffuse map for the submaterial. Press "m" to bring up the material editor. The 
submaterials are named after their shader, so if you are familiar with Max's 
material editor, loading the right images will be straightforward.

If the script runs out of memory, go to customize->preferences, maxscript, and
set a higher heap memory number (100MB won´t hurt...).

If you select "Reorient Bones", then the skeleton after import will look nicer,
but bone orientations will not be the same as in the md5mesh it was imported
from. Use this only if you don't want to use original animations with the new
md5mesh resulting from an export.


Camera Import:
If the "import to selected camera" checkbox is checked, then the animation will 
be written to the selected camera. If not, a new camera with the name of the 
md5camera file will be generated.
The "Import at frame #" input is used to move the imported anim to that frame. 
This makes it easy to append camera animations. That's useful because Doom3
sometimes uses several md5camera files for a scene.




Have fun!

