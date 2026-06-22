#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <clientprefs>

public Plugin myinfo = {
    name = "Glow Overlay",
    author = "NTLDR",
    description = "",
    version = "1.0",
    url = ""
};

char g_sColorNames[][] = {
    "Red", "Blue", "Green", "Yellow", "Purple", "Cyan", "Orange", "Pink", "White", "Rainbow"
};

char g_sColorRGBs[][] = {
    "255 0 0", "0 0 255", "0 255 0", "255 255 0", "128 0 128", "0 255 255", "255 165 0", "255 0 255", "255 255 255", "rainbow"
};

char g_sSelectedGlow[MAXPLAYERS + 1][32];
char g_sSelectedColor[MAXPLAYERS + 1][32];

bool g_bHasRainbowGlow[MAXPLAYERS + 1];
bool g_bHasRainbowColor[MAXPLAYERS + 1];

Cookie g_hGlowCookie;
Cookie g_hColorCookie;

public void OnPluginStart() {
    g_hGlowCookie = new Cookie("glow_overlay_glow", "Glow overlay glow settings", CookieAccess_Private);
    g_hColorCookie = new Cookie("glow_overlay_color", "Glow overlay color settings", CookieAccess_Private);

    RegConsoleCmd("sm_gomenu", Cmd_GoMenu, "Opens Glow Overlay Menu");

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_team", Event_PlayerTeam);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            if (AreClientCookiesCached(i)) {
                OnClientCookiesCached(i);
            }
        }
    }
}

public void OnClientCookiesCached(int client) {
    if (g_hGlowCookie != null) {
        g_hGlowCookie.Get(client, g_sSelectedGlow[client], 32);
    }
    if (g_hColorCookie != null) {
        g_hColorCookie.Get(client, g_sSelectedColor[client], 32);
    }
    ApplyGlowAndColor(client);
}

public void OnClientDisconnect(int client) {
    g_sSelectedGlow[client][0] = '\0';
    g_sSelectedColor[client][0] = '\0';
    g_bHasRainbowGlow[client] = false;
    g_bHasRainbowColor[client] = false;
}

public Action Cmd_GoMenu(int client, int args) {
    if (client <= 0 || !IsClientInGame(client)) {
        return Plugin_Handled;
    }
    OpenGoMenu(client);
    return Plugin_Handled;
}

void OpenGoMenu(int client) {
    Menu menu = new Menu(Menu_GoMain);
    menu.SetTitle("Glow Overlay Menu");
    menu.AddItem("glow", "Glow Settings");
    menu.AddItem("color", "Overlay Settings (Body Color)");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_GoMain(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        if (strcmp(info, "glow") == 0) {
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

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client)) {
        RequestFrame(Frame_ApplyGlowAndColor, GetClientUserId(client));
    }
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
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

void ApplyGlowAndColor(int client) {
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 2) {
        return;
    }

    // Apply Glow
    if (g_sSelectedGlow[client][0] != '\0') {
        if (strcmp(g_sSelectedGlow[client], "rainbow", false) == 0) {
            g_bHasRainbowGlow[client] = true;
        } else {
            g_bHasRainbowGlow[client] = false;
            int rgb[3];
            GetRGBFromString(g_sSelectedGlow[client], rgb);
            int glowColorInt = rgb[0] + (rgb[1] * 256) + (rgb[2] * 65536);
            SetEntProp(client, Prop_Send, "m_iGlowType", 3);
            SetEntProp(client, Prop_Send, "m_glowColorOverride", glowColorInt);
        }
    } else {
        g_bHasRainbowGlow[client] = false;
        SetEntProp(client, Prop_Send, "m_iGlowType", 0);
        SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
    }

    // Apply Body Color (Overlay)
    if (g_sSelectedColor[client][0] != '\0') {
        if (strcmp(g_sSelectedColor[client], "rainbow", false) == 0) {
            g_bHasRainbowColor[client] = true;
        } else {
            g_bHasRainbowColor[client] = false;
            int rgb[3];
            GetRGBFromString(g_sSelectedColor[client], rgb);
            SetEntityRenderMode(client, RENDER_TRANSCOLOR);
            SetEntityRenderColor(client, rgb[0], rgb[1], rgb[2], 255);
        }
    } else {
        g_bHasRainbowColor[client] = false;
        SetEntityRenderMode(client, RENDER_NORMAL);
        SetEntityRenderColor(client, 255, 255, 255, 255);
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client)) {
        return Plugin_Continue;
    }

    if (g_bHasRainbowGlow[client] || g_bHasRainbowColor[client]) {
        if (tickcount % 10 == 0) {
            if (g_bHasRainbowGlow[client]) {
                int rgb[3];
                GetRGBFromString("rainbow", rgb);
                int glowColorInt = rgb[0] + (rgb[1] * 256) + (rgb[2] * 65536);
                SetEntProp(client, Prop_Send, "m_iGlowType", 3);
                SetEntProp(client, Prop_Send, "m_glowColorOverride", glowColorInt);
            }
            if (g_bHasRainbowColor[client]) {
                int rgb[3];
                GetRGBFromString("rainbow", rgb);
                SetEntityRenderMode(client, RENDER_TRANSCOLOR);
                SetEntityRenderColor(client, rgb[0], rgb[1], rgb[2], 255);
            }
        }
    }

    return Plugin_Continue;
}

void GetRGBFromString(const char[] colorStr, int rgb[3]) {
    if (strcmp(colorStr, "rainbow", false) == 0) {
        float time = GetEngineTime();
        rgb[0] = RoundToNearest(Sine(time) * 127.5 + 127.5);
        rgb[1] = RoundToNearest(Sine(time + 2.094) * 127.5 + 127.5);
        rgb[2] = RoundToNearest(Sine(time + 4.188) * 127.5 + 127.5);
    } else {
        char parts[3][4];
        if (ExplodeString(colorStr, " ", parts, 3, 4) == 3) {
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