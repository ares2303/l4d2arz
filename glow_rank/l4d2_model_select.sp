#pragma semicolon 1
#define PLUGIN_VERSION "1.7"  
#define PLUGIN_NAME "Survivor Chat Select"
#define PLUGIN_AUTHOR "Emilio3"
#include <sourcemod>  
#include <sdktools>  
#include <clientprefs>
#include <adminmenu>
#pragma newdecls required

#define MODEL_BILL "models/survivors/survivor_namvet.mdl" 
#define MODEL_FRANCIS "models/survivors/survivor_biker.mdl" 
#define MODEL_LOUIS "models/survivors/survivor_manager.mdl" 
#define MODEL_ZOEY "models/survivors/survivor_teenangst.mdl" 
#define MODEL_NICK "models/survivors/survivor_gambler.mdl" 
#define MODEL_ROCHELLE "models/survivors/survivor_producer.mdl" 
#define MODEL_COACH "models/survivors/survivor_coach.mdl" 
#define MODEL_ELLIS "models/survivors/survivor_mechanic.mdl" 
#define MODEL_PARACHUTIS "models/infected/common_male_parachutist.mdl" 
#define NICK 0
#define ROCHELLE 1
#define COACH 2
#define ELLIS 3
#define BILL 4
#define ZOEY 5
#define FRANCIS 6
#define LOUIS 7
#define PARACHUTIS 8

TopMenu hTopMenu;

ConVar convarSpawn, convarAdminsOnly, convarCookies;
char current_map[56];
int g_iSelectedClient[MAXPLAYERS+1];
Handle g_hClientID, g_hClientModel;

public Plugin myinfo =  
{  
	name = PLUGIN_NAME,  
	author = PLUGIN_AUTHOR,  
	description = "Select a survivor character by typing their name into the chat.",  
	version = PLUGIN_VERSION,
	url = "N/A"
}  

