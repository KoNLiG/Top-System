#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <Regex>
#include <TopSystem>

#define PLUGIN_AUTHOR "KoNLiG"
#define PLUGIN_VERSION "1.00"

/* Settings */

#define PREFIX " \x04[Top]\x01"
#define PREFIX_MENU "[Top]"

#define CONFIG_PATH "addons/sourcemod/configs/TopData.cfg"
#define DATABASE_ENTRY "csgotest"

/*  */

enum struct LastWinner
{
	char szAuth[64];
	char szName[MAX_NAME_LENGTH];
}

enum struct Top
{
	LastWinner WinnerData;
	char szUnique[128];
	char szName[128];
	char szDesc[256];
	char szCounter[32];
	int iDefaultPoints;
}

ArrayList g_arTopData;

ConVar g_cvCategoriesStartPoints;

enum struct Client
{
	char szAuth[64];
	char szName[MAX_NAME_LENGTH];
	ArrayList iPoints;
	
	void Reset() {
		this.szAuth[0] = '\0';
		this.szName[0] = '\0';
		this.Init();
	}
	
	void Init() {
		delete this.iPoints;
		this.iPoints = new ArrayList();
		for (int iCurrentTop = 0; iCurrentTop < g_arTopData.Length; iCurrentTop++) {
			this.iPoints.Push(g_cvCategoriesStartPoints.IntValue);
		}
	}
}

Client g_esClientData[MAXPLAYERS + 1];

Database g_dbDatabase;

GlobalForward g_fwdOnTopReset;

ConVar g_cvTopClientsAmount;
ConVar g_cvDaysUntilReset;
ConVar g_cvPrintProgressMessages;

int g_iResetTime;

public Plugin myinfo = 
{
	name = "[CS:GO] Top System - Core", 
	author = PLUGIN_AUTHOR, 
	description = "Provides a generic top system, with special feature to automatically reset the top statistics every certain time.", 
	version = PLUGIN_VERSION, 
	url = "https://steamcommunity.com/id/KoNLiGrL/"
};

public void OnPluginStart()
{
	SQL_MakeConnection();
	
	g_arTopData = new ArrayList(sizeof(Top));
	
	g_cvTopClientsAmount = CreateConVar("top_show_clients_amount", "50", "Amount of clients that will be shown on the quests menu.", _, true, 5.0, true, 100.0);
	g_cvDaysUntilReset = CreateConVar("top_days_until_reset", "7", "Amount of days until every top category resets, 0 to disable the reset.", _, true, 0.0, true, 90.0);
	g_cvPrintProgressMessages = CreateConVar("top_print_progress_messages", "1", "If true, every progress change will be print with a chat message, 0 To disable the print.", _, true, 0.0, true, 1.0);
	g_cvCategoriesStartPoints = CreateConVar("top_categories_start_points", "0", "Starting points to set for every category once its created.");
	
	RegConsoleCmd("sm_tops", Command_Tops, "Access the Tops list menu.");
	RegConsoleCmd("sm_top", Command_Tops, "Access the Tops list menu. (An Alias)");
	
	char sDirPath[PLATFORM_MAX_PATH], szConfigPath[PLATFORM_MAX_PATH];
	strcopy(szConfigPath, sizeof(szConfigPath), CONFIG_PATH);
	ReplaceString(szConfigPath, sizeof(szConfigPath), "addons/sourcemod/", "", true);
	BuildPath(Path_SM, sDirPath, sizeof(sDirPath), szConfigPath);
	File hFile = OpenFile(sDirPath, "a+");
	delete hFile;
	
	AutoExecConfig(true, "TopSystem");
}

public void OnPluginEnd()
{
	for (int iCurrentClient = 1; iCurrentClient <= MaxClients; iCurrentClient++)
	{
		if (IsClientInGame(iCurrentClient) && !IsFakeClient(iCurrentClient)) {
			OnClientDisconnect(iCurrentClient);
		}
	}
}

/* Events */

