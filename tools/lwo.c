#include <stdio.h>
#include <fcntl.h>
#include <string.h>



typedef struct {
	unsigned int tag;
	unsigned int length;
	unsigned int size;
	unsigned char *data;
} chunk_t;

typedef struct {
	unsigned int tag;
	unsigned int length;
	unsigned int fileID;
	unsigned int file_size;
	int num_chunks;
	chunk_t *chunks[200];  //better never have more than 200 chunks :P
} lwoFile;

unsigned char * flipBytes ( unsigned char *data, int num_bytes ) {
	unsigned char *newnum = ( unsigned char * )malloc( num_bytes );
	int i;
	for ( i = 0; i != num_bytes; i++ ) {
		newnum[i] = data[ num_bytes - 1 - i];
	}
	return newnum;
}

void readlwo ( FILE * file, lwoFile * lwo ) {
	fread ( &lwo->tag, 4, 1, file );
	fread ( &lwo->length, 4, 1, file );
	fread ( &lwo->fileID, 4, 1, file );
	lwo->file_size = *(unsigned int *)flipBytes( (unsigned char *)&(lwo->length), 4 );
	//start reading chunks
	while ( 1 ) {
		unsigned int id;
		fread ( &id, 4, 1, file );
		unsigned int len;
		fread ( &len, 4, 1, file );
		if ( feof(file) )
			break;
		unsigned int *size = (unsigned int *)flipBytes( (unsigned char *)&len, 4 );
		unsigned char *data = (unsigned char *)malloc( *size );
		fread ( data, *size, 1, file );
		chunk_t *chunk = (chunk_t *)malloc(sizeof(chunk_t));
		chunk->tag = id;
		chunk->length = len;
		chunk->size = *size;
		chunk->data = data;
		lwo->chunks[lwo->num_chunks] = chunk;
		lwo->num_chunks++;
	}
}

void printChar4B ( unsigned int print ) {
	printf ( "%c%c%c%c\n", print>>24, (print & 0x00ff0000) >> 16, (print & 0x0000ff00) >> 8, print & 0x000000ff);
}

void printChunk ( chunk_t *chunk ) {
	printChar4B( *(unsigned int *)flipBytes( (unsigned char *)&(chunk->tag), 4 ) );
	printf ( "%08x\n", chunk->size );
	int i;
	for (i=0;i<chunk->size;i++) {
		printf("%02x", chunk->data[i]);
	}
	printf("\n");
}

void printLWO ( lwoFile * lwo ) {
	printChar4B( *(unsigned int *)flipBytes( (unsigned char *)&(lwo->tag), 4 ) );
	printf ( "%08x\n", lwo->file_size );
	printChar4B( *(unsigned int *)flipBytes( (unsigned char *)&(lwo->fileID), 4 ) );
	int i;
	for (i=0;i<lwo->num_chunks;i++) {
		printChunk( lwo->chunks[i] );
	}
}

int findLetters ( lwoFile * lwo ) {
	int i;
	int j;
	for (i=0;i<lwo->num_chunks;i++) {
		printf("%i-",i);
		printChar4B( *(unsigned int *)flipBytes( (unsigned char *)&(lwo->chunks[i]->tag), 4 ) );
		for (j=0;j<lwo->chunks[i]->size;j++) {
			if ( (lwo->chunks[i]->data[j] >= 'A' && lwo->chunks[i]->data[j] <= 'Z') || (lwo->chunks[i]->data[j] >= 'a' && lwo->chunks[i]->data[j] <= 'z') )
				printf( "%c", lwo->chunks[i]->data[j] );
		}
		printf( "\n" );
	}
	printf( "Which chunk do you want to modify?" );
	scanf( "%i", &i );
	return i;
}

int doFind ( lwoFile * lwo, char *outfile ) {
	int chunk = findLetters ( lwo );
	FILE * out = fopen( outfile, "wb" );
	if ( out==NULL ) {
		printf("error opening file %s\n", outfile);
		return 1;
	}
	fwrite( &chunk, 4, 1, out );	
	fwrite( &lwo->chunks[chunk]->tag, 4, 1, out );	
	//fwrite( &lwo->chunks[chunk]->length, 4, 1, out );
	fwrite( lwo->chunks[chunk]->data, lwo->chunks[chunk]->size, 1, out );
	fclose( out );
	return 0;
}

int writeFile ( lwoFile * lwo, char *outfile, chunk_t chunk, int chunk_num ) {
	FILE * out = fopen( outfile, "wb" );
	if ( out==NULL ) {
		printf("error opening file %s\n", outfile);
		return 1;
	}
	fwrite ( &lwo->tag, 4, 1, out );
	unsigned int new_size = lwo->file_size + ( chunk.size - lwo->chunks[chunk_num]->size );
	unsigned int *size = (unsigned int *)flipBytes( (unsigned char *)&new_size, 4 );
	fwrite ( size, 4, 1, out );
	fwrite ( &lwo->fileID, 4, 1, out );
	int i;
	for ( i=0; i<lwo->num_chunks; i++ ) {
		if ( i != chunk_num ) {
			fwrite ( &lwo->chunks[i]->tag, 4, 1, out );
			fwrite ( &lwo->chunks[i]->length, 4, 1, out );
			fwrite ( lwo->chunks[i]->data, lwo->chunks[i]->size, 1, out );
		} else {
			fwrite ( &chunk.tag, 4, 1, out );
			fwrite ( &chunk.length, 4, 1, out );
			fwrite ( chunk.data, chunk.size, 1, out );
		}
	}
	fclose(out);
	return 0;
}

