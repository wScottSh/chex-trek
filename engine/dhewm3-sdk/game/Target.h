/*
===========================================================================

Doom 3 GPL Source Code
Copyright (C) 1999-2011 id Software LLC, a ZeniMax Media company.

This file is part of the Doom 3 GPL Source Code ("Doom 3 Source Code").

Doom 3 Source Code is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Doom 3 Source Code is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Doom 3 Source Code.  If not, see <http://www.gnu.org/licenses/>.

In addition, the Doom 3 Source Code is also subject to certain additional terms. You should have received a copy of these additional terms immediately following the terms and conditions of the GNU General Public License which accompanied the Doom 3 Source Code.  If not, please request a copy in writing from id Software at the address below.

If you have questions concerning this license or the applicable additional terms, you may contact in writing id Software LLC, c/o ZeniMax Media Inc., Suite 120, Rockville, Maryland 20850 USA.

===========================================================================
*/

#ifndef __GAME_TARGET_H__
#define __GAME_TARGET_H__

#include "idlib/math/Interpolate.h"

#include "Entity.h"
// chextrek: spec #16/#33 (decomp-so/reference/end-level-stats.md). idTarget_EndLevelGUI's
// displayStats member is playerStats_s by value (declared in Player.h, next to idPlayer::
// levelStats, which needs the full definition too - see the comment there for why it lives there
// rather than here).
#include "Player.h"

/*
===============================================================================

idTarget

===============================================================================
*/

class idTarget : public idEntity {
public:
	CLASS_PROTOTYPE( idTarget );
};


/*
===============================================================================

idTarget_Remove

===============================================================================
*/

class idTarget_Remove : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_Remove );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_Show

===============================================================================
*/

class idTarget_Show : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_Show );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_Damage

===============================================================================
*/

class idTarget_Damage : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_Damage );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_SessionCommand

===============================================================================
*/

class idTarget_SessionCommand : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_SessionCommand );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_EndLevel

===============================================================================
*/

class idTarget_EndLevel : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_EndLevel );

private:
	void				Event_Activate( idEntity *activator );

};


/*
===============================================================================

idTarget_WaitForButton

===============================================================================
*/

class idTarget_WaitForButton : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_WaitForButton );

	void				Think( void );

private:
	void				Event_Activate( idEntity *activator );
};

/*
===============================================================================

idTarget_SetGlobalShaderTime

===============================================================================
*/

class idTarget_SetGlobalShaderTime : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_SetGlobalShaderTime );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_SetShaderParm

===============================================================================
*/

class idTarget_SetShaderParm : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_SetShaderParm );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_SetShaderTime

===============================================================================
*/

class idTarget_SetShaderTime : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_SetShaderTime );

private:
	void				Event_Activate( idEntity *activator );
};

/*
===============================================================================

idTarget_FadeEntity

===============================================================================
*/

class idTarget_FadeEntity : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_FadeEntity );

						idTarget_FadeEntity( void );

	void				Save( idSaveGame *savefile ) const;
	void				Restore( idRestoreGame *savefile );

	void				Think( void );

private:
	idVec4				fadeFrom;
	int					fadeStart;
	int					fadeEnd;

	void				Event_Activate( idEntity *activator );
};

/*
===============================================================================

idTarget_LightFadeIn

===============================================================================
*/

class idTarget_LightFadeIn : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_LightFadeIn );

private:
	void				Event_Activate( idEntity *activator );
};

/*
===============================================================================

idTarget_LightFadeOut

===============================================================================
*/

class idTarget_LightFadeOut : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_LightFadeOut );

private:
	void				Event_Activate( idEntity *activator );
};

/*
===============================================================================

idTarget_Give

===============================================================================
*/

class idTarget_Give : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_Give );

	void				Spawn( void );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_GiveEmail

===============================================================================
*/

class idTarget_GiveEmail : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_GiveEmail );

	void				Spawn( void );

private:
	void				Event_Activate( idEntity *activator );
};

/*
===============================================================================

idTarget_SetModel

===============================================================================
*/