public void OnMapStart()
{
	if (g_cvDaysUntilReset.IntValue)
	{
		KV_LoadTops();
		if (!g_iResetTime) {
			KV_InitData();
		}
		else if (g_iResetTime <= GetTime()) {
			for (int iCurrentTop = 0; iCurrentTop < g_arTopData.Length; iCurrentTop++) {
				ResetTop(-1, iCurrentTop);
			}
		}
	}
}

public void OnClientPostAdminCheck(int iPlayerIndex)
{
	g_esClientData[iPlayerIndex].Reset();
	if (!IsFakeClient(iPlayerIndex))
	{
		if (!GetClientAuthId(iPlayerIndex, AuthId_Steam2, g_esClientData[iPlayerIndex].szAuth, sizeof(g_esClientData[].szAuth)))
		{
			KickClient(iPlayerIndex, "Verification error, please reconnect.");
			return;
		}
		
		GetClientName(iPlayerIndex, g_esClientData[iPlayerIndex].szName, sizeof(g_esClientData[].szName));
		SQL_FetchUser(iPlayerIndex);
	}
}

public void OnClientDisconnect(int iPlayerIndex)
{
	if (!IsFakeClient(iPlayerIndex))
	{
		SQL_UpdateUser(iPlayerIndex);
	}
}

/*  */

/* Commands */

public Action Command_Tops(int iPlayerIndex, int args)
{
	showTopsMainMenu(iPlayerIndex);
	return Plugin_Handled;
}

/*  */

/* Natives */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Top_AddCategory", Native_AddCategory);
	CreateNative("Top_GetPoints", Native_GetTopPoints);
	CreateNative("Top_AddPoints", Native_AddTopPoints);
	CreateNative("Top_TakePoints", Native_TakeTopPoints);
	
	g_fwdOnTopReset = CreateGlobalForward("Top_OnTopReset", ET_Event, Param_Cell);
	
	RegPluginLibrary("TopSystem");
	return APLRes_Success;
}

public int Native_AddCategory(Handle plugin, int numParams)
{
	Top TopData;
	GetNativeString(1, TopData.szUnique, sizeof(TopData.szUnique));
	
	if (GetTopId(TopData.szUnique) != -1) {
		return GetTopId(TopData.szUnique);
	}
	
	GetNativeString(2, TopData.szName, sizeof(TopData.szName));
	GetNativeString(3, TopData.szDesc, sizeof(TopData.szDesc));
	GetNativeString(4, TopData.szCounter, sizeof(TopData.szCounter));
	TopData.iDefaultPoints = GetNativeCell(5);
	
	return g_arTopData.PushArray(TopData, sizeof(TopData));
}

public int Native_GetTopPoints(Handle plugin, int numParams)
{
	int iPlayerIndex = GetNativeCell(1);
	int iTopId = GetNativeCell(2);
	
	if (iPlayerIndex < 1 || iPlayerIndex > MaxClients || IsFakeClient(iPlayerIndex)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", iPlayerIndex);
	}
	if (!IsClientConnected(iPlayerIndex)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", iPlayerIndex);
	}
	if (!(0 <= iTopId < g_arTopData.Length)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid top index (%d)", iTopId);
	}
	
	return g_esClientData[iPlayerIndex].iPoints.Get(iTopId);
}

