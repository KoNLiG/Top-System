#if defined _TopSystem_included
#endinput
#endif
#define _TopSystem_included

/**
 * Adds a new top category to the core.
 * 
 * @param unique             Unique name of the top, used to be stored for the database.
 * @param name               Name of the top.
 * @param description        Description of the top, will be shown on the top detail.
 * @param counter            Points counter name, will be shown after the top points number.
 * @param defaultValue       An initial value for the category points to be set.
 * @return                  Top index.
 */
native int Top_AddCategory(char[] unique, char[] name, char[] description, char[] counter, int defaultValue = 0);

/**
 * Gets a client points from a specific top category.
 * 
 * @param client             Client Index.
 * @param topId              Top categoty index to get the points from.
 * @return                  Client Points.
 * @error                  Invalid client index.
 */
native int Top_GetPoints(int client, int topId);

/**
 * Adds a points for a specific client.
 * 
 * @param client             Client Index.
 * @param topId              Top categoty index to add the points.
 * @param points             Points to be added.
 * @param broadcast          Print a chat message to the client, true by default.
 * @error                   Invalid client index, or invalid points amount.
 */
native void Top_AddPoints(int client, int topId, int points, bool broadcast = true);

/**
 * Removes a points for a specific client.
 * .
 * @param client             Client Index.
 * @param topId              Top categoty index to remove the points.
 * @param points             Points to be removed.
 * @param broadcast          Print a chat message to the client, true by default.
 * @error                   Invalid client index.
 */
native void Top_TakePoints(int client, int topId, int points, bool broadcast = true);

/**
 * Called when the top statistics has reset.
 * 
 * @param topId              Top category index.
 */
forward void Top_OnTopReset(int topId);

#if !defined REQUIRE_PLUGIN
public void __pl_TopSystem_SetNTVOptional()
{
	MarkNativeAsOptional("Top_AddCategory");
	MarkNativeAsOptional("Top_GetPoints");
	MarkNativeAsOptional("Top_AddPoints");
	MarkNativeAsOptional("Top_TakePoints");
}
#endif

public SharedPlugin __pl_TopSystem = 
{
	name = "TopSystem", 
	file = "TopSystem.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
}; 