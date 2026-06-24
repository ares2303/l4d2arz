#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#if !defined _LMCCore_included
native int LMC_GetClientOverlayModel(int iClient);
#endif

public Plugin myinfo = {
    name = "Glow Overlay (Dynamic AFK Fixed - LMC Compatible)",
    author = "NTLDR",
    description = "Mengunci glow dan warna body player agar tidak hilang, 100% bekerja saat AFK",
    version = "2.5",
    url = ""
};

char g_sColorNames[][] = {
    "Green", "Blue", "Violet", "Cyan", "Orange", "Red", "Gray", "Yellow", "Lime", "Maroon", "Teal", "Pink", "Purple", "White", "Golden", "Rainbow"
};

char g_sColorRGBs[][] = {
    "0 255 0", "7 19 250", "249 19 250", "66 250 250", "255 90 0", "255 0 0", "50 50 50", "255 255 0", "128 255 0", "128 0 0", "0 128 128", "168 126 255", "155 0 255", "255 255 255", "255 155 0", "rainbow"
};

char g_sSelectedGlow[MAXPLAYERS + 1][32];
char g_sSelectedColor[MAXPLAYERS + 1][32];
int g_sUseRank[MAXPLAYERS + 1];

Cookie g_hGlowCookie;
Cookie g_hColorCookie;
Cookie g_hUseRankCookie;
bool g_bLmcAvailable = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    MarkNativeAsOptional("LMC_GetClientOverlayModel");
    return APLRes_Success;
}

public void OnPluginStart() {
    g_hGlowCookie = new Cookie("glow_overlay_glow", "Glow overlay glow settings", CookieAccess_Private);
    g_hColorCookie = new Cookie("glow_overlay_color", "Glow overlay color settings", CookieAccess_Private);
    g_hUseRankCookie = new Cookie("glow_overlay_use_rank", "Use rank colors settings", CookieAccess_Private);

    RegAdminCmd("sm_gomenu", Cmd_GoMenu, ADMFLAG_CUSTOM1, "Opens Glow Overlay Menu");
    RegAdminCmd("sm_gcolor", Cmd_GoMenu, ADMFLAG_CUSTOM1, "Opens Glow Overlay Menu");
    
    // Perintah baru untuk penyegaran manual oleh sistem / SCS
    RegAdminCmd("sm_refresh_glow_overlay", Cmd_RefreshGlowOverlay, ADMFLAG_CUSTOM1, "Refreshes client glow and color overlay");

    RegAdminCmd("sm_grg", Command_RG, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_crg", Command_CRG, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gwhite", Command_WHITE, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_ggreen", Command_GREEN, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gred", Command_RED, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gblue", Command_BLUE, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_ggold", Command_GOLD, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gcyan", Command_CYAN, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gviolet", Command_VIOLET, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gmar", Command_MAROON, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_glima", Command_LIME, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gyellow", Command_YELLOW, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gtea", Command_TEAL, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gpink", Command_PINK, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gpurple", Command_PURPLE, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_gorange", Command_ORANGE, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_grainbow", Command_RAINBOW, ADMFLAG_CUSTOM1);

    RegAdminCmd("sm_cwhite", Command_CWHITE, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_cgreen", Command_CGREEN, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_cred", Command_CRED, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_cblue", Command_CBLUE, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_cgold", Command_CGOLD, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_ccyan", Command_CCYAN, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_cviolet", Command_CVIOLET, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_cmar", Command_CMAROON, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_clima", Command_CLIME, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_cyellow", Command_CYELLOW, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_ctea", Command_CTEAL, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_cpink", Command_CPINK, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_cpurple", Command_CPURPLE, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_corange", Command_CORANGE, ADMFLAG_CUSTOM1);
    RegAdminCmd("sm_crainbow", Command_CRAINBOW, ADMFLAG_CUSTOM1);

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_team", Event_PlayerTeam);
    HookEvent("player_use", Event_PlayerUse);
    HookEvent("heal_begin", Event_HealBegin);
    HookEvent("heal_success", Event_HealSuccess);
    HookEvent("heal_end", Event_HealEnd);
    HookEvent("survivor_rescued", Event_SurvivorRescued);
    HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
    HookEvent("player_left_checkpoint", Event_PlayerLeftCheckpoint);
    HookEvent("defibrillator_used", Event_DefibrillatorUsed);
    HookEvent("player_bot_replace", Event_PlayerBotReplace);
    HookEvent("bot_player_replace", Event_BotPlayerReplace);
    HookEvent("revive_success", Event_ReviveSuccess);

    CreateTimer(0.1, Timer_UpdateVisuals, _, TIMER_REPEAT);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            if (AreClientCookiesCached(i)) {
                OnClientCookiesCached(i);
            }
        }
    }
}