public int Native_AddTopPoints(Handle plugin, int numParams)
{
	int iPlayerIndex = GetNativeCell(1);
	int iTopId = GetNativeCell(2);
	int iPoints = GetNativeCell(3);
	bool bBroadcast = GetNativeCell(4);
	
	if (iPlayerIndex < 1 || iPlayerIndex > MaxClients || IsFakeClient(iPlayerIndex)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", iPlayerIndex);
	}
	if (!IsClientConnected(iPlayerIndex)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", iPlayerIndex);
	}
	if (!(0 <= iTopId < g_arTopData.Length)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid top index (%d)", iTopId);
	}
	if (iPoints < 0) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid points amount (%d)", iPlayerIndex, iPoints);
	}
	
	g_esClientData[iPlayerIndex].iPoints.Set(iTopId, g_esClientData[iPlayerIndex].iPoints.Get(iTopId) + iPoints);
	
	Top TopData; TopData = GetTopByIndex(iTopId);
	if (g_cvPrintProgressMessages.BoolValue && bBroadcast) {
		PrintToChat(iPlayerIndex, "%s You have gained \x04+%d\x01 points in \x0E%s\x01 top.", PREFIX, iPoints, TopData.szName);
	}
	
	char szFile[64];
	GetPluginFilename(plugin, szFile, sizeof(szFile));
	WriteLogLine("Points of \"%L\" in \"%s\" changed from %s to %s by plugin %s", iPlayerIndex, TopData.szName, AddCommas(g_esClientData[iPlayerIndex].iPoints.Get(iTopId) - iPoints), AddCommas(g_esClientData[iPlayerIndex].iPoints.Get(iTopId)), szFile);
	return 0;
}

public int Native_TakeTopPoints(Handle plugin, int numParams)
{
	int iPlayerIndex = GetNativeCell(1);
	int iTopId = GetNativeCell(2);
	int iPoints = GetNativeCell(3);
	bool bBroadcast = GetNativeCell(4);
	
	if (iPlayerIndex < 1 || iPlayerIndex > MaxClients || IsFakeClient(iPlayerIndex)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", iPlayerIndex);
	}
	if (!IsClientConnected(iPlayerIndex)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", iPlayerIndex);
	}
	if (!(0 <= iTopId < g_arTopData.Length)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid top index (%d)", iTopId);
	}
	if (iPoints < 0) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid points amount (%d)", iPlayerIndex, iPoints);
	}
	
	Top TopData; TopData = GetTopByIndex(iTopId);
	
	if (g_esClientData[iPlayerIndex].iPoints.Get(iTopId) - iPoints <= TopData.iDefaultPoints) {
		g_esClientData[iPlayerIndex].iPoints.Set(iTopId, TopData.iDefaultPoints);
		return 0;
	}
	
	g_esClientData[iPlayerIndex].iPoints.Set(iTopId, g_esClientData[iPlayerIndex].iPoints.Get(iTopId) - iPoints);
	
	if (g_cvPrintProgressMessages.BoolValue && bBroadcast) {
		PrintToChat(iPlayerIndex, "%s You have lost \x02-%d\x01 points in \x0E%s\x01 top.", PREFIX, iPoints, TopData.szName);
	}
	
	char szFile[64];
	GetPluginFilename(plugin, szFile, sizeof(szFile));
	WriteLogLine("Points of \"%L\" in \"%s\" changed from %s to %s by plugin %s", iPlayerIndex, TopData.szName, AddCommas(g_esClientData[iPlayerIndex].iPoints.Get(iTopId - iPoints)), AddCommas(g_esClientData[iPlayerIndex].iPoints.Get(iTopId)), szFile);
	return 0;
}

/*  */

/* Menus */

