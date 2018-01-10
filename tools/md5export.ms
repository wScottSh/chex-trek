-- md5 exporter by der_ton, tom-(at)gmx.de
-- start this script with Ctrl-E or File->Evaluate All
-- see the "info" button in the rollout window for more information

--todo: 
--  add "mayastyle" output option/sync with importer's method of bone orientation
--  output multiple skinned objects into one md5mesh
--  don't include unanimated components into framedata output
--  filter degenerated triangles (detect vertices with the same x,y,z coords), do not rely on vertexindex and tvertexindex but on their actual coordinates (weights and weightcoordinates, in case of verts)
--  include bones in md5-skeleton that are not really used for skinning, but are parents of bones (model looks correct anyway, but md5bones have no parent if their corresponding 3dsmax bone has a parent that is not used for skinning)
--  support for editable_poly objects?
--  scaling option for character export
--  progress bar
--  output material names as shaders, not the image filenames
--  for the readme: heap memory in settings, origin problem with "origin" named rootbone
--  reorganize file output to lower heap memory requirements

-- version history:
-- 0.92 (2004-08-24) added camera export
-- 0.91 (2004-08-20) fixed boundingbox output to be relative to the root bone
-- 0.9  (2004-08-16) initial version, rewrite of the old exporter for new MD5 syntax


--user defined globals:
global g_reversenormals = false --"false" or "true", toggle it if your md5mesh looks wrong
global g_timerange = #(1, 60) --#(startframe, endframe) the time range that should be exported to the md5anim
global g_mapchannel = 1 --the mapping channel that contains the texture vertices and faces, usually "1". change this only if you know what you're doing
global g_flipverticaltexcoord = true --should be true
global g_bindpos_frame = 0
global g_export_anim_only = false
--user defined globals end here


global md5skin --the skin modifier object
global md5bonemapping = #() --mapping of the skin modifier bone index to the md5 bone index
global md5skel --the skeleton structure that is going to be constructed


fn printfloat flt =
--maxscript doesn't provide a way to format float output that I know of. It seems that Doom3 does not understand the <x>e<y> notation of floats
--if you plan to use this in your scripts, note that this function doesn't check against a large number passed in
(
	--if (abs flt)>10.0 then return flt -- this could be used to gain some speed.
	--else
	local numdigits = 10
	(
		str = ""
		if flt<0 then str += "-"
		flt2 = abs flt
		str += ((flt2 as integer) as string)
		flt2 -= (flt2 as integer)
		str +="."
		for i=1 to numdigits do
		(
			flt2 *=10.0
			str += ((flt2 as integer) as string)
			flt2 -= (flt2 as integer)
		)
		return str
	)
)
fn printfloat_old flt =
--maxscript doesn't provide a way to format float output that I know of. It seems that Doom3 does not understand the <x>e<y> notation of floats
--if you plan to use this in your scripts, note that this function doesn't check against a large number passed in
(
	if (abs flt)>=0.0001 then return flt
	else
	(
		if (abs flt)>=0.00005 then 
		(
			if flt>0.0 then return (0.0001)
			else return -0.0001
		)
		else return 0.0
	)
)

fn righthand_mat mat =
(
	-- convert the matrix to a righthanded one, by flipping its Z axis if it's lefthanded
	if dot (cross mat.row1 mat.row2) mat.row3 > 0 then
	(
		md5mat = copy mat
	)
	else
	(
		md5mat = copy mat
		md5mat.row3 = - md5mat.row3
	)
	return md5mat
)

struct md5vertex
(
	loc,
	uvmap,
	numweights,
	firstweightindx,
	weights,
	origvertindx,
	origtvertindx,
	
	fn tomd5mesh =
	(
		s = stringstream ""
		if g_flipverticaltexcoord then uvmap[2]=1.0-uvmap[2]
		format "( % % ) % %\n" (printfloat uvmap[1]) (printfloat uvmap[2]) (firstweightindx-1) numweights to:s
		if g_flipverticaltexcoord then uvmap[2]=1.0-uvmap[2]
		if (numweights==0) then format "found a vertex without skin attachement!\n"
		return s
	)
)
struct md5weight
(
	loc,
	tboneid,
	tweight,
	
	fn tomd5mesh =
	(
		s = stringstream ""
		format "% % ( % % % )" (md5bonemapping[tboneid]-1) (printfloat tweight) (printfloat loc.x) (printfloat loc.y) (printfloat loc.z) to:s
		return s
	)
)
struct md5tri
(
	v1,
	v2,
	v3,
	fn tomd5mesh =
	(
		s = stringstream ""
		if g_reversenormals == false then
			format "% % %" (v1-1) (v3-1) (v2-1) to:s
		else
			format "% % %" (v1-1) (v2-1) (v3-1) to:s
			
		return s
	)
)