public void OnAllPluginsLoaded() {
    g_bLmcAvailable = LibraryExists("LMCCore") || LibraryExists("L4D2ModelChanger");
}

public void OnLibraryAdded(const char[] name) {
    if (strcmp(name, "LMCCore") == 0 || strcmp(name, "L4D2ModelChanger") == 0) {
        g_bLmcAvailable = true;
    }
}

public void OnLibraryRemoved(const char[] name) {
    if (strcmp(name, "LMCCore") == 0 || strcmp(name, "L4D2ModelChanger") == 0) {
        g_bLmcAvailable = false;
    }
}

public void OnClientCookiesCached(int client) {
    if (g_hGlowCookie != null) {
        g_hGlowCookie.Get(client, g_sSelectedGlow[client], 32);
    }
    if (g_hColorCookie != null) {
        g_hColorCookie.Get(client, g_sSelectedColor[client], 32);
    }
    
    char sRank[4];
    if (g_hUseRankCookie != null) {
        g_hUseRankCookie.Get(client, sRank, sizeof(sRank));
        if (sRank[0] == '\0') {
            g_sUseRank[client] = 1;
        } else {
            g_sUseRank[client] = StringToInt(sRank);
        }
    }
    RequestApplyGlow(client);
    if (g_sUseRank[client] == 1) {
        ServerCommand("sm_refresh_rank_color %d", GetClientUserId(client));
    }
}

public void OnClientDisconnect(int client) {
    g_sSelectedGlow[client][0] = '\0';
    g_sSelectedColor[client][0] = '\0';
    g_sUseRank[client] = 1;
}

bool CanUserHaveGlow(int client) {
    if (!IsClientInGame(client)) {
        return false;
    }
    AdminId admin = GetUserAdmin(client);
    if (admin == INVALID_ADMIN_ID) {
        return false;
    }
    return GetAdminFlag(admin, Admin_Custom1) || GetAdminFlag(admin, Admin_Root);
}

int GetClientOfIdleClient(int bot) {
    if (HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID")) {
        int userid = GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID");
        if (userid > 0) {
            int owner = GetClientOfUserId(userid);
            if (owner > 0 && IsClientInGame(owner)) {
                return owner;
            }
        }
    }
    return 0;
}

int GetGlowTarget(int client) {
    if (g_bLmcAvailable) {
        int overlay = LMC_GetClientOverlayModel(client);
        if (overlay > MaxClients) {
            return overlay;
        }
    }
    return client;
}

int GetColorTarget(int client) {
    if (g_bLmcAvailable) {
        int overlay = LMC_GetClientOverlayModel(client);
        if (overlay > MaxClients) {
            return overlay;
        }
    }
    return client;
}

void RequestApplyGlow(int client) {
    if (client > 0 && IsClientInGame(client)) {
        RequestFrame(Frame_ApplyGlowAndColor, GetClientUserId(client));
    }
}

void Frame_ApplyGlowAndColor(any userid) {
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client)) {
        ApplyGlowAndColor(client);
    }
}

public Action Timer_ApplyGlow(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client)) {
        ApplyGlowAndColor(client);
    }
    return Plugin_Handled;
}