void showTopsMainMenu(int iPlayerIndex)
{
	char szItem[64], szItemInfo[16];
	Menu menu = new Menu(Handler_Tops);
	
	float fResetTime = (float(g_iResetTime) - float(GetTime())) / 86400.0;
	Format(szItemInfo, sizeof(szItemInfo), "%.1f Days", fResetTime);
	Format(szItem, sizeof(szItem), "• Resets In: %s\n ", fResetTime <= 0.09 ? "Next Map!":szItemInfo);
	menu.SetTitle("%s Top System - Main Menu\n%s ", PREFIX_MENU, g_cvDaysUntilReset.IntValue ? szItem:"");
	
	Top CurrentTopData;
	for (int iCurrentTop = 0; iCurrentTop < g_arTopData.Length; iCurrentTop++)
	{
		IntToString(iCurrentTop, szItemInfo, sizeof(szItemInfo));
		CurrentTopData = GetTopByIndex(iCurrentTop);
		menu.AddItem(szItemInfo, CurrentTopData.szName);
	}
	
	if (!menu.ItemCount) {
		menu.AddItem("", "There are no available tops.\n ", ITEMDRAW_DISABLED);
	}
	
	Format(szItem, sizeof(szItem), "Last Top Winners%s", GetAdminFlag(GetUserAdmin(iPlayerIndex), Admin_Root) ? "\n ":"");
	menu.AddItem("LastWinners", szItem, g_cvDaysUntilReset.IntValue != 0 ? ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
	menu.AddItem("ResetTop", "Reset A Top", GetAdminFlag(GetUserAdmin(iPlayerIndex), Admin_Root) ? ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
	
	menu.Display(iPlayerIndex, MENU_TIME_FOREVER);
}

public void SQL_TopMenu_CB(Database db, DBResultSet results, const char[] error, DataPack dPack)
{
	if (!StrEqual(error, ""))
	{
		LogError("Databse error, %s", error);
		return;
	}
	
	int iPlayerIndex = GetClientFromSerial(dPack.ReadCell());
	
	if (!iPlayerIndex) {
		return;
	}
	
	int iTopId = dPack.ReadCell();
	dPack.Close();
	
	Top TopData; TopData = GetTopByIndex(iTopId);
	
	char szItem[64], szItemInfo[8];
	Menu menu = new Menu(Handler_Tops);
	menu.SetTitle("%s Top System - Viewing %s \n• Description: %s \n• My Progress: %s %s\n ", PREFIX_MENU, 
		TopData.szName, 
		TopData.szDesc, 
		AddCommas(g_esClientData[iPlayerIndex].iPoints.Get(iTopId)), 
		TopData.szCounter
		);
	
	char szAuth[64], szName[MAX_NAME_LENGTH];
	int iCounter = 0;
	
	while (results.FetchRow())
	{
		iCounter++;
		results.FetchString(0, szAuth, sizeof(szAuth));
		results.FetchString(1, szName, sizeof(szName));
		
		int iPoints = results.FetchInt(3);
		int iCurrentClient = GetClientFromAuth(szAuth);
		
		IntToString(iTopId, szItemInfo, sizeof(szItemInfo));
		Format(szItem, sizeof(szItem), "(#%d) %s - %s %s", iCounter, szName, iCurrentClient != -1 ? AddCommas(g_esClientData[iCurrentClient].iPoints.Get(iTopId)):AddCommas(iPoints), TopData.szCounter);
		menu.AddItem(szItemInfo, szItem);
	}
	
	if (!iCounter) {
		menu.AddItem("", "No player was found.", ITEMDRAW_DISABLED);
	}
	
	menu.ExitBackButton = true;
	menu.Display(iPlayerIndex, MENU_TIME_FOREVER);
}

public int Handler_Tops(Menu menu, MenuAction action, int iPlayerIndex, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char szItem[32];
		menu.GetItem(itemNum, szItem, sizeof(szItem));
		int iTopId = StringToInt(szItem);
		
		if (StrEqual(szItem, "LastWinners", true)) {
			showLastWinnersMenu(iPlayerIndex);
		}
		else if (StrEqual(szItem, "ResetTop", true)) {
			showResetTopMenu(iPlayerIndex);
		}
		else
		{
			DataPack dPack = new DataPack();
			dPack.WriteCell(GetClientSerial(iPlayerIndex));
			dPack.WriteCell(iTopId);
			dPack.Reset();
			
			Top TopData; TopData = GetTopByIndex(iTopId);
			
			char szQuery[512];
			g_dbDatabase.Format(szQuery, sizeof(szQuery), "SELECT * FROM `top_stats` WHERE `unique` = '%s' ORDER BY `points` DESC LIMIT %d", TopData.szUnique, g_cvTopClientsAmount.IntValue);
			g_dbDatabase.Query(SQL_TopMenu_CB, szQuery, dPack);
		}
	}
	else if (action == MenuAction_Cancel && itemNum == MenuCancel_ExitBack) {
		showTopsMainMenu(iPlayerIndex);
	}
	else if (action == MenuAction_End) {
		delete menu;
	}
}

void showLastWinnersMenu(int iPlayerIndex)
{
	char szItem[64];
	Menu menu = new Menu(Handler_LastWinners);
	menu.SetTitle("%s Top System - Last Top Winners\n ", PREFIX_MENU);
	
	Top TopData;
	for (int iCurrentTop = 0; iCurrentTop < g_arTopData.Length; iCurrentTop++)
	{
		TopData = GetTopByIndex(iCurrentTop);
		Format(szItem, sizeof(szItem), "%s Winner: %s", TopData.szName, TopData.WinnerData.szName[0] == '\0' ? "None":TopData.WinnerData.szName);
		menu.AddItem("", szItem);
	}
	
	int iItemCount = menu.ItemCount;
	if (!iItemCount) {
		menu.AddItem("", "There are no available winners.", ITEMDRAW_DISABLED);
	}
	
	for (int iCurrentItem = 0; iCurrentItem < (6 - iItemCount); iCurrentItem++) {
		menu.AddItem("", "", ITEMDRAW_NOTEXT); // Fix the back button gap.
	}
	
	menu.ExitBackButton = true;
	menu.Display(iPlayerIndex, MENU_TIME_FOREVER);
}

public int Handler_LastWinners(Menu menu, MenuAction action, int iPlayerIndex, int itemNum)
{
	if (action == MenuAction_Select) {
		showLastWinnersMenu(iPlayerIndex);
	}
	else if (action == MenuAction_Cancel && itemNum == MenuCancel_ExitBack) {
		showTopsMainMenu(iPlayerIndex);
	}
	else if (action == MenuAction_End) {
		delete menu;
	}
}

void showResetTopMenu(int iPlayerIndex)
{
	char szItemInfo[8];
	Menu menu = new Menu(Handler_ResetTop);
	menu.SetTitle("%s Top System - Reset Top \n• Choose a top to reset, or go back to cancel the operation.\n ", PREFIX_MENU);
	
	Top TopData;
	for (int iCurrentTop = 0; iCurrentTop < g_arTopData.Length; iCurrentTop++)
	{
		TopData = GetTopByIndex(iCurrentTop);
		IntToString(iCurrentTop, szItemInfo, sizeof(szItemInfo));
		menu.AddItem(szItemInfo, TopData.szName);
	}
	
	int iItemCount = menu.ItemCount;
	if (!iItemCount) {
		menu.AddItem("", "There are no available tops.", ITEMDRAW_DISABLED);
	}
	
	for (int iCurrentItem = 0; iCurrentItem < (6 - iItemCount); iCurrentItem++) {
		menu.AddItem("", "", ITEMDRAW_NOTEXT); // Fix the back button gap.
	}
	
	menu.ExitBackButton = true;
	menu.Display(iPlayerIndex, MENU_TIME_FOREVER);
}

public int Handler_ResetTop(Menu menu, MenuAction action, int iPlayerIndex, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char szItem[32];
		menu.GetItem(itemNum, szItem, sizeof(szItem));
		int iTopId = StringToInt(szItem);
		
		Top TopData; TopData = GetTopByIndex(iTopId);
		ResetTop(iPlayerIndex, iTopId);
		PrintToChat(iPlayerIndex, "%s Succesfully reset the \x04%s\x01!", PREFIX, TopData.szName);
	}
	else if (action == MenuAction_Cancel && itemNum == MenuCancel_ExitBack) {
		showTopsMainMenu(iPlayerIndex);
	}
	else if (action == MenuAction_End) {
		delete menu;
	}
}

