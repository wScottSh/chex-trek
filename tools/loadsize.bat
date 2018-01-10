export DOOMPATH=/K/GAMES/DooM3/
export MODPATH=ChexTrek
export fixloadsize="doom3.exe +set fs_game $MODPATH +set com_updateLoadSize 1"
export MAPS="e1m1 sf_923"
export MODES="0 1 2 3"

cd $DOOMPATH
for s in $MODES
	do for m in $MAPS
		do $DOOMPATH$fixloadsize +set com_machineSpec $s +map $m +wait 100 +quit
	done
done	