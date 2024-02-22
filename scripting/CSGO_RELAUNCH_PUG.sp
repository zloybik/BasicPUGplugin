#include <sourcemod>
#include <cstrike>
#include <sdktools>

public Plugin myinfo =
{
	name = "CSGO RELAUNCH PUG",
	author = "Cahid Armatura",
	description = "",
	version = "1.0.0",
	url = "https://github.com/zloybik/"
};

int player_ReadyStatus[MAXPLAYERS+1];
int ReadyPlayersInMM = 0;
int CountPlayersInServer;
bool g_bKnivesIsNotActive = false;
bool g_bChooseTeamEnd = false;
bool g_bChooseTeamYes = false;
bool g_bKnifeRoundEnd = true;
bool g_bLiveIsActive = false;
bool g_bTimeToChangeMap = false;
bool g_bKillBeforeSwitch = true;
bool g_bNeedRandomChoose = true;
char g_cCurrentMap[128];

public void OnPluginStart() {
	RegConsoleCmd("sm_r", SetReadyClient, "Set to client READY status");
	RegConsoleCmd("sm_ur", SetUnReadyClient, "Set to client UNREADY status");
	RegAdminCmd("sm_start", StartMatchForAdmin, 99, "For Admin start", "z");
	RegAdminCmd("sm_stopgame", StopMatchForAdmin, 99, "For Admin stop game", "z");
}

public void OnMapStart() {
	if(g_bChooseTeamEnd == true) {
		g_bChooseTeamEnd = false;
	}
	if(g_bLiveIsActive == true) {
		g_bLiveIsActive = false;
	}
	if(g_bNeedRandomChoose == false) {
		g_bNeedRandomChoose = true;
	}

	CreateTimer(0.5, SetNoChangeMap);

	ServerCommand("exec CSGORELAUNCH/warmup.cfg");
	ServerCommand("mp_unpause_match");
	PrintToChatAll("\x01[\x04CS:GO Relaunch\x01]: warmup.cfg is \x04loaded\x01!");
}

public void OnMapEnd() {
	if(g_bTimeToChangeMap == false) { 
		g_bTimeToChangeMap = true;
	}
	
	CreateTimer(0.1, ChangeMapRandom);
}

public void OnClientPutInServer(int client) {
	if(!IsFakeClient(client)) {
		++CountPlayersInServer;
		player_ReadyStatus[client] = 0;
	}
}

public void OnClientDisconnect_Post(int client) {
	if(!IsFakeClient(client)) {
		if(player_ReadyStatus[client] == 0) {
			//... nothing
		}
		else
		{
			player_ReadyStatus[client] = 0;
			MinusPlayerInRM();
		}

		--CountPlayersInServer;
		if(CountPlayersInServer <= 1 && g_bLiveIsActive == true && !IsFakeClient(client)) {
			ServerCommand("exec CSGORELAUNCH/warmup.cfg");
			ServerCommand("mp_unpause_match");
			PrintToChatAll("\x01[\x04CS:GO Relaunch\x01]: warmup.cfg is \x04loaded\x01!");
			PrintHintTextToAll("Game is stopped, because players <= 1");
			g_bLiveIsActive = false;
		}
		else
		{
			//... nothing
		}
	}
}

public Action MinusPlayerInRM() {
	ReadyPlayersInMM = ReadyPlayersInMM - 1;
}

public Action PlusPlayerInRM() {
	ReadyPlayersInMM = ReadyPlayersInMM + 1;
}

public Action SetReadyClient(int client, int args) {
	if(g_bLiveIsActive == false) {
		if(player_ReadyStatus[client] == 1) {
			ReplyToCommand(client, "\x01[\x04CS:GO Relaunch\x01]: You already ready. If you want unready, write in chat !ur");
		}
		else
		{
			player_ReadyStatus[client] = 1;
			PlusPlayerInRM();
			PrintHintTextToAll("%d of 8 is ready. If you want unready, write in chat !ur", ReadyPlayersInMM);
			char name[64];
			GetClientName(client, name, sizeof(name));
			PrintToChatAll("\x01[\x04CS:GO Relaunch\x01]: \x0B%s\x01 is \x04ready\x01!", name);
			CS_SetClientClanTag(client, "Ready");
			if(ReadyPlayersInMM == 8) {
				StartMatch();
			}
		}
	}
	else {
		ReplyToCommand(client, "\x01[\x04CS:GO Relaunch\x01]: Game is \x04LIVE\x01");
	}
}	