public void OnPluginStart()  
{  
	g_hClientID = RegClientCookie("Player_Character", "Player's default character ID.", CookieAccess_Protected);
	g_hClientModel = RegClientCookie("Player_Model", "Player's default character model.", CookieAccess_Protected);	 
	RegConsoleCmd("sm_zoey", ZoeyUse, "Changes your survivor character into Zoey");  
	RegConsoleCmd("sm_nick", NickUse, "Changes your survivor character into Nick");  
	RegConsoleCmd("sm_ellis", EllisUse, "Changes your survivor character into Ellis");  
	RegConsoleCmd("sm_coach", CoachUse, "Changes your survivor character into Coach");  
	RegConsoleCmd("sm_rochelle", RochelleUse, "Changes your survivor character into Rochelle");  
	RegConsoleCmd("sm_bill", BillUse, "Changes your survivor character into Bill");  
	RegConsoleCmd("sm_francis", BikerUse, "Changes your survivor character into Francis");  
	RegConsoleCmd("sm_louis", LouisUse, "Changes your survivor character into Louis"); 
 	RegConsoleCmd("sm_parachutis", ParachutisUse, "Changes your survivor character into Parashutis"); 
	RegConsoleCmd("sm_z", ZoeyUse, "Changes your survivor character into Zoey");  
	RegConsoleCmd("sm_n", NickUse, "Changes your survivor character into Nick");  
	RegConsoleCmd("sm_e", EllisUse, "Changes your survivor character into Ellis");  
	RegConsoleCmd("sm_c", CoachUse, "Changes your survivor character into Coach");  
	RegConsoleCmd("sm_r", RochelleUse, "Changes your survivor character into Rochelle");  
	RegConsoleCmd("sm_b", BillUse, "Changes your survivor character into Bill");  
	RegConsoleCmd("sm_f", BikerUse, "Changes your survivor character into Francis");  
	RegConsoleCmd("sm_l", LouisUse, "Changes your survivor character into Louis"); 
    RegConsoleCmd("sm_pa", ParachutisUse, "Changes your survivor character into Parachutis"); 	
	RegAdminCmd("sm_csc", InitiateMenuAdmin, ADMFLAG_GENERIC, "Brings up a menu to select a client's character"); 
	RegConsoleCmd("sm_csm", ShowMenu, "Brings up a menu to select a client's character"); 	
	HookEvent("player_bot_replace", Event_PlayerToBot, EventHookMode_Post);
	convarAdminsOnly = CreateConVar("l4d2_csm_admins_only", "0","Changes access to the sm_csm command. 1 = Admin access only.",FCVAR_NOTIFY,true, 0.0, true, 1.0);		
	convarSpawn = CreateConVar("l4d2_csm_botschange", "0","Change new bots to least prevalent survivor? 1:Enable, 0:Disable",FCVAR_NOTIFY,true, 0.0, true, 1.0);
	convarCookies = CreateConVar("l4d2_csm_cookies", "1","Store player's survivor? 1:Enable, 0:Disable",FCVAR_NOTIFY,true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_model_select");
	LoadTranslations("l4d2_model_select.phrases"); 
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
}
	
Action ZoeyUse(int client, int args)  
{  
	SurvivorChange(client, ZOEY, MODEL_ZOEY, "Zoey");
	return Plugin_Handled;
}
Action NickUse(int client, int args)  
{
	SurvivorChange(client, NICK, MODEL_NICK, "Nick");
	return Plugin_Handled;
}
Action EllisUse(int client, int args)  
{
	SurvivorChange(client, ELLIS, MODEL_ELLIS, "Ellis");
	return Plugin_Handled;
}
Action CoachUse(int client, int args)  
{
	SurvivorChange(client, COACH, MODEL_COACH, "Coach");
	return Plugin_Handled;
}
Action RochelleUse(int client, int args)  
{  
	SurvivorChange(client, ROCHELLE, MODEL_ROCHELLE, "Rochelle");
	return Plugin_Handled;
}  
Action BillUse(int client, int args)  
{  
	SurvivorChange(client, BILL, MODEL_BILL, "Bill");
	return Plugin_Handled;
}  
Action BikerUse(int client, int args)  
{  
	SurvivorChange(client, FRANCIS, MODEL_FRANCIS, "francis");
	return Plugin_Handled;
}  
Action LouisUse(int client, int args)  
{  
	SurvivorChange(client, LOUIS, MODEL_LOUIS, "Louis");
	return Plugin_Handled;
}  
Action ParachutisUse(int client, int args)  
{  
	SurvivorChange(client, NICK, MODEL_PARACHUTIS, "Parashutis");
	return Plugin_Handled;
}

void SurvivorChange(int client, int prop, char[] model,  char[] name, bool save = true)
{
	if(client == 0)  
	{	
	    PrintToServer("You must be in the survivor team to use this command!"); return;
	}
	if(!IsSurvivor(client))
	{ 
	    PrintToChat(client, "You must be in the survivor team to use this command!"); 	return; 
	}
	if (IsFakeClient(client))  
	{
		SetClientInfo(client, "name", name);
	}	
	SetEntProp(client, Prop_Send, "m_survivorCharacter", prop);  
	SetEntityModel(client, model);
	ReEquipWeapons(client);	
	if (convarCookies.BoolValue && save)
	{
		char sprop[2]; IntToString(prop, sprop, 2);
		SetClientCookie(client, g_hClientID, sprop);
		SetClientCookie(client, g_hClientModel, model);
		PrintToChat(client,"%t", "Current skin is replaced by the skin %s", name); 
	}

	// Memicu refresh ranking color dan glow overlay dengan jeda waktu tipis
	CreateTimer(0.3, Timer_RefreshGlowAndColors, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}	

public Action Timer_RefreshGlowAndColors(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0 && IsClientInGame(client))
	{
		// Refresh ranking color (Plugin ranking)
		ServerCommand("sm_refresh_rank_color %d", userid);
		// Refresh glow overlay (Plugin glow overlay)
		ServerCommand("sm_refresh_glow_overlay %d", userid);
	}
	return Plugin_Continue;
}
	
public void OnMapStart() 
{     
	(FindConVar("precache_all_survivors").IntValue = 1); 	
	if (!IsModelPrecached("models/survivors/survivor_teenangst.mdl")) PrecacheModel("models/survivors/survivor_teenangst.mdl", false); 
	if (!IsModelPrecached("models/survivors/survivor_biker.mdl")) PrecacheModel("models/survivors/survivor_biker.mdl", false); 
	if (!IsModelPrecached("models/survivors/survivor_manager.mdl")) PrecacheModel("models/survivors/survivor_manager.mdl", false); 
	if (!IsModelPrecached("models/survivors/survivor_namvet.mdl")) PrecacheModel("models/survivors/survivor_namvet.mdl", false); 
	if (!IsModelPrecached("models/survivors/survivor_gambler.mdl")) PrecacheModel("models/survivors/survivor_gambler.mdl", false); 
	if (!IsModelPrecached("models/survivors/survivor_coach.mdl")) PrecacheModel("models/survivors/survivor_coach.mdl", false); 
	if (!IsModelPrecached("models/survivors/survivor_mechanic.mdl")) PrecacheModel("models/survivors/survivor_mechanic.mdl", false); 
	if (!IsModelPrecached("models/survivors/survivor_producer.mdl")) PrecacheModel("models/survivors/survivor_producer.mdl", false); 
	if (!IsModelPrecached("models/infected/common_male_parachutist.mdl")) PrecacheModel("models/infected/common_male_parachutist.mdl", false);	
	GetCurrentMap(current_map, sizeof(current_map));
} 

bool IsSurvivor(int client)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	return false;
}

