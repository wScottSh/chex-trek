-- md5 importer by der_ton, tom-(at)gmx.de
-- start this script with Ctrl-E or File->Evaluate All
-- see the "info" button in the rollout window for more information
-- and read the readme :)

-- todo:
-- find md5anim import bug or confirm it's an issue with max/maxscript

-- version history:
-- 0.94  (2004-10-19) fixed problem with anim import where bones sometimes got stretched
-- 0.93b (2004-08-31) fixed problem when importing several models without restarting the script
-- 0.93a (2004-08-30) added md5anim import (not final. this is released so people can give me ideas and test if the problem is there in other Max versions)
--                   fixed problem with bone matrix (fixed it with a hack. it was needed for bones that have qx==qy==qz==-0.5)
-- 0.92 (2004-08-24) added md5camera import
-- 0.91 (2004-08-20) added "reorient bones" on/off option (was on by default in 0.9). Enables import of Doom3 skeletons without changing their orientations, if the option is OFF.
--                   fixed degenerated bone matrix generation occuring in rare cases (rounding errors when calculating quat.w)
-- 0.9 (2004-08-08) initial version

md5bones = #()
maxbones = #()
md5import_mayastyle = false
md5import_reorganizeskeleton = false

global g_flipverticaltexcoord = true --should be true
global g_basepath = ""
global g_seethrough = true

global g_cam_selectedcam = false
global g_cam_startframe = 0

boneheight=.50
bonewidth =.50
md5mesh = #() --list of md5submeshes
maxmesh = #() --list of editable_mesh objects
global theskinmod

struct md5bone
(
	name,
	theboneobj, --the bone's node
	parentptr,	--parent bone's node
	parentmd5bone,
	md5boneindex,
	bindmat = matrix3 1, --initialized as identity matrix, bone's idle matrix
	bindmatinv = matrix3 1, --stores the inverted idle matrix, to speed up calculations
	animmat = matrix3 1,
	parentindex,
	parentname
)
struct md5submesh
(
	shader,
	md5verts = #(),
	md5weights = #(),
	md5tris = #(),
	maxverts = #(),
	maxtris = #(),
	maxtverts = #()
)
struct md5tri
(
	v1,
	v2,
	v3
)
struct md5vertex
(
	uvmap=#(),
	numweights,
	firstweightindx,
	weights,
	origvertindx,
	origtvertindx
)
struct md5weight
(
	loc,
	tboneid,
	tweight,
	weightsgrouploc,
	weightsgroupnumber
)	

fn findfirstchild bonearray thebone=
(
	for bn in bonearray do
	(
		if bn.parentname == thebone.name then return bn
	)
	return undefined
)

