BEGIN { 
	RS = "\n"
	FS = " "
	compressor = "K:\\PATH\\ATI_COMP\\thecompressonator -convert "
}

{ 
	if( $1 == "@echo" ) {
		print $0
	} else {
		i = index( $3, "\\dds\\" )
		input = substr( $3, 0, i ) substr( $3, i+5 )
		out = " " $4
		print compressor input out " " $5 " " $6 " " $7 " " $8 " " $9 " " $10 " " $11 " " $12 " " $13 " " $14 " " $15 " " $16 " " $17 " " $18 " " $19 " " $20
	}
}

END {
}


