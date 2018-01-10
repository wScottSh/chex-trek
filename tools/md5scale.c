//Matt Kory
//md5 scaling utility
//only supports 1 file at a time (make a script or use make)

#include "md5scale.h"

int seperateString( const char * string, const char * seperators, char *** seperated ) {
	char temp;
	int i=0;
	int j;
	int start = 0;
	int numelements=0;
	char ** elements;
	int maxelements = 0;
	while( temp != '\0' ){
		temp = string[i];
		j=0;
		while( seperators[j] != '\0' ){
			if( temp == seperators[j] ) {
				maxelements++;
			}
			j++;
		}
		i++;
	}
	i=0;
	elements = (char **)malloc_s((maxelements+1)*sizeof(char *));
	*seperated = elements;
	while( 1 ) {
		temp = string[i];
		j=0;
		while( seperators[j] != '\0' ) {
			if( temp == seperators[j] || temp == '\0' ) {
				if( i > start ) {
					elements[numelements]=(char *)malloc_s((i-start+1)*sizeof(char));
					memcpy( elements[numelements], string + start, (i-start)*sizeof(char) );
					elements[numelements][i-start] = '\0';
					//printf( "%s\n", elements[numelements] );
					numelements++;
				}
				start = i + 1;
			}
			j++;
		}
		i++;
		if( temp == '\0' ) {
			return numelements;
		}
	}
}

void readJoints( FILE * file, joint_t ** jointsp, int numjoints ) {
	char * readline = ( char * )malloc_s( MAX_LINE );
	joint_t * joints = (joint_t *)malloc_s(numjoints*sizeof(joint_t));
	*jointsp = joints;
	int i;
	for( i=0; i<numjoints; i++ ) {
		fgets( readline, MAX_LINE, file );
		char ** seperated;
		int numelements = seperateString( readline, SEPERATORS, &seperated );
		joints[i].name = (char *)malloc_s(sizeof(char) * (strlen( seperated[0] ) + 1) );
		strcpy( joints[i].name, seperated[0] );
		sscanf( seperated[1], "%i", &joints[i].parenti );
		sscanf( seperated[2], "%lf", &joints[i].xpos );
		sscanf( seperated[3], "%lf", &joints[i].ypos );
		sscanf( seperated[4], "%lf", &joints[i].zpos );
		sscanf( seperated[5], "%lf", &joints[i].xort );
		sscanf( seperated[6], "%lf", &joints[i].yort );
		sscanf( seperated[7], "%lf", &joints[i].zort );
		freeSeperated( seperated, numelements );
	}
	free_s( readline );
}

