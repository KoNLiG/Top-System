#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <TopSystem>

#define PLUGIN_AUTHOR "KoNLiG"
#define PLUGIN_VERSION "1.00"

int g_iTopId = -1;

public Plugin myinfo = 
{
	name = "[CS:GO] Top System - Top Knife Kills", 
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
		g_iTopId = Top_AddCategory("knifekills", "Top Knife Kills", "Top Knife kills that players have killed.", "Kills");
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	char szKillerWeapon[64];
	int iKillerIndex = GetClientOfUserId(event.GetInt("attacker"));
	
	event.GetString("weapon", szKillerWeapon, sizeof(szKillerWeapon), "0");
	if (StrContains(szKillerWeapon, "knife") != -1 || StrContains(szKillerWeapon, "bayonet") != -1) {
		Top_AddPoints(iKillerIndex, g_iTopId, 1);
	}
} 