struct md5submesh
(
	verts = #(),
	weights = #(),
	tris = #(),
	shader,
	
	fn tomd5mesh =
	(
		s = stringstream ""
		format "\tshader \"%\"\n\n" shader to:s
		format "\tnumverts %\n" verts.count to:s
		for v=1 to verts.count do
			format "\tvert % %" (v-1) (verts[v].tomd5mesh() as string) to:s
		format "\n\tnumtris %\n" tris.count to:s
		for t=1 to tris.count do
			format "\ttri % %\n" (t-1) (tris[t].tomd5mesh() as string) to:s
		format "\n\tnumweights %\n" weights.count to:s
		for t=1 to weights.count do
			format "\tweight % %\n" (t-1) (weights[t].tomd5mesh() as string) to:s
		return s
	),
	
	fn checkforvertex vertindx tvertindx=
	(
		for i=1 to verts.count do
		(
			if (vertindx == verts[i].origvertindx and tvertindx == verts[i].origtvertindx) do
			(
				return i
			)
		)
		return undefined
	),
	
	fn addmd5tri obj triindx self =
	(
		vertindices = getface obj triindx
		if (meshop.getMapSupport obj 1) then
			tvertindices = meshop.getmapface obj g_mapchannel triindx
		else
			tvertindices = [0,0,0]
		vertindices = #(vertindices.x as integer, vertindices.y as integer, vertindices.z as integer)
		tvertindices = #(tvertindices.x as integer, tvertindices.y as integer, tvertindices.z as integer)
		md5vertindices = #()
		for i=1 to 3 do
		(
			md5vertindices[i] = self.checkforvertex vertindices[i] tvertindices[i]
			if (md5vertindices[i] == undefined) do
			(
				pos = obj.verts[vertindices[i]].pos
				if (meshop.getMapSupport obj 1) then
					uv = meshop.getmapvert obj g_mapchannel tvertindices[i]
				else uv = [0,0,0]
				numweights = skinops.getvertexweightcount md5skin vertindices[i]
				newvert = md5vertex pos #(uv.x, uv.y) numweights (self.weights.count+1) origvertindx:vertindices[i] origtvertindx:tvertindices[i] 
				for w = 1 to numweights do 
				(
					weightval = skinops.getvertexweight md5skin vertindices[i] w
					boneid = skinops.getvertexweightboneid md5skin vertindices[i] w
					bspos = pos * md5skel.md5bones[boneid].bindmatinv
					newweight = md5weight bspos boneid weightval
					append self.weights newweight					
				)
				append self.verts newvert
				md5vertindices[i] = self.verts.count
			)
		)
		append self.tris (md5tri md5vertindices[1] md5vertindices[2] md5vertindices[3])
	) --phew, that function was quite non-trivial... now I gotta take a break and play Turrican
)

struct md5mesh
(
	submeshes = #(),
	bones = #(),
	
	fn tomd5mesh =
	(
		s = stringstream ""
		--format "numMeshes %\n" submeshes.count to:s
		
		for i=1 to submeshes.count do
		(
			format "\nmesh {\n" to:s
			format "%" (submeshes[i].tomd5mesh() as string) to:s
			format "}\n" to:s
		)
		return s
	)
)