void readMesh( FILE * file, mesh_t * meshp ) {
	char * readline = ( char * )malloc_s( MAX_LINE );
	readline[0] = '\0';
	int vert,tri,weight;
	vert=tri=weight=0;
	while( readline[0] != '}' ) {
		fgets( readline, MAX_LINE, file );
		char ** seperated;
		int numelements = seperateString( readline, SEPERATORS, &seperated );
		if( !numelements ) {
			freeSeperated( seperated, numelements );
			continue;
		}
		if( !strncmp( seperated[0], "shader", 6 ) ) {
			meshp->shader = (char *)malloc_s(sizeof(char)*(strlen(seperated[1]) + 1));
			strcpy( meshp->shader, seperated[1] );
		}
		if( !strncmp( seperated[0], "numverts", 8 ) ) {
			sscanf( seperated[1], "%i", &meshp->numverts );
			meshp->verts = (vert_t *)malloc_s( sizeof(vert_t) * meshp->numverts );
		}
		if( !strncmp( seperated[0], "numtris", 8 ) ) {
			sscanf( seperated[1], "%i", &meshp->numtris );
			meshp->tris = (tri_t *)malloc_s( sizeof(tri_t) * meshp->numtris );
		}
		if( !strncmp( seperated[0], "numweights", 8 ) ) {
			sscanf( seperated[1], "%i", &meshp->numweights );
			meshp->weights = (weight_t *)malloc_s( sizeof(weight_t) * meshp->numweights );
		}
		if( !strncmp( seperated[0], "vert", 4 ) ) {
			sscanf( seperated[1], "%i", &meshp->verts[vert].verti );
			sscanf( seperated[2], "%lf", &meshp->verts[vert].texu );
			sscanf( seperated[3], "%lf", &meshp->verts[vert].texv );
			sscanf( seperated[4], "%i", &meshp->verts[vert].weighti );
			sscanf( seperated[5], "%i", &meshp->verts[vert].weighte );
			vert++;
		}
		if( !strncmp( seperated[0], "tri", 3 ) ) {
			sscanf( seperated[1], "%i", &meshp->tris[tri].trii );
			sscanf( seperated[2], "%i", &meshp->tris[tri].verti1 );
			sscanf( seperated[3], "%i", &meshp->tris[tri].verti2 );
			sscanf( seperated[4], "%i", &meshp->tris[tri].verti3 );
			tri++;
		}
		if( !strncmp( seperated[0], "weight", 6 ) ) {
			sscanf( seperated[1], "%i", &meshp->weights[weight].weighti );
			sscanf( seperated[2], "%i", &meshp->weights[weight].jointi );
			sscanf( seperated[3], "%lf", &meshp->weights[weight].weightv );
			sscanf( seperated[4], "%lf", &meshp->weights[weight].xpos );
			sscanf( seperated[5], "%lf", &meshp->weights[weight].ypos );
			sscanf( seperated[6], "%lf", &meshp->weights[weight].zpos );
			weight++;
		}
		freeSeperated( seperated, numelements );
	}
	free_s( readline );
}

		
		

meshfile_t * readMeshFile( FILE * meshf ) {
	char * readline = ( char * )malloc_s( MAX_LINE );
	int meshindex = 0;
	meshfile_t * meshfile = (meshfile_t *)malloc_s(sizeof(meshfile_t));
	while(1) {
		fgets( readline, MAX_LINE, meshf );
		if( feof( meshf ) ) {
			free_s( readline );
			return meshfile;
		}
		if( !strncmp( readline, "MD5Version", 10 ) ) {
			sscanf( readline + 11, "%i", &meshfile->version );
		}
		if( !strncmp( readline, "numJoints", 9 ) ) {
			sscanf( readline + 10, "%i", &meshfile->numjoints );
		}
		if( !strncmp( readline, "numMeshes", 9 ) ) {
			sscanf( readline + 10, "%i", &meshfile->nummeshes );
			meshfile->meshs = (mesh_t *)malloc_s( sizeof(mesh_t) * meshfile->nummeshes );
		}
		if( !strncmp( readline, "joints", 6 ) ) {
			readJoints( meshf, &meshfile->joints, meshfile->numjoints );
		}
		if( !strncmp( readline, "mesh", 4 ) ) {
			readMesh( meshf, &meshfile->meshs[meshindex] );
			meshindex++;
		}
	}
}

frame_t readFrame( FILE * file, int numjoints ) {
	int jointnum = 0;
	char * readline = ( char * )malloc_s( MAX_LINE );
	readline[0] = '\0';
	frame_t frame;
	frame.joints = (joint_t *)malloc_s(sizeof(joint_t)*numjoints);
	while( jointnum < numjoints ) {
		fgets( readline, MAX_LINE, file );
		char ** seperated;
		int numelements = seperateString( readline, SEPERATORS, &seperated );
		if( readline[0] == '}' ) {
			free_s( readline );
			freeSeperated( seperated, numelements );
			return frame;
		}
		sscanf( seperated[0], "%lf", &frame.joints[jointnum].xpos );
		sscanf( seperated[1], "%lf", &frame.joints[jointnum].ypos );
		sscanf( seperated[2], "%lf", &frame.joints[jointnum].zpos );
		sscanf( seperated[3], "%lf", &frame.joints[jointnum].xort );
		sscanf( seperated[4], "%lf", &frame.joints[jointnum].yort );
		sscanf( seperated[5], "%lf", &frame.joints[jointnum].zort );
		freeSeperated( seperated, numelements );
		jointnum++;
	}
	free_s( readline );
	return frame;
}
	
