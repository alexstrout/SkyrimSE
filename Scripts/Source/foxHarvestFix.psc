Scriptname foxHarvestFix Hidden
{Simple wrapper functions to abstract the ObjectReference "hooks"}

;Check if we're a valid HarvestFix target - if false, we're either not a plant or shouldn't have respawned yet
bool function IsValidHarvestRef(ObjectReference akRef, float afLastActivateTime) global
	;As IsHarvested is implemented for all ObjectReference types (hence "hooking" ObjectReference), we can simply call this function to determine if we:
	;	A) Are a valid plant (e.g. Flora / TreeObject reference, or anything else that supports IsHarvested)
	;	B) Have actually been harvested (no point in caring if we haven't!)
	;Note: There is a weird issue where some ObjectReferences are apparently invalid and can't call methods on themselves - I don't know why (or how) this happens
	;Despite checking akRef, the IsHarvested() call can still fail. As our "hooked" functions would otherwise be empty calls anyway, this appears harmless (other than printing an error to log)
	return akRef && akRef.IsHarvested() \
		&& (afLastActivateTime <= 0.0 || Utility.GetCurrentGameTime() > afLastActivateTime + 3.0) ;Adjust the "3.0" here to your desired respawn time in days (e.g. 3.0 = 3 days, 0.125 = 3 hours)
endFunction

;Process our OnActivate "hook" - our "foxHarvestFixLastActivateTime" in ObjectReference should both be passed as afLastActivateTime AND assigned the result of this function (so it may be updated)
float function OnActivate(ObjectReference akRef, float afLastActivateTime) global
	;If we're a valid HarvestFix target (we're a plant, and ready to be harvested), return our current game time
	if (IsValidHarvestRef(akRef, afLastActivateTime))
		return Utility.GetCurrentGameTime()
	endif
	;Otherwise, just return whatever afLastActivateTime was (so that the value remains unchanged)
	return afLastActivateTime
endFunction

;Brutal harvest fix here - don't try this at home! ... Wait
function OnCellAttach(ObjectReference akRef, float afLastActivateTime = -1.0) global
	if (IsValidHarvestRef(akRef, afLastActivateTime))
		;Unfortunately, SetHarvested seems to have an upper limit (10?) on how many meshes it can update at once
		;Disable/enable works fine, but having to disable/enable parent objects (e.g. all of Breezehome) is a bit awkward with Havoc objects flying about
		;However, we can nicely sidestep this with a quasi-unique wait time based on our Reference FormID (clamped to some reasonable time)
		;We can avoid deriving too many overlapping wait times (or too long of a wait time) by wrapping on some number via modulus
		;Absolute worst case, we miss a plant or two - I think this is an acceptable tradeoff for its simplicity and speed
		;Debug.Trace(akRef + " FormID " + akRef.GetFormID() + " was harvested OnCellAttach (" + akRef.GetBaseObject().GetName() + ")")
		Utility.Wait((Math.abs(akRef.GetFormID()) as int % 2048) / 1000.0) ;Wrap on 0x7FF (2048 possible values) so we have sufficient distribution for a max 2s wait time
		akRef.SetHarvested(false)
	endif
endFunction