struct md5bone
(
	name,
	theboneobj, --the bone's node
	parentptr,	--parent bone's node
	parentmd5bone,
	md5boneindex,
	bindmat = matrix3 1, --initialized as identity matrix, bone's idle matrix
	bindmatinv = matrix3 1, --stores the inverted idle matrix, to speed up calculations
	
	fn tomd5mesh =
	(
		s = stringstream ""
		format "\t\"%\"\t" name to:s
		if (parentptr != undefined) then 
			format "%" (parentmd5bone.md5boneindex-1) to:s
		else
			format "-1" to:s
		format " ( % % % ) " (printfloat bindmat[4].x) (printfloat bindmat[4].y) (printfloat bindmat[4].z) to:s
		bindquat = bindmat as quat
		if (bindquat.w<0) then 
		(
			bindquat.x=-bindquat.x
			bindquat.y=-bindquat.y
			bindquat.z=-bindquat.z
		)
		format "( % % % )\t\t//" (printfloat bindquat.x) (printfloat bindquat.y) (printfloat bindquat.z) to:s
		if (parentptr != undefined) then 
			format " %" (parentmd5bone.name) to:s
		return s
	)
	
)

struct md5animation
(
	md5skeleton,
	md5version = 10,
	commandline = "",
	numFrames,
	numJoints,
	md5framerate,
	numAnimatedComponents,
	bounds=#(),
	baseframe = #(),
	frames = #(),
	boneflags = #(),
	boneframedataindex = #(),
	
	fn tomd5anim =
	(
		s = stringstream ""
		format "MD5Version %\ncommandline \"%\"\n\n" md5version commandline to:s
		format "numFrames %\nnumJoints %\nframeRate %\nnumAnimatedComponents %\n\n" numFrames numJoints frameRate numAnimatedComponents to:s
		
		format "hierarchy {\n" to:s
		for i=1 to md5skeleton.md5bones.count do
		(
			for j=1 to md5skeleton.md5bones.count do
			(
				if md5bonemapping[j]==i then 
				(
					if (md5skeleton.md5bones[j].parentptr != undefined) then 
					(
						parentmd5indx = md5skeleton.md5bones[j].parentmd5bone.md5boneindex-1
						parentmd5name = md5skeleton.md5bones[j].parentmd5bone.name
					)
					else
					(
						parentmd5indx = -1
						parentmd5name = ""
					)

					format "\t\"%\"\t% % %\t// %\n" md5skeleton.md5bones[j].name parentmd5indx boneflags[j] boneframedataindex[j] parentmd5name to:s
				)
			)
		)
		format "}\n\n" to:s
				
		format "bounds {\n" to:s
		for i=1 to numFrames do
		(
			format "\t( % % % ) ( % % % )\n" (printfloat bounds[i*6-5]) (printfloat bounds[i*6-4]) (printfloat bounds[i*6-3]) (printfloat bounds[i*6-2]) (printfloat bounds[i*6-1]) (printfloat bounds[i*6]) to:s
		)
		format "}\n\n" to:s

		format "baseframe {\n" to:s
		for i=1 to numJoints do
		(
			format "\t( % % % ) ( % % % )\n" (printfloat baseframe[i*6-5]) (printfloat baseframe[i*6-4]) (printfloat baseframe[i*6-3]) (printfloat baseframe[i*6-2]) (printfloat baseframe[i*6-1]) (printfloat baseframe[i*6]) to:s
		)
		format "}\n\n" to:s

		for t=1 to numFrames do
		(
			format "frame % {\n" (t-1) to:s
			for i=1 to numJoints do
			(
				format "\t% % % % % %\n" (printfloat frames[t][i*6-5]) (printfloat frames[t][i*6-4]) (printfloat frames[t][i*6-3]) (printfloat frames[t][i*6-2]) (printfloat frames[t][i*6-1]) (printfloat frames[t][i*6-0]) to:s
			)
			format "}\n\n" to:s
		)
		
		return s
	),
	
	fn build timerange obj=
	(
		
		numFrames = timerange[2] - timerange[1] + 1
		numJoints = md5skeleton.md5bones.count
		md5framerate = framerate
		--build bounds
		originbone = undefined
		for j=1 to md5skeleton.md5bones.count do
		(
			if md5bonemapping[j]==1 then 
			(
				originbone = md5skeleton.md5bones[j].theboneobj
				format "using originbone: %\n" originbone.name
			)
		)
		
		set time timerange[1]
		origposx = originbone.pos.x
		origposy = originbone.pos.y
		origposz = originbone.pos.z
		
		for t=timerange[1] to timerange[2] do
		(
			set time t

			append bounds (obj.min.x - origposx)
			append bounds (obj.min.y - origposy)
			append bounds (obj.min.z - origposz)
			append bounds (obj.max.x - origposx)
			append bounds (obj.max.y - origposy)
			append bounds (obj.max.z - origposz)
			append frames #() -- initialize each of the elements in frames with empty array
		)

		-- build baseframe
		set time timerange[1]
		
		for i=1 to md5skeleton.md5bones.count do
		(
			for j=1 to md5skeleton.md5bones.count do
			(
				if md5bonemapping[j]==i then
				(
					if md5skeleton.md5bones[j].parentptr!=undefined then
					(	
						tr = copy md5skeleton.md5bones[j].parentptr.transform
						tr = righthand_mat tr
						tr = inverse tr
					)
					else
						tr = matrix3 1
					tr = md5skeleton.md5bones[j].theboneobj.transform * tr
					tr = righthand_mat tr

					baseframe[i*6-5] = tr[4].x
					baseframe[i*6-4] = tr[4].y
					baseframe[i*6-3] = tr[4].z
					quat = copy tr.rotationpart
					if (quat.w<0) then 
					(
						quat.x=-quat.x
						quat.y=-quat.y
						quat.z=-quat.z
					)
					baseframe[i*6-2] = quat.x
					baseframe[i*6-1] = quat.y
					baseframe[i*6-0] = quat.z
				)
			)
		)
		
		for abst = timerange[1] to timerange[2] do
		(
			set time abst
			for i=1 to md5skeleton.md5bones.count do
			(
				for j=1 to md5skeleton.md5bones.count do
				(
					if md5bonemapping[j]==i then
					(
						boneflags[j] = 63
						boneframedataindex[j] = (i-1)*6
						t = abst - timerange[1]+1
						if md5skeleton.md5bones[j].parentptr!=undefined then
						(	
							tr = copy md5skeleton.md5bones[j].parentptr.transform
							tr = righthand_mat tr
							tr = inverse tr
						)
						else
							tr = matrix3 1
						tr = md5skeleton.md5bones[j].theboneobj.transform * tr
						tr = righthand_mat tr
	
						frames[t][i*6-5] = tr[4].x
						frames[t][i*6-4] = tr[4].y
						frames[t][i*6-3] = tr[4].z
						quat = copy tr.rotationpart
						if (quat.w<0) then 
						(
							quat.x=-quat.x
							quat.y=-quat.y
							quat.z=-quat.z
						)
						frames[t][i*6-2] = quat.x
						frames[t][i*6-1] = quat.y
						frames[t][i*6-0] = quat.z
					)
				)
			)
		)
		numAnimatedComponents = numJoints * 6 --boneframedataindexcounter
	)
)