hierarchy_t * readHierarchy( FILE * file, int numjoints ) {
	int jointnum = 0;
	char * readline = ( char * )malloc_s( MAX_LINE );
	readline[0] = '\0';
	hierarchy_t * hierarchy = (hierarchy_t *)malloc_s(numjoints * sizeof(hierarchy_t));
	while( jointnum < numjoints ) {
		fgets( readline, MAX_LINE, file );
		char ** seperated;
		int numelements = seperateString( readline, SEPERATORS, &seperated );
		if( readline[0] == '}' ) {
			free_s( readline );
			freeSeperated( seperated, numelements );
			return hierarchy;
		}
		hierarchy[jointnum].bonename = (char *)malloc_s(sizeof(char)*(strlen(seperated[0])+1));
		memcpy( hierarchy[jointnum].bonename, seperated[0], strlen(seperated[0])+1 );
		sscanf( seperated[1], "%i", &hierarchy[jointnum].parenti );
		sscanf( seperated[2], "%i", &hierarchy[jointnum].numcomp );
		sscanf( seperated[3], "%i", &hierarchy[jointnum].framei );
		freeSeperated( seperated, numelements );
		jointnum++;
	}
	free_s( readline );
	return hierarchy;
}

bounds_t * readBounds( FILE * file, int numframes ) {
	int framenum = 0;
	char * readline = ( char * )malloc_s( MAX_LINE );
	readline[0] = '\0';
	bounds_t * bounds = (bounds_t *)malloc_s(sizeof(bounds_t)*numframes);
	while( framenum < numframes ) {
		fgets( readline, MAX_LINE, file );
		char ** seperated;
		int numelements = seperateString( readline, SEPERATORS, &seperated );
		if( readline[0] == '}' ) {
			free_s( readline );
			freeSeperated( seperated, numelements );
			return bounds;
		}
		sscanf( seperated[0], "%lf", &bounds[framenum].xmin );
		sscanf( seperated[1], "%lf", &bounds[framenum].ymin );
		sscanf( seperated[2], "%lf", &bounds[framenum].zmin );
		sscanf( seperated[3], "%lf", &bounds[framenum].xmax );
		sscanf( seperated[4], "%lf", &bounds[framenum].ymax );
		sscanf( seperated[5], "%lf", &bounds[framenum].zmax );
		freeSeperated( seperated, numelements );
		framenum++;
	}
	free_s( readline );
	return bounds;
}
		
animfile_t * readAnimFile( FILE * animf ) {
	char * readline = ( char * )malloc_s( MAX_LINE );
	animfile_t * animfile = (animfile_t *)malloc_s(sizeof(animfile_t));
	while(1) {
		fgets( readline, MAX_LINE, animf );
		if( feof( animf ) ) {
			free_s( readline );
			return animfile;
		}
		if( !strncmp( readline, "MD5Version", 10 ) ) {
			sscanf( readline + 11, "%i", &animfile->version );
		}
		if( !strncmp( readline, "numFrames", 9 ) ) {
			sscanf( readline + 10, "%i", &animfile->numframes );
			animfile->frames = (frame_t *)malloc_s(animfile->numframes*sizeof(frame_t));
		}
		if( !strncmp( readline, "numJoints", 9 ) ) {
			sscanf( readline + 10, "%i", &animfile->numjoints );
		}
		if( !strncmp( readline, "frameRate", 9 ) ) {
			sscanf( readline + 10, "%i", &animfile->framerate );
		}
		if( !strncmp( readline, "numAnimatedComponents", 21 ) ) {
			sscanf( readline + 22, "%i", &animfile->numanimatedcomponents );
		}
		if( !strncmp( readline, "hierarchy", 9 ) ) {
			animfile->hierarchy = readHierarchy( animf, animfile->numjoints );
		}
		if( !strncmp( readline, "bounds", 6 ) ) {
			animfile->bounds = readBounds( animf, animfile->numframes );
		}
		if( !strncmp( readline, "baseframe", 6 ) ) {
			animfile->baseframe = readFrame( animf, animfile->numjoints );
		}
		if( !strncmp( readline, "frame ", 6 ) ) {
			char ** seperated;
			int numelements = seperateString( readline, SEPERATORS, &seperated );
			int i;
			sscanf( seperated[1], "%i", &i );
			freeSeperated( seperated, numelements );
			animfile->frames[i] = readFrame( animf, animfile->numjoints );
		}
	}
}

