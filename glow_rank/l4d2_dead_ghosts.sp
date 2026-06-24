#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "2.2"
#define PLUGIN_AUTHOR "Emilio3"
#define PLUGIN_NAME "l4d2_dead_ghosts"
#define ZC_SMOKER 1
#define ZC_BOOMER 2
#define ZC_HUNTER 3
#define ZC_SPITTER 4
#define ZC_JOCKEY 5
#define ZC_CHARGER 6
#define ZC_WITCH 7
#define ZC_TANK 8
#define COLOR_MAROON "155 0 255 255"
#define COLOR_GREEN "0 255 0 255"
#define COLOR_RED "255 0 0 255"
#define COLOR_BLUE "0 0 255"
#define COLOR_VIOLET "249 19 250 255"
#define COLOR_CYAN "0 255 255 255"
#define COLOR_TEAL "0 128 128 255"
#define COLOR_YELLOW "255 255 0 255"
#define COLOR_PINK "255 105 180 255"
#define COLOR_PURPLE "128 0 128 255"
#define COLOR_ORANGE "255, 69, 0, 255"
#define COLOR_ORANGECLARO "249 155 84 255"
#define COLOR_LIME "128 255 0 255"
#define COLOR_GOLDEN "255 155 0 255"

enum L4D2GlowType
{
    L4D2Glow_None = 0,
    L4D2Glow_OnUse,
    L4D2Glow_OnLookAt,
    L4D2Glow_Constant
}

ConVar g_cvarEnable = null;

static	ConVar g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog;

bool g_bCvarAllow;

static const int InfGlowColor[] =
{
	0x000000,	//   0
	0x00FF00,	//   0 + (255 * 256) + (  0 * 65536));
	0xFA1307,	//   7 + ( 19 * 256) + (250 * 65536));
	0xFA13F9,	// 249 + ( 19 * 256) + (250 * 65536));
	0xFAFA42,	//  66 + (250 * 256) + (250 * 65536));
	0x005AFF,	//   5 + (175 * 256) + (255 * 65536));
	0x0000FF,	// 255 + (  0 * 256) + (  0 * 65536));
	0x323232,	//  50 + ( 50 * 256) + ( 50 * 65536));
	0x00FFFF,	// 255 + (255 * 256) + (  0 * 65536));
	0x00FF80,	// 128 + (255 * 256) + (  0 * 65536));
	0x000080,	// 128 + (  0 * 256) + (  0 * 65536));
	0x808000,	//   0 + (128 * 256) + (128 * 65536));
	0xFF7EA8,	// 255 + (126 * 256) + (168 * 65536));
	0xFF009B,	// 155 + (  0 * 256) + (255 * 65536));
	0xFFFFFF,	//  -1 + ( -1 * 256) + ( -1 * 65536));
	0x009BFF,	// 255 + (155 * 256) + (  0 * 65536));
    0x549BF9,	// 249 + (155 * 256) + ( 84 * 65536))
};

	
public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = "Shows a temporary ghost where a Special Infected died",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public void OnPluginStart()
{
	g_cvarEnable = CreateConVar("l4d2_deadghost_enable", "1", "Enables plugin");
	CreateConVar("l4d2_dead_ghost_version", PLUGIN_VERSION, PLUGIN_NAME);
	AutoExecConfig(true, "l4d2_dead_ghost");	
	HookEvent("player_spawn", Event_Spawn, EventHookMode_Post);
	HookEvent("player_death", Event_Infected_Dead, EventHookMode_Pre);	
	g_hCvarModes =	 CreateConVar("l4d2_deadghost_modes", "", "Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).");
	g_hCvarModesOff =	CreateConVar("l4d2_deadghost_modes_off", "", "Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).");
	g_hCvarModesTog =	CreateConVar("l4d2_deadghost_modes_tog", "0", "Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.");
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	HookConVarChange(g_hCvarMPGameMode, ConVarChanged_Allow);
	HookConVarChange(g_hCvarModes, ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesOff, ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesTog, ConVarChanged_Allow);
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	bool bCvarAllow = g_cvarEnable.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	if(g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true)
	{
		g_bCvarAllow = true;
		HookEvent("player_spawn", Event_Spawn, EventHookMode_Post);		
	}
	else if(g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false))
	{
		g_bCvarAllow = false;
		UnhookEvent("player_spawn", Event_Spawn, EventHookMode_Post);		
	}
}

static int g_iCurrentMode;

bool IsAllowedGameMode()
{
	if(g_hCvarMPGameMode == null)
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if(iCvarModesTog != 0)
	{
		g_iCurrentMode = 0;
		int entity = CreateEntityByName("info_gamemode");
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		AcceptEntityInput(entity, "PostSpawnActivate");
		AcceptEntityInput(entity, "Kill");
		if(g_iCurrentMode == 0)
			return false;

		if(!(iCvarModesTog & g_iCurrentMode))
			return false;
	}
	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);
	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if(strcmp(sGameModes, ""))
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if(StrContains(sGameModes, sGameMode, false) == -1)
			return false;
	}
	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if(strcmp(sGameModes, ""))
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if(StrContains(sGameModes, sGameMode, false) != -1)
			return false;
	}
	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if(strcmp(output, "OnCoop") == 0)
		g_iCurrentMode = 1;
	else if(strcmp(output, "OnSurvival") == 0)
		g_iCurrentMode = 2;
	else if(strcmp(output, "OnVersus") == 0)
		g_iCurrentMode = 4;
	else if(strcmp(output, "OnScavenge") == 0)
		g_iCurrentMode = 8;
}

