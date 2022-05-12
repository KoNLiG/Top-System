#include <sourcemod>
#include <TopSystem>

#pragma semicolon 1
#pragma newdecls required

Handle g_hMinuteTimer[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };

int g_iTopId = -1;

public Plugin myinfo = 
{
	name = "[CS:GO] Top System - Top Playtime", 
	author = "KoNLiG", 
	description = "Top playtime for the top system.", 
	version = "1.0.0", 
	url = "https://steamcommunity.com/id/KoNLiG/ || KoNLiG#6417"
};

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "TopSystem"))
	{
		g_iTopId = Top_AddCategory("playtime", "Top Playtime", "Top playtime in minutes that players have spent on the server.", "Minutes");
	}
}

public void OnMapStart()
{
	for (int current_client = 1; current_client <= MaxClients; current_client++)
	{
		if (IsClientInGame(current_client))
		{
			delete g_hMinuteTimer[current_client];
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	g_hMinuteTimer[client] = CreateTimer(60.0, Timer_GivePoint, GetClientUserId(client), TIMER_REPEAT);
}

public void OnClientDisconnect(int client)
{
	delete g_hMinuteTimer[client];
}

Action Timer_GivePoint(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client)
	{
		Top_AddPoints(client, g_iTopId, 1, false);
	}
	else
	{
		g_hMinuteTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
} 