void printMesh( meshfile_t * meshfile ) {
	int i,j;
	printf( "MD5Version %i\n", meshfile->version );
	printf( "commandline \"\"\n" );
	printf( "\n" );
	printf( "numJoints %i\n", meshfile->numjoints );
	printf( "numMeshes %i\n", meshfile->nummeshes );
	printf( "\n" );
	printf( "joints {\n" );
	for( i=0; i<meshfile->numjoints; i++ ) {
		joint_t * joint = &meshfile->joints[i];
		printf( "\t%s\t%i ( %.10lf %.10lf %.10lf ) ( %.10lf %.10lf %.10lf )\n", joint->name, joint->parenti, joint->xpos, joint->ypos, joint->zpos, joint->xort, joint->yort, joint->zort );
	}
	printf( "}\n" );
	printf( "\n" );
	for( i=0; i<meshfile->nummeshes; i++ ) {
		printf( "mesh {\n" );
		printf( "\tshader %s\n", meshfile->meshs[i].shader );
		printf( "\n" );
		printf( "\tnumverts %i\n", meshfile->meshs[i].numverts );
		for( j=0; j<meshfile->meshs[i].numverts; j++ ) {
			vert_t * vert = &meshfile->meshs[i].verts[j];
			printf( "\tvert %i ( %.10lf %.10lf ) %i %i\n", vert->verti, vert->texu, vert->texv, vert->weighti, vert->weighte );
		}
		printf( "\n\tnumtris %i\n", meshfile->meshs[i].numtris );
		for( j=0; j<meshfile->meshs[i].numtris; j++ ) {
			tri_t * tri = &meshfile->meshs[i].tris[j];
			printf( "\ttri %i %i %i %i\n", tri->trii, tri->verti1, tri->verti2, tri->verti3 );
		}
		printf( "\n\tnumweights %i\n", meshfile->meshs[i].numweights );
		for( j=0; j<meshfile->meshs[i].numweights; j++ ) {
			weight_t * weight = &meshfile->meshs[i].weights[j];
			printf( "\tweight %i %i %.10lf ( %.10lf %.10lf %.10lf )\n", weight->weighti, weight->jointi, weight->weightv, weight->xpos, weight->ypos, weight->zpos );
		}
		printf( "}\n\n" );
	}	
}


void printFrame( frame_t * frame, int numjoints, int isbaseframe ) {
	int i;
	for( i=0; i<numjoints; i++ ) {
		joint_t * joint = &frame->joints[i];
		if( isbaseframe )
			printf( "\t( %.10lf %.10lf %.10lf ) ( %.10lf %.10lf %.10lf )\n", joint->xpos, joint->ypos, joint->zpos, joint->xort, joint->yort, joint->zort );
		else
			printf( "\t%.10lf %.10lf %.10lf %.10lf %.10lf %.10lf\n", joint->xpos, joint->ypos, joint->zpos, joint->xort, joint->yort, joint->zort );
	}
}