public Action Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	static int infected;
	int color = 0, iEntity;
	if (!g_bCvarAllow) return Plugin_Continue;	
	infected = GetClientOfUserId(event.GetInt("userid"));
	if (infected < 1 || infected > MaxClients) return Plugin_Continue;
	if (!IsClientInGame(infected) || !IsPlayerAlive(infected)) return Plugin_Continue;
	if (GetClientTeam(infected) == 3)
	{	
		switch (GetInfectedClass(infected))
        {	
			case ZC_HUNTER: color = 4, SetGlowColor(infected, color);
			case ZC_JOCKEY: color = 6, SetGlowColor(infected, color);
			case ZC_SMOKER: color = 10, SetGlowColor(infected, color);
			case ZC_SPITTER: color = 3, SetGlowColor(infected, color);
			case ZC_BOOMER: color = 5, SetGlowColor(infected, color);
			case ZC_CHARGER: color = 15, SetGlowColor(infected, color);
		}
	}
	int iMaxEntities = GetMaxEntities();
	if (!IsValidEntity(iEntity)) return Plugin_Continue;
	for (iEntity = MaxClients + 1; iEntity < iMaxEntities; iEntity++)
    {
		if (IsCommonInfected(iEntity) && isRiot(iEntity))
		{			
		    color = 2, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 0, 0, 255, 255);
		}
		else if (IsCommonInfected(iEntity) && isCeda(iEntity))	
		{			
		    color = 8, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 255, 0, 255);
		}
		else if (IsCommonInfected(iEntity) && isClown(iEntity))
		{			
		    color = 6, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 0, 0, 255);
		}
		else if (IsCommonInfected(iEntity) && isMud(iEntity))
		{			
		    color = 10, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 155, 0, 255, 255);
		}		
		else if (IsCommonInfected(iEntity) && isRoadCrew(iEntity))
		{			
		    color = 9, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 128, 255, 0, 255);
		}
		else if (IsCommonInfected(iEntity) && isJimmy(iEntity))
		{			
		    color = 4, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 0, 255, 255, 255);
		}
		else if (IsCommonInfected(iEntity) && isFallen(iEntity))
		{			
		    color = 6, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 0, 0, 255);
		}
		else if (IsCommonInfected(iEntity) && isPolice(iEntity))
		{			
		    color = 4, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 0, 255, 255, 255);
		}
		else if (IsCommonInfected(iEntity) && isPatient(iEntity))
		{			
		    color = 14, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 105, 180, 255);
		}
		else if (IsCommonInfected(iEntity) && isMilitary(iEntity))
		{			
		    color = 11, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 0 ,128, 128, 255);
		}
		else if (IsCommonInfected(iEntity) && isTSAAgent(iEntity))
		{						
			color = 5, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 69, 0, 255);
		}
		else if (IsCommonInfected(iEntity) && isBiker(iEntity))
		{			
			color = 13, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 155, 0, 255, 255);		
		}
		else if (IsCommonInfected(iEntity) && isPilot(iEntity))
		{			
			color = 15, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 255, 0, 255);
		}
		else if (IsCommonInfected(iEntity) && isSuit(iEntity))
		{			
			color = 4, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 0, 255, 255, 255);
		}
		else if (IsCommonInfected(iEntity) && isSurgeon(iEntity))
		{			
			color = 15, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 255, 0, 255);	
		}
		else if (IsCommonInfected(iEntity) && isWorker(iEntity))
		{			
			color = 12, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 105, 180, 255);	
		}
		else if (IsCommonInfected(iEntity) && isBaggagehandler(iEntity))
		{			
			color = 11, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 0 ,128, 128, 255);
		}
		else if (IsCommonInfected(iEntity) && isNurse(iEntity))
		{			
			color = 14, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 105, 180, 255);
		}
		else if (IsCommonInfected(iEntity) && isFormal(iEntity))
		{			
			color = 8, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 255, 0, 255);
		}
		else if (IsCommonInfected(iEntity))
		{			
		    color = 16, SetGlowColor(iEntity, color);
			SetEntityRenderColor(iEntity, 255, 155, 0, 255);
		}
	}		
	return Plugin_Continue;	
}

