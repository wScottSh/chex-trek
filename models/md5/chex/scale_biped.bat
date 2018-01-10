:: script to scale all biped anim's by 120%
@set scale=-s 1.20 1.20 1.20
@set md5scale=md5scale.exe
%md5scale% %scale% -m biped_old.md5mesh > biped.md5mesh
%md5scale% %scale% -a biped_old.md5anim > biped.md5anim
%md5scale% %scale% -a biped_idle_old.md5anim > biped_idle.md5anim
%md5scale% %scale% -a biped_melee1_old.md5anim > biped_melee1.md5anim
%md5scale% %scale% -a biped_melee2_old.md5anim > biped_melee2.md5anim
%md5scale% %scale% -a biped_pain1_old.md5anim > biped_pain1.md5anim
%md5scale% %scale% -a biped_pain2_old.md5anim > biped_pain2.md5anim
%md5scale% %scale% -a biped_walk_old.md5anim > biped_walk.md5anim
%md5scale% %scale% -a biped_range1_old.md5anim > biped_range1.md5anim
%md5scale% %scale% -a biped_range2_old.md5anim > biped_range2.md5anim
pause