void printAnim( animfile_t * animfile ) {
	int i;
	printf( "MD5Version %i\n", animfile->version );
	printf( "commandline \"\"\n\n" );
	printf( "numFrames %i\n", animfile->numframes );
	printf( "numJoints %i\n", animfile->numjoints );
	printf( "frameRate %i\n", animfile->framerate );
	printf( "numAnimatedComponents %i\n\n", animfile->numanimatedcomponents );
	printf( "hierarchy {\n" );
	for( i=0; i<animfile->numjoints; i++ ) {
		hierarchy_t * hierarchy = &animfile->hierarchy[i];
		printf( "\t%s\t%i %i %i\n", hierarchy->bonename, hierarchy->parenti, hierarchy->numcomp, hierarchy->framei );
	}
	printf( "}\n\n" );
	printf( "bounds {\n" );
	bounds_t * bounds = animfile->bounds;
	for( i=0; i<animfile->numframes; i++ ) {
		printf( "\t( %.10lf %.10lf %.10lf ) ( %.10lf %.10lf %.10lf )\n", bounds[i].xmin, bounds[i].ymin, bounds[i].zmin, bounds[i].xmax, bounds[i].ymax, bounds[i].zmax );
	}
	printf( "}\n\n" );
	printf( "baseframe {\n" );
	printFrame( &animfile->baseframe, animfile->numjoints, 1 );
	printf( "}\n\n" );
	for( i=0; i<animfile->numframes; i++ ) {
		printf( "frame %i {\n", i );
		printFrame( &animfile->frames[i], animfile->numjoints, 0 );
		printf( "}\n\n" );
	}
}
	
	


/*
int parseAnims( char * animss ) {
	char temp;
	int i = 0;
	int animc = 0;
	do{
		temp = animss[i];
		if( temp == ',' )
			animc++;
		i++;
	} while( temp != 0 );
	animc++;
	anims = (char **)malloc( animc * sizeof(char *) );
	i=0;
	animc = 0;
	int start = -1;
	do{
		temp = animss[i];
		if( temp == ',' || temp == '\0' ) {
			anims[animc]=(char *)malloc( ( i - start ) * sizeof(char) );
			memcpy( anims[animc], animss + start + 1, ( i - start - 1 ) * sizeof(char) );
			anims[animc][i-start-1] = '\0';
			start = i;			
			animc++;
		}
		i++;
	} while( temp != 0 );
	return animc;
}	
*/

void reorderJointsMesh( meshfile_t * meshfile ) {
	int i,j;
	for( i=0; i<meshfile->numjoints; i++ ) {
		fprintf( stderr, "%i. %s\n", i, meshfile->joints[i].name );
	}
	joint_t * newjoints = (joint_t *)malloc_s( meshfile->numjoints * sizeof( joint_t ) );
	fprintf( stderr, "Enter new order of joints ie '0 2 1 5 3 ....'\n" );
	char buffer[200];
	int * neworder = (int *)malloc_s( sizeof(int)*meshfile->numjoints );
	gets( buffer );
	char ** seperated;
	int numelements = seperateString( buffer, SEPERATORS, &seperated );
	for( i=0; i<meshfile->numjoints; i++ ) {
		sscanf( seperated[i], "%i", &neworder[i] );
	}
	for( i=0; i<meshfile->numjoints; i++ ) {
		memcpy( &newjoints[i], &meshfile->joints[neworder[i]], sizeof(joint_t) );
	}
	//fix up parent index
	for( i=0; i<meshfile->numjoints; i++ ) {
		for( j=0; j<meshfile->numjoints; j++ ) {
			if( neworder[j]==newjoints[i].parenti ) {
				newjoints[i].parenti = ( newjoints[i].parenti == -1 ) ? -1 : j;
				break;
			}
		}
	}
	for( i=0; i<meshfile->nummeshes; i++ ) {
		for( j=0; j<meshfile->meshs[i].numweights; j++ ) {
			meshfile->meshs[i].weights[j].jointi = neworder[ meshfile->meshs[i].weights[j].jointi ];
		}
	}		
	free_s( meshfile->joints );
	freeSeperated( seperated, numelements );
	meshfile->joints = newjoints;
}	
void scaleMesh( meshfile_t * meshfile, const double scale[3] ) {
	int i,j;
	for( i=0; i<meshfile->nummeshes; i++ ) {
			for( j=0; j<meshfile->meshs[i].numweights; j++ ) {
				meshfile->meshs[i].weights[j].xpos *= scale[0];
				meshfile->meshs[i].weights[j].ypos *= scale[1];
				meshfile->meshs[i].weights[j].zpos *= scale[2];
			}
		}
	for( i=0; i<meshfile->numjoints; i++ ) {
		meshfile->joints[i].xpos *= scale[0];
		meshfile->joints[i].ypos *= scale[1];
		meshfile->joints[i].zpos *= scale[2];
	}
}