public void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast) {
    int bot = GetClientOfUserId(event.GetInt("bot"));
    if (bot > 0 && IsClientInGame(bot)) {
        CreateTimer(0.1, Timer_ApplyGlow, GetClientUserId(bot), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast) {
    int player = GetClientOfUserId(event.GetInt("player"));
    int bot = GetClientOfUserId(event.GetInt("bot"));
    
    if (bot > 0 && IsClientInGame(bot)) {
        int glowEnt = GetGlowTarget(bot);
        SetEntProp(glowEnt, Prop_Send, "m_iGlowType", 0);
        SetEntProp(glowEnt, Prop_Send, "m_glowColorOverride", 0);
        
        int colorEnt = GetColorTarget(bot);
        SetEntityRenderMode(colorEnt, RENDER_NORMAL);
        SetEntityRenderColor(colorEnt, 255, 255, 255, 255);
        
        if (glowEnt != bot) {
            SetEntProp(bot, Prop_Send, "m_iGlowType", 0);
            SetEntProp(bot, Prop_Send, "m_glowColorOverride", 0);
        }
    }

    if (player > 0 && IsClientInGame(player)) {
        CreateTimer(0.1, Timer_ApplyGlow, GetClientUserId(player), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void LMC_OnClientModelApplied(int client, int entity, const char model[PLATFORM_MAX_PATH], bool baseReattach) {
    if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 2) {
        ApplyGlowAndColor(client);
    }
}

public void LMC_OnClientModelDestroyed(int client, int entity) {
    if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 2) {
        ApplyGlowAndColor(client);
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_PlayerUse(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_HealBegin(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("userid")));
    RequestApplyGlow(GetClientOfUserId(event.GetInt("subject")));
}

public void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("health_restored")));
    RequestApplyGlow(GetClientOfUserId(event.GetInt("subject")));
}

public void Event_HealEnd(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_SurvivorRescued(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("victim")));
}

public void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_PlayerLeftCheckpoint(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("subject")));
}

public Action Cmd_GoMenu(int client, int args) {
    if (client <= 0 || !IsClientInGame(client)) {
        return Plugin_Handled;
    }
    if (!CanUserHaveGlow(client)) {
        PrintToChat(client, "\x04[Glow Overlay] \x01You do not have access to this menu.");
        return Plugin_Handled;
    }
    OpenGoMenu(client);
    return Plugin_Handled;
}