struct md5skeleton
(
	md5bones = #(),
	
	fn buildparentlinks =
	(
		for i=1 to md5bones.count do
		(
			if md5bones[i].parentptr!=undefined do
			(
				for j=1 to md5bones.count do
				(
					if md5bones[i].parentptr==md5bones[j].theboneobj then md5bones[i].parentmd5bone=md5bones[j]
				)
				if md5bones[i].parentmd5bone==undefined then md5bones[i].parentptr=undefined
			)
		)
	),	
	fn generatemapping =
	(
		currentb = 1
		while (currentb<=md5bones.count) do
		(
			--print currentb --a cheap progress indicator
			for i=1 to md5bones.count do
			(
				if md5bones[i].md5boneindex==undefined and (md5bones[i].parentmd5bone==undefined or (md5bones[i].parentmd5bone!=undefined and md5bones[i].parentmd5bone.md5boneindex!=undefined)) do
				(
					md5bones[i].md5boneindex=currentb
					md5bonemapping[i]=currentb
					currentb +=1
				)
			)
		)
	),
	fn tomd5mesh numMeshes =
	(
		s = stringstream ""
		format "MD5Version 10\ncommandline \"\"\n\n" to:s

		format "numJoints %\n" md5bones.count to:s
		format "numMeshes %\n\n" numMeshes to:s
		format "joints {\n" to:s
		for i=1 to md5bones.count do
		(
			for j=1 to md5bones.count do
			(
				if md5bonemapping[j]==i then format "%\n" (md5bones[j].tomd5mesh() as string) to:s
			)
		)
		format "}\n" to:s
		return s
	)
)