int applyFile ( lwoFile * lwo, char *modfile, char *outfile ) {
	FILE * in = fopen ( modfile, "rb" );
	if ( in==NULL ) {
		printf("error opening file %s\n", modfile);
		return 1;
	}
	chunk_t chunk;
	int chunk_num;
	fread( &chunk_num, 4, 1, in );	
	fread( &chunk.tag, 4, 1, in );	
	unsigned int i = 0;
		
	char crap;
	while ( !feof(in) ) {
		fread ( &crap, 1, 1, in );
		//printf("%c",crap);
		i++;
	}
	i--;
	unsigned char *temp_data = (unsigned char *)malloc(i);
	chunk.data = temp_data;
	fseek( in, 8L, SEEK_SET );
	i=0;
	while ( !feof(in) ) {
		fread ( &chunk.data[i], 1, 1, in );
		//printf("%c",chunk.data[i]);
		i++;
	}
	i--;
	chunk.size = i;
	//printf( "%i\n" , i );
	if ( i%2 != 0 )
		if ( chunk.data[i-1]==0 && chunk.data[i-2]==0 ) {
			unsigned char *new_data = (unsigned char *)malloc(i-1);
			memcpy( new_data, chunk.data, i-1 );
			free( chunk.data );
			chunk.data = new_data;
			chunk.size = i-1;
			//printf ( "1" );
		}
		else {
			unsigned char *new_data = (unsigned char *)malloc(i+1);
			memcpy( new_data, chunk.data, i );
			chunk.data[i]=0;
			free( chunk.data );
			chunk.data = new_data;
			chunk.size = i+1;
			//printf ( "2" );
		}
	chunk.length = chunk.size;
	chunk.length  = *(unsigned int *)flipBytes( (unsigned char *)&chunk.length, 4 );
	fclose (in);
	return writeFile ( lwo, outfile, chunk, chunk_num );		
}


int main ( int argc, char **argv ) {
	int i;
	char *filename = NULL;
	char *modfile = NULL;
	char *outfile = NULL;
	int find = 0;
	int verbose = 0;
	for ( i=1; i<argc; i++ ) {
		if ( !strncmp( argv[i], "--", 2 ) ) {
			if ( !strcmp( "help", &argv[i][2] ) ) {
				printf( 
						"LWO CHUNK MODIFYING UTILITY\n"
						"---------------------------\n"
						"--help		This screen\n"
						"--file	[file]	The LWO file to modify\n"
						"--find		Find the chunk you want to modify\n"
						"--apply [file]	Modified chunk to apply to LWO file\n"
						"--out [file]	Output file\n"
						"--verbose	print a bunch of crap\n" );	
				return 0;
			} else
			if ( !strcmp( "file", &argv[i][2] ) ) {
				if ( i+1 < argc ) {
					filename = argv[ i + 1 ];
					i++;
				} else { printf( "no file specified\n" );
						 return 1;
					   }
			} else
			if ( !strcmp( "out", &argv[i][2] ) ) {
				if ( i+1 < argc ) {
					outfile = argv[ i + 1 ];
					i++;
				} else { printf( "no out file specified\n" );
						 return 1;
					   }
			} else
			if ( !strcmp( "find", &argv[i][2] ) ) {
				find = 1;
			} else
			if ( !strcmp( "apply", &argv[i][2] ) ) {
				if ( i+1 < argc ) {
					modfile = argv[ i + 1 ];
					i++;
				} else { printf( "no apply file specified\n" );
						 return 1;
					   }
			} else
			if ( !strcmp( "verbose", &argv[i][2] ) ) {
				verbose = 1;
			} else { printf ("unknown option %s, try --help\n", argv[i]);
				   	 return 1; }
		} else { printf ("unknown option %s, try --help\n", argv[i]);
				 return 1; }
	}
	
	FILE * file;
	lwoFile lwo;
	lwo.num_chunks = 0;
	if ( filename != NULL ) {
		if ( modfile != NULL && find ) {
			printf ("find and apply are exclusive\n");
			return 1;
		}
		file = fopen ( filename, "rb" );
		if ( file == NULL ) {
			printf ("error opening file %s", filename);
			return 1;
		}
		readlwo ( file, &lwo );
		fclose ( file );
		if ( verbose )
			printLWO ( &lwo );
		if ( ( find || modfile != NULL ) && outfile == NULL ) {
			printf( "must specify out file\n" );
			return 1;
		}
		if ( find )
			return doFind ( &lwo, outfile );
		if ( modfile != NULL )
			return applyFile ( &lwo, modfile, outfile );
	} else printf( "Must enter a filename\n" );
	
	return 0;
}