/*  */

/* Database */

void SQL_MakeConnection()
{
	delete g_dbDatabase;
	Database.Connect(SQL_CB_OnDatabaseConnected, DATABASE_ENTRY);
}

public void SQL_CB_OnDatabaseConnected(Database db, const char[] error, any data)
{
	if (db == null)
		SetFailState("Cannot connect to MySQL Server! | Error: %s", error);
	
	g_dbDatabase = db;
	g_dbDatabase.Query(SQL_CheckForErrors, "CREATE TABLE IF NOT EXISTS `top_stats` (`steam_id` VARCHAR(64) NOT NULL , `name` VARCHAR(128) NOT NULL, `unique` VARCHAR(128) NOT NULL, `points` INT NOT NULL, UNIQUE(`steam_id`, `unique`))");
	
	for (int iCurrentClient = 1; iCurrentClient <= MaxClients; iCurrentClient++)
	{
		if (IsClientInGame(iCurrentClient) && !IsFakeClient(iCurrentClient)) {
			OnClientPostAdminCheck(iCurrentClient);
		}
	}
}

void SQL_FetchUser(int iPlayerIndex)
{
	char szQuery[128];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "SELECT * FROM `top_stats` WHERE `steam_id` = '%s'", g_esClientData[iPlayerIndex].szAuth);
	g_dbDatabase.Query(SQL_FetchUser_CB, szQuery, GetClientSerial(iPlayerIndex));
}