fn md5exportobj obj = 
(
	max modify mode
	set coordsys world
	mods = obj.modifiers
	for i=1 to mods.count do
	(
		if (classof mods[i] as string == "Skin") do
		(
			md5skin = mods[i]
			modPanel.setCurrentObject obj.modifiers[i]
			exit
		)
		if (i==mods.count) do
		(
			messagebox "there is no skin modifier for the selected object"
			return undefined
		)	)
	
	set time g_bindpos_frame
	--md5 data construction begins here
	numbones = skinops.getnumberbones md5skin
	md5skel = md5skeleton()
	for i=1 to numbones do
	(
		bname = skinops.getbonename md5skin i 1
		bn = md5bone name:bname
		append md5skel.md5bones bn
		boneobjname = skinops.getbonename md5skin i 0
		thebone = getnodebyname boneobjname
		bn.theboneobj = thebone
		if (thebone.parent != undefined) then bn.parentptr = thebone.parent
		bn.bindmat = thebone.transform
		bn.bindmat = righthand_mat bn.bindmat
		bindmat2 = copy bn.bindmat
		bn.bindmatinv = inverse bn.bindmat
	)
	md5skel.buildparentlinks()
	md5skel.generatemapping()
	
	faces = obj.faces
	usedmaterials = #()
	-- collect used materials
	for i=1 to faces.count do
	(
		m = getfacematid obj i
		j=1 
		found=false
		while (j<=usedmaterials.count and found==false) do
		(
			if usedmaterials[j]==m then found=true
			j+=1
		)
		if found==false then usedmaterials[usedmaterials.count+1]=m
	)
	-- for each used material, we need a submesh
	md5 = md5mesh()
	if (obj.material!=undefined) then
	(
		for i=1 to usedmaterials.count do
		(
			md5.submeshes[i]= md5submesh()
		)
	)
	else
	(
		md5.submeshes[1]= md5submesh()
		usedmaterials = #()
	)
	
	if (usedmaterials.count>1 and ((classof obj.material) as string == "Multimaterial")) do
	(
		for i=1 to usedmaterials.count do
		(
			if (classof obj.material.materiallist[i].diffusemap) as string == "Bitmaptexture" then
				md5.submeshes[i].shader = obj.material.materiallist[i].diffusemap.filename
			else
				md5.submeshes[i].shader = obj.material.materiallist[i].name
		)
	)
	if (usedmaterials.count>1 and ((classof obj.material) as string != "Multimaterial")) do
	(
		for i=1 to md5.submeshes.count do
		(
		--	if (classof obj.material.diffusemap) as string == "Bitmaptexture" then
		--		md5.submeshes[i].shader = obj.material.diffusemap.filename
		--	else
				md5.submeshes[i].shader = obj.material.name
		)
	)
	
	if (usedmaterials.count==1) do
	(
		if (classof obj.material) as string != "Multimaterial" then
		(
			if (classof obj.material.diffusemap) as string == "Bitmaptexture" then
				md5.submeshes[1].shader = obj.material.diffusemap.filename
			else
				md5.submeshes[1].shader = obj.material.name
		)
		else
		(
			if (classof obj.material.materiallist[1].diffusemap) as string == "Bitmaptexture" then
				md5.submeshes[1].shader = obj.material.materiallist[1].diffusemap.filename
			else
				md5.submeshes[1].shader = obj.material.materiallist[1].name
		)
	)
	if obj.material != undefined then
	(
		-- collect faces into the submeshes, according to the material the faces use
		for i=1 to faces.count do
		(
			m = getfacematid obj i
			j=1
			while (j<=usedmaterials.count) do
			(
				if usedmaterials[j]==m then
				(
					submeshnumber=j
					break
				)
				j+=1
			)
			md5.submeshes[submeshnumber].addmd5tri obj i md5.submeshes[submeshnumber]
		)
	)
	else
	(
		for i=1 to faces.count do
		(
			md5.submeshes[1].addmd5tri obj i md5.submeshes[1]
		)
	)
	
	md5anim = md5animation(md5skel)
	md5anim.build g_timerange obj
	

	--md5 data construction ends here
		
	local md5string = stringstream ""
	local md5animstring = stringstream ""
	format "%" ((md5skel.tomd5mesh md5.submeshes.count) as string) to:md5string
	format "%" (md5.tomd5mesh() as string) to:md5string
	format "%" (md5anim.tomd5anim() as string) to:md5animstring
	
	return #(md5string, md5animstring)
)