void OpenGoMenu(int client) {
    Menu menu = new Menu(Menu_GoMain);
    menu.SetTitle("Glow Overlay Menu");
    
    char rankStatus[32];
    if (g_sUseRank[client] == 1) {
        Format(rankStatus, sizeof(rankStatus), "Rank Color: [ON]");
    } else {
        Format(rankStatus, sizeof(rankStatus), "Rank Color: [OFF]");
    }
    menu.AddItem("toggle_rank", rankStatus);
    
    menu.AddItem("glow", "Glow Settings");
    menu.AddItem("color", "Overlay Settings (Body Color)");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_GoMain(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        if (strcmp(info, "toggle_rank") == 0 || param2 == 0) {
            if (g_sUseRank[param1] == 1) {
                g_sUseRank[param1] = 0;
                g_hUseRankCookie.Set(param1, "0");
                PrintToChat(param1, "\x04[Glow Overlay] \x01Rank Color disabled. Custom selection active.");
            } else {
                g_sUseRank[param1] = 1;
                g_hUseRankCookie.Set(param1, "1");
                PrintToChat(param1, "\x04[Glow Overlay] \x01Rank Color enabled.");
                
                int targetEnt = param1;
                if (GetClientTeam(param1) != 2) {
                    for (int i = 1; i <= MaxClients; i++) {
                        if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2) {
                            if (GetClientOfIdleClient(i) == param1) {
                                targetEnt = i;
                                break;
                            }
                        }
                    }
                }
                int colorEnt = GetColorTarget(targetEnt);
                SetEntityRenderMode(colorEnt, RENDER_NORMAL);
                SetEntityRenderColor(colorEnt, 255, 255, 255, 255);
                
                ServerCommand("sm_refresh_rank_color %d", GetClientUserId(param1));
            }
            ApplyGlowAndColor(param1);
            OpenGoMenu(param1);
        } else if (strcmp(info, "glow") == 0) {
            OpenGlowMenu(param1);
        } else if (strcmp(info, "color") == 0) {
            OpenColorMenu(param1);
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void OpenGlowMenu(int client) {
    Menu menu = new Menu(Menu_Glow);
    menu.SetTitle("Glow Settings");
    menu.AddItem("none", "Disable Glow");
    for (int i = 0; i < sizeof(g_sColorNames); i++) {
        menu.AddItem(g_sColorRGBs[i], g_sColorNames[i]);
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Glow(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        if (strcmp(info, "none") == 0) {
            g_sSelectedGlow[param1][0] = '\0';
            if (g_hGlowCookie != null) {
                g_hGlowCookie.Set(param1, "");
            }
            PrintToChat(param1, "\x04[Glow Overlay] \x01Glow disabled.");
        } else {
            g_sUseRank[param1] = 0;
            g_hUseRankCookie.Set(param1, "0");
            strcopy(g_sSelectedGlow[param1], 32, info);
            if (g_hGlowCookie != null) {
                g_hGlowCookie.Set(param1, info);
            }
            PrintToChat(param1, "\x04[Glow Overlay] \x01Glow color updated!");
        }
        ApplyGlowAndColor(param1);
        OpenGlowMenu(param1);
    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        OpenGoMenu(param1);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void OpenColorMenu(int client) {
    Menu menu = new Menu(Menu_Color);
    menu.SetTitle("Overlay Settings (Body Color)");
    menu.AddItem("none", "Disable Body Color");
    for (int i = 0; i < sizeof(g_sColorNames); i++) {
        menu.AddItem(g_sColorRGBs[i], g_sColorNames[i]);
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Color(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        if (strcmp(info, "none") == 0) {
            g_sSelectedColor[param1][0] = '\0';
            if (g_hColorCookie != null) {
                g_hColorCookie.Set(param1, "");
            }
            PrintToChat(param1, "\x04[Glow Overlay] \x01Body Color disabled.");
        } else {
            g_sUseRank[param1] = 0;
            g_hUseRankCookie.Set(param1, "0");
            strcopy(g_sSelectedColor[param1], 32, info);
            if (g_hColorCookie != null) {
                g_hColorCookie.Set(param1, info);
            }
            PrintToChat(param1, "\x04[Glow Overlay] \x01Body Color updated!");
        }
        ApplyGlowAndColor(param1);
        OpenColorMenu(param1);
    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        OpenGoMenu(param1);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ApplyGlowAndColor(int client) {
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 2) return;

    int target = client;
    if (IsFakeClient(client)) {
        target = GetClientOfIdleClient(client);
        if (target <= 0 || !IsClientInGame(target)) {
            int glowEnt = GetGlowTarget(client);
            SetEntProp(glowEnt, Prop_Send, "m_iGlowType", 0);
            SetEntProp(glowEnt, Prop_Send, "m_glowColorOverride", 0);
            
            int colorEnt = GetColorTarget(client);
            SetEntityRenderMode(colorEnt, RENDER_NORMAL);
            SetEntityRenderColor(colorEnt, 255, 255, 255, 255);
            
            if (glowEnt != client) {
                SetEntProp(client, Prop_Send, "m_iGlowType", 0);
                SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
            }
            return;
        }
    }

    int glowEnt = GetGlowTarget(client);
    if (!CanUserHaveGlow(target)) {
        SetEntProp(glowEnt, Prop_Send, "m_iGlowType", 0);
        SetEntProp(glowEnt, Prop_Send, "m_glowColorOverride", 0);
        if (glowEnt != client) {
            SetEntProp(client, Prop_Send, "m_iGlowType", 0);
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
        }
    } else {
        if (g_sSelectedGlow[target][0] != '\0' && strcmp(g_sSelectedGlow[target], "rainbow", false) != 0) {
            int rgb[3];
            GetRGBFromString(g_sSelectedGlow[target], rgb);
            int glowColorInt = rgb[0] + (rgb[1] * 256) + (rgb[2] * 65536);
            SetEntProp(glowEnt, Prop_Send, "m_iGlowType", 3);
            SetEntProp(glowEnt, Prop_Send, "m_glowColorOverride", glowColorInt);
            SetEntProp(glowEnt, Prop_Send, "m_nGlowRange", 99999); 
            SetEntProp(glowEnt, Prop_Send, "m_nGlowRangeMin", 0);  
            
            if (glowEnt != client) {
                SetEntProp(client, Prop_Send, "m_iGlowType", 0);
                SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
            }
        } else if (g_sSelectedGlow[target][0] == '\0') {
            SetEntProp(glowEnt, Prop_Send, "m_iGlowType", 0);
            SetEntProp(glowEnt, Prop_Send, "m_glowColorOverride", 0);
            if (glowEnt != client) {
                SetEntProp(client, Prop_Send, "m_iGlowType", 0);
                SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
            }
        }
    }

    int colorEnt = GetColorTarget(client);
    if (g_sUseRank[target] == 1) {
        return;
    }

    if (g_sSelectedColor[target][0] != '\0' && strcmp(g_sSelectedColor[target], "rainbow", false) != 0) {
        int rgb[3];
        GetRGBFromString(g_sSelectedColor[target], rgb);
        SetEntityRenderMode(colorEnt, RENDER_TRANSCOLOR);
        SetEntityRenderColor(colorEnt, rgb[0], rgb[1], rgb[2], 255);
    } else if (g_sSelectedColor[target][0] == '\0') {
        SetEntityRenderMode(colorEnt, RENDER_NORMAL);
        SetEntityRenderColor(colorEnt, 255, 255, 255, 255);
    }
}

public Action Timer_UpdateVisuals(Handle timer) {
    static int tickCounter = 0;
    tickCounter++;

    float time = GetEngineTime();
    int rgb[3];
    rgb[0] = RoundToNearest(Sine(time) * 127.5 + 127.5);
    rgb[1] = RoundToNearest(Sine(time + 2.094) * 127.5 + 127.5);
    rgb[2] = RoundToNearest(Sine(time + 4.188) * 127.5 + 127.5);
    int rainbowGlowInt = rgb[0] + (rgb[1] * 256) + (rgb[2] * 65536);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2) {
            int target = i;
            if (IsFakeClient(i)) {
                target = GetClientOfIdleClient(i);
                if (target <= 0 || !IsClientInGame(target)) continue;
            }

            if (!CanUserHaveGlow(target)) continue;

            int glowEnt = GetGlowTarget(i);
            int colorEnt = GetColorTarget(i);

            if (strcmp(g_sSelectedGlow[target], "rainbow", false) == 0) {
                SetEntProp(glowEnt, Prop_Send, "m_iGlowType", 3);
                SetEntProp(glowEnt, Prop_Send, "m_glowColorOverride", rainbowGlowInt);
                SetEntProp(glowEnt, Prop_Send, "m_nGlowRange", 99999);
                SetEntProp(glowEnt, Prop_Send, "m_nGlowRangeMin", 0);
                
                if (glowEnt != i) {
                    SetEntProp(i, Prop_Send, "m_iGlowType", 0);
                    SetEntProp(i, Prop_Send, "m_glowColorOverride", 0);
                }
            }

            if (g_sUseRank[target] == 0) {
                if (strcmp(g_sSelectedColor[target], "rainbow", false) == 0) {
                    SetEntityRenderMode(colorEnt, RENDER_TRANSCOLOR);
                    SetEntityRenderColor(colorEnt, rgb[0], rgb[1], rgb[2], 255);
                }
            }

            if (tickCounter >= 10) {
                ApplyGlowAndColor(i);
            }
        }
    }

    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "survivor_death_model")) != -1) {
        int client = GetSurvivorFromDeathModel(entity);
        if (client > 0 && IsClientInGame(client)) {
            int target = client;
            if (IsFakeClient(client)) {
                target = GetClientOfIdleClient(client);
            }

            if (target > 0 && IsClientInGame(target)) {
                if (CanUserHaveGlow(target)) {
                    if (strcmp(g_sSelectedGlow[target], "rainbow", false) == 0) {
                        SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
                        SetEntProp(entity, Prop_Send, "m_glowColorOverride", rainbowGlowInt);
                        SetEntProp(entity, Prop_Send, "m_nGlowRange", 99999);
                        SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 0);
                    }

                    if (g_sUseRank[target] == 0) {
                        if (strcmp(g_sSelectedColor[target], "rainbow", false) == 0) {
                            SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
                            SetEntityRenderColor(entity, rgb[0], rgb[1], rgb[2], 255);
                        }
                    }
                }
            }
        }
    }
    
    if (tickCounter >= 10) tickCounter = 0;
    return Plugin_Continue;
}

void SetGlowShortcut(int client, const char[] rgb) {
    g_sUseRank[client] = 0;
    g_hUseRankCookie.Set(client, "0");
    strcopy(g_sSelectedGlow[client], 32, rgb);
    if (g_hGlowCookie != null) {
        g_hGlowCookie.Set(client, rgb);
    }
    
    if (GetClientTeam(client) != 2) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2) {
                if (GetClientOfIdleClient(i) == client) {
                    ApplyGlowAndColor(i);
                    return;
                }
            }
        }
    } else {
        ApplyGlowAndColor(client);
    }
}

