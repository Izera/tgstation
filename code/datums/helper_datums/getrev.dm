var/global/datum/getrev/revdata = new()

/datum/getrev
	var/parentcommit
	var/commit
	var/list/testmerge = list()
	var/has_pr_details = FALSE	//example data in a testmerge entry when this is true: https://api.github.com/repositories/3234987/pulls/22586
	var/date

/datum/getrev/New()
	var/head_file = return_file_text(".git/logs/HEAD")
	if(SERVERTOOLS && fexists("..\\prtestjob.lk"))
		var/list/tmp = file2list("..\\prtestjob.lk")
		for(var/I in tmp)
			if(I)
				testmerge |= I
	var/testlen = max(testmerge.len - 1, 0)
	var/regex/head_log = new("(\\w{40}) .+> (\\d{10}).+(?=(\n.*(\\w{40}).*){[testlen]}\n*\\Z)")
	head_log.Find(head_file)
	parentcommit = head_log.group[1]
	date = unix2date(text2num(head_log.group[2]))
	commit = head_log.group[4]
	log_world("Running /tg/ revision:")
	log_world("[date]")
	if(testmerge.len)
		log_world(commit)
		for(var/line in testmerge)
			if(line)
				log_world("Test merge active of PR #[line]")
				feedback_add_details("testmerged_prs","[line]")
		log_world("Based off master commit [parentcommit]")
	else
		log_world(parentcommit)
	log_world("Current map - [MAP_NAME]") //can't think of anywhere better to put it

/datum/getrev/proc/DownloadPRDetails()
	if(!config.githubrepoid)
		if(testmerge.len)
			log_world("PR details download failed: No github repo config set")
		return
	if(!isnum(text2num(config.githubrepoid)))
		log_world("PR details download failed: Invalid github repo id: [config.githubrepoid]")
		return
	for(var/line in testmerge)
		if(!isnum(text2num(line)))
			log_world("PR details download failed: Invalid PR number: [line]")
			return

		var/url = "https://api.github.com/repositories/[config.githubrepoid]/pulls/[line].json"
		valid_HTTPSGet = TRUE
		var/json = HTTPSGet(url)
		if(!json)
			return

		testmerge[line] = json_decode(json)

		if(!testmerge[line])
			log_world("PR details download failed: null details returned")
			return
		CHECK_TICK
	log_world("PR details successfully downloaded")
	has_pr_details = TRUE

/datum/getrev/proc/GetTestMergeInfo(header = TRUE)
	if(!testmerge.len)
		return ""
	. = header ? "The following pull requests are currently test merged:<br>" : ""
	for(var/line in testmerge)
		var/details = ""
		if(has_pr_details)
			details = ": '" + html_encode(testmerge[line]["title"]) + "' by " + html_encode(testmerge[line]["user"]["login"])
		. += "<a href='[config.githuburl]/pull/[line]'>#[line][details]</a><br>"

/client/verb/showrevinfo()
	set category = "OOC"
	set name = "Show Server Revision"
	set desc = "Check the current server code revision"

	if(revdata.parentcommit)
		src << "<b>Server revision compiled on:</b> [revdata.date]"
		if(revdata.testmerge.len)
			src << revdata.GetTestMergeInfo()
			src << "Based off master commit:"
		src << "<a href='[config.githuburl]/commit/[revdata.parentcommit]'>[revdata.parentcommit]</a>"
	else
		src << "Revision unknown"
	src << "<b>Current Infomational Settings:</b>"
	src << "Protect Authority Roles From Traitor: [config.protect_roles_from_antagonist]"
	src << "Protect Assistant Role From Traitor: [config.protect_assistant_from_antagonist]"
	src << "Enforce Human Authority: [config.enforce_human_authority]"
	src << "Allow Latejoin Antagonists: [config.allow_latejoin_antagonists]"
	src << "Enforce Continuous Rounds: [config.continuous.len] of [config.modes.len] roundtypes"
	src << "Allow Midround Antagonists: [config.midround_antag.len] of [config.modes.len] roundtypes"
	if(config.show_game_type_odds)
		if(ticker.current_state == GAME_STATE_PLAYING)
			var/prob_sum = 0
			var/current_odds_differ = FALSE
			var/list/probs = list()
			var/list/modes = config.gamemode_cache
			for(var/mode in modes)
				var/datum/game_mode/M = mode
				var/ctag = initial(M.config_tag)
				if(!(ctag in config.probabilities))
					continue
				if((config.min_pop[ctag] && (config.min_pop[ctag] > ticker.totalPlayersReady)) || (config.max_pop[ctag] && (config.max_pop[ctag] < ticker.totalPlayersReady)) || (initial(M.required_players) > ticker.totalPlayersReady))
					current_odds_differ = TRUE
					continue
				probs[ctag] = 1
				prob_sum += config.probabilities[ctag]
			if(current_odds_differ)
				src <<"<b>Game Mode Odds for current round:</b>"
				for(var/ctag in probs)
					if(config.probabilities[ctag] > 0)
						var/percentage = round(config.probabilities[ctag] / prob_sum * 100, 0.1)
						src << "[ctag] [percentage]%"
		
		src <<"<b>All Game Mode Odds:</b>"
		var/sum = 0
		for(var/ctag in config.probabilities)
			sum += config.probabilities[ctag]
		for(var/ctag in config.probabilities)
			if(config.probabilities[ctag] > 0)
				var/percentage = round(config.probabilities[ctag] / sum * 100, 0.1)
				src << "[ctag] [percentage]%"