fn md5importfile md5filename =
(
	md5file = openFile md5filename
	
	--first we read the list of bones
	while eof md5file == false do
	(
		line = readline md5file
		linestream = line as stringstream
		linetokens = filterstring line " \t"
		if (linetokens[1]=="joints") do
		(
			currentbone=1
			while (linetokens[1] != "}") do (
				line = readline md5file
				linetokens = filterstring line " \t"
				linestream = line as stringstream
			
				if linetokens[1] == "}" then exit
				
				md5bones[currentbone] = md5bone ()
				skiptostring linestream "\""
				md5bones[currentbone].name = readDelimitedString linestream "\""
				
				md5bones[currentbone].parentindex = readvalue linestream
				skiptostring linestream "("
				tx = (readvalue linestream) as float
				ty = (readvalue linestream) as float
				tz = (readvalue linestream) as float
				skiptostring linestream ")"
				skiptostring linestream "("
				qx = (readvalue linestream) as float
				qy = (readvalue linestream) as float
				qz = (readvalue linestream) as float
				skiptostring linestream ")"
				if (qx==-0.5 and qy==-0.5 and qz==-0.5) then 
				(
					qz= -0.499999 -- HACK to make things work (otherwise caused problems in rare cases)
				)
				s = 1.0 - qx*qx - qy*qy - qz*qz
				if s<0.0 then -- numerical precision issues...
				(
					--print s
					s=0.0
				) 
				qw = sqrt(s) 
				md5bones[currentbone].bindmat = (normalize (quat qx qy qz qw)) as matrix3
				md5bones[currentbone].bindmat.row4.x = tx
				md5bones[currentbone].bindmat.row4.y = ty
				md5bones[currentbone].bindmat.row4.z = tz
				if md5bones[currentbone].parentindex>=0 then
				(
					md5bones[currentbone].parentname = md5bones[md5bones[currentbone].parentindex+1].name
				)

				currentbone += 1
			)
		)
	)
	--generate the bones
	for bn in md5bones do
	(
		childbone = findfirstchild md5bones bn
		if childbone != undefined then length=distance bn.bindmat.row4 childbone.bindmat.row4
		else length=4 --should make this the distance to the parent bone...
		if (md5import_reorganizeskeleton and (childbone!=undefined)) then
		(
			newbone = bonesys.createbone bn.bindmat.row4 childbone.bindmat.row4 bn.bindmat.row3
		)
		else
		(
			if (md5import_mayastyle == false) then
			(
				newbone = bonesys.createbone bn.bindmat.row4 (bn.bindmat.row4 + length*(normalize bn.bindmat.row1)) (normalize bn.bindmat.row3)
			)
			else (newbone = bonesys.createbone bn.bindmat.row4 (bn.bindmat.row4 + length*(normalize bn.bindmat.row2)) (normalize bn.bindmat.row1))
		)
		bn.theboneobj = newbone
		newbone.name = bn.name
		newbone.width=bonewidth
		newbone.height=boneheight
		newbone.setBoneEnable false 0
		append maxbones newbone
		--hide newbone
	)
	--do the parent-child linking in the 3dsmax-bones
	for i=1 to maxbones.count do
	(
		if md5bones[i].parentname!=undefined do
		(
			maxbones[i].parent = getnodebyname md5bones[i].parentname
			md5bones[i].parentptr = maxbones[i].parent
		)
	)
	
	-- read the submeshes
	seek md5file 0
	currentsubmesh = 1
	while eof md5file == false do
	(
		line = readline md5file
		linetokens = filterstring line " \t"
		if (linetokens[1]=="mesh") do
		(
			md5mesh[currentsubmesh] = md5submesh()
			endofsubmesh = false
			triindx = 1
			while (eof md5file == false) and (endofsubmesh==false) do
			(
				line = readline md5file
				linetokens = filterstring line " \t"
				if (linetokens[1]=="shader") then
				(
					linestream = line as stringstream
					skiptostring linestream "\""
					md5mesh[currentsubmesh].shader = readDelimitedString linestream "\""
				)
				if (linetokens[1]=="}") then endofsubmesh=true
				if (linetokens[1]=="vert") then
				(
					md5mesh[currentsubmesh].md5verts[(linetokens[2] as integer)+1] = md5vertex uvmap:#(linetokens[4] as float,linetokens[5] as float) firstweightindx:((linetokens[7] as integer)+1) numweights:(linetokens[8] as integer)
					if g_flipverticaltexcoord then md5mesh[currentsubmesh].md5verts[(linetokens[2] as integer)+1].uvmap[2]=1-(linetokens[5] as float)
				)
				if (linetokens[1]=="tri") then
				(
					--md5mesh[currentsubmesh].md5tris[(linetokens[2] as integer)+1] = md5tri ((linetokens[3] as integer) +1) ((linetokens[4] as integer) +1) ((linetokens[5] as integer) +1)
					md5mesh[currentsubmesh].md5tris[triindx] = md5tri ((linetokens[3] as integer) +1) ((linetokens[4] as integer) +1) ((linetokens[5] as integer) +1)
					triindx+=1
				)
				if (linetokens[1]=="weight") then
				(
					md5mesh[currentsubmesh].md5weights[(linetokens[2] as integer)+1] = md5weight loc:[linetokens[6] as float,linetokens[7] as float,linetokens[8] as float] tboneid:((linetokens[3] as integer) +1) tweight:(linetokens[4] as float)
				)
			)
			currentsubmesh += 1
		)
	)	
	close md5file
	
	maxtris = #()
	maxverts = #()
	nummaxmapverts=0
	weightsgroupcounter=1
	for s in md5mesh do
	(
		--generate the 3dsmax-vertices list from the weights of the mesh
		-- go through the verts: go through each vert´s weights, fill their weightsgrouploc and weightsgroupnumber
		for vert in s.md5verts do
		(
			if (s.md5weights[vert.firstweightindx].weightsgroupnumber == undefined) do
			(
				s.md5weights[vert.firstweightindx].weightsgrouploc = [0,0,0]
				s.md5weights[vert.firstweightindx].weightsgroupnumber = weightsgroupcounter
				for w=vert.firstweightindx to (vert.firstweightindx + vert.numweights-1) do
				(
					s.md5weights[vert.firstweightindx].weightsgrouploc+=(s.md5weights[w].loc * md5bones[s.md5weights[w].tboneid].bindmat) * s.md5weights[w].tweight
				)
				maxverts[weightsgroupcounter] = s.md5weights[vert.firstweightindx].weightsgrouploc
				weightsgroupcounter+=1
			)
		)
		--faces are generated according to the weightsgroupnumber of the md5weight of the md5vert
		for i=1 to s.md5tris.count do
		(
			tri = s.md5tris[i]
			vert1 = s.md5weights[s.md5verts[tri.v1].firstweightindx].weightsgroupnumber
			vert2 = s.md5weights[s.md5verts[tri.v2].firstweightindx].weightsgroupnumber
			vert3 = s.md5weights[s.md5verts[tri.v3].firstweightindx].weightsgroupnumber
			append maxtris [vert1, vert3, vert2] --vertex ordering is counterclockwise in md5
		)
	)
	namecomponents = filterstring md5filename "/\\."
	thenewmesh = mesh vertices:maxverts faces:maxtris name:namecomponents[namecomponents.count-1]
	append maxmesh thenewmesh
	thenewmesh.xray = g_seethrough
	meshop.setmapsupport thenewmesh 1 true --enable texturemap channel
	for s in md5mesh do
		nummaxmapverts +=s.md5verts.count
	meshop.setnummapverts thenewmesh 1 nummaxmapverts --set number of texture vertices
	--generate the texture-vertices
	maxmapvertindx=1
	for s in md5mesh do
	(
		for i=1 to s.md5verts.count do
		(
			meshop.setmapvert thenewmesh 1 maxmapvertindx [s.md5verts[i].uvmap[1], s.md5verts[i].uvmap[2], s.md5verts[i].uvmap[2]]
			maxmapvertindx +=1
		)
	)
	--generate the texture-faces
	maxmapfaceindx=1
	previoustvertcount=0
	for s in md5mesh do
	(
		for i=1 to s.md5tris.count do
		(
			meshop.setmapface thenewmesh 1 maxmapfaceindx [(s.md5tris[i].v1)+previoustvertcount, (s.md5tris[i].v3)+previoustvertcount, (s.md5tris[i].v2)+previoustvertcount]
			maxmapfaceindx += 1
		)
		previoustvertcount+=s.md5verts.count
	)
	-- assign the correct submesh´s material to the faces
	faceindx=1
	matindx=1
	for s in md5mesh do
	(
		for i=1 to s.md5tris.count do
		(
			setfacematid thenewmesh faceindx matindx
			faceindx+=1
		)
		matindx+=1
	)
	thenewmaterial = multimaterial numsubs:md5mesh.count
	for i=1 to md5mesh.count do
	(
		thenewsubmaterial = standardmaterial name:md5mesh[i].shader
		thenewsubmaterial.diffusemap = bitmaptexture name:md5mesh[i].shader
		thenewsubmaterial.diffusemap.filename = md5mesh[i].shader
		thenewmaterial.materiallist[i] = thenewsubmaterial
		showtexturemap thenewsubmaterial thenewsubmaterial.diffusemap true
	)
	thenewmesh.material = thenewmaterial
	
	--generate the skin modifier
	max modify mode
	select thenewmesh
	
	theskinmod = skin()
	addmodifier thenewmesh theskinmod
	for bn=1 to maxbones.count do
	(
		if bn == maxbones.count then
			skinops.addbone theskinmod maxbones[bn] 1
		else
			skinops.addbone theskinmod maxbones[bn] 0
	)
	update thenewmesh
	modpanel.setcurrentobject theskinmod
	disableSceneRedraw() -- thanks to chris cookson for this... it immensely speeds up the weight assignment loop
	--assign bones and weights to the vertices
	for s in md5mesh do
	(
		for vert in s.md5verts do
		(
			if s.md5weights[vert.firstweightindx] != undefined then 
			(
				bone_array = #()
				weight_array = #()
				if (s.md5weights[vert.firstweightindx].weightsgroupnumber != undefined) do
				(
					for w=vert.firstweightindx to (vert.firstweightindx + vert.numweights-1) do
					(
						append bone_array s.md5weights[w].tboneid
						append weight_array s.md5weights[w].tweight
					)
					weightsgroupcounter+=1
				)
				
				skinops.replacevertexweights theskinmod (s.md5weights[vert.firstweightindx].weightsgroupnumber) bone_array weight_array
			)
		)
	)
	enableSceneRedraw()
	
	gc()
)