void scaleAnim( animfile_t * animfile, const double scale[3] ) {
	int i,j;
	for( i=0; i<animfile->numframes; i++ ) {
		animfile->bounds[i].xmin *= scale[0];
		animfile->bounds[i].ymin *= scale[1];
		animfile->bounds[i].zmin *= scale[2];
		animfile->bounds[i].xmax *= scale[0];
		animfile->bounds[i].ymax *= scale[1];
		animfile->bounds[i].zmax *= scale[2];
	}
	for( i=0; i<animfile->numframes; i++ ) {
		for( j=0; j<animfile->numjoints; j++ ) {
			animfile->frames[i].joints[j].xpos *= scale[0];
			animfile->frames[i].joints[j].ypos *= scale[1];
			animfile->frames[i].joints[j].zpos *= scale[2];
		}
	}
	for( j=0; j<animfile->numjoints; j++ ) {
		animfile->baseframe.joints[j].xpos *= scale[0];
		animfile->baseframe.joints[j].ypos *= scale[1];
		animfile->baseframe.joints[j].zpos *= scale[2];
	}
}

void showHelp( void ) {
	printf( "md5Scale Utility\n"
			"----------------\n"
			"-s  X Y Z             scale\n"
			"-m  mesh              mesh\n"
			"-a  anim              animation\n"
			"-r                    reorder joints (mesh only)\n"
			"-h                    help\n"
	);
}

int main( int nargs, char ** args ) {
	int i,options;
	char * mesh; //mesh file name
	meshfile_t * meshfile;
	double scale[3] = { 1.0, 1.0, 1.0 };
	char * anim;
	animfile_t * animfile;
	options = 0;
	for( i=1; i<nargs; i++ ) {
		if( !strcmp(args[i],"-m") ) {
			i++;
			mesh = args[i];
			options |= MESHOP;
			continue;
		}
		if( !strcmp(args[i],"-s") ) {
			i++;
			sscanf( args[i], "%lf", &scale[0] );
			i++;
			sscanf( args[i], "%lf", &scale[1] );
			i++;
			sscanf( args[i], "%lf", &scale[2] );
			options |= SCALE;
			continue;
		}
		if( !strcmp(args[i],"-a") ) {
			i++;
			anim = args[i];
			options |= ANIMOP;
			continue;
		}
		if( !strcmp(args[i],"-r") ) {
			options |= REORDER;
			continue;
		}
		if( !strcmp(args[i],"-h") ) {
			showHelp();
			return 0;
		} else {
			printf( "unknown option - %s\n", args[i] );
			showHelp();
			return 1;
		}
	}
	if( !options ) {
		showHelp();
		return 0;
	}
	if( (options & MESHOP) && (options & ANIMOP) ) {
		printf( "Only one file at a time\n" );
		return 1;
	}
	if( options & MESHOP ) {
		FILE * meshf;
		meshf = fopen( mesh, "rb" );
		if( !meshf ){
			printf( "can't open %s\n", mesh );
			return 1;
		}
		meshfile = readMeshFile( meshf );
		fclose( meshf );
	}
	if( options & ANIMOP ) {
		FILE * animf;
		animf = fopen( anim, "rb" );
		if( !animf ){
			printf( "can't open %s\n", anim );
			return 1;
		}
		animfile = readAnimFile( animf );
		fclose( animf );
	}
	if( options & MESHOP && options & SCALE ) {
		scaleMesh( meshfile, scale );
	}
	if( options & ANIMOP && options & SCALE ) {
		scaleAnim( animfile, scale );
	}
	if( options & MESHOP && options & REORDER ) {
		reorderJointsMesh( meshfile );
	}
	if( options & MESHOP ) {
		printMesh( meshfile );
	}
	if( options & ANIMOP ) {
		printAnim( animfile );
	}
	return 0;
}


