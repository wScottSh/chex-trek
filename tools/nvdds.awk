BEGIN { 
	RS = "\n"
	FS = " "
	nvdxt = "c:\\path\\nvdds\\nvdxt"
}

{ 
	if( $1 == "@echo" ) {
		print $0
	} else {
		i = index( $3, "\\dds\\" )
		input = " -file " substr( $3, 0, i ) substr( $3, i+5 )
		temp = $4
		sub( /\\[^ \\]*\....\"/, "" , temp )
		print "dir " temp
		print "if ERRORLEVEL 1 mkdir " temp
		out = " -output " $4
		if( $5 == "DXT3" ) {
			options = " -dxt3"
		}
		if( $5 == "DXT1" ) {
			options = " -dxt1c"
		}
		if( $5 == "RXGB" ) {
			#this actually doesnt work
			options = " -dxt5"
		}
		print nvdxt input out options
	}
}

END {
}