struct hierarchyitem
(
	name,
	flags,
	framedataindex,
	md5bone		-- the md5bone object that the hierarchyitem refers to
)

fn md5animfileimport md5filename startframe =
(
	set coordsys world
	baseframe = #()
	framedata = #()
	
	md5file = openFile md5filename
	line = readline md5file
	if line != "MD5Version 10" then 
	(
		messagebox "Wrong MD5 Version"
		return undefined
	)
	

	md5animhierarchy = #()	
	--first we read the list of bones
	while eof md5file == false do
	(
		line = readline md5file
		linestream = line as stringstream
		linetokens = filterstring line " \t"
		if (linetokens[1]=="hierarchy") do
		(
			currentbone=1
			while (linetokens[1] != "}") do (
				line = readline md5file
				linetokens = filterstring line " \t"
				linestream = line as stringstream

				if linetokens[1] == "}" then exit
				
				md5animhierarchy[currentbone] = hierarchyitem()
				skiptostring linestream "\""
				hname = readDelimitedString linestream "\""
				-- search for the md5bone
				for bone in md5bones do
				(
					if bone.name == hname then
					(
						md5animhierarchy[currentbone].md5bone = bone
						break
					)
				)
				if md5animhierarchy[currentbone].md5bone == undefined then format "Couldn't find matching bone for %" hname
				hparentindex = readvalue linestream -- here we could check if it's the same parent as in the md5mesh...
				md5animhierarchy[currentbone].flags = readvalue linestream
				md5animhierarchy[currentbone].framedataindex = readvalue linestream

				currentbone += 1
			)
		) -- end if linetokens...
		
		if (linetokens[1]=="baseframe") do
		(
			currentbone = 1
			while (linetokens[1] != "}") do (
				line = readline md5file
				linetokens = filterstring line " \t"
				linestream = line as stringstream

				if linetokens[1] == "}" then exit
				skiptostring linestream "("
				tx = (readvalue linestream) as float
				ty = (readvalue linestream) as float
				tz = (readvalue linestream) as float
				skiptostring linestream ")"
				skiptostring linestream "("
				qx = (readvalue linestream) as float
				qy = (readvalue linestream) as float
				qz = (readvalue linestream) as float
				skiptostring linestream ")"
				append baseframe #(tx, ty, tz, qx, qy, qz)
				
				currentbone += 1
			)
		)

		if (linetokens[1]=="frame") do
		(
			currentframe = (linetokens[2] as Integer) -- if the frames are not consecutive, we'll get an error, that's better than garbled data
			framedata[currentframe+1] = #()
			while (linetokens[1] != "}") do (
				line = readline md5file
				linetokens = filterstring line " \t"
				linestream = line as stringstream

				if linetokens[1] == "}" then exit
				for i=1 to linetokens.count do
				(
					append framedata[currentframe+1] (linetokens[i] as float)
				)
			)
		)
	) -- end while eof md5file...

	animate on
	(
		for currentframe = 1 to framedata.count do
		(
			at time (currentframe-1+startframe)
			for currentbone = 1 to md5animhierarchy.count do
			(
				tx = baseframe[currentbone][1]
				ty = baseframe[currentbone][2]
				tz = baseframe[currentbone][3]
				qx = baseframe[currentbone][4]
				qy = baseframe[currentbone][5]
				qz = baseframe[currentbone][6]
				framedataindx = md5animhierarchy[currentbone].framedataindex + 1 -- + 1 because maxscript arrays start at 1
				
				if (bit.and md5animhierarchy[currentbone].flags 1)>0 then
				(
					tx = framedata[currentframe][framedataindx]
					framedataindx += 1
				)
				if (bit.and md5animhierarchy[currentbone].flags 2)>0 then
				(
					ty = framedata[currentframe][framedataindx]
					framedataindx += 1
				)
				if (bit.and md5animhierarchy[currentbone].flags 4)>0 then
				(
					tz = framedata[currentframe][framedataindx]
					framedataindx += 1
				)
				if (bit.and md5animhierarchy[currentbone].flags 8)>0 then
				(
					qx = framedata[currentframe][framedataindx]
					framedataindx += 1
				)
				if (bit.and md5animhierarchy[currentbone].flags 16)>0 then
				(
					qy = framedata[currentframe][framedataindx]
					framedataindx += 1
				)
				if (bit.and md5animhierarchy[currentbone].flags 32)>0 then
				(
					qz = framedata[currentframe][framedataindx]
					framedataindx += 1
				)
				
				if (qx==-0.5 and qy==-0.5 and qz==-0.5) then 
				(
					qz= -0.499999 -- HACK to make things work (otherwise caused problems in rare cases)
				)
				s = 1.0 - qx*qx - qy*qy - qz*qz
				if s<0 then s=0 -- numerical precision issues...
				qw = sqrt(s) 
				
				parentspacemat = (quat qx qy qz qw) as matrix3
				parentspacemat[4] = [tx, ty, tz]
				
				--alternative 1:
				if md5animhierarchy[currentbone].md5bone.parentptr!=undefined then
				(
					md5animhierarchy[currentbone].md5bone.animmat = parentspacemat * md5bones[md5animhierarchy[currentbone].md5bone.parentindex+1].animmat
				)
				else
				(
					md5animhierarchy[currentbone].md5bone.animmat = parentspacemat
				)
				md5animhierarchy[currentbone].md5bone.theboneobj.transform = md5animhierarchy[currentbone].md5bone.animmat
				--md5animhierarchy[currentbone].md5bone.theboneobj.scale = [1,1,1]
				--md5animhierarchy[currentbone].md5bone.theboneobj.rotation = md5animhierarchy[currentbone].md5bone.animmat as quat
				--md5animhierarchy[currentbone].md5bone.theboneobj.pos = md5animhierarchy[currentbone].md5bone.animmat[4]
				
				--if md5animhierarchy[currentbone].md5bone.name == "loneck" then
				--(
				--	format "%: %\n" currentframe md5animhierarchy[currentbone].md5bone.animmat
				--)

				--alternative 2: I thought it should be equivalent, but it doesn't seem to work
				--if md5animhierarchy[currentbone].md5bone.parentptr!=undefined then
				--(
				--	set coordsys parent
				--)
				--else
				--(
				--	set coordsys world
				--)
				--md5animhierarchy[currentbone].md5bone.theboneobj.transform = parentspacemat


			) -- end for currentbone
		) -- end for frame
	) --end animate on
	ar_start = animationRange.start.frame
	ar_end = animationRange.end.frame
	if animationRange.start.frame > startframe then
		ar_start = startframe
	if animationRange.end.frame < startframe+framedata.count then
		ar_end = startframe+framedata.count - 1
	animationRange = interval ar_start ar_end

)
	