function md5export = (
	cursel = GetCurrentSelection()
	mesh = cursel[1]
	if mesh == undefined do
	(
		messagebox "no object selected"
		return undefined
	)
	if (((classof mesh.baseobject) as string) != "Editable_mesh") do
	(
		messagebox "selected obj is not an editable_mesh"
		return undefined
	)
	if g_export_anim_only then
	(
		animfilename = getsavefilename caption:"Save MD5anim" types:"MD5anim (*.md5anim)|*.md5anim"
		if animfilename != undefined do
		(
			animfile = createfile animfilename
			if (animfile != undefined) do
			(
				md5 = md5exportobj mesh
			--	format "%" (md5[1] as string) to:outfile
				format "%" (md5[2] as string) to:animfile
			--	format "%\n" (md5[1] as string)
			--	format "%\n" (md5[2] as string)
			--	close outfile
				close animfile
			)
		)
	
	)
	else
	(
		outfilename = getsavefilename caption:"Save MD5" types:"MD5mesh (*.md5mesh)|*.md5mesh"
		if outfilename != undefined do
		(
			outfile=createfile outfilename
			animfilename = copy outfilename
			endindx = findstring animfilename ".md5mesh"
			animfilename = replace animfilename endindx 8 ".md5anim"
			animfilename = getsavefilename caption:"Save MD5anim" filename:animfilename types:"MD5anim (*.md5anim)|*.md5anim"
			if animfilename != undefined then animfile = createfile animfilename
			if (outfile!= undefined and animfile != undefined) do
			(
				md5 = md5exportobj mesh
				format "%" (md5[1] as string) to:outfile
				format "%" (md5[2] as string) to:animfile
			--	format "%\n" (md5[1] as string)
			--	format "%\n" (md5[2] as string)
				close outfile
				close animfile
			)
		)
	)
)

struct md5camera
(
	numFrames = 0,
	md5frameRate = 24,
	cuts = #(),
	camdata = #(),
	
	fn build camobjs rangestart rangeend =
	(
		set time 0
	
		set coordsys world
		numFrames = rangeend - rangestart + 1
		md5frameRate = framerate
		thecamobj = camobjs[1]
		for t = rangestart to rangeend do
		(
			set time t
			tr = thecamobj.transform
			tr2 = matrix3 1
			tr2[1]=-tr[3]
			tr2[2]=-tr[1]
			tr2[3]=tr[2]
			tr2[4]=tr[4]
			q = normalize(tr2 as quat) -- should already be normalized? maybe not if the object is scaled
			if q.w<0 then
			(
				q.x=-q.x
				q.y=-q.y
				q.z=-q.z
			)
			append camdata #(thecamobj.pos.x, thecamobj.pos.y, thecamobj.pos.z, q.x, q.y, q.z, thecamobj.fov)
		)
	),
	
	fn tomd5camera =
	(	
		local md5string = stringstream ""
		format "MD5Version 10\ncommandline \"\"\n\n" to:md5string
		format "numFrames %\n" numFrames to:md5string
		format "frameRate %\n" md5framerate to:md5string
		format "numCuts %\n\n" cuts.count to:md5string
		format "cuts {\n" cuts.count to:md5string
		for i=1 to cuts.count do
		(
			format "\t%\n" cuts[i] to:md5string
		)
		format "}\n\n" to:md5string
		
		format "camera {\n" cuts.count to:md5string
		for i=1 to camdata.count do
		(
			format "\t( % % % ) ( % % % ) %\n" (printfloat camdata[i][1]) (printfloat camdata[i][2]) (printfloat camdata[i][3]) (printfloat camdata[i][4]) (printfloat camdata[i][5]) (printfloat camdata[i][6]) (printfloat camdata[i][7]) to:md5string
		)
		format "}\n\n" to:md5string

		return md5string
		)
)