class idTarget_SetModel : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_SetModel );

	void				Spawn( void );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_SetInfluence

===============================================================================
*/

class idTarget_SetInfluence : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_SetInfluence );

						idTarget_SetInfluence( void );

	void				Save( idSaveGame *savefile ) const;
	void				Restore( idRestoreGame *savefile );

	void				Spawn( void );

private:
	void				Event_Activate( idEntity *activator );
	void				Event_RestoreInfluence();
	void				Event_GatherEntities();
	void				Event_Flash( float flash, int out );
	void				Event_ClearFlash( float flash );
	void				Think( void );

	idList<int>			lightList;
	idList<int>			guiList;
	idList<int>			soundList;
	idList<int>			genericList;
	float				flashIn;
	float				flashOut;
	float				delay;
	idStr				flashInSound;
	idStr				flashOutSound;
	idEntity *			switchToCamera;
	idInterpolate<float>fovSetting;
	bool				soundFaded;
	bool				restoreOnTrigger;
};


/*
===============================================================================

idTarget_SetKeyVal

===============================================================================
*/

class idTarget_SetKeyVal : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_SetKeyVal );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_SetFov

===============================================================================
*/

class idTarget_SetFov : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_SetFov );

	void				Save( idSaveGame *savefile ) const;
	void				Restore( idRestoreGame *savefile );

	void				Think( void );

private:
	idInterpolate<int>	fovSetting;

	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_SetPrimaryObjective

===============================================================================
*/

class idTarget_SetPrimaryObjective : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_SetPrimaryObjective );

private:
	void				Event_Activate( idEntity *activator );
};

/*
===============================================================================

idTarget_LockDoor

===============================================================================
*/

class idTarget_LockDoor: public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_LockDoor );

private:
	void				Event_Activate( idEntity *activator );
};

/*
===============================================================================

idTarget_CallObjectFunction

===============================================================================
*/

class idTarget_CallObjectFunction : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_CallObjectFunction );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_LockDoor

===============================================================================
*/

class idTarget_EnableLevelWeapons : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_EnableLevelWeapons );

private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_Tip

===============================================================================
*/

class idTarget_Tip : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_Tip );

						idTarget_Tip( void );

	void				Spawn( void );

	void				Save( idSaveGame *savefile ) const;
	void				Restore( idRestoreGame *savefile );

private:
	idVec3				playerPos;

	void				Event_Activate( idEntity *activator );
	void				Event_TipOff( void );
	void				Event_GetPlayerPos( void );
};

/*
===============================================================================

idTarget_GiveSecurity

===============================================================================
*/
class idTarget_GiveSecurity : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_GiveSecurity );
private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_RemoveWeapons

===============================================================================
*/
class idTarget_RemoveWeapons : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_RemoveWeapons );
private:
	void				Event_Activate( idEntity *activator );
};


/*
===============================================================================

idTarget_LevelTrigger

===============================================================================
*/
class idTarget_LevelTrigger : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_LevelTrigger );
private:
	void				Event_Activate( idEntity *activator );
};

/*
===============================================================================

idTarget_EnableStamina

===============================================================================
*/
class idTarget_EnableStamina : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_EnableStamina );
private:
	void				Event_Activate( idEntity *activator );
};

/*
===============================================================================

idTarget_FadeSoundClass

===============================================================================
*/
class idTarget_FadeSoundClass : public idTarget {
public:
	CLASS_PROTOTYPE( idTarget_FadeSoundClass );
private:
	void				Event_Activate( idEntity *activator );
	void				Event_RestoreVolume();
};


/*
===============================================================================

idCustomUI

chextrek: spec #16/#33, ported from decomp-so/reference/custom-ui.md. Abstract. An entity that
shows a GUI to the local player and routes that GUI's commands back to itself. Its one subclass is
idTarget_EndLevelGUI, below.

===============================================================================
*/

class idCustomUI : public idEntity {
public:
	ABSTRACT_PROTOTYPE( idCustomUI );

						idCustomUI( void );
						~idCustomUI( void );

	void				Save( idSaveGame *savefile ) const;
	void				Restore( idRestoreGame *savefile );