void SetColorShortcut(int client, const char[] rgb) {
    g_sUseRank[client] = 0;
    g_hUseRankCookie.Set(client, "0");
    strcopy(g_sSelectedColor[client], 32, rgb);
    if (g_hColorCookie != null) {
        g_hColorCookie.Set(client, rgb);
    }
    
    if (GetClientTeam(client) != 2) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2) {
                if (GetClientOfIdleClient(i) == client) {
                    ApplyGlowAndColor(i);
                    return;
                }
            }
        }
    } else {
        ApplyGlowAndColor(client);
    }
}

// Callback perintah penyegaran manual dari system / console server
public Action Cmd_RefreshGlowOverlay(int client, int args) {
    if (args < 1) return Plugin_Handled;
    char arg[16];
    GetCmdArg(1, arg, sizeof(arg));
    int target = GetClientOfUserId(StringToInt(arg));
    if (target > 0 && IsClientInGame(target)) {
        RequestApplyGlow(target);
    }
    return Plugin_Handled;
}

public Action Command_RG(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow disabled.");
    }
    return Plugin_Handled;
}

public Action Command_CRG(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        g_sSelectedColor[client][0] = '\0';
        if (g_hColorCookie != null) {
            g_hColorCookie.Set(client, "");
        }
        ApplyGlowAndColor(client);
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color disabled.");
    }
    return Plugin_Handled;
}

