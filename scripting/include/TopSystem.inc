#if defined _TopSystem_included
 #endinput
#endif
#define _TopSystem_included

/**
 * Creates a new top category to the core.
 * 
 * @param identifier         Unique identifier of the top, used to be stored in the database.
 * @param name               Name of the top.
 * @param description        Description of the top, will be shown on the top detail.
 * @param counter            Points counter name, will be shown after the top points number.
 * @param defaultValue       An initial value for the category points to be set.
 *
 * @return                 	 Top index.
 */
native int Top_AddCategory(char[] identifier, char[] name, char[] description, char[] counter, int defaultValue = 0);

/**
 * Finds and returns the top category index, 
 * by searching the index with the given identifier.
 * 
 * @param identifier          The identifier for the specified top category.
 * @return                    Top category index, or -1 if there is no top category matching the given identifier.
 */
native int Top_FindCategory(char[] identifier);

/**
 * Gets a client points from a specific top category.
 * 
 * @param client             Client Index.
 * @param topId              Top categoty index to get the points from.
 *
 * @return                   Client Points.
 * @error                    Invalid client index.
 */
native int Top_GetPoints(int client, int topId);

/**
 * Adds a points for a specific client.
 * 
 * @param client             Client Index.
 * @param topId              Top categoty index to add the points.
 * @param points             Points to be added.
 * @param broadcast          Print a chat message to the client, true by default.
 *
 * @error                    Invalid client index, or invalid points amount.
 */
native void Top_AddPoints(int client, int topId, int points, bool broadcast = true);

/**
 * Removes a points for a specific client.
 * .
 * @param client             Client Index.
 * @param topId              Top categoty index to remove the points.
 * @param points             Points to be removed.
 * @param broadcast          Print a chat message to the client, true by default.
 *
 * @error                    Invalid client index.
 */
native void Top_TakePoints(int client, int topId, int points, bool broadcast = true);

/**
 * Shows to a certain client the top category menu by the given top index.
 * 
 * @param client             Client Index.
 * @param topId              Top categoty index to display the menu from.
 *
 * @error                    Invalid client index.
 */
native void Top_ShowMenu(int client, int topId);

/**
 * Called when a top category has been reset.
 * 
 * @param topId              Top category index.
 */
forward void Top_OnCategoryReset(int topId);

#if !defined REQUIRE_PLUGIN
public void __pl_TopSystem_SetNTVOptional()
{
	MarkNativeAsOptional("Top_AddCategory");
	MarkNativeAsOptional("Top_FindCategory");
	MarkNativeAsOptional("Top_GetPoints");
	MarkNativeAsOptional("Top_AddPoints");
	MarkNativeAsOptional("Top_TakePoints");
	MarkNativeAsOptional("Top_ShowMenu");
}
#endif

public SharedPlugin __pl_TopSystem = 
{
	name = "TopSystem", 
	file = "TopSystem.smx", 
#if defined REQUIRE_PLUGIN
    required = 1, 
#else
    required = 0, 
#endif
}; 