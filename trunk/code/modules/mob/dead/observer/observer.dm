/mob/dead/observer/New(mob/body, var/safety = 0)
	invisibility = 10
	sight |= SEE_TURFS | SEE_MOBS | SEE_OBJS | SEE_SELF
	see_invisible = 15
	see_in_dark = 100
	verbs += /mob/dead/observer/proc/dead_tele

	if(body)
		var/turf/location = get_turf(body)//Where is the mob located?
		if(location)//Found turf.
			loc = location
		else//Safety, in case a turf cannot be found.
			loc = pick(latejoin)
		if(!istype(body,/mob))	return//This needs to be recoded sometime so it has loc as its first arg
		real_name = body.name
		original_name = body.original_name //Original name is only used in ghost chat! It is not to be edited by anything!
		name = body.original_name
		if(!name)
			name = capitalize(pick(first_names_male) + " " + capitalize(pick(last_names)))
			real_name = name
		if(!safety)
			corpse = body
			verbs += /mob/dead/observer/proc/reenter_corpse
		return

/*
Transfer_mind is there to check if mob is being deleted/not going to have a body.
Works together with spawning an observer, noted above.
*/

/mob/proc/ghostize(var/transfer_mind = 0)
	if(key)
		if(client)
			client.screen.len = null//Clear the hud, just to be sure.
		var/mob/dead/observer/ghost = new(src,transfer_mind)//Transfer safety to observer spawning proc.
		if(transfer_mind)//When a body is destroyed.
			if(mind)
				mind.transfer_to(ghost)
			else//They may not have a mind and be gibbed/destroyed.
				ghost.key = key
		else//Else just modify their key and connect them.
			ghost.key = key

		verbs -= /mob/proc/ghost
		if (ghost.client)
			ghost.client.eye = ghost

	else if(transfer_mind)//Body getting destroyed but the person is not present inside.
		for(var/mob/dead/observer/O in world)
			if(O.corpse == src&&O.key)//If they have the same corpse and are keyed.
				if(mind)
					O.mind = mind//Transfer their mind if they have one.
				break
	return

/*
This is the proc mobs get to turn into a ghost. Forked from ghostize due to compatibility issues.
*/
/mob/proc/ghost()
	set category = "Ghost"
	set name = "Ghost"
	set desc = "You cannot be revived as a ghost."

	/*if(stat != 2) //this check causes nothing but troubles. Commented out for Nar-Sie's sake. --rastaf0
		src << "Only dead people and admins get to ghost, and admins don't use this verb to ghost while alive."
		return*/
	if(key)
		var/mob/dead/observer/ghost = new(src)
		ghost.key = key
		verbs -= /mob/proc/ghost
		if (ghost.client)
			ghost.client.eye = ghost
	return

/mob/proc/adminghostize()
	if(client)
		client.mob = new/mob/dead/observer(src)
	return

/mob/dead/observer/Move(NewLoc, direct)
	if(NewLoc)
		loc = NewLoc
		return
	loc = get_turf(src) //Get out of closets and such as a ghost
	if((direct & NORTH) && y < world.maxy)
		y++
	if((direct & SOUTH) && y > 1)
		y--
	if((direct & EAST) && x < world.maxx)
		x++
	if((direct & WEST) && x > 1)
		x--

/mob/dead/observer/examine()
	if(usr)
		usr << desc

/mob/dead/observer/can_use_hands()	return 0
/mob/dead/observer/is_active()		return 0

/mob/dead/observer/Stat()
	..()
	statpanel("Status")
	if (client.statpanel == "Status")
		if(emergency_shuttle)
			if(emergency_shuttle.online && emergency_shuttle.location < 2)
				var/timeleft = emergency_shuttle.timeleft()
				if (timeleft)
					stat(null, "ETA-[(timeleft / 60) % 60]:[add_zero(num2text(timeleft % 60), 2)]")

/mob/dead/observer/proc/reenter_corpse()
	set category = "Ghost"
	set name = "Re-enter Corpse"
	if(!corpse)
		alert("You don't have a corpse!")
		return
	if(client && client.holder && client.holder.state == 2)
		var/rank = client.holder.rank
		client.clear_admin_verbs()
		client.holder.state = 1
		client.update_admins(rank)
	if(corpse.ajourn)
		corpse.ajourn=0
	client.mob = corpse
	if (corpse.stat==2)
		verbs += /mob/proc/ghost
	del(src)

