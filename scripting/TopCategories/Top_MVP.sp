#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <TopSystem>

#define PLUGIN_AUTHOR "KoNLiG"
#define PLUGIN_VERSION "1.00"

int g_iTopId = -1;

public Plugin myinfo = 
{
	name = "[CS:GO] Top System - Top MVP's", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = "https://steamcommunity.com/id/KoNLiGrL/"
};

public void OnPluginStart()
{
	HookEvent("round_mvp", Event_RoundMVP, EventHookMode_Post);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "TopSystem"))
	{
		g_iTopId = Top_AddCategory("mvp", "Top MVP's", "Top round MVP's that players have got.", "MVP's");
	}
}

public void Event_RoundMVP(Handle event, const char[] name, bool dontBroadcast)
{
	int iPlayerIndex = GetClientOfUserId(GetEventInt(event, "userid"));
	Top_AddPoints(iPlayerIndex, g_iTopId, 1);
} 