function md5cameraexport= (
	camobjs = #()  --list of cameras for export
	if ((getcurrentselection()).count > 0) then
	(
		for i=1 to (getcurrentselection()).count do
		(
			camobj = (getcurrentselection())[i]
			if (((superclassof camobj) as string) == "camera") do
			(
				append camobjs camobj
			)
		)
	)
	if camobjs.count == 0 then
	(
		if ($cameras.count > 0) then
			camobjs = #($cameras[1])
		else
		(
			messagebox "there is no camera in the scene"
			return undefined
		)
	)
	
	outfilename = getsavefilename caption:"Save MD5" filename:(camobjs[1].name+".md5camera") types:"MD5camera (*.md5camera)|*.md5camera"
	if outfilename != undefined do
	(
		md5camobj = md5camera()
		md5camobj.build camobjs g_timerange[1] g_timerange[2]
		md5 = md5camobj.tomd5camera()
		outfile=createfile outfilename
		format "%" (md5 as string) to:outfile
		close outfile
	)
)

rollout floaterMD5Export "der_ton's MD5 Export" width:160 height:328
(
	spinner rangestart "" pos:[80,8] width:64 height:16 range:[0,10000,(animationRange.start.frame as integer)] type:#integer scale:1
	spinner rangeend "" pos:[80,32] width:64 height:16 range:[0,10000,(animationRange.end.frame as integer)] type:#integer scale:1
	label lbl1 "Startframe:" pos:[16,8] width:56 height:16
	label lbl2 "Endframe:" pos:[16,32] width:56 height:16
	checkbox chk1 "reversenormalschk" pos:[16,72] width:16 height:16 
	label lbl3 "reverse face-normals" pos:[32,72] width:112 height:16
	spinner spn3 "" pos:[96,120] width:48 height:16 range:[0,100,1] type:#integer scale:1
	label lbl4 "Mapchannel:" pos:[16,120] width:64 height:16
	GroupBox grp1 "Character Export" pos:[8,56] width:144 height:168
	button btn1 "Export..." pos:[32,192] width:88 height:24 toolTip:"Export the currently selected object"
	GroupBox grp2 "Camera Export" pos:[8,232] width:144 height:48
	button btn2 "Export..." pos:[32,248] width:88 height:24 toolTip:"Export the currently selected camera, or the first camera in the scene"
	--label lbltemp "Coming soon." pos:[32,253] width:88 height:24

	button info_button "Info about this exporter" pos:[8,288] width:144 height:32 toolTip:"read some info here"
	
	checkbox flipverticaltexcoords "Checkbox" pos:[16,96] width:16 height:16 checked:true
	label lbl5 "flip vertical texcoords" pos:[32,96] width:112 height:16
	spinner bindpos_frame_spn "" pos:[96,144] width:48 height:16 range:[0,10000,0] type:#integer
	label lbl6 "Bindpos Frame:" pos:[16,144] width:80 height:16
	checkbox export_anim_only_chk "Checkbox" pos:[16,168] width:16 height:16
	label lbl13 "export md5anim only" pos:[32,168] width:112 height:16

	on btn1 pressed do
	(
		g_timerange = #(rangestart.value, rangeend.value)
		g_bindpos_frame = bindpos_frame_spn.value
		g_mapchannel = spn3.value
		g_reversenormals = chk1.checked
		g_flipverticaltexcoord = flipverticaltexcoords.checked
		g_export_anim_only = export_anim_only_chk.checked
		md5export()
	)

	on btn2 pressed do
	(
		g_timerange = #(rangestart.value, rangeend.value)
		md5cameraexport()
	)

	on info_button pressed do
	(
		messagebox "MD5 Exporter  V0.92 - 2004-08-24\n(C) 2004, der_ton (tom-@gmx.de)\nVisit www.doom3world.org forum for tech-support\nAny feedback is welcome! :)"
	)
)

-- create the rollout window and add the  rollout
if MD5ExportFloater != undefined do
(
	closerolloutfloater MD5ExportFloater 
)
MD5ExportFloater = newRolloutFloater "MD5 Export" 190 390 
addRollout floaterMD5Export MD5ExportFloater 

