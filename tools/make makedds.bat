@set DOOMPATH=K:\GAMES\DooM3\
@set MODPATH=chex
@set GAWKPATH=K:\CODING\msys\bin\
@set MAPS=+map e1m1 +map sf_923 +map office

start /D%DOOMPATH% /WAIT %DOOMPATH%\doom3.exe +set fs_game %MODPATH% +set image_usePrecompressedTextures 0 +set image_useNormalCompression 1 +set image_useOfflineCompression 1 +set com_makingBuild 1 +startBuild +vid_restart +wait 100 %MAPS% +wait 100 +finishBuild +quit
%GAWKPATH%\gawk.exe -f%DOOMPATH%\%MODPATH%\tools\atidds.awk %DOOMPATH%\%MODPATH%\makedds.bat > chexdds.bat
pause

