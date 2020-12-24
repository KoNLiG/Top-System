#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <TopSystem>

#define PLUGIN_AUTHOR "KoNLiG"
#define PLUGIN_VERSION "1.00"

Handle g_hMinuteTimer[MAXPLAYERS + 1] =  { INVALID_HANDLE, ... };

int g_iTopId = -1;

public Plugin myinfo = 
{
	name = "[CS:GO] Top System - Top Playtime", 
	author = PLUGIN_AUTHOR, 
	description = "Top playtime for the top system.", 
	version = PLUGIN_VERSION, 
	url = "https://steamcommunity.com/id/KoNLiGrL/"
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
	for (int iCurrentClient = 1; iCurrentClient <= MaxClients; iCurrentClient++)
	{
		if (IsClientInGame(iCurrentClient)) {
			if (g_hMinuteTimer[iCurrentClient] != INVALID_HANDLE) {
				KillTimer(g_hMinuteTimer[iCurrentClient]);
			}
			g_hMinuteTimer[iCurrentClient] = INVALID_HANDLE;
		}
	}
}

public void OnClientPostAdminCheck(int iPlayerIndex)
{
	g_hMinuteTimer[iPlayerIndex] = CreateTimer(60.0, Timer_GivePoint, GetClientSerial(iPlayerIndex), TIMER_REPEAT);
}

public void OnClientDisconnect(int iPlayerIndex)
{
	if (g_hMinuteTimer[iPlayerIndex] != INVALID_HANDLE) {
		KillTimer(g_hMinuteTimer[iPlayerIndex]);
	}
	g_hMinuteTimer[iPlayerIndex] = INVALID_HANDLE;
}

public Action Timer_GivePoint(Handle hTimer, any serial)
{
	int iPlayerIndex = GetClientFromSerial(serial);
	if (iPlayerIndex != 0 && IsClientInGame(iPlayerIndex)) {
		Top_AddPoints(iPlayerIndex, g_iTopId, 1, false);
	} else {
		g_hMinuteTimer[iPlayerIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	return Plugin_Continue;
} 