fn md5import =
(
	set coordsys world

	md5filename=getOpenFileName types:"MD5Mesh (*.md5mesh)|*.md5mesh|All (*.*)|*.*|"
	if md5filename != undefined then 
	(
		if DoesFileExist md5filename then md5importfile md5filename
	)
)

fn md5importcamerafile md5filename startframe camobj =
(
	md5file = openFile md5filename
	camframes = #()
	if (camobj == undefined) then
	(
		namecomponents = filterstring md5filename "/\\."
		thenewcam = FreeCamera name:namecomponents[namecomponents.count-1]
	)
	else
		thenewcam = camobj
	if startframe == undefined then startframe = 0
	while eof md5file == false do
	(
		line = readline md5file
		linestream = line as stringstream
		linetokens = filterstring line " \t"
		if (linetokens[1]=="camera") do
		(
			currentframe=1
			while (linetokens[1] != "}") do (
				line = readline md5file
				linetokens = filterstring line " \t"
				linestream = line as stringstream
			
				if linetokens[1] == "}" then exit
				
				camframes[currentframe]=#(linetokens[2] as float, linetokens[3] as float, linetokens[4] as float, linetokens[7] as float, linetokens[8] as float,linetokens[9] as float, linetokens[11] as float)
				currentframe += 1
			)
		)
	)
	animate on
	(
		for t=1 to camframes.count do
		(
			qx = camframes[t][4]
			qy = camframes[t][5]
			qz = camframes[t][6]
			s = 1.0 - qx*qx - qy*qy - qz*qz
			if s<0 then s = 0 -- numerical precision issues...
			qw = sqrt(s)
			quatmatr = (quat qx qy qz qw) as matrix3
			cammatr = copy quatmatr
			cammatr[3]=-quatmatr[1]
			cammatr[1]=-quatmatr[2]
			cammatr[2]=quatmatr[3]
			cammatr[4]=[camframes[t][1],camframes[t][2],camframes[t][3]]
			at time (t-1+startframe)
			(
				thenewcam.transform = cammatr
				thenewcam.fov = camframes[t][7]
			)
		)
	)
	ar_start = animationRange.start.frame
	ar_end = animationRange.end.frame
	if animationRange.start.frame > startframe then
		ar_start = startframe
	if animationRange.end.frame < startframe+camframes.count then
		ar_end = startframe+camframes.count - 1
	animationRange = interval ar_start ar_end
)
	