public Action SetUnReadyClient(int client, int args) {
	if(g_bLiveIsActive == false) {
		if(player_ReadyStatus[client] == 0) {
			ReplyToCommand(client, "\x01[\x04CS:GO Relaunch\x01]: You already unready. If you want ready, write in chat !r");
		}
		else
		{
			player_ReadyStatus[client] = 0;
			MinusPlayerInRM();
			PrintHintTextToAll("%d of 8 is ready. If you want ready, write in chat !r", ReadyPlayersInMM);
			char name[64];
			GetClientName(client, name, sizeof(name));
			PrintToChatAll("\x01[\x04CS:GO Relaunch\x01]: \x0B%s\x01 is \x02unready\x01!", name);
			CS_SetClientClanTag(client, "Not Ready");
		}
	}
	else {
		ReplyToCommand(client, "\x01[\x04CS:GO Relaunch\x01]: Game is \x04LIVE\x01");
	}
}	

public Action StartMatch() {
	g_bKnivesIsNotActive = false;
	g_bKnifeRoundEnd = false;
	g_bKnifeRoundEnd = true;
	g_bLiveIsActive = true;
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("round_mvp", ChooseTeam);
	HookEvent("round_end", RoundEndKnife);

	
	ServerCommand("exec CSGORELAUNCH/Knife.cfg");
	ServerCommand("mp_give_player_c4 0");
	CreateTimer(0.1, Restart);
	CreateTimer(2.0, Restart1);
	CreateTimer(3.0, Restart2);
	CreateTimer(4.0, PrintWarning);
	CreateTimer(10.0, SetNoKnifes);
	GetCurrentMap(g_cCurrentMap, sizeof(g_cCurrentMap));
}

public Action RoundEndKnife(Event event, const char[] name, bool dontBroadcast) {
	if(g_bKnifeRoundEnd == false) {
		ServerCommand("mp_pause_match");
		g_bKnifeRoundEnd = true;
	}
}

stock void StripOnePlayerWeapons(int client)
{
	if (IsPlayerAlive(client))
	{
		int iTempWeapon = -1;
		for (int j = 0; j < 5; j++)
			if ((iTempWeapon = GetPlayerWeaponSlot(client, j)) != -1)
			{
				if (j == 2) 
					continue;
				if (IsValidEntity(iTempWeapon))
					RemovePlayerItem(client, iTempWeapon);
			}
		ClientCommand(client, "slot3");
	}
}

public Action PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bKnivesIsNotActive == false) {
		StripOnePlayerWeapons(GetClientOfUserId(GetEventInt(event, "userid")));

		CS_SetClientClanTag(GetClientOfUserId(event.GetInt("userid")), "");
	}

	if(g_bChooseTeamYes == true) {
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		
		if(GetClientTeam(client) == CS_TEAM_CT && !IsFakeClient(client)) {
			CS_SwitchTeam(client, CS_TEAM_T);
		}
		else if(GetClientTeam(client) == CS_TEAM_T && !IsFakeClient(client)) {
			CS_SwitchTeam(client, CS_TEAM_CT);
		}
		else if(GetClientTeam(client) == CS_TEAM_SPECTATOR && !IsFakeClient(client)) {
			//.. nothing
		}

	}
}

public Action Restart(Handle timer) {
	ServerCommand("mp_restartgame 1");
	PrintToChatAll("\x01[\x04CS:GO Relaunch\x01]: Game is \x04LIVE\x01! Restart \x041");
}

public Action Restart1(Handle timer) {
	ServerCommand("mp_restartgame 1");
	PrintToChatAll("\x01[\x04CS:GO Relaunch\x01]: Game is \x04LIVE\x01! Restart \x042");
}

public Action Restart2(Handle timer) {
	ServerCommand("mp_restartgame 3");
	PrintToChatAll("\x01[\x04CS:GO Relaunch\x01]: Game is \x04LIVE\x01! Restart \x043");
}

public Action SetNoKnifes(Handle timer) {
	g_bKnivesIsNotActive = true;
	ServerCommand("mp_give_player_c4 1");
	g_bKnifeRoundEnd = false;
}

public Action ChooseTeam(Event event, const char[] name, bool dontBroadcast) {
	if(g_bChooseTeamEnd == false) {
		int client = GetClientOfUserId(event.GetInt("userid"));
		Menu menu = new Menu(Menu_CallbackTeam);
		menu.SetTitle("CS:GO Relaunch waiting your choose...");
		menu.AddItem("switch", "Switch");
		menu.AddItem("stay", "Stay");
		menu.Display(client, 60);
	}
	return Plugin_Handled;
}