public void SQL_FetchUser_CB(Database db, DBResultSet results, const char[] error, any serial)
{
	if (!StrEqual(error, ""))
	{
		LogError("Databse error, %s", error);
		return;
	}
	
	char szUnique[128], szQuery[256];
	int iPlayerIndex = GetClientFromSerial(serial);
	
	if (!iPlayerIndex) {
		return;
	}
	
	bool[] bIsRowExist = new bool[g_arTopData.Length];
	
	while (results.FetchRow())
	{
		results.FetchString(2, szUnique, sizeof(szUnique));
		int iTopId = GetTopId(szUnique);
		if (iTopId != -1) {
			bIsRowExist[iTopId] = true;
			g_esClientData[iPlayerIndex].iPoints.Set(iTopId, results.FetchInt(3));
		}
	}
	
	Top TopData;
	for (int iCurrentTop = 0; iCurrentTop < g_arTopData.Length; iCurrentTop++)
	{
		if (bIsRowExist[iCurrentTop]) {
			continue;
		}
		
		TopData = GetTopByIndex(iCurrentTop);
		g_esClientData[iPlayerIndex].iPoints.Set(iCurrentTop, TopData.iDefaultPoints);
		g_dbDatabase.Format(szQuery, sizeof(szQuery), "INSERT INTO `top_stats` (`steam_id`, `name`, `unique`, `points`) VALUES ('%s', '%s', '%s', %d)", 
			g_esClientData[iPlayerIndex].szAuth, 
			g_esClientData[iPlayerIndex].szName, 
			TopData.szUnique, 
			g_esClientData[iPlayerIndex].iPoints.Get(iCurrentTop)
			);
		
		g_dbDatabase.Query(SQL_CheckForErrors, szQuery);
	}
}


void SQL_UpdateUser(int iPlayerIndex)
{
	char szQuery[128];
	for (int iCurrentTop = 0; iCurrentTop < g_arTopData.Length; iCurrentTop++)
	{
		DataPack dPack = new DataPack();
		dPack.WriteCell(iPlayerIndex);
		dPack.WriteCell(iCurrentTop);
		dPack.Reset();
		
		g_dbDatabase.Format(szQuery, sizeof(szQuery), "SELECT * FROM `top_stats` WHERE `steam_id` = '%s'", g_esClientData[iPlayerIndex].szAuth);
		g_dbDatabase.Query(SQL_UpdateUser_CB, szQuery, dPack);
	}
}

public void SQL_UpdateUser_CB(Database db, DBResultSet results, const char[] error, DataPack dPack)
{
	if (!StrEqual(error, ""))
	{
		LogError("Databse error, %s", error);
		return;
	}
	
	int iPlayerIndex = dPack.ReadCell();
	int iTopId = dPack.ReadCell();
	dPack.Close();
	
	char szQuery[256];
	if (results.FetchRow())
	{
		g_dbDatabase.Format(szQuery, sizeof(szQuery), "UPDATE `top_stats` SET `name` = '%s', `points` = %d WHERE `steam_id` = '%s' AND `unique` = '%s'", 
			g_esClientData[iPlayerIndex].szName, 
			g_esClientData[iPlayerIndex].iPoints.Get(iTopId), 
			g_esClientData[iPlayerIndex].szAuth, 
			GetTopByIndex(iTopId).szUnique
			);
		g_dbDatabase.Query(SQL_CheckForErrors, szQuery);
	}
}