fn md5camimport =
(
	set coordsys world
	md5filename=getOpenFileName types:"MD5Camera (*.md5camera)|*.md5camera|All (*.*)|*.*|"
	camobj = undefined
	if g_cam_selectedcam then
	(
		if ((getcurrentselection()).count > 0) then
		(
			for i=1 to (getcurrentselection()).count do
			(
				camobjsel = (getcurrentselection())[i]
				if (((superclassof camobjsel) as string) == "camera") do
				(
					camobj = camobjsel
					break
				)
			)
			if camobj == undefined then
			(
				messagebox "Select the camera that you want to use the imported animation."
			)
		)
		else
		(
			messagebox "Select the camera that you want to use the imported animation."
			return undefined
		)
	)
	
	if md5filename != undefined then 
	(
		if DoesFileExist md5filename then md5importcamerafile md5filename g_cam_startframe camobj
	)
)

fn md5animimport =
(
	if md5bones.count == 0 then
	(
		messagebox "Import a md5mesh first, then press md5anim import."
		return undefined
	)
	md5filename=getOpenFileName types:"MD5Anim (*.md5anim)|*.md5anim|All (*.*)|*.*|"
	
	if md5filename != undefined then 
	(
		if DoesFileExist md5filename then md5animfileimport md5filename 1
	)
)
	