public int Menu_CallbackTeam(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Select:
		{
			char item[64];
			menu.GetItem(param2, item, sizeof(item));

			if(StrEqual(item, "switch")) {
				g_bChooseTeamYes = true;
				g_bKillBeforeSwitch = false;
				g_bNeedRandomChoose = false;
				CreateTimer(0.1, RestartForSwap);
				CreateTimer(2.0, SetNoKill);
				CreateTimer(2.9, SetNoSwitch);
				char nickname[64];
				char msg[64];
				GetClientName(param1, nickname, sizeof(nickname));
				Format(msg, sizeof(msg), "\x01[\x04CS:GO Relaunch\x01]: \x0B%s\x01 choose \x04SWITCH", nickname);
				PrintToChatAll(msg);
			}
			else if(StrEqual(item, "stay")) {
				g_bNeedRandomChoose = false;
				CreateTimer(0.1, RestartForStay);
				CreateTimer(0.2, SetNoSwitch);
				char nickname[64];
				char msg[64];
				GetClientName(param1, nickname, sizeof(nickname));
				Format(msg, sizeof(msg), "\x01[\x04CS:GO Relaunch\x01]: \x0B%s\x01 choose \x04STAY", nickname);
				PrintToChatAll(msg);
			}

			ServerCommand("exec CSGORELAUNCH/Live.cfg");
			ServerCommand("mp_unpause_match");
			CreateTimer(2.0, Restart);
			CreateTimer(3.0, Restart1);
			CreateTimer(4.2, Restart2);
		}
		case MenuAction_End:
		{
			delete menu;
			if(g_bNeedRandomChoose == true) {
				int i = GetRandomInt(1, 2);
				if(i == 1) {
					g_bChooseTeamYes = true;
					g_bKillBeforeSwitch = false;
					CreateTimer(0.1, RestartForSwap);
					CreateTimer(2.0, SetNoKill);
					CreateTimer(2.9, SetNoSwitch);
					char msg[64];
					Format(msg, sizeof(msg), "\x01[\x04CS:GO Relaunch\x01]: \x0BRANDOM\x01 choose \x04SWITCH");
					PrintToChatAll(msg);
				}
				else if(i == 2) {
					CreateTimer(0.1, RestartForStay);
					CreateTimer(0.2, SetNoSwitch);
					char msg[64];
					Format(msg, sizeof(msg), "\x01[\x04CS:GO Relaunch\x01]: \x0BRANDOM\x01 choose \x04STAY");
					PrintToChatAll(msg);
				}

				ServerCommand("exec CSGORELAUNCH/Live.cfg");
				ServerCommand("mp_unpause_match");
				CreateTimer(2.0, Restart);
				CreateTimer(3.0, Restart1);
				CreateTimer(4.2, Restart2);
			}
		}
	}
}

public Action RestartForSwap(Handle timer) {
	ServerCommand("mp_restartgame 1");
	HookEvent("player_spawn", KillPlayerBeforeSpawn);
}

public Action SetNoSwitch(Handle timer) {
	g_bChooseTeamYes = false;
	g_bChooseTeamEnd = true;
}

public Action StartMatchForAdmin(int client, int args) {
	StartMatch();
}

public Action SetNoChangeMap(Handle timer) {
	if(g_bTimeToChangeMap == true) {
		g_bTimeToChangeMap = false;
	}
}

public Action ChangeMapRandom(Handle timer) {
	if(g_bTimeToChangeMap == true) {
		char maps[][] = {
			"de_dust2",
			"de_inferno",
			"de_mirage",
			"de_season",
			"de_seaside",
			"de_train",
			"de_nuke",
			"de_overpass",
			"de_cbble",
			"de_cache"
		}

		int i;
		i = GetRandomInt(0, 9);

		if(StrEqual(maps[i], g_cCurrentMap)) {
			if(i == 9) {
				--i;
			}
			else
			{
				++i;
			}
		}
			
		ServerCommand("map %s", maps[i]);
	}
}

public Action StopMatchForAdmin(int client, int args) {
	if(g_bLiveIsActive == true) {
		ServerCommand("exec CSGORELAUNCH/warmup.cfg");
		ServerCommand("mp_unpause_match");
		PrintToChatAll("\x01[\x04CS:GO Relaunch\x01]: warmup.cfg is \x04loaded\x01!");
		CreateTimer(0.5, TimerForStopGameByAdmin, client);
		g_bLiveIsActive = false;
	}
	else
	{
		PrintToChat(client, "Game is not in LIVE");
	}
}

public Action PrintWarning(Handle timer) {
	PrintToChatAll("\x01WARNING! \x06CSGO RELAUNCH PUG\x01 IN ALPHA TEST! MAYBE HAVE PROBLEMS!");
}

public Action KillPlayerBeforeSpawn(Event event, const char[] name, bool dontBroadcast) {
	if(g_bKillBeforeSwitch == false) {
		int client = GetClientOfUserId(event.GetInt("userid"));

		ForcePlayerSuicide(client);
	}
}

public Action SetNoKill(Handle timer) {
	if(g_bKillBeforeSwitch == false) {
		g_bKillBeforeSwitch = true;
	}
}

public Action RestartForStay(Handle timer) {
	ServerCommand("mp_restartgame 1");
}

public Action TimerForStopGameByAdmin(Handle timer, int client) {
	char NameAdmin[64];
	GetClientName(client, NameAdmin, sizeof(NameAdmin));
	PrintHintTextToAll("Game is stopped by Administrator(%s)", NameAdmin);
}
