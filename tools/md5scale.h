//Matt Kory
//md5 scaling utility
//only supports 1 file at a time (make a script or use make)

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

inline void free_s( void * ptr ) {
	free( ptr );
	ptr = NULL;
	return;
}

inline void * malloc_s( size_t size ) {
	void * rt = malloc( size );
	assert( rt );
	return rt;
}

inline void freeSeperated( char ** seperated, int numelements ) {
	int i;
	for( i=0; i<numelements; i++ ) {
		free_s( seperated[i] );
	}
	free_s( seperated );
}

#define MESHOP 1
#define ANIMOP 2
#define SCALE 4
#define REORDER 8

#define MAX_LINE sizeof(char) * 200

char SEPERATORS[] = { 10, 13, '\t', '(', ')', ' ', '\0' };

typedef struct {
	int verti;
	double texu;
	double texv;
	int weighti;
	int weighte;
} vert_t;

typedef struct {
	int trii;
	int verti1;
	int verti2;
	int verti3;
} tri_t;

typedef struct {
	int weighti;
	int jointi;
	double weightv;
	double xpos;
	double ypos;
	double zpos;
} weight_t;

typedef struct {
	char * name;
	int parenti;
	double xpos;
	double ypos;
	double zpos;
	double xort;
	double yort;
	double zort;
} joint_t;

typedef struct {
	char * shader;
	int numverts;
	vert_t * verts;
	int numtris;
	tri_t * tris;
	int numweights;
	weight_t * weights;	
} mesh_t;
	
typedef struct {
	int version;
	int numjoints;
	joint_t * joints;
	int nummeshes;
	mesh_t * meshs;
} meshfile_t;

typedef struct {
	char * bonename;
	int parenti;
	int numcomp;
	int framei;
} hierarchy_t;

typedef struct {
	double xmin;
	double ymin;
	double zmin;
	double xmax;
	double ymax;
	double zmax;
} bounds_t;

typedef struct {
	joint_t * joints;
} frame_t;

typedef struct {
	int version;
	int numframes;
	int numjoints;
	int framerate;
	int numanimatedcomponents;
	hierarchy_t * hierarchy;
	bounds_t * bounds;
	frame_t baseframe;
	frame_t * frames;
} animfile_t;


inline void free_s( void * ptr );
inline void * malloc_s( size_t size );

int seperateString( const char * string, const char * seperators, char *** seperated );
inline void freeSeperated( char ** seperated, int numelements );

void readJoints( FILE * file, joint_t ** jointsp, int numjoints );

meshfile_t * readMeshFile( FILE * meshf );
void readMesh( FILE * file, mesh_t * meshp );
void reorderJointsMesh( meshfile_t * meshfile );
void scaleMesh( meshfile_t * meshfile, const double scale[3] );
void printMesh( meshfile_t * meshfile );

animfile_t * readAnimFile( FILE * animf );
frame_t readFrame( FILE * file, int numjoints );
bounds_t * readBounds( FILE * file, int numframes );
hierarchy_t * readHierarchy( FILE * file, int numjoints );
void scaleAnim( animfile_t * animfile, const double scale[3] );
void printFrame( frame_t * frame, int numjoints, int isbaseframe );
void printAnim( animfile_t * animfile );

void showHelp( void );