rollout MD5importrollout "MD5 Import" width:184 height:336
(
	--button basepath_browse "Browse..." pos:[104,48] width:48 height:24
	--edittext basepath_edit "" pos:[8,48] width:96 height:24
	button import_btn "Import MD5..." pos:[16,64] width:147 height:32
	button info_button "Info about this importer" pos:[16,296] width:147 height:32 toolTip:"read some info here"
	
	
	--on basepath_browse pressed do
	--(
	--	tempbasepath = getsavepath caption:"Set gamedata BASE directory"
	--	if tempbasepath != undefined then g_basepath = tempbasepath
	--	basepath_edit.text = g_basepath
	--)

	--on basepath_edit entered basepathtext do
	--(
	--	g_basepath = basepathtext
	--)

	checkbox chk_seethrough "See-Through Mesh" pos:[16,16] width:144 height:16 checked:true
	checkbox chk_reorganizeskel "Reorient Bones" pos:[16,40] width:144 height:16 checked:false
	button importcam_btn "Import MD5camera..." pos:[16,248] width:147 height:32
	checkbox chk_cam_selectedcam "Import to selected camera" pos:[16,200] width:144 height:16 checked:false
	spinner spn_cam_startframe "" pos:[104,224] width:56 height:16 range:[0,10000,0] type:#integer
	label lbl1 "Import at frame #" pos:[16,224] width:88 height:16
	GroupBox grp1 "Camera Import" pos:[8,184] width:168 height:104
	GroupBox grp2 "Mesh Import" pos:[8,0] width:168 height:104
	button btn_animimport "Import MD5Anim..." pos:[16,136] width:147 height:32
	GroupBox grp3 "Anim Import" pos:[8,112] width:168 height:64

	on import_btn pressed do
	(
		md5bones = #()
		maxbones = #()
		md5mesh = #()
		maxmesh = #()
		md5import()
	)

	on info_button pressed do
	(
		messagebox "MD5 Importer V0.93a - 2004-08-30\n(C) 2004, der_ton (tom-@gmx.de)\nVisit www.doom3world.org forum for tech-support\nAny feedback is welcome! :)"
	)

	on chk_seethrough changed state do
		g_seethrough = chk_seethrough.checked

	on chk_reorganizeskel changed state do
		md5import_reorganizeskeleton  = chk_reorganizeskel.checked

	on importcam_btn pressed do
	(
		g_cam_startframe = spn_cam_startframe.value
		md5camimport()
	)

	on chk_cam_selectedcam changed state do
	(
		g_cam_selectedcam = chk_cam_selectedcam.checked
	)

	on btn_animimport pressed do
	(
		md5animimport()
	)
)
if MD5ImportFloater != undefined do
(
	closerolloutfloater MD5ImportFloater 
)
MD5ImportFloater = newRolloutFloater "MD5 Import" 210 400 
addRollout MD5importrollout MD5ImportFloater 