public Action Command_WHITE(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "255 255 255");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to White!");
    }
    return Plugin_Handled;
}

public Action Command_GREEN(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "0 255 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Green!");
    }
    return Plugin_Handled;
}

public Action Command_RED(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "255 0 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Red!");
    }
    return Plugin_Handled;
}

public Action Command_BLUE(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "7 19 250");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Blue!");
    }
    return Plugin_Handled;
}

public Action Command_GOLD(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "255 155 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Gold!");
    }
    return Plugin_Handled;
}

public Action Command_CYAN(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "66 250 250");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Cyan!");
    }
    return Plugin_Handled;
}

public Action Command_VIOLET(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "249 19 250");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Violet!");
    }
    return Plugin_Handled;
}

public Action Command_MAROON(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "128 0 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Maroon!");
    }
    return Plugin_Handled;
}

public Action Command_LIME(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "128 255 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Lime!");
    }
    return Plugin_Handled;
}

public Action Command_YELLOW(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "255 255 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Yellow!");
    }
    return Plugin_Handled;
}

public Action Command_TEAL(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "0 128 128");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Teal!");
    }
    return Plugin_Handled;
}

public Action Command_PINK(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "168 126 255");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Pink!");
    }
    return Plugin_Handled;
}

public Action Command_PURPLE(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "155 0 255");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Purple!");
    }
    return Plugin_Handled;
}

public Action Command_ORANGE(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "255 90 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Orange!");
    }
    return Plugin_Handled;
}

public Action Command_RAINBOW(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetGlowShortcut(client, "rainbow");
        PrintToChat(client, "\x04[Glow Overlay] \x01Glow set to Rainbow!");
    }
    return Plugin_Handled;
}

public Action Command_CWHITE(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "255 255 255");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to White!");
    }
    return Plugin_Handled;
}

public Action Command_CGREEN(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "0 255 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Green!");
    }
    return Plugin_Handled;
}

public Action Command_CRED(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "255 0 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Red!");
    }
    return Plugin_Handled;
}

public Action Command_CBLUE(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "7 19 250");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Blue!");
    }
    return Plugin_Handled;
}

public Action Command_CGOLD(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "255 155 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Gold!");
    }
    return Plugin_Handled;
}

public Action Command_CCYAN(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "66 250 250");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Cyan!");
    }
    return Plugin_Handled;
}

public Action Command_CVIOLET(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "249 19 250");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Violet!");
    }
    return Plugin_Handled;
}

public Action Command_CMAROON(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "128 0 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Maroon!");
    }
    return Plugin_Handled;
}

public Action Command_CLIME(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "128 255 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Lime!");
    }
    return Plugin_Handled;
}