Action InitiateMenuAdmin(int client, int args)  
{ 
	if (client == 0)  
	{ 
		ReplyToCommand(client, "Menu is in-game only."); 
		return Plugin_Handled; 
	} 
	char name[MAX_NAME_LENGTH]; char number[10]; 	
	Menu menu = new Menu(ShowMenu2);
	menu.SetTitle("%t", "Select a client:"); 	
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		if (!IsClientInGame(i)) continue; 
		if (GetClientTeam(i) != 2) continue; 		
		Format(name, sizeof(name), "%N", i); 
		Format(number, sizeof(number), "%i", i); 
		menu.AddItem(number, name); 
	} 
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled; 
} 

public void ShowMenu2(Menu menu, MenuAction action, int client, int param2)  
{ 
	switch (action)  
	{ 
		case MenuAction_Select:  
		{ 
			char number[4];
			menu.GetItem(param2, number, sizeof(number)); 
			g_iSelectedClient[client] = StringToInt(number);
			ShowMenuAdmin(client, 0); 
		} 
		case MenuAction_Cancel: 
		{ 
			if (param2 == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE)
			{
				hTopMenu.Display(client, TopMenuPosition_LastCategory);
			}			
		} 
		case MenuAction_End:  
		{ 
			delete menu; 
		} 
	} 
} 

public void ShowMenuAdmin(int client, int args)  
{ 
	char sMenuEntry[9]; 	
	Menu menu = new Menu(CharMenuAdmin); 
	menu.SetTitle("%t", "Choose a Character:"); 	
	IntToString(NICK, sMenuEntry, sizeof(sMenuEntry)); 
	menu.AddItem(sMenuEntry, "Nick"); 
	IntToString(ROCHELLE, sMenuEntry, sizeof(sMenuEntry)); 
	menu.AddItem(sMenuEntry, "Rochelle"); 
	IntToString(COACH, sMenuEntry, sizeof(sMenuEntry)); 
	menu.AddItem(sMenuEntry, "Coach"); 
	IntToString(ELLIS, sMenuEntry, sizeof(sMenuEntry)); 
	menu.AddItem(sMenuEntry, "Ellis"); 	
	IntToString(BILL, sMenuEntry, sizeof(sMenuEntry)); 
	menu.AddItem(sMenuEntry, "Bill");     
	IntToString(ZOEY, sMenuEntry, sizeof(sMenuEntry)); 
	menu.AddItem(sMenuEntry, "Zoey"); 
	IntToString(FRANCIS, sMenuEntry, sizeof(sMenuEntry)); 
	menu.AddItem(sMenuEntry, "Francis"); 
	IntToString(LOUIS, sMenuEntry, sizeof(sMenuEntry)); 
	menu.AddItem(sMenuEntry, "Louis"); 
	IntToString(PARACHUTIS, sMenuEntry, sizeof(sMenuEntry)); 
	menu.AddItem(sMenuEntry, "Parachutis"); 		
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
} 

