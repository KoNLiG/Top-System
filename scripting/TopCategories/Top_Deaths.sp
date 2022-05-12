#include <sourcemod>
#include <TopSystem>

#pragma semicolon 1
#pragma newdecls required

int g_iTopId = -1;

public Plugin myinfo = 
{
	name = "[CS:GO] Top System - Top Deaths", 
	author = "KoNLiG", 
	description = "Top System module.", 
	version = "1.0.0", 
	url = "https://steamcommunity.com/id/KoNLiG/ || KoNLiG#6417"
};

public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "TopSystem"))
	{
		g_iTopId = Top_AddCategory("deaths", "Top Deaths", "Top deaths that players have died.", "Deaths");
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iVictimIndex = GetClientOfUserId(event.GetInt("userid"));
	int iKillerIndex = GetClientOfUserId(event.GetInt("attacker"));
	
	if (iKillerIndex != iVictimIndex) {
		Top_AddPoints(iVictimIndex, g_iTopId, 1);
	}
} 