public Action Command_CYELLOW(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "255 255 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Yellow!");
    }
    return Plugin_Handled;
}

public Action Command_CTEAL(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "0 128 128");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Teal!");
    }
    return Plugin_Handled;
}

public Action Command_CPINK(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "168 126 255");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Pink!");
    }
    return Plugin_Handled;
}

public Action Command_CPURPLE(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "155 0 255");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Purple!");
    }
    return Plugin_Handled;
}

public Action Command_CORANGE(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "255 90 0");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Orange!");
    }
    return Plugin_Handled;
}

public Action Command_CRAINBOW(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        SetColorShortcut(client, "rainbow");
        PrintToChat(client, "\x04[Glow Overlay] \x01Body Color set to Rainbow!");
    }
    return Plugin_Handled;
}

void GetRGBFromString(const char[] colorStr, int rgb[3]) {
    if (strcmp(colorStr, "rainbow", false) == 0) {
        float time = GetEngineTime();
        rgb[0] = RoundToNearest(Sine(time) * 127.5 + 127.5);
        rgb[1] = RoundToNearest(Sine(time + 2.094) * 127.5 + 127.5);
        rgb[2] = RoundToNearest(Sine(time + 4.188) * 127.5 + 127.5);
    } else {
        char parts[3][16];
        if (ExplodeString(colorStr, " ", parts, 3, 16) == 3) {
            rgb[0] = StringToInt(parts[0]);
            rgb[1] = StringToInt(parts[1]);
            rgb[2] = StringToInt(parts[2]);
        } else {
            rgb[0] = 255;
            rgb[1] = 255;
            rgb[2] = 255;
        }
    }
}

public void OnEntityCreated(int entity, const char[] classname) {
    if (strcmp(classname, "survivor_death_model", false) == 0) {
        RequestFrame(Frame_ApplyDeathModelGlow, EntIndexToEntRef(entity));
    }
}

void Frame_ApplyDeathModelGlow(any entRef) {
    int entity = EntRefToEntIndex(entRef);
    if (entity > 0 && IsValidEntity(entity)) {
        int client = GetSurvivorFromDeathModel(entity);
        if (client > 0 && IsClientInGame(client)) {
            int target = client;
            if (IsFakeClient(client)) {
                target = GetClientOfIdleClient(client);
            }
            
            if (target > 0 && IsClientInGame(target)) {
                if (CanUserHaveGlow(target)) {
                    if (g_sSelectedGlow[target][0] != '\0') {
                        if (strcmp(g_sSelectedGlow[target], "rainbow", false) == 0) {
                            SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
                            SetEntProp(entity, Prop_Send, "m_glowColorOverride", 0);
                            SetEntProp(entity, Prop_Send, "m_nGlowRange", 99999);
                            SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 0);
                        } else {
                            int rgb[3];
                            GetRGBFromString(g_sSelectedGlow[target], rgb);
                            int glowColorInt = rgb[0] + (rgb[1] * 256) + (rgb[2] * 65536);
                            SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
                            SetEntProp(entity, Prop_Send, "m_glowColorOverride", glowColorInt);
                            SetEntProp(entity, Prop_Send, "m_nGlowRange", 99999);
                            SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 0);
                        }
                    }
                    
                    if (g_sUseRank[target] == 0) {
                        if (g_sSelectedColor[target][0] != '\0') {
                            if (strcmp(g_sSelectedColor[target], "rainbow", false) == 0) {
                                SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
                                SetEntityRenderColor(entity, 255, 255, 255, 255);
                            } else {
                                int rgb[3];
                                GetRGBFromString(g_sSelectedColor[target], rgb);
                                SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
                                SetEntityRenderColor(entity, rgb[0], rgb[1], rgb[2], 255);
                            }
                        }
                    }
                }
            }
        }
    }
}

int GetSurvivorFromDeathModel(int iEntity) {
    int iTargetChar = GetEntProp(iEntity, Prop_Send, "m_nCharacterType");
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || GetClientTeam(i) != 2) {
            continue;
        }
        if (iTargetChar == GetEntProp(i, Prop_Send, "m_survivorCharacter")) {
            return i;
        }
    }
    return 0;
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast) {
    RequestApplyGlow(GetClientOfUserId(event.GetInt("subject")));
}