public void CharMenuAdmin(Menu menu, MenuAction action, int client, int param2)  
{ 
	switch (action)  
	{ 
		case MenuAction_Select:  
		{ 
			char item[9]; 
			menu.GetItem(param2, item, sizeof(item)); 
			
			switch(StringToInt(item))  
			{
				case NICK:        {    SurvivorChange(g_iSelectedClient[client], NICK, MODEL_NICK,    "Nick",false);    }     
				case ROCHELLE:    {    SurvivorChange(g_iSelectedClient[client], ROCHELLE, MODEL_ROCHELLE,"Rochelle",false);}     
				case COACH:       {    SurvivorChange(g_iSelectedClient[client], COACH, MODEL_COACH,   "Coach",false);   }
				case ELLIS:       {    SurvivorChange(g_iSelectedClient[client], ELLIS, MODEL_ELLIS,   "Ellis",false);   } 
				case BILL:        {    SurvivorChange(g_iSelectedClient[client], BILL, MODEL_BILL,    "Bill",false);    }
				case ZOEY:        {    SurvivorChange(g_iSelectedClient[client], ZOEY, MODEL_ZOEY,    "Zoey",false);    }  
				case FRANCIS:     {    SurvivorChange(g_iSelectedClient[client], FRANCIS, MODEL_FRANCIS, "Francis",false); }  
				case LOUIS:       {    SurvivorChange(g_iSelectedClient[client], LOUIS, MODEL_LOUIS,   "Louis", false);   }
				case PARACHUTIS:  {    SurvivorChange(g_iSelectedClient[client], NICK, MODEL_PARACHUTIS,   "Parachutis", false);   }
			} 
		} 
		case MenuAction_Cancel: 
		{
		} 
		case MenuAction_End:
        {
             delete menu;
        }
    }
}  

Action ShowMenu(int client, int args) 
{
	if (client == 0) 
	{
		ReplyToCommand(client, "[SCS] Character Select Menu is in-game only.");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) != 2)
	{
		ReplyToCommand(client, "[SCS] Character Select Menu is only available to survivors.");
		return Plugin_Handled;
	}
	if (!IsPlayerAlive(client)) 
	{
		ReplyToCommand(client, "[SCS] You must be alive to use the Character Select Menu!");
		return Plugin_Handled;
	}
	if (GetUserFlagBits(client) == 0 && convarAdminsOnly.BoolValue)
	{
		ReplyToCommand(client, "[SCS] Character Select Menu is only available to admins.");
		return Plugin_Handled;
	}
	char sMenuEntry[9];	
	Menu menu = new Menu(CharMenu);
	menu.SetTitle("%t", "Choose a Character:");
	IntToString(NICK, sMenuEntry, sizeof(sMenuEntry));
	menu.AddItem(sMenuEntry, "Nick");
	IntToString(ROCHELLE, sMenuEntry, sizeof(sMenuEntry));
	menu.AddItem(sMenuEntry, "Rochelle");
	IntToString(COACH, sMenuEntry, sizeof(sMenuEntry));
	menu.AddItem(sMenuEntry, "Coach");
	IntToString(ELLIS, sMenuEntry, sizeof(sMenuEntry));
	menu.AddItem(sMenuEntry, "Ellis");	
	IntToString(BILL, sMenuEntry, sizeof(sMenuEntry));
	menu.AddItem(sMenuEntry, "Bill");    
	IntToString(ZOEY, sMenuEntry, sizeof(sMenuEntry));
	menu.AddItem(sMenuEntry, "Zoey");
	IntToString(FRANCIS, sMenuEntry, sizeof(sMenuEntry));
	menu.AddItem(sMenuEntry, "Francis");
	IntToString(LOUIS, sMenuEntry, sizeof(sMenuEntry));
	menu.AddItem(sMenuEntry, "Louis");	
	IntToString(PARACHUTIS, sMenuEntry, sizeof(sMenuEntry));
	menu.AddItem(sMenuEntry, "Parachutis");		
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public void CharMenu(Menu menu, MenuAction action, int param1, int param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			char item[9];
			menu.GetItem(param2, item, sizeof(item));
			
			switch(StringToInt(item)) 
			{
				case NICK:        {    NickUse(param1, NICK);        }
				case ROCHELLE:    {    RochelleUse(param1, ROCHELLE);    }
				case COACH:        {    CoachUse(param1, COACH);        }
				case ELLIS:        {    EllisUse(param1, ELLIS);        }
				case BILL:        {    BillUse(param1, BILL);        }
				case ZOEY:        {    ZoeyUse(param1, ZOEY);        }
				case FRANCIS:    {    BikerUse(param1, FRANCIS);    }
				case LOUIS:        {    LouisUse(param1, LOUIS);        }
				case PARACHUTIS:        {    ParachutisUse(param1, NICK);        }
				
			}
		}
		case MenuAction_Cancel:
		{	
		}
		case MenuAction_End: 
		{
			delete menu;
		}
	}
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
	if (topmenu == hTopMenu)
	{
		return;
	}
	hTopMenu = topmenu;	
	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(hTopMenu, "Select player's survivor", TopMenuObject_Item, InitiateMenuAdmin2, player_commands, "Select player's survivor", ADMFLAG_GENERIC);
	}
}

