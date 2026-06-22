#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <clientprefs>

#define PLUGIN_AUTHOR "Emilio3"
#define PLUGIN_VERSION "2.0"

int glowscolor[MAXPLAYERS+1];
Handle g_hGlowCookie = INVALID_HANDLE;

static char sColorName[][] =
{
	"Desactive\n ",
	"Green",
	"Blue",
	"Violet",
	"Cyan",
	"Orange",
	"Red",
	"Gray",
	"Yellow",
	"Lime",
	"Maroon",
	"Teal",
	"Pink",
	"Purple",
	"White",
	"Golden",
	"Rainbow"
};

static const int
	COLOR_VALUE[] = 
{
	0x000000,
	0x00FF00,
	0xFA1307,
	0xFA13F9,
	0xFAFA42,
	0x005AFF,
	0x0000FF,
	0x323232,
	0x00FFFF,
	0x00FF80,
	0x000080,
	0x808000,
	0xFF7EA8,
	0xFF009B,
	0xFFFFFF,
	0x009BFF,
	0x000000
};

static const char sCommandList[][] = 
{
	"sm_grg", "sm_gwhite", "sm_ggreen", "sm_gred", "sm_gblue",
	"sm_ggold", "sm_gcyan", "sm_gvio", "sm_gmar", "sm_glima",
	"sm_gyellow", "sm_gtea", "sm_gpink", "sm_gpurple", "sm_gorange"
};

static const int iCommandIndex[] = 
{
	0, 14, 1, 6, 2,
	15, 4, 3, 10, 9,
	8, 11, 12, 13, 5
};

int numColors;

public Plugin myinfo =
{
	name = "Overlay Glow Colors",
	author = PLUGIN_AUTHOR,
	description = "Allow you overlay glow color by a menu.",
	version = PLUGIN_VERSION
};

public void OnPluginStart()
{
	LoadTranslations("l4d2_glowcolor.phrases");
	
	g_hGlowCookie = RegClientCookie("l4d2_overlay_glowcolor", "Saves overlay glow color index", CookieAccess_Private);
	
	RegAdminCmd("sm_gocolor", GlowColors, ADMFLAG_CUSTOM1);

	for (int i = 0; i < sizeof(sCommandList); i++)
	{
		RegAdminCmd(sCommandList[i], Command_GlowShortcut, ADMFLAG_CUSTOM1);
	}

	int names_array_size = sizeof(sColorName), colors_array_size = sizeof(COLOR_VALUE);
	numColors = names_array_size > colors_array_size ? colors_array_size : names_array_size;
}

native int LMC_GetClientOverlayModel(int iClient);

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("LMC_GetClientOverlayModel");
	if(GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;	
}

public void OnClientCookiesCached(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && !IsFakeClient(client))
	{
		char sValue[8];
		GetClientCookie(client, g_hGlowCookie, sValue, sizeof(sValue));
		if (sValue[0] != '\0')
		{
			glowscolor[client] = StringToInt(sValue);
		}
		else
		{
			glowscolor[client] = 0;
		}
		
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			int iOverlayModel = GetOverlayModelSafe(client);
			if (iOverlayModel > 0 && IsValidEntity(iOverlayModel))
			{
				ApplyGlow(iOverlayModel, glowscolor[client]);
			}
		}
	}
}

public void OnClientDisconnect(int client)
{
	glowscolor[client] = 0;
}

public void LMC_OnClientModelApplied(int iClient, int iEntity, const char[] sModel, bool bBaseReattach)
{
	ApplySavedGlow(iClient, iEntity);
}

public void LMC_OnClientModelChanged(int iClient, int iEntity, const char[] sModel)
{
	ApplySavedGlow(iClient, iEntity);
}

void ApplySavedGlow(int client, int entity)
{
	if (!IsValidClient(client) || entity <= 0 || !IsValidEntity(entity))
		return;

	int colorIndex = glowscolor[client];
	if (colorIndex >= 0 && colorIndex < numColors)
	{
		ApplyGlow(entity, colorIndex);
	}
}

public Action GlowColors(int client, int args)
{
	if (!IsValidClient(client) || GetClientTeam(client) != 2)
		return Plugin_Handled;

	Menu colors = new Menu(GlowColorCallback);
	colors.SetTitle("☢OverlayGlow Color Menu☢\n - %i colors -\n☣UKS☣", numColors);
	for(int i; i < numColors; i++) colors.AddItem("", sColorName[i]);
	colors.ExitButton = true;
	colors.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public void GlowColorCallback(Menu menu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if (IsValidClient(client))
			{
				SetClientGlowColor(client, item);
			}
		}
		case MenuAction_End: delete menu;
	}
}

void SetClientGlowColor(int client, int colorIndex)
{
	glowscolor[client] = colorIndex;
	
	if (AreClientCookiesCached(client) && !IsFakeClient(client))
	{
		char sValue[8];
		IntToString(colorIndex, sValue, sizeof(sValue));
		SetClientCookie(client, g_hGlowCookie, sValue);
	}
	
	int iOverlayModel = GetOverlayModelSafe(client);
	if (iOverlayModel > 0 && IsValidEntity(iOverlayModel))
	{
		ApplyGlow(iOverlayModel, colorIndex);
	}
}

void ApplyGlow(int entity, int colorIndex)
{
	if (colorIndex == 0)
	{
		SetEntProp(entity, Prop_Send, "m_iGlowType", 0);
	}
	else
	{
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", COLOR_VALUE[colorIndex]);
		SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
		SetEntProp(entity, Prop_Send, "m_nGlowRange", 99999);
		SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 0);
	}
}

int GetOverlayModelSafe(int client)
{
	if (GetFeatureStatus(FeatureType_Native, "LMC_GetClientOverlayModel") == FeatureStatus_Available)
	{
		return LMC_GetClientOverlayModel(client);
	}
	return -1;
}

public Action Command_GlowShortcut(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	char sCmd[32];
	GetCmdArg(0, sCmd, sizeof(sCmd));

	for (int i = 0; i < sizeof(sCommandList); i++)
	{
		if (strcmp(sCmd, sCommandList[i], false) == 0)
		{
			SetClientGlowColor(client, iCommandIndex[i]);
			break;
		}
	}
	return Plugin_Handled;
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}