public void SQL_CheckForErrors(Database db, DBResultSet results, const char[] error, any data)
{
	if (!StrEqual(error, ""))
	{
		LogError("Databse error, %s", error);
		return;
	}
}

/*  */

/* KeyValues */

void KV_LoadTops()
{
	if (!FileExists(CONFIG_PATH)) {
		SetFailState("Cannot find file %s", CONFIG_PATH);
	}
	
	if (!g_arTopData.Length) {
		return;
	}
	
	KeyValues keyValues = new KeyValues("TopData");
	keyValues.ImportFromFile(CONFIG_PATH);
	g_iResetTime = keyValues.GetNum("GetTime");
	keyValues.GotoFirstSubKey();
	
	Top TopData;
	int iCounter = 0;
	
	do {
		TopData = GetTopByIndex(iCounter);
		keyValues.GetString("Auth", TopData.WinnerData.szAuth, sizeof(LastWinner::szAuth));
		keyValues.GetString("Name", TopData.WinnerData.szName, sizeof(LastWinner::szName));
		iCounter++;
	} while (keyValues.GotoNextKey() && iCounter < g_arTopData.Length);
	
	keyValues.Rewind();
	keyValues.ExportToFile(CONFIG_PATH);
	delete keyValues;
}

public void KV_SetTopData(Database db, DBResultSet results, const char[] error, any iTopId)
{
	if (!StrEqual(error, ""))
	{
		LogError("Databse error, %s", error);
		return;
	}
	
	if (!FileExists(CONFIG_PATH)) {
		SetFailState("Cannot find file %s", CONFIG_PATH);
	}
	
	KeyValues keyValues = new KeyValues("TopData");
	keyValues.ImportFromFile(CONFIG_PATH);
	
	keyValues.SetNum("GetTime", GetTime() + (g_cvDaysUntilReset.IntValue * 24 * 60 * 60));
	keyValues.GoBack();
	
	char szKvKey[16];
	char szAuth[64], szName[MAX_NAME_LENGTH];
	while (results.FetchRow())
	{
		results.FetchString(0, szAuth, sizeof(szAuth));
		results.FetchString(1, szName, sizeof(szName));
		
		IntToString(iTopId, szKvKey, sizeof(szKvKey));
		keyValues.JumpToKey(szKvKey, true);
		keyValues.SetString("Auth", szAuth);
		keyValues.SetString("Name", szName);
		keyValues.GoBack();
	}
	
	keyValues.Rewind();
	keyValues.ExportToFile(CONFIG_PATH);
	delete keyValues;
	
	KV_LoadTops();
	
	char szQuery[128];
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "DELETE FROM `top_stats` WHERE `unique` = '%s'", GetTopByIndex(iTopId).szUnique);
	g_dbDatabase.Query(SQL_CheckForErrors, szQuery);
	
	for (int iCurrentClient = 1; iCurrentClient <= MaxClients; iCurrentClient++)
	{
		if (IsClientInGame(iCurrentClient) && !IsFakeClient(iCurrentClient)) {
			OnClientPostAdminCheck(iCurrentClient);
		}
	}
}

void KV_InitData()
{
	if (!FileExists(CONFIG_PATH)) {
		SetFailState("Cannot find file %s", CONFIG_PATH);
	}
	
	KeyValues keyValues = new KeyValues("TopData");
	keyValues.ImportFromFile(CONFIG_PATH);
	
	keyValues.SetNum("GetTime", GetTime() + (g_cvDaysUntilReset.IntValue * 24 * 60 * 60));
	
	keyValues.Rewind();
	keyValues.ExportToFile(CONFIG_PATH);
	delete keyValues;
	
	KV_LoadTops();
}