public void InitiateMenuAdmin2(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Select player's survivor", "", client);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		InitiateMenuAdmin(client, 0);
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && convarCookies.BoolValue)
	{
		CreateTimer(0.3, Timer_LoadCookie, GetClientUserId(client));
	}
}
	
public void Timer_LoadCookie(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	char sID[2]; char sModel[64];
	if(client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && convarCookies.BoolValue && AreClientCookiesCached(client))
	{
		GetClientCookie(client, g_hClientID, sID, sizeof(sID));
		GetClientCookie(client, g_hClientModel, sModel, sizeof(sModel));
	
		if(strlen(sID) && strlen(sModel))
		{
			SetEntProp(client, Prop_Send, "m_survivorCharacter", StringToInt(sID)); 
			SetEntityModel(client, sModel); 
		}
	}
}

char survivor_models[9][] = { MODEL_NICK, MODEL_ROCHELLE, MODEL_COACH, MODEL_ELLIS, MODEL_BILL,	MODEL_ZOEY,	MODEL_FRANCIS, MODEL_LOUIS, MODEL_PARACHUTIS };
char survivor_commands[9][] = { "sm_nick", "sm_rochelle", "sm_coach", "sm_ellis", "sm_bill", "sm_zoey", "sm_francis", "sm_louis", "sm_parachutis"};

public void Event_PlayerToBot(Event event, char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	int bot    = GetClientOfUserId(GetEventInt(event, "bot")); 	
	if(player > 0 && GetClientTeam(player)== 2  &&  IsFakeClient(player) && convarSpawn.BoolValue) 
	{
		FakeClientCommand(bot, survivor_commands[GetFewestSurvivor(bot)]);
	}
}

int GetFewestSurvivor(int clientignore = -1) 
{
	char Model[128];
	int Survivors[9];
	for (int client=1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2 && client != clientignore)
		{
			GetClientModel(client, Model, 128);
			for (int s = 0; s < 9; s++)
			{
				if (StrEqual(Model, survivor_models[s])) Survivors[s] = Survivors[s] + 1;
			}		
		}
	}	
	int minS = 1;
	int min  = 9999;	
	for (int s = 0; s < 9; s++)
	{
		if (Survivors[s] < min) 
		{
			minS = s;
			min  = Survivors[s];
		}
	}
	return minS;
}

enum
{
	iClip = 0,
	iAmmo,
	iUpgrade,
	iUpAmmo
}

void ReEquipWeapons(int client)
{
	int i_Weapon = GetEntDataEnt2(client, FindSendPropInfo("CBasePlayer", "m_hActiveWeapon"));	
	if (!IsPlayerAlive(client) || !IsValidEdict(i_Weapon) || !IsValidEntity(i_Weapon))  return;
	int iSlot0 = GetPlayerWeaponSlot(client, 0);  	int iSlot1 = GetPlayerWeaponSlot(client, 1);	
	int iSlot2 = GetPlayerWeaponSlot(client, 2);  	int iSlot3 = GetPlayerWeaponSlot(client, 3);
	int iSlot4 = GetPlayerWeaponSlot(client, 4);  	
	char sWeapon[64];
	GetClientWeapon(client, sWeapon, sizeof(sWeapon));	
	if (iSlot2 > 0 && strcmp(sWeapon, "weapon_vomitjar", true) && strcmp(sWeapon, "weapon_pipe_bomb", true) && strcmp(sWeapon, "weapon_molotov", true ))
	{
		GetEdictClassname(iSlot2, sWeapon, 64);
		DeletePlayerSlot(client, iSlot2);
		CheatCommand(client, "give", sWeapon, "");
	}
	if (iSlot3 > 0)
	{
		GetEdictClassname(iSlot3, sWeapon, 64);
		DeletePlayerSlot(client, iSlot3);
		CheatCommand(client, "give", sWeapon, "");
	}
	if (iSlot4 > 0)
	{
		GetEdictClassname(iSlot4, sWeapon, 64);
		DeletePlayerSlot(client, iSlot4);
		CheatCommand(client, "give", sWeapon, "");
	}
	if (iSlot1 > 0) ReEquipSlot1(client, iSlot1);
	if (iSlot0 > 0) ReEquipSlot0(client, iSlot0);
}

void ReEquipSlot0(int client, int iSlot0)
{
	int iWeapon0[4];
	char sWeapon[64];	
	GetEdictClassname(iSlot0, sWeapon, 64);		
	iWeapon0[iClip] = GetEntProp(iSlot0, Prop_Send, "m_iClip1", 4);
	iWeapon0[iAmmo] = GetClientAmmo(client, sWeapon);
	iWeapon0[iUpgrade] = GetEntProp(iSlot0, Prop_Send, "m_upgradeBitVec", 4);
	iWeapon0[iUpAmmo]  = GetEntProp(iSlot0, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", 4);		
	DeletePlayerSlot(client, iSlot0);
	CheatCommand(client, "give", sWeapon, "");		
	iSlot0 = GetPlayerWeaponSlot(client, 0);
	if (iSlot0 > 0)
	{
		SetEntProp(iSlot0, Prop_Send, "m_iClip1", iWeapon0[iClip], 4);
		SetClientAmmo(client, sWeapon, iWeapon0[iAmmo]);
		SetEntProp(iSlot0, Prop_Send, "m_upgradeBitVec", iWeapon0[iUpgrade], 4);
		SetEntProp(iSlot0, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", iWeapon0[iUpAmmo], 4);
	}			
}

void ReEquipSlot1(int client, int iSlot1)
{
	char className[64], modelName[64], sWeapon[64];
	sWeapon[0] = '\0';
	int Ammo = -1;
	int iSlot = -1;	
	GetEdictClassname(iSlot1, className, sizeof(className));	
	if 		(!strcmp(className, "weapon_melee", true))   GetEntPropString(iSlot1, Prop_Data, "m_strMapSetScriptName", sWeapon, 64);
	else if (strcmp(className, "weapon_pistol", true))   GetEdictClassname(iSlot1, sWeapon, 64);	
	if (sWeapon[0] == '\0')
	{
		GetEntPropString(iSlot1, Prop_Data, "m_ModelName", modelName, sizeof(modelName));
		if (StrContains(modelName, "v_pistolA.mdl", true) != -1) sWeapon = "weapon_pistol";
		else if (StrContains(modelName, "v_dual_pistolA.mdl", true) != -1) sWeapon = "dual_pistol";
		else if (StrContains(modelName, "v_desert_eagle.mdl", true) != -1) sWeapon = "weapon_pistol_magnum";
		else if (StrContains(modelName, "v_bat.mdl", true) != -1) sWeapon = "baseball_bat";
		else if (StrContains(modelName, "v_cricket_bat.mdl", true) != -1) sWeapon = "cricket_bat";
		else if (StrContains(modelName, "v_crowbar.mdl", true) != -1) sWeapon = "crowbar";
		else if (StrContains(modelName, "v_fireaxe.mdl", true) != -1) sWeapon = "fireaxe";
		else if (StrContains(modelName, "v_katana.mdl", true) != -1) sWeapon = "katana";
		else if (StrContains(modelName, "v_golfclub.mdl", true) != -1) sWeapon = "golfclub";
		else if (StrContains(modelName, "v_machete.mdl", true) != -1) sWeapon = "machete";
		else if (StrContains(modelName, "v_tonfa.mdl", true) != -1) sWeapon = "tonfa";
		else if (StrContains(modelName, "v_electric_guitar.mdl", true) != -1) sWeapon = "electric_guitar";
		else if (StrContains(modelName, "v_frying_pan.mdl", true) != -1) sWeapon = "frying_pan";
		else if (StrContains(modelName, "v_knife_t.mdl", true) != -1) sWeapon = "knife";
		else if (StrContains(modelName, "v_chainsaw.mdl", true) != -1) sWeapon = "weapon_chainsaw";
		else if (StrContains(modelName, "v_riotshield.mdl", true) != -1) sWeapon = "alliance_shield";
		else if (StrContains(modelName, "v_fubar.mdl", true) != -1) sWeapon = "fubar";
		else if (StrContains(modelName, "v_paintrain.mdl", true) != -1) sWeapon = "nail_board";
		else if (StrContains(modelName, "v_sledgehammer.mdl", true) != -1) sWeapon = "sledgehammer";
		else if (StrContains(modelName, "v_shovel.mdl", true) != -1) sWeapon = "shovel";
		else if (StrContains(modelName, "v_pitchfork.mdl", true) != -1) sWeapon = "pitchfork";
	}

	if (sWeapon[0] != '\0')
	{
		if (!strcmp(sWeapon, "dual_pistol", true)   || !strcmp(sWeapon, "weapon_pistol", true)
		|| !strcmp(sWeapon, "weapon_pistol_magnum", true) || !strcmp(sWeapon, "weapon_chainsaw", true))
		{
			Ammo = GetEntProp(iSlot1, Prop_Send, "m_iClip1", 4);
		}		
		DeletePlayerSlot(client, iSlot1);		
		if (!strcmp(sWeapon, "dual_pistol", true))
		{
			 CheatCommand(client, "give", "weapon_pistol", "");
			 CheatCommand(client, "give", "weapon_pistol", "");
		}
		else CheatCommand(client, "give", sWeapon, "");		
		if (Ammo >= 0)
		{
			iSlot = GetPlayerWeaponSlot(client, 1);
			if (iSlot > 0) SetEntProp(iSlot, Prop_Send, "m_iClip1", Ammo, 4);
		}
	}
}

void DeletePlayerSlot(int client, int weapon)
{		
	if(RemovePlayerItem(client, weapon)) AcceptEntityInput(weapon, "Kill");
}

void CheatCommand(int client, const char[] command, const char[] argument1, const char[] argument2)
{
	int userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s", command, argument1, argument2);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}

int GetClientAmmo(int client, char[] weapon)
{
	int weapon_offset = GetWeaponOffset(weapon);
	int iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");	
	return weapon_offset > 0 ? GetEntData(client, iAmmoOffset+weapon_offset) : 0;
}

void SetClientAmmo(int client, char[] weapon, int count)
{
	int weapon_offset = GetWeaponOffset(weapon);
	int iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	if (weapon_offset > 0) SetEntData(client, iAmmoOffset+weapon_offset, count);
}

int GetWeaponOffset(char[] weapon)
{
	int weapon_offset;
	if (StrEqual(weapon, "weapon_rifle") || StrEqual(weapon, "weapon_rifle_sg552") || StrEqual(weapon, "weapon_rifle_desert") || StrEqual(weapon, "weapon_rifle_ak47"))
	{
		weapon_offset = 12;
	}
	else if (StrEqual(weapon, "weapon_rifle_m60"))
	{
		weapon_offset = 24;
	}
	else if (StrEqual(weapon, "weapon_smg") || StrEqual(weapon, "weapon_smg_silenced") || StrEqual(weapon, "weapon_smg_mp5"))
	{
		weapon_offset = 20;
	}
	else if (StrEqual(weapon, "weapon_pumpshotgun") || StrEqual(weapon, "weapon_shotgun_chrome"))
	{
		weapon_offset = 28;
	}
	else if (StrEqual(weapon, "weapon_autoshotgun") || StrEqual(weapon, "weapon_shotgun_spas"))
	{
		weapon_offset = 32;
	}
	else if (StrEqual(weapon, "weapon_hunting_rifle"))
	{
		weapon_offset = 36;
	}
	else if (StrEqual(weapon, "weapon_sniper_scout") || StrEqual(weapon, "weapon_sniper_military") || StrEqual(weapon, "weapon_sniper_awp"))
	{
		weapon_offset = 40;
	}
	else if (StrEqual(weapon, "weapon_grenade_launcher"))
	{
		weapon_offset = 68;
	}
	return weapon_offset;
}