/mob/dead/observer/proc/dead_tele()
	set category = "Ghost"
	set name = "Teleport"
	set desc= "Teleport to a location"
	if((usr.stat != 2) || !istype(usr, /mob/dead/observer))
		usr << "Not when you're not dead!"
		return
	usr.verbs -= /mob/dead/observer/proc/dead_tele
	spawn(30)
		usr.verbs += /mob/dead/observer/proc/dead_tele
	var/A
	A = input("Area to jump to", "BOOYEA", A) in ghostteleportlocs
	var/area/thearea = ghostteleportlocs[A]

	var/list/L = list()
	for(var/turf/T in get_area_turfs(thearea.type))
		L+=T
	usr.loc = pick(L)

/mob/dead/observer/verb/jumptomob() //Moves the ghost instead of just changing the ghosts's eye -Nodrak
	set category = "Ghost"
	set name = "Jump to Mob"
	set desc = "Teleport to a mob"

	if(istype(usr, /mob/dead/observer)) //Make sure they're an observer!


		var/list/dest = list() //List of possible destinations (mobs)
		var/target = null	   //Chosen target.

		dest += getmobs() //Fill list, prompt user with list
		target = input("Please, select a player!", "Jump to Mob", null, null) as null|anything in dest

		if (!target)//Make sure we actually have a target
			return
		else
			var/mob/M = dest[target] //Destination mob
			var/mob/A = src			 //Source mob
			var/turf/T = get_turf(M) //Turf of the destination mob

			if(T && isturf(T))	//Make sure the turf exists, then move the source to that destination.
				A.loc = T
			else
				A << "This mob is not located in the game world."

var/list/karma_spenders = list()

/mob/dead/observer/verb/spend_karma(var/mob/M in world) // Karma system -- TLE
	set name = "Spend Karma"
	set category = "Ghost"
	set desc = "Let the gods know whether someone's been naughty or nice. <One use only>"
	if(!istype(M, /mob))
		usr << "\red That's not a mob. You shouldn't have even been able to specify that. Please inform your server administrator post haste."
		return

	if(!M.client)
		usr << "\red That mob has no client connected at the moment."
		return
	if(client.karma_spent)
		usr << "\red You've already spent your karma for the round."
		return
	for(var/a in karma_spenders)
		if(a == key)
			usr << "\red You've already spent your karma for the round."
			return
	if(M.key == key)
		usr << "\red You can't spend karma on yourself!"
		return
	var/choice = input("Give [M.name] good karma or bad karma?", "Karma") in list("Good", "Bad", "Cancel")
	client.karma_spent = 1
	if(!choice || choice == "Cancel")
		return
	client.karma_spent = 0
	if(choice == "Good")
		M.client.karma += 1
	if(choice == "Bad")
		M.client.karma -= 1
	usr << "[choice] karma spent on [M.name]."
	client.karma_spent = 1
	karma_spenders.Add(key)
	if(M.client.karma <= -2 || M.client.karma >= 2)
		var/special_role = "None"
		var/assigned_role = "None"
		var/karma_diary = file("data/logs/karma_[time2text(world.realtime, "YYYY/MM-Month/DD-Day")].log")
		if(M.mind)
			if(M.mind.special_role)
				special_role = M.mind.special_role
			if(M.mind.assigned_role)
				assigned_role = M.mind.assigned_role
		karma_diary << "[M.name] ([M.key]) [assigned_role]/[special_role]: [M.client.karma] - [time2text(world.timeofday, "hh:mm:ss")]"
	var/isnegative = 1
	if(choice == "Good")
		isnegative = 0
	else
		isnegative = 1
	sql_report_karma(src, M, isnegative)

/mob/dead/observer/verb/toggle_alien_candidate()
	set name = "Toggle Be Alien Candidate"
	set category = "Ghost"
	set desc = "Determines whether you will or will not be an alien candidate when someone bursts."
	if(client.be_alien)
		client.be_alien = 0
		src << "You are now excluded from alien candidate lists until end of round."
	else if(!client.be_alien)
		client.be_alien = 1
		src << "You are now included in alien candidate lists until end of round."

/mob/dead/observer/verb/toggle_pai_candidate()
	set name = "Toggle Be pAI Candidate"
	set category = "Ghost"
	set desc = "Receive a pop-up request when a pAI device requests a new personality. (toggle)"
	if(client.be_pai)
		client.be_pai = 0
		src << "You will no longer receive pAI recruitment pop-ups this round."
	else
		client.be_pai = 1
		src << "You will now be considered a viable candidate when a pAI device requests a new personality, effective until the end of this round."

/mob/dead/observer/memory()
	set hidden = 1
	src << "\red You are dead! You have no mind to store memory!"

/mob/dead/observer/add_memory()
	set hidden = 1
	src << "\red You are dead! You have no mind to store memory!"