	void				setGUI( const char *guiName );
	void				RegisterGUI( void );
	void				UnregisterGUI( void );

	// New virtual (not on idEntity). The stock idPlayer::HandleSingleGuiCommand edit (Player.cpp)
	// calls this on player->customUIEntity when player->customUI is also non-NULL.
	virtual bool		HandleCustomGUICommand( idEntity *entityGui, idToken *token );

	idUserInterface *	gui;
	bool				registered;

private:
	void				Event_Hide( void );	// replaces idEntity::Event_Hide for EV_Hide
};


/*
===============================================================================

idTarget_EndLevelGUI

chextrek: spec #16/#33, ported from decomp-so/reference/end-level-stats.md. Shows the end-of-level
stats GUI (entityDef target_endLevelGUI, def/endlevelgui.def) to the local player, counts each
line up on it, then starts the next map (or triggers its targets).

===============================================================================
*/

class idTarget_EndLevelGUI : public idCustomUI {
public:
	CLASS_PROTOTYPE( idTarget_EndLevelGUI );

						~idTarget_EndLevelGUI( void );

	void				Spawn( void );
	void				Save( idSaveGame *savefile ) const;
	void				Restore( idRestoreGame *savefile );

	// Overrides idCustomUI's: re-implements "unregister" instead of calling it.
	virtual bool		HandleCustomGUICommand( idEntity *entityGui, idToken *token );

private:
	// The counts shown so far, one per line of the screen (same order as idPlayer::levelStats).
	// Only total and found are used here, and not with the player's meaning: total holds the
	// percent shown ([3]: the time shown, in ms) and found the count shown. The name pointers stay
	// NULL.
	playerStats_s		displayStats[ 4 ];
	int					unknown2d4;			// zeroed in Spawn, saved and restored, read nowhere else
	int					timeStep;			// ms added to the shown time per tic
	const idSoundShader *ticSound;			// "s_shader", played every tic. Not saved.
	int					state;				// -1 idle, 0-2 counting stats[state], 3 time, 4 pause, 5 next map

	bool				updateStats( playerStats_s *stats, playerStats_s *display );

	void				Event_Activate( idEntity *activator );
	void				Event_UpdateStats( void );
};


/*
===============================================================================

mkObjective

chextrek: spec #16/#31 (decomp-so/reference/objectives.md). A map objective (entityDef
trigger_objective, def/func_envshot.def). Triggering it adds it to the local player's objective
list: its image goes on the HUD map and the PDA map, its title and description on the PDA.
Triggering it again removes it (and, with "remove" "1", the entity).

===============================================================================
*/

class mkObjective : public idEntity {
public:
	CLASS_PROTOTYPE( mkObjective );

	// No declared destructor: the reference marks whether the original had an empty ~mkObjective()
	// as UNCERTAIN (both decompiled clones only run the compiler-generated member/base
	// destructors), and behaves the same either way - see decomp-so/reference/objectives.md.

	void				Spawn( void );
	// Save/Restore intentionally do NOT persist objectiveNum/mapLevel, matching the reference:
	// Restore re-attaches (below) when active, which sets both again via idPlayer::addObjective.
	void				Save( idSaveGame *savefile ) const;
	void				Restore( idRestoreGame *savefile );

	// UNCERTAIN: access level of everything below except mapLevel in the reference - kept public
	// there (and here) because idPlayer::updateMapUI, the hud-map group's future reader, needs it.
	int					objectiveNum;	// number addObjective gave (1-5), -1 if the list was full
	idStr				image;			// map icon material (map_obj%d)
	idStr				title;			// PDA title (map_obj%d_tle)
	int					mapLevel;		// HUD map level of the origin (idPlayer::HudMapLevel)
	idStr				description;	// PDA text (map_obj%d_txt)
	bool				active;			// true while on the player's list. Saved.

	bool				AttachToLocalPlayer( bool showMessage );
	void				RemoveFromLocalPlayer( bool showMessage );

private:
	void				Event_Activate( idEntity *activator );
};

#endif /* !__GAME_TARGET_H__ */