/* */

/* Functions */

int GetTopId(const char[] unique)
{
	Top CurrentTopData;
	for (int iCurrentTop = 0; iCurrentTop < g_arTopData.Length; iCurrentTop++)
	{
		g_arTopData.GetArray(iCurrentTop, CurrentTopData, sizeof(CurrentTopData));
		if (StrEqual(CurrentTopData.szUnique, unique, true)) {
			return iCurrentTop;
		}
	}
	return -1;
}

int GetClientFromAuth(const char[] auth)
{
	char szAuth[64];
	for (int iCurrentClient = 1; iCurrentClient <= MaxClients; iCurrentClient++)
	{
		if (IsClientInGame(iCurrentClient))
		{
			GetClientAuthId(iCurrentClient, AuthId_Steam2, szAuth, sizeof(szAuth));
			if (StrEqual(szAuth, auth, false)) {
				return iCurrentClient;
			}
		}
	}
	return -1;
}

any[] GetTopByIndex(int index)
{
	Top TopData;
	g_arTopData.GetArray(index, TopData, sizeof(TopData));
	return TopData;
}

void ResetTop(int iPlayerIndex, int iTopId)
{
	char szQuery[128];
	Top TopData; TopData = GetTopByIndex(iTopId);
	g_dbDatabase.Format(szQuery, sizeof(szQuery), "SELECT * FROM `top_stats` WHERE `unique` = '%s' ORDER BY `points` DESC LIMIT 1", TopData.szUnique);
	g_dbDatabase.Query(KV_SetTopData, szQuery, iTopId);
	
	for (int iCurrentClient = 1; iCurrentClient <= MaxClients; iCurrentClient++)
	{
		if (IsClientInGame(iCurrentClient) && !IsFakeClient(iCurrentClient)) {
			g_esClientData[iCurrentClient].iPoints.Set(iTopId, TopData.iDefaultPoints);
		}
	}
	
	Call_StartForward(g_fwdOnTopReset);
	Call_PushCell(iTopId);
	Call_Finish();
	
	if (iPlayerIndex != -1)
		WriteLogLine("Player\"%L\" has reset top \"%s\".", iPlayerIndex, TopData.szName);
	else
		WriteLogLine("Top \"%s\" has automatically reset.", TopData.szName);
}

char AddCommas(int value, const char[] seperator = ",")
{
	static Regex rgxCommasPostions = null;
	
	if (!rgxCommasPostions) {
		rgxCommasPostions = CompileRegex("\\d{1,3}(?=(\\d{3})+(?!\\d))");
	}
	
	char buffer[MAX_NAME_LENGTH];
	IntToString(value, buffer, MAX_NAME_LENGTH);
	
	rgxCommasPostions.MatchAll(buffer);
	
	for (int iCurrentOffset = 0; iCurrentOffset < rgxCommasPostions.MatchCount(); iCurrentOffset++)
	{
		int iOffset = rgxCommasPostions.MatchOffset(iCurrentOffset);
		iOffset += iCurrentOffset;
		
		Format(buffer[iOffset], sizeof(buffer) - iOffset, "%c%s", seperator, buffer[iOffset]);
	}
	
	return buffer;
}

void WriteLogLine(const char[] log, any...)
{
	char szLogLine[1024];
	VFormat(szLogLine, sizeof(szLogLine), log, 2);
	
	static char szPath[128];
	if (strlen(szPath) < 1)
	{
		char szFileName[64];
		GetPluginFilename(INVALID_HANDLE, szFileName, sizeof(szFileName));
		ReplaceString(szFileName, sizeof(szFileName), ".smx", "");
		
		FormatTime(szPath, sizeof(szPath), "%Y%m%d", GetTime());
		BuildPath(Path_SM, szPath, sizeof(szPath), "logs/%s_%s.log", szFileName, szPath);
	}
	
	LogToFile(szPath, szLogLine);
}

/*  */