public Action Event_Infected_Dead(Event event, const char[] name, bool dontBroadcast)
{
	static int infected;
	int color = 26, iEntity;	
	if (!g_bCvarAllow) return Plugin_Continue;	
	infected = GetClientOfUserId(event.GetInt("userid"));
	if (infected < 1 || infected > MaxClients) return Plugin_Continue;
	if (!IsClientInGame(infected)) return Plugin_Continue;
	if (GetClientTeam(infected) == 3 && event.GetBool("victimisbot"))
	{	
		switch (GetInfectedClass(infected))
        {	
			case ZC_HUNTER: UnSetGlowColor(infected, color);
			case ZC_JOCKEY: UnSetGlowColor(infected, color);
			case ZC_SMOKER: UnSetGlowColor(infected, color);
			case ZC_SPITTER: UnSetGlowColor(infected, color);
			case ZC_BOOMER: UnSetGlowColor(infected, color);
			case ZC_CHARGER: UnSetGlowColor(infected, color);
		}
	}
	int iMaxEntities = GetMaxEntities();
	if (!IsValidEntity(iEntity)) return Plugin_Continue;	
	for (iEntity = MaxClients + 1; iEntity < iMaxEntities; iEntity++)
    {
		if (isRiot(iEntity) && isCeda(iEntity) && isClown(iEntity) && IsCommonInfected(iEntity) 
		&& isMud(iEntity) && isRoadCrew(iEntity) && isJimmy(iEntity) && isFallen(iEntity) && isPolice(iEntity)
		&& isPatient(iEntity) && isMilitary(iEntity) && isTSAAgent(iEntity) && isBiker(iEntity) && isPilot(iEntity)
		&& isSuit(iEntity) && isSurgeon(iEntity) && isWorker(iEntity) && isBaggagehandler(iEntity) && isNurse(iEntity)
		&& isFormal(iEntity))
		{			
		    UnSetGlowColor(iEntity, color);		
		}
	}		
	return Plugin_Continue;	
}

public void OnEntityDestroyed(int iEntity)
{
	int iMaxEntities = GetMaxEntities();
	int color = 26;
	if (!IsValidEntity(iEntity)) return;	
	for (iEntity = MaxClients + 1; iEntity < iMaxEntities; iEntity++)
    {
		if (isRiot(iEntity) && isCeda(iEntity) && isClown(iEntity) && IsCommonInfected(iEntity) 
		&& isMud(iEntity) && isRoadCrew(iEntity) && isJimmy(iEntity) && isFallen(iEntity) && isPolice(iEntity)
		&& isPatient(iEntity) && isMilitary(iEntity) && isTSAAgent(iEntity) && isBiker(iEntity) && isPilot(iEntity)
		&& isSuit(iEntity) && isSurgeon(iEntity) && isWorker(iEntity) && isBaggagehandler(iEntity) && isNurse(iEntity)
		&& isFormal(iEntity))
		{			
		    UnSetGlowColor(iEntity, color);		
		}
	}	
}

stock int GetInfectedClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}
	
stock void SetGlowColor(int client, int color)
{
    if(!EnableGlow(client, L4D2Glow_OnLookAt, InfGlowColor[color])) return;
}

stock void UnSetGlowColor(int client, int color)
{
    if(!EnableGlow(client, L4D2Glow_None, InfGlowColor[color])) return;
}

stock bool EnableGlow(int entity, L4D2GlowType type, int color)
{
    char netclass[128];
    GetEntityNetClass(entity, netclass, 128);
    if(FindSendPropInfo(netclass, "m_iGlowType") < 1) return false;
    SetEntProp(entity, Prop_Send, "m_iGlowType", type);
    SetEntProp(entity, Prop_Send, "m_glowColorOverride", color);
    SetEntProp(entity, Prop_Send, "m_nGlowRange", 700);
	AcceptEntityInput(entity, "StartGlowing");
    return true;
}

stock bool IsCommonInfected(int iEntity)
{
    if (iEntity && IsValidEntity(iEntity) && IsValidEdict(iEntity))
    {
        char strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "infected");
    }
    return false;
}

stock bool isRiot(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "riot") != -1; 
}

stock bool isCeda(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "ceda") != -1; 
}

stock bool isClown(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "clown") != -1; 
}

stock bool isMud(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "mud") != -1; 
}

stock bool isRoadCrew(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "roadcrew") != -1; 
}

stock bool isJimmy(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "jimmy") != -1; 
}

stock bool isFallen(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "fallen") != -1; 
}

stock bool isPolice(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "police") != -1; 
}

stock bool isPatient(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "patient") != -1; 
}

stock bool isMilitary(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "military") != -1; 
}

stock bool isTSAAgent(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "tsaagent") != -1; 
}

stock bool isBiker(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "biker") != -1; 
}

stock bool isPilot(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "pilot") != -1; 
}

stock bool isSuit(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "suit") != -1; 
}

stock bool isSurgeon(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "surgeon") != -1; 
}

stock bool isWorker(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "worker") != -1; 
}

stock bool isBaggagehandler(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "baggagehandler") != -1; 
}

stock bool isNurse(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "nurse") != -1; 
}

stock bool isFormal(int entity)
{
    if (entity <= 0 || entity > 2048 || !IsValidEdict(entity)) return false;
    char model[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
    return StrContains(model, "formal") != -1; 
}