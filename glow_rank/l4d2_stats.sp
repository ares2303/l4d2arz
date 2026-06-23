#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <geoip>
#include <socket>
#include <clientprefs>
#include <adminmenu>
#pragma newdecls required

stock bool Safe_IsClientInGame(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock bool Safe_IsClientConnected(int client)
{
	return (client > 0 && client <= MaxClients && IsClientConnected(client));
}

stock bool Safe_IsPlayerAlive(int client)
{
	return (client > 0 && client <= MaxClients && IsPlayerAlive(client));
}

stock bool Safe_IsFakeClient(int client)
{
	return (client > 0 && client <= MaxClients && IsFakeClient(client));
}

#define IsClientInGame(%1) Safe_IsClientInGame(%1)
#define IsClientConnected(%1) Safe_IsClientConnected(%1)
#define IsPlayerAlive(%1) Safe_IsPlayerAlive(%1)
#define IsFakeClient(%1) Safe_IsFakeClient(%1)

native int LMC_GetClientOverlayModel(int iClient);
static bool g_bLmcActive = false;
Handle g_hUseRankCookie = null;

#define PLUGIN_VERSION "2.1"
#define PLUGIN_AUTHOR "Emilio3"
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3
#define ZC_ZOMBIE 0
#define ZC_SMOKER 1
#define ZC_BOOMER 2
#define ZC_HUNTER 3
#define ZC_SPITTER 4
#define ZC_JOCKEY 5
#define ZC_CHARGER 6
#define ZC_WITCH 7
#define ZC_TANK 8
#define L4D_MINPLAYERS	4
#define L4D_MAXPLAYERS	32
#define MAX_LINE_WIDTH 64
#define STATS "l4dstats"

float RDifficultyMultiplier = 1.0, DamageBody[10], DamageHeadshot[9], MapTimingStartTime = -1.0, rank_sum;

bool l4d2_plugin_loot = true, l4d2_plugin_monsterbots = true, extra_charger = false, autodifficulty_calculated = false,
IsTimeAutodifficulty, IsMapFinished, IsPrint, IsRoundStarted, g_Socket[MAXPLAYERS + 1], g_HaveSteam[MAXPLAYERS + 1], g_IsTimeAutodifficulty;

ConVar hm_autodifficulty, hm_autodifficulty_forcehp, z_difficulty, z_special_spawn_interval,
director_special_respawn_interval, z_max_player_zombies;

ConVar hm_auto_tongue_range_min, hm_auto_tongue_range_max, hm_auto_tongue_miss_delay_min, hm_auto_tongue_miss_delay_max, hm_auto_tongue_hit_delay_min,
hm_auto_tongue_hit_delay_max, hm_auto_tongue_choke_dmg_min, hm_auto_tongue_choke_dmg_max, hm_auto_tongue_drag_dmg_min, hm_auto_tongue_drag_dmg_max,
hm_auto_smoker_pz_claw_dmg_min, hm_auto_smoker_pz_claw_dmg_max, hm_auto_jockey_pz_claw_dmg_min, hm_auto_jockey_pz_claw_dmg_max, hm_auto_grenade_lr_dmg_min,
hm_auto_grenade_lr_dmg_max;

ConVar damage_type, hm_damage_ak47_min, hm_damage_ak47_max, hm_damage_awp_min, hm_damage_awp_max, hm_damage_m60_min, hm_damage_m60_max, hm_damage_scout_min,
hm_damage_scout_max, hm_damage_sg552_min, hm_damage_sg552_max, hm_damage_spas_min, hm_damage_spas_max, hm_damage_sniper_military_min, hm_damage_sniper_military_max,
hm_damage2_ak47_min, hm_damage2_ak47_max, hm_damage2_awp_min, hm_damage2_awp_max, hm_damage2_m60_min, hm_damage2_m60_max, hm_damage2_scout_min,
hm_damage2_scout_max, hm_damage2_sg552_min, hm_damage2_sg552_max, hm_damage2_spas_min, hm_damage2_spas_max, hm_damage2_sniper_military_min, hm_damage2_sniper_military_max;

ConVar hm_meleefix_min, hm_meleefix_max, hm_meleefix_headshot_min, hm_meleefix_headshot_max, hm_meleefix_tank_min, hm_meleefix_tank_max, hm_meleefix_tank_headshot_min,
hm_meleefix_tank_headshot_max, hm_meleefix_witch_min, hm_meleefix_witch_max;

ConVar hm_loot_mod, hm_tank_hp_mod, hm_infected_hp_mod, hm_spawn_time_mod, hm_spawn_count_mod, hm_special_infected_min, hm_special_infected_max,
hm_spawn_interval_min, hm_spawn_interval_max, hm_tank_burn_duration_min, hm_tank_burn_duration_max;

ConVar hm_autohp_automod, hm_autohp_supercharger_auto, hm_autohp_zombie_min, hm_autohp_zombie_max, hm_autohp_hunter_min, hm_autohp_hunter_max,
hm_autohp_smoker_min, hm_autohp_smoker_max, hm_autohp_boomer_min, hm_autohp_boomer_max, hm_autohp_jockey_min, hm_autohp_jockey_max,
hm_autohp_charger_min, hm_autohp_charger_max, hm_autohp_spitter_min, hm_autohp_spitter_max, hm_autohp_witch_min, hm_autohp_witch_max,
hm_autohp_tank_min, hm_autohp_tank_max;

ConVar hm_items_automod, hm_items_supercharger_auto, hm_items_hunter_min, hm_items_hunter_max, hm_items_smoker_min, hm_items_smoker_max,
hm_items_boomer_min, hm_items_boomer_max, hm_items_jockey_min, hm_items_jockey_max, hm_items_charger_min, hm_items_charger_max,
hm_items_spitter_min, hm_items_spitter_max, hm_items_tank_min, hm_items_tank_max;

ConVar hm_spawn_automod, hm_spawn_zombie_min, hm_spawn_zombie_max, hm_spawn_hunter_min, hm_spawn_hunter_max, hm_spawn_smoker_min,
hm_spawn_smoker_max, hm_spawn_boomer_min, hm_spawn_boomer_max, hm_spawn_jockey_min, hm_spawn_jockey_max, hm_spawn_charger_min,
hm_spawn_charger_max, hm_spawn_spitter_min, hm_spawn_spitter_max;

ConVar hm_speed_automod, hm_speed_hunter_min, hm_speed_hunter_max, hm_speed_smoker_min, hm_speed_smoker_max, hm_speed_boomer_min,
hm_speed_boomer_max, hm_speed_jockey_min, hm_speed_jockey_max, hm_speed_charger_min, hm_speed_charger_max, hm_speed_spitter_min,
hm_speed_spitter_max, hm_speed_tank_min, hm_speed_tank_max;

ConVar MeleeDmg[10], MeleeHeadshotDmg[9], hm_damage, hm_damage_friendly, hm_damage_showvalue, hm_damage_type;

ConVar hm_damage_hunter, hm_damage_smoker, hm_damage_boomer, hm_damage_spitter1, hm_damage_spitter2, hm_damage_jockey,
hm_damage_charger, hm_damage_tank, hm_damage_tankrock, hm_damage_common;

ConVar hm_damage_ak47, hm_damage_awp, hm_damage_scout, hm_damage_m60, hm_damage_pipebomb, hm_damage_spas, hm_damage_sg552,
hm_damage_smg, hm_damage_smg_silenced, hm_damage_m16, hm_damage_pumpshotgun, hm_damage_autoshotgun, hm_damage_hunting_rifle,
hm_damage_rifle_desert, hm_damage_shotgun_chrome, hm_damage_smg_mp5, hm_damage_sniper_military, hm_damage_pistol, hm_damage_pistol_magnum;

ConVar hm_damage2_ak47, hm_damage2_awp, hm_damage2_scout, hm_damage2_m60, hm_damage2_spas, hm_damage2_sg552, hm_damage2_sniper_military;

ConVar hm_count_fails, hm_stats_colors, hm_stats_bot_colors, l4d2_rankmod_mode, l4d2_rankmod_min, l4d2_rankmod_max, l4d2_rankmod_logarithm,
l4d2_players_join_message_timer, hm_blockvote_kick, hm_blockvote_map, hm_allowvote_map_players, hm_blockvote_lobby, hm_blockvote_restart,
hm_blockvote_difficulty, hm_blockvote_difference, hm_allowvote_mission;

ConVar cvar_Hunter, cvar_Smoker, cvar_Boomer, cvar_Spitter, cvar_Jockey, cvar_Charger, cvar_Witch, cvar_Tank, cvar_Bonus, cvar_SiteURL, SDifficultyMultiplier;

int AutodifficultyHP[L4D_MAXPLAYERS + 1][9], AutodifficultyGrenadeLRDmg[L4D_MAXPLAYERS + 1], AutodifficultyItems[L4D_MAXPLAYERS + 1][9],
AutodifficultySpawnLimit[L4D_MAXPLAYERS + 1][9], AutodifficultySpeed[L4D_MAXPLAYERS + 1][9], AutodifficultySpawnInterval[L4D_MAXPLAYERS + 1],
AutodifficultySpawnCount[L4D_MAXPLAYERS + 1], AutodifficultyTongueMissDelay[L4D_MAXPLAYERS + 1], AutodifficultyTongueHitDelay[L4D_MAXPLAYERS + 1],
AutodifficultyTongueRange[L4D_MAXPLAYERS + 1], AutodifficultyTongueChokeDmg[L4D_MAXPLAYERS + 1], AutodifficultyTongueDragDmg[L4D_MAXPLAYERS + 1],
AutodifficultySmokerClawDmg[L4D_MAXPLAYERS + 1], AutodifficultyJockeyClawDmg[L4D_MAXPLAYERS + 1], AutodifficultyTankBurnTime[L4D_MAXPLAYERS + 1],
Autodifficulty_ak47_Dmg[L4D_MAXPLAYERS + 1], Autodifficulty_awp_Dmg[L4D_MAXPLAYERS + 1], Autodifficulty_m60_Dmg[L4D_MAXPLAYERS + 1],
Autodifficulty_scout_Dmg[L4D_MAXPLAYERS + 1], Autodifficulty_sg552_Dmg[L4D_MAXPLAYERS + 1], Autodifficulty_spas_Dmg[L4D_MAXPLAYERS + 1],
Autodifficulty_sniper_military_Dmg[L4D_MAXPLAYERS + 1], Autodifficulty_meleefix_Dmg[L4D_MAXPLAYERS + 1], Autodifficulty_meleefix_headshot_Dmg[L4D_MAXPLAYERS + 1],
Autodifficulty_meleefix_tank_Dmg[L4D_MAXPLAYERS + 1], Autodifficulty_meleefix_tank_headshot_Dmg[L4D_MAXPLAYERS + 1], Autodifficulty_meleefix_witch_Dmg[L4D_MAXPLAYERS + 1];

int tystatsbalans = 0, bonus = 0, RankTotal = 0, PlaytimeDB, UpTime, playerscount = 4, cvar_difficulty = 1, cvar_maxplayers, round_end_repeats,
ClientPoints[MAXPLAYERS+1] = {0, ...}, ClientKills[MAXPLAYERS + 1] = {0, ...}, ClientRank[MAXPLAYERS+1] = {0, ...}, ProtectedFriendlyCounter[MAXPLAYERS + 1] = {0, ...}, ClientPlaytime[MAXPLAYERS + 1] = {0, ...}, PlaytimeMap[MAXPLAYERS + 1] = {0, ...},
Playtime[MAXPLAYERS + 1] = {0, ...}, KillsInfected[MAXPLAYERS + 1] = {0, ...}, NewPoints[MAXPLAYERS + 1] = {0, ...}, ClientHeadshots[MAXPLAYERS + 1] = {0, ...}, TKblockDamage[MAXPLAYERS + 1], NewKills[MAXPLAYERS + 1] = {0, ...}, 
NewHeadshots[MAXPLAYERS + 1] = {0, ...}, TKblockPunishment[MAXPLAYERS + 1] = {0, ...}, TKblockmin = 120, TKblockmax = 360, Pills[4096], Adrenaline[4096], g_votekick[MAXPLAYERS + 1], LastVotebanTIME[MAXPLAYERS + 1] = {0, ...};

StringMap g_HaveSteam_Trie; 

Handle Join_Timer[MAXPLAYERS + 1];

char sg_buf[40], datafilepath[256], MOTD_TITLE[32] = "Message Of The Day", MessageOfTheDay[1024], g_ProfileID[MAXPLAYERS + 1][21], g_SteamID[MAXPLAYERS + 1][32], CV_FileName[256],
sGameDifficulty[16], Server_UpTime[20];

Database Rank_db;

public Plugin myinfo =
{
	name = "[L4D2] ranking",
	author = PLUGIN_AUTHOR,
	description = "L4D2 Coop Ranking With Autodifficulty",
	version = PLUGIN_VERSION,
	url = ""
};

public void CoopAutoDiffOnPluginStart()
{
	UpTime = GetTime();
	hm_autodifficulty = CreateConVar("hm_autodifficulty", "1", "Is the plugin enabled.");
	hm_autodifficulty_forcehp = CreateConVar("hm_autodifficulty_forcehp", "0", "");
	hm_loot_mod = CreateConVar("hm_loot_mod", "1.0", "");
	hm_tank_hp_mod = CreateConVar("hm_tank_hp_mod", "1.0", "");
	hm_infected_hp_mod = CreateConVar("hm_infected_hp_mod", "1.0", "");
	hm_spawn_time_mod = CreateConVar("hm_spawn_time_mod", "1.0", "");
	hm_spawn_count_mod = CreateConVar("hm_spawn_count_mod", "1.0", "");
	z_difficulty = FindConVar("z_difficulty");
	HookConVarChange(z_difficulty, z_difficulty_changed);
	z_special_spawn_interval = FindConVar("z_special_spawn_interval");
	director_special_respawn_interval = FindConVar("director_special_respawn_interval");
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	hm_auto_tongue_range_min = CreateConVar("hm_auto_tongue_range_min", "750", "");
	hm_auto_tongue_range_max = CreateConVar("hm_auto_tongue_range_max", "1500", "");
	hm_auto_tongue_miss_delay_min = CreateConVar("hm_auto_tongue_miss_delay_min", "5", "Minimum time to recharge the language with a miss.");
	hm_auto_tongue_miss_delay_max = CreateConVar("hm_auto_tongue_miss_delay_max", "15", "The maximum time to recharge the language with a miss.");
	hm_auto_tongue_hit_delay_min = CreateConVar("hm_auto_tongue_hit_delay_min", "5", "Minimum time to recharge the language, after releasing (no matter for what reason) the previous victim.");
	hm_auto_tongue_hit_delay_max = CreateConVar("hm_auto_tongue_hit_delay_max", "20", "The maximum time to recharge the language, after releasing (no matter for what reason) the previous victim.");
	hm_auto_tongue_choke_dmg_min = CreateConVar("hm_auto_tongue_choke_dmg_min", "24", "");
	hm_auto_tongue_choke_dmg_max = CreateConVar("hm_auto_tongue_choke_dmg_max", "67", "");
	hm_auto_tongue_drag_dmg_min = CreateConVar("hm_auto_tongue_drag_dmg_min", "9", "");
	hm_auto_tongue_drag_dmg_max = CreateConVar("hm_auto_tongue_drag_dmg_max", "35", "");
	hm_auto_smoker_pz_claw_dmg_min = CreateConVar("hm_auto_smoker_pz_claw_dmg_min", "5", "");
	hm_auto_smoker_pz_claw_dmg_max = CreateConVar("hm_auto_smoker_pz_claw_dmg_max", "18", "");
	hm_auto_jockey_pz_claw_dmg_min = CreateConVar("hm_auto_jockey_pz_claw_dmg_min", "5", "");
	hm_auto_jockey_pz_claw_dmg_max = CreateConVar("hm_auto_jockey_pz_claw_dmg_max", "18", "");
	hm_auto_grenade_lr_dmg_min = CreateConVar("hm_auto_grenade_lr_dmg_min", "400", "");
	hm_auto_grenade_lr_dmg_max = CreateConVar("hm_auto_grenade_lr_dmg_max", "4000", "");
	hm_damage_ak47_min = CreateConVar("hm_damage_ak47_min", "2523", "");
	hm_damage_ak47_max = CreateConVar("hm_damage_ak47_max", "11160", "");
	hm_damage_awp_min = CreateConVar("hm_damage_awp_min", "9486", "");
	hm_damage_awp_max = CreateConVar("hm_damage_awp_max", "39272", "");
	hm_damage_m60_min = CreateConVar("hm_damage_m60_min", "1652", "");
	hm_damage_m60_max = CreateConVar("hm_damage_m60_max", "9812", "");
	hm_damage_scout_min = CreateConVar("hm_damage_scout_min", "4667", "");
	hm_damage_scout_max = CreateConVar("hm_damage_scout_max", "20286", "");
	hm_damage_sg552_min = CreateConVar("hm_damage_sg552_min", "1111", "");
	hm_damage_sg552_max = CreateConVar("hm_damage_sg552_max", "4500", "");
	hm_damage_spas_min = CreateConVar("hm_damage_spas_min", "3000", "");
	hm_damage_spas_max = CreateConVar("hm_damage_spas_max", "12430", "");
	hm_damage_sniper_military_min = CreateConVar("hm_damage_sniper_military_min", "1055", "");
	hm_damage_sniper_military_max = CreateConVar("hm_damage_sniper_military_max", "2000", "");
	hm_damage2_ak47_min = CreateConVar("hm_damage2_ak47_min", "140", "");
	hm_damage2_ak47_max = CreateConVar("hm_damage2_ak47_max", "600", "");
	hm_damage2_awp_min = CreateConVar("hm_damage2_awp_min", "700", "");
	hm_damage2_awp_max = CreateConVar("hm_damage2_awp_max", "4000", "");
	hm_damage2_m60_min = CreateConVar("hm_damage2_m60_min", "85", "");
	hm_damage2_m60_max = CreateConVar("hm_damage2_m60_max", "490", "");
	hm_damage2_scout_min = CreateConVar("hm_damage2_scout_min", "420", "");
	hm_damage2_scout_max = CreateConVar("hm_damage2_scout_max", "1820", "");
	hm_damage2_sg552_min = CreateConVar("hm_damage2_sg552_min", "70", "");
	hm_damage2_sg552_max = CreateConVar("hm_damage2_sg552_max", "250", "");
	hm_damage2_spas_min = CreateConVar("hm_damage2_spas_min", "60", "");
	hm_damage2_spas_max = CreateConVar("hm_damage2_spas_max", "250", "");
	hm_damage2_sniper_military_min = CreateConVar("hm_damage2_sniper_military_min", "50", "");
	hm_damage2_sniper_military_max = CreateConVar("hm_damage2_sniper_military_max", "150", "");
	hm_meleefix_min = CreateConVar("hm_meleefix_min", "650", "");
	hm_meleefix_max = CreateConVar("hm_meleefix_max", "3200", "");
	hm_meleefix_headshot_min = CreateConVar("hm_meleefix_headshot_min", "900", "");
	hm_meleefix_headshot_max = CreateConVar("hm_meleefix_headshot_max", "3800", "");
	hm_meleefix_tank_min = CreateConVar("hm_meleefix_tank_min", "700", "");
	hm_meleefix_tank_max = CreateConVar("hm_meleefix_tank_max", "4000", "");
	hm_meleefix_tank_headshot_min = CreateConVar("hm_meleefix_tank_headshot_min", "1400", "");
	hm_meleefix_tank_headshot_max = CreateConVar("hm_meleefix_tank_headshot_max", "5000", "");
	hm_meleefix_witch_min = CreateConVar("hm_meleefix_witch_min", "200", "");
	hm_meleefix_witch_max = CreateConVar("hm_meleefix_witch_max", "360", "");
	hm_special_infected_min = CreateConVar("hm_special_infected_min", "4", "");
	hm_special_infected_max = CreateConVar("hm_special_infected_max", "6", "");
	hm_spawn_interval_min = CreateConVar("hm_spawn_interval_min", "8", "");
	hm_spawn_interval_max = CreateConVar("hm_spawn_interval_max", "16", "");
	hm_tank_burn_duration_min = CreateConVar("hm_tank_burn_duration_min", "75", "");
	hm_tank_burn_duration_max = CreateConVar("hm_tank_burn_duration_max", "250", "");
	hm_autohp_automod = CreateConVar("hm_autohp_automod", "1", "");
	hm_autohp_supercharger_auto = CreateConVar("hm_autohp_supercharger_auto", "0", "");
	hm_autohp_zombie_min = CreateConVar("hm_autohp_zombie_min", "50", "");
	hm_autohp_zombie_max = CreateConVar("hm_autohp_zombie_max", "120", "");
	hm_autohp_hunter_min = CreateConVar("hm_autohp_hunter_min", "250", "");
	hm_autohp_hunter_max = CreateConVar("hm_autohp_hunter_max", "2500", "");
	hm_autohp_smoker_min = CreateConVar("hm_autohp_smoker_min", "250", "");
	hm_autohp_smoker_max = CreateConVar("hm_autohp_smoker_max", "2800", "");
	hm_autohp_boomer_min = CreateConVar("hm_autohp_boomer_min", "100", "");
	hm_autohp_boomer_max = CreateConVar("hm_autohp_boomer_max", "1000", "");
	hm_autohp_jockey_min = CreateConVar("hm_autohp_jockey_min", "325", "");
	hm_autohp_jockey_max = CreateConVar("hm_autohp_jockey_max", "3200", "");
	hm_autohp_spitter_min = CreateConVar("hm_autohp_spitter_min", "100", "");
	hm_autohp_spitter_max = CreateConVar("hm_autohp_spitter_max", "1700", "");
	hm_autohp_charger_min = CreateConVar("hm_autohp_charger_min", "600", "");
	hm_autohp_charger_max = CreateConVar("hm_autohp_charger_max", "3400", "");
	hm_autohp_witch_min = CreateConVar("hm_autohp_witch_min", "1000", "");
	hm_autohp_witch_max = CreateConVar("hm_autohp_witch_max", "1800", "");
	hm_autohp_tank_min = CreateConVar("hm_autohp_tank_min", "16000", "");
	hm_autohp_tank_max = CreateConVar("hm_autohp_tank_max", "150000", "");
	hm_items_automod = CreateConVar("hm_items_automod", "1", "");
	hm_items_supercharger_auto = CreateConVar("hm_items_supercharger_auto", "2", "");
	hm_items_hunter_min = CreateConVar("hm_items_hunter_min", "1", "");
	hm_items_hunter_max = CreateConVar("hm_items_hunter_max", "3", "");
	hm_items_smoker_min = CreateConVar("hm_items_smoker_min", "1", "");
	hm_items_smoker_max = CreateConVar("hm_items_smoker_max", "3", "");
	hm_items_boomer_min = CreateConVar("hm_items_boomer_min", "1", "");
	hm_items_boomer_max = CreateConVar("hm_items_boomer_max", "3", "");
	hm_items_jockey_min = CreateConVar("hm_items_jockey_min", "1", "");
	hm_items_jockey_max = CreateConVar("hm_items_jockey_max", "3", "");
	hm_items_charger_min = CreateConVar("hm_items_charger_min", "2", "");
	hm_items_charger_max = CreateConVar("hm_items_charger_max", "4", "");
	hm_items_spitter_min = CreateConVar("hm_items_spitter_min", "1", "");
	hm_items_spitter_max = CreateConVar("hm_items_spitter_max", "3", "");
	hm_items_tank_min = CreateConVar("hm_items_tank_min", "7", "");
	hm_items_tank_max = CreateConVar("hm_items_tank_max", "24", "");
	hm_spawn_automod = CreateConVar("hm_spawn_automod", "1", "");
	hm_spawn_zombie_min = CreateConVar("hm_spawn_zombie_min", "15", "");
	hm_spawn_zombie_max = CreateConVar("hm_spawn_zombie_max", "10", "");
	hm_spawn_hunter_min = CreateConVar("hm_spawn_hunter_min", "1", "");
	hm_spawn_hunter_max = CreateConVar("hm_spawn_hunter_max", "3", "");
	hm_spawn_smoker_min = CreateConVar("hm_spawn_smoker_min", "1", "");
	hm_spawn_smoker_max = CreateConVar("hm_spawn_smoker_max", "3", "");
	hm_spawn_boomer_min = CreateConVar("hm_spawn_boomer_min", "1", "");
	hm_spawn_boomer_max = CreateConVar("hm_spawn_boomer_max", "4", "");
	hm_spawn_jockey_min = CreateConVar("hm_spawn_jockey_min", "1", "");
	hm_spawn_jockey_max = CreateConVar("hm_spawn_jockey_max", "3", "");
	hm_spawn_spitter_min = CreateConVar("hm_spawn_spitter_min", "1", "");
	hm_spawn_spitter_max = CreateConVar("hm_spawn_spitter_max", "3", "");
	hm_spawn_charger_min = CreateConVar("hm_spawn_charger_min", "1", "");
	hm_spawn_charger_max = CreateConVar("hm_spawn_charger_max", "3", "");
	hm_speed_automod = CreateConVar("hm_speed_automod", "1", "");
	hm_speed_hunter_min = CreateConVar("hm_speed_hunter_min", "300", "");
	hm_speed_hunter_max = CreateConVar("hm_speed_hunter_max", "350", "");
	hm_speed_smoker_min = CreateConVar("hm_speed_smoker_min", "210", "");
	hm_speed_smoker_max = CreateConVar("hm_speed_smoker_max", "315", "");
	hm_speed_boomer_min = CreateConVar("hm_speed_boomer_min", "175", "");
	hm_speed_boomer_max = CreateConVar("hm_speed_boomer_max", "280", "");
	hm_speed_jockey_min = CreateConVar("hm_speed_jockey_min", "250", "");
	hm_speed_jockey_max = CreateConVar("hm_speed_jockey_max", "300", "");
	hm_speed_charger_min = CreateConVar("hm_speed_charger_min", "250", "");
	hm_speed_charger_max = CreateConVar("hm_speed_charger_max", "300", "");
	hm_speed_spitter_min = CreateConVar("hm_speed_spitter_min", "210", "");
	hm_speed_spitter_max = CreateConVar("hm_speed_spitter_max", "315", "");
	hm_speed_tank_min = CreateConVar("hm_speed_tank_min", "210", "");
	hm_speed_tank_max = CreateConVar("hm_speed_tank_max", "315", "");
	RegAdminCmd("sm_autodifficulty_init", Command_AutoDifficultyInit, ADMFLAG_CONFIG, "");
	RegAdminCmd("sm_autodifficulty_refresh", Command_AutoDifficultyRefresh, ADMFLAG_CONFIG, "");
	RegAdminCmd("sm_check", Command_Check, ADMFLAG_CONFIG, "");
	RegAdminCmd("sm_spawn_limits", Command_SpawnLimits, ADMFLAG_CONFIG, "");
	RegConsoleCmd("sm_rankmod", Command_RankMod, "");
	RegConsoleCmd("sm_ddfull", Command_ddfull, "");
	RegConsoleCmd("sm_damage", Command_damage, "");
	RegConsoleCmd("sm_chance", Command_ammo, "");
	RegConsoleCmd("sm_melee", Command_melee, "");
	RegConsoleCmd("sm_info1", Command_info2, "");
	RegConsoleCmd("sm_pinfo", Command_pinfo, "");
	RegConsoleCmd("sm_vivos", Command_Aliveinfo, "");
	RegAdminCmd("sm_swd", Command_swd, ADMFLAG_CONFIG, "sm_swd", "");
	RegAdminCmd("sm_swdoff", Command_swdoff, ADMFLAG_CONFIG, "sm_swdoff", "");
	HookConVarChange(FindConVar("sv_maxplayers"), cvar_maxplayers_changed);
	RegConsoleCmd("say", cmd_Say, "");
	RegConsoleCmd("say_team", cmd_Say, "");
}

void ADOnMapStart()
{
	g_IsTimeAutodifficulty = false;
}

void ADRoundStart()
{
	if (FindConVar("monsterbots_interval") == null) l4d2_plugin_monsterbots = false;
	else l4d2_plugin_monsterbots = true;
	if (!l4d2_plugin_monsterbots)
	{
		int flags = FindConVar("z_max_player_zombies").Flags;
		FindConVar("z_max_player_zombies").SetBounds(ConVarBound_Upper, false);
		FindConVar("z_max_player_zombies").Flags = flags & ~FCVAR_NOTIFY;
	}
	cvar_maxplayers = FindConVar("sv_maxplayers").IntValue + -5;
	CreateTimer(25.0, g_TimedAutoDifficultyInit);
}

public void g_TimedAutoDifficultyInit(Handle timer, any client)
{
	g_IsTimeAutodifficulty = true;
}

Action Command_AutoDifficultyInit(int client, int args)
{
	AutoDifficultyInit();
	return Plugin_Handled;
}

Action Command_AutoDifficultyRefresh(int client, int args)
{
	if (GetRealtyClientCount(true) > 0 && g_IsTimeAutodifficulty)
	{
		Autodifficulty();
	}
	return Plugin_Handled;
}

Action Command_Check(int client, int args)
{
	PrintToServer("hm_autohp_charger_min = %d, hm_autohp_charger_max = %d, sv_maxplayers = %d", hm_autohp_charger_min.IntValue, hm_autohp_charger_max.IntValue, cvar_maxplayers);
	for (int i = L4D_MINPLAYERS; i <= L4D_MAXPLAYERS; i++)
	{
		PrintToServer("AutodifficultyItems[%d][ZC_SMOKER] = %d | AutodifficultyHP[%d][ZC_CHARGER] = %d", i, AutodifficultyItems[i][ZC_SMOKER], i, AutodifficultyHP[i][ZC_CHARGER]);
	}
	return Plugin_Handled;
}

Action Command_SpawnLimits(int client, int args)
{
	if (client)
	{
		PrintToChat(client, "z_common_limit = %d", FindConVar("z_common_limit").IntValue);
		PrintToChat(client, "z_hunter_limit = %d", FindConVar("z_hunter_limit").IntValue);
		PrintToChat(client, "z_smoker_limit = %d", FindConVar("z_smoker_limit").IntValue);
		PrintToChat(client, "z_boomer_limit = %d", FindConVar("z_boomer_limit").IntValue);
		PrintToChat(client, "z_spitter_limit = %d", FindConVar("z_spitter_limit").IntValue);
		PrintToChat(client, "z_jockey_limit = %d", FindConVar("z_jockey_limit").IntValue);
		PrintToChat(client, "z_charger_limit = %d", FindConVar("z_charger_limit").IntValue);
	}
	else
	{
		PrintToServer("z_common_limit = %d", FindConVar("z_common_limit").IntValue);
		PrintToServer("z_hunter_limit = %d (spawned %d)", FindConVar("z_hunter_limit").IntValue, CountMonsters(ZC_HUNTER));
		PrintToServer("z_smoker_limit = %d (spawned %d)", FindConVar("z_smoker_limit").IntValue, CountMonsters(ZC_SMOKER));
		PrintToServer("z_boomer_limit = %d (spawned %d)", FindConVar("z_boomer_limit").IntValue, CountMonsters(ZC_BOOMER));
		PrintToServer("z_spitter_limit = %d (spawned %d)", FindConVar("z_spitter_limit").IntValue, CountMonsters(ZC_SPITTER));
		PrintToServer("z_jockey_limit = %d (spawned %d)", FindConVar("z_jockey_limit").IntValue, CountMonsters(ZC_JOCKEY));
		PrintToServer("z_charger_limit = %d (spawned %d)", FindConVar("z_charger_limit").IntValue, CountMonsters(ZC_CHARGER));
	}
	return Plugin_Handled;
}

int CountMonsters(int ZOMBIE_CLASS)
{
	int count = 0;
	for (int i = 1; i <= L4D_MAXPLAYERS; i++) if (GetClientZC(i) == ZOMBIE_CLASS) count++;
	return count;
}

public void z_difficulty_changed(Handle hVariable, char[] strOldValue, char[] strNewValue)
{
	UpdateDifficultyName();
}

public void hm_ad_options_changed(Handle hVariable, char[] strOldValue, char[] strNewValue)
{
	AutoDifficultyInit();
}

void UpdateDifficultyName()
{
	z_difficulty.GetString(sGameDifficulty, sizeof(sGameDifficulty));
	if (ReplaceString(sGameDifficulty, sizeof(sGameDifficulty), "Impossible", "Expert", false)) cvar_difficulty = 4;
	else if (ReplaceString(sGameDifficulty, sizeof(sGameDifficulty), "Hard", "Master", false)) cvar_difficulty = 3;
}

void AutoDifficultyInit()
{
	UpdateDifficultyName();
	if (!cvar_maxplayers) cvar_maxplayers = FindConVar("sv_maxplayers").IntValue;
	if (cvar_maxplayers < 1) return;
	damage_type = FindConVar("hm_damage_type");
	if (FindConVar("l4d2_loot_h_drop_items") == null) l4d2_plugin_loot = false;
	else l4d2_plugin_loot = true;
	if (FindConVar("monsterbots_interval") == null) l4d2_plugin_monsterbots = false;
	else l4d2_plugin_monsterbots = true;
	if (FindConVar("l4d2_charger_steering_allow") != null && FindConVar("l4d2_charger_steering_allow").IntValue > 0 && hm_autohp_supercharger_auto.FloatValue > 0) extra_charger = true;
	else extra_charger = false;
	for (int i = L4D_MINPLAYERS; i <= L4D_MAXPLAYERS; i++)
	{
		AutodifficultyHP[i][ZC_ZOMBIE] = GetLineFunction(hm_autohp_zombie_min.IntValue, hm_autohp_zombie_max.IntValue, i);
		AutodifficultyHP[i][ZC_SMOKER] = GetLineFunction(hm_autohp_smoker_min.IntValue, hm_autohp_smoker_max.IntValue, i);
		AutodifficultyHP[i][ZC_BOOMER] = GetLineFunction(hm_autohp_boomer_min.IntValue, hm_autohp_boomer_max.IntValue, i);
		AutodifficultyHP[i][ZC_HUNTER] = GetLineFunction(hm_autohp_hunter_min.IntValue, hm_autohp_hunter_max.IntValue, i);
		AutodifficultyHP[i][ZC_SPITTER] = GetLineFunction(hm_autohp_spitter_min.IntValue, hm_autohp_spitter_max.IntValue, i);
		AutodifficultyHP[i][ZC_JOCKEY] = GetLineFunction(hm_autohp_jockey_min.IntValue, hm_autohp_jockey_max.IntValue, i);
		AutodifficultyHP[i][ZC_CHARGER] = GetLineFunction(hm_autohp_charger_min.IntValue, hm_autohp_charger_max.IntValue, i);
		AutodifficultyHP[i][ZC_WITCH] = GetLineFunction(hm_autohp_witch_min.IntValue, hm_autohp_witch_max.IntValue, i);
		AutodifficultyHP[i][ZC_TANK] = RoundToNearest(GetLineFunction(hm_autohp_tank_min.IntValue, hm_autohp_tank_max.IntValue, i) / 2.0);
		if (l4d2_plugin_loot)
		{
			AutodifficultyItems[i][ZC_SMOKER] = GetLineFunction(hm_items_smoker_min.IntValue, hm_items_smoker_max.IntValue, i);
			AutodifficultyItems[i][ZC_BOOMER] = GetLineFunction(hm_items_boomer_min.IntValue, hm_items_boomer_max.IntValue, i);
			AutodifficultyItems[i][ZC_HUNTER] = GetLineFunction(hm_items_hunter_min.IntValue, hm_items_hunter_max.IntValue, i);
			AutodifficultyItems[i][ZC_SPITTER] = GetLineFunction(hm_items_spitter_min.IntValue, hm_items_spitter_max.IntValue, i);
			AutodifficultyItems[i][ZC_JOCKEY] = GetLineFunction(hm_items_jockey_min.IntValue, hm_items_jockey_max.IntValue, i);
			AutodifficultyItems[i][ZC_CHARGER] = GetLineFunction(hm_items_charger_min.IntValue, hm_items_charger_max.IntValue, i);
			AutodifficultyItems[i][ZC_TANK] = GetLineFunction(hm_items_tank_min.IntValue, hm_items_tank_max.IntValue, i);
		}
		AutodifficultySpawnLimit[i][ZC_ZOMBIE] = GetLineFunction(hm_spawn_zombie_min.IntValue, hm_spawn_zombie_max.IntValue, i);
		AutodifficultySpawnLimit[i][ZC_SMOKER] = GetLineFunction(hm_spawn_smoker_min.IntValue, hm_spawn_smoker_max.IntValue, i);
		AutodifficultySpawnLimit[i][ZC_BOOMER] = GetLineFunction(hm_spawn_boomer_min.IntValue, hm_spawn_boomer_max.IntValue, i);
		AutodifficultySpawnLimit[i][ZC_HUNTER] = GetLineFunction(hm_spawn_hunter_min.IntValue, hm_spawn_hunter_max.IntValue, i);
		AutodifficultySpawnLimit[i][ZC_SPITTER] = GetLineFunction(hm_spawn_spitter_min.IntValue, hm_spawn_spitter_max.IntValue, i);
		AutodifficultySpawnLimit[i][ZC_JOCKEY] = GetLineFunction(hm_spawn_jockey_min.IntValue, hm_spawn_jockey_max.IntValue, i);
		AutodifficultySpawnLimit[i][ZC_CHARGER] = GetLineFunction(hm_spawn_charger_min.IntValue, hm_spawn_charger_max.IntValue, i);
		
		AutodifficultySpeed[i][ZC_SMOKER] = GetLineFunction(hm_speed_smoker_min.IntValue, hm_speed_smoker_max.IntValue, i);
		AutodifficultySpeed[i][ZC_BOOMER] = GetLineFunction(hm_speed_boomer_min.IntValue, hm_speed_boomer_max.IntValue, i);
		AutodifficultySpeed[i][ZC_HUNTER] = GetLineFunction(hm_speed_hunter_min.IntValue, hm_speed_hunter_max.IntValue, i);
		AutodifficultySpeed[i][ZC_SPITTER] = GetLineFunction(hm_speed_spitter_min.IntValue, hm_speed_spitter_max.IntValue, i);
		AutodifficultySpeed[i][ZC_JOCKEY] = GetLineFunction(hm_speed_jockey_min.IntValue, hm_speed_jockey_max.IntValue, i);
		AutodifficultySpeed[i][ZC_CHARGER] = GetLineFunction(hm_speed_charger_min.IntValue, hm_speed_charger_max.IntValue, i);
		AutodifficultySpeed[i][ZC_TANK] = GetLineFunction(hm_speed_tank_min.IntValue, hm_speed_tank_max.IntValue, i);
		
		AutodifficultySpawnInterval[i] = GetLineFunction(hm_spawn_interval_max.IntValue, hm_spawn_interval_min.IntValue, i);
		AutodifficultySpawnCount[i] = GetLineFunction(hm_special_infected_min.IntValue, hm_special_infected_max.IntValue, i);
		AutodifficultyTongueRange[i] = GetLineFunction(hm_auto_tongue_range_min.IntValue, hm_auto_tongue_range_max.IntValue, i);
		AutodifficultyTongueMissDelay[i] = GetLineFunction(hm_auto_tongue_miss_delay_max.IntValue, hm_auto_tongue_miss_delay_min.IntValue, i);
		AutodifficultyTongueHitDelay[i] = GetLineFunction(hm_auto_tongue_hit_delay_max.IntValue, hm_auto_tongue_hit_delay_min.IntValue, i);
		AutodifficultyTongueChokeDmg[i] = GetLineFunction(hm_auto_tongue_choke_dmg_min.IntValue, hm_auto_tongue_choke_dmg_max.IntValue, i);
		AutodifficultyTongueDragDmg[i] = GetLineFunction(hm_auto_tongue_drag_dmg_min.IntValue, hm_auto_tongue_drag_dmg_max.IntValue, i);
		AutodifficultySmokerClawDmg[i] = GetLineFunction(hm_auto_smoker_pz_claw_dmg_min.IntValue, hm_auto_smoker_pz_claw_dmg_max.IntValue, i);
		AutodifficultyJockeyClawDmg[i] = GetLineFunction(hm_auto_jockey_pz_claw_dmg_min.IntValue, hm_auto_jockey_pz_claw_dmg_max.IntValue, i);
		AutodifficultyGrenadeLRDmg[i] = GetLineFunction(hm_auto_grenade_lr_dmg_min.IntValue, hm_auto_grenade_lr_dmg_max.IntValue, i);
		AutodifficultyTankBurnTime[i] = GetLineFunction(hm_tank_burn_duration_min.IntValue, hm_tank_burn_duration_max.IntValue, i);
		if (damage_type.IntValue == 1)
		{
			Autodifficulty_ak47_Dmg[i] = GetLineFunction(hm_damage_ak47_min.IntValue, hm_damage_ak47_max.IntValue, i);
			Autodifficulty_awp_Dmg[i] = GetLineFunction(hm_damage_awp_min.IntValue, hm_damage_awp_max.IntValue, i);
			Autodifficulty_m60_Dmg[i] = GetLineFunction(hm_damage_m60_min.IntValue, hm_damage_m60_max.IntValue, i);
			Autodifficulty_scout_Dmg[i] = GetLineFunction(hm_damage_scout_min.IntValue, hm_damage_scout_max.IntValue, i);
			Autodifficulty_sg552_Dmg[i] = GetLineFunction(hm_damage_sg552_min.IntValue, hm_damage_sg552_max.IntValue, i);
			Autodifficulty_spas_Dmg[i] = GetLineFunction(hm_damage_spas_min.IntValue, hm_damage_spas_max.IntValue, i);
			Autodifficulty_sniper_military_Dmg[i] = GetLineFunction(hm_damage_sniper_military_min.IntValue, hm_damage_sniper_military_max.IntValue, i);
		}
		else if (damage_type.IntValue == 2)
		{
			Autodifficulty_ak47_Dmg[i] = GetLineFunction(hm_damage2_ak47_min.IntValue, hm_damage2_ak47_max.IntValue, i);
			Autodifficulty_awp_Dmg[i] = GetLineFunction(hm_damage2_awp_min.IntValue, hm_damage2_awp_max.IntValue, i);
			Autodifficulty_m60_Dmg[i] = GetLineFunction(hm_damage2_m60_min.IntValue, hm_damage2_m60_max.IntValue, i);
			Autodifficulty_scout_Dmg[i] = GetLineFunction(hm_damage2_scout_min.IntValue, hm_damage2_scout_max.IntValue, i);
			Autodifficulty_sg552_Dmg[i] = GetLineFunction(hm_damage2_sg552_min.IntValue, hm_damage2_sg552_max.IntValue, i);
			Autodifficulty_spas_Dmg[i] = GetLineFunction(hm_damage2_spas_min.IntValue, hm_damage2_spas_max.IntValue, i);
			Autodifficulty_sniper_military_Dmg[i] = GetLineFunction(hm_damage2_sniper_military_min.IntValue, hm_damage2_sniper_military_max.IntValue, i);		
		}
		Autodifficulty_meleefix_Dmg[i] = GetLineFunction(hm_meleefix_min.IntValue, hm_meleefix_max.IntValue, i);
		Autodifficulty_meleefix_headshot_Dmg[i] = GetLineFunction(hm_meleefix_headshot_min.IntValue, hm_meleefix_headshot_max.IntValue, i);
		Autodifficulty_meleefix_tank_Dmg[i] = GetLineFunction(hm_meleefix_tank_min.IntValue, hm_meleefix_tank_max.IntValue, i);
		Autodifficulty_meleefix_tank_headshot_Dmg[i] = GetLineFunction(hm_meleefix_tank_headshot_min.IntValue, hm_meleefix_tank_headshot_max.IntValue, i);
		Autodifficulty_meleefix_witch_Dmg[i] = GetLineFunction(hm_meleefix_witch_min.IntValue, hm_meleefix_witch_max.IntValue, i);
	}
	autodifficulty_calculated = true;
}

int GetLineFunction(int GLF_Min, int GLF_Max, int i)
{
	int result = GetLineFunctionEx(GLF_Min, GLF_Max, i, cvar_maxplayers);
	if (result < 0) return GLF_Min;
	return result;
}

int GetLineFunctionEx(int GLF_Min, int GLF_Max, int i, int GLF_maxplayers)
{
	float k = (GLF_Max - GLF_Min) * 1.0 / (GLF_maxplayers - L4D_MINPLAYERS) * 1.0;
	float b = GLF_Max * 1.0 - k * GLF_maxplayers;
	return RoundToNearest(k * i + b);
}

int GetTankHP()
{
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		if (IsValidEntity(i) && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			if (GetEntProp(i, Prop_Send, "m_zombieClass") == ZC_TANK)
			{
				if (GetEntProp(i, Prop_Send, "m_isIncapacitated")) return 0;
				return GetClientHealth(i);
			}
		}
	}
	return FindConVar("z_tank_health").IntValue * 2;
}

public Action Command_info2(int client, int args)
{
	if (client)
	{
		char sFormattedTime[24];
		FormatTime(sFormattedTime, sizeof(sFormattedTime), "%m/%d/%Y - %H:%M:%S", GetTime());
		char Mapname[128];
		GetCurrentMap(Mapname, sizeof(Mapname));
		UpdateServerUpTime();
		CPrintToChat(client, "%t", "•UKSupercoop•(7.4) | UpTime: %s", Server_UpTime);
		if (RDifficultyMultiplier >= 1000.0)
		{
			char MapDifficultyMultiplier[8];
			FloatToString(RDifficultyMultiplier, MapDifficultyMultiplier, sizeof(MapDifficultyMultiplier));
			CPrintToChat(client, "%t", "Difficulty: %s x %s | Players: %i | [%i]|[%i]|[%i]", sGameDifficulty, MapDifficultyMultiplier, GetRealClientCount(true), TeamSurvivors(), TeamDead(), TeamSpectators());
		}
		else if (RDifficultyMultiplier >= 100.0)
		{
			char MapDifficultyMultiplier[7];
			FloatToString(RDifficultyMultiplier, MapDifficultyMultiplier, sizeof(MapDifficultyMultiplier));
			CPrintToChat(client, "%t", "Difficulty: %s x %s | Players: %i | [%i]|[%i]|[%i]", sGameDifficulty, MapDifficultyMultiplier, GetRealClientCount(true), TeamSurvivors(), TeamDead(), TeamSpectators());
		}
		else if (RDifficultyMultiplier >= 10.0)
		{
			char MapDifficultyMultiplier[6];
			FloatToString(RDifficultyMultiplier, MapDifficultyMultiplier, sizeof(MapDifficultyMultiplier));
			CPrintToChat(client, "%t", "Difficulty: %s x %s | Players: %i | [%i]|[%i]|[%i]", sGameDifficulty, MapDifficultyMultiplier, GetRealClientCount(true), TeamSurvivors(), TeamDead(), TeamSpectators());
		}
		else
		{
			char MapDifficultyMultiplier[5];
			FloatToString(RDifficultyMultiplier, MapDifficultyMultiplier, sizeof(MapDifficultyMultiplier));
			CPrintToChat(client, "%t", "Difficulty: %s x %s | Players: %i | [%i]|[%i]|[%i]", sGameDifficulty, MapDifficultyMultiplier, GetRealClientCount(true), TeamSurvivors(), TeamDead(), TeamSpectators());
		}
		if (IsTankAlive())
		{
			char Message[256], TempMessage[64];
			bool more_than_one;
			Format(TempMessage, sizeof(TempMessage), "%t", "Tank HP: ");
			StrCat(Message, sizeof(Message), TempMessage);
			for (int i = 1; i <= MaxClients; i++) 
			{
				if (IsClientInGame(i))
				{
					if (GetClientTeam(i) == TEAM_INFECTED && !IsIncapacitated(i) && IsPlayerAlive(i) && GetClientZC(i) == ZC_TANK && GetClientHealth(i) > 0)
					{
						if (more_than_one)
						{
							Format(TempMessage, sizeof(TempMessage), "\x04& \x03%d ", GetClientHealth(i));
							StrCat(Message, sizeof(Message), TempMessage);
						}
						else
						{
							Format(TempMessage, sizeof(TempMessage), "\x03%d ", GetClientHealth(i));
							StrCat(Message, sizeof(Message), TempMessage);
						}
						more_than_one = true;
					}
				}
				i++;
			}
			Format(TempMessage, sizeof(TempMessage), "%t", "| Witch HP: %i | Zombie HP: %i", FindConVar("z_witch_health").IntValue, FindConVar("z_health").IntValue);
			StrCat(Message, sizeof(Message), TempMessage);
			PrintToChat(client, Message);
		}
		else
		{
			PrintToChat(client, "%t", "Tank HP: %i | Witch HP: %i | Zombie HP: %i", GetTankHP(), FindConVar("z_witch_health").IntValue, FindConVar("z_health").IntValue);
		}
		PrintToChat(client, "%t", "Hunter HP: %i | Smoker HP: %i | Boomer HP: %i \nCharger HP: %i | Spitter HP: %i | Jockey HP: %i", FindConVar("z_hunter_health").IntValue, FindConVar("z_gas_health").IntValue, FindConVar("z_exploding_health").IntValue, FindConVar("z_charger_health").IntValue, FindConVar("z_spitter_health").IntValue, FindConVar("z_jockey_health").IntValue);
		PrintToChat(client, "%t", "Grenade Launcher Damage: %d. Server time: %s", FindConVar("grenadelauncher_damage").IntValue, sFormattedTime);
		PrintToChat(client, "%t", "CurrentMap: %s", Mapname);
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action Command_Aliveinfo(int client, int args)
{
	if (client > 0)
	{
		CPrintToChat(client, "%t", "Informantion:");
		CPrintToChat(client, "%t", "Alive: [%i]|[%i]|[%i]", TeamSurvivors(), TeamDead(), TeamSpectators());
	}
	return Plugin_Continue;
}

int TeamSurvivors()
{
	int j = 0;
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			j++;
		}
	}
	return j;
}


int TeamSpectators()
{
	int j = 0;
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 1)
		{
			j++;
		}
	}
	return j;
}

int TeamDead()
{
	int j = 0;
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i) && !IsAlive(i))
		{
			j++;
		}
	}
	return j;
}

bool IsAlive(int client)
{
	if (!GetEntProp(client, Prop_Send, "m_lifeState"))
	{
		return true;
	}
	return false;
}

public void Autodifficulty()
{
	if (hm_autodifficulty.IntValue < 1) return;
	if (!autodifficulty_calculated)
	{
		AutoDifficultyInit();
		return;
	}
	if (playerscount < L4D_MINPLAYERS) playerscount = L4D_MINPLAYERS;
	if (playerscount > cvar_maxplayers) playerscount = cvar_maxplayers;
	if (l4d2_plugin_monsterbots)
	{
		FindConVar("monsterbots_maxbots").IntValue = RoundToNearest(AutodifficultySpawnCount[playerscount] * hm_spawn_count_mod.FloatValue);
		FindConVar("monsterbots_interval").IntValue = RoundToNearest(AutodifficultySpawnInterval[playerscount] * hm_spawn_time_mod.FloatValue);
	}
	else
	{
		z_special_spawn_interval.IntValue = RoundToNearest(AutodifficultySpawnInterval[playerscount] * hm_spawn_time_mod.FloatValue);
		director_special_respawn_interval.IntValue = RoundToNearest(AutodifficultySpawnInterval[playerscount] * hm_spawn_time_mod.FloatValue);
		z_max_player_zombies.IntValue = RoundToNearest(AutodifficultySpawnCount[playerscount] * hm_spawn_count_mod.FloatValue);
	}
	RDifficultyMultiplier = Calculate_Rank_Mod();
	if (GetConVarInt(hm_speed_automod) > 0)
	{
		FindConVar("z_hunter_speed").IntValue = AutodifficultySpeed[playerscount][ZC_HUNTER];
		FindConVar("z_gas_speed").IntValue = AutodifficultySpeed[playerscount][ZC_SMOKER];
		FindConVar("z_exploding_speed").IntValue = AutodifficultySpeed[playerscount][ZC_BOOMER];
		FindConVar("z_spitter_speed").IntValue = AutodifficultySpeed[playerscount][ZC_SPITTER];
		FindConVar("z_jockey_speed").IntValue = AutodifficultySpeed[playerscount][ZC_JOCKEY];
		FindConVar("z_charge_start_speed").IntValue = AutodifficultySpeed[playerscount][ZC_CHARGER];
		FindConVar("z_tank_speed").IntValue = AutodifficultySpeed[playerscount][ZC_TANK];
	}
	ConVar tank_burn_duration = null;
	switch (cvar_difficulty)
	{
		case 1: tank_burn_duration = FindConVar("tank_burn_duration");
		case 3: tank_burn_duration = FindConVar("tank_burn_duration_hard");
		case 4: tank_burn_duration = FindConVar("tank_burn_duration_expert");
	}
	tank_burn_duration.IntValue = AutodifficultyTankBurnTime[playerscount];
	FindConVar("grenadelauncher_damage").IntValue = AutodifficultyGrenadeLRDmg[playerscount];
	if (hm_spawn_automod.IntValue > 0)
	{
		FindConVar("z_common_limit").IntValue = AutodifficultySpawnLimit[playerscount][ZC_ZOMBIE];
		FindConVar("z_hunter_limit").IntValue = AutodifficultySpawnLimit[playerscount][ZC_HUNTER];
		FindConVar("z_smoker_limit").IntValue = AutodifficultySpawnLimit[playerscount][ZC_SMOKER];
		FindConVar("z_boomer_limit").IntValue = AutodifficultySpawnLimit[playerscount][ZC_BOOMER];
		FindConVar("z_spitter_limit").IntValue = AutodifficultySpawnLimit[playerscount][ZC_SPITTER];
		FindConVar("z_jockey_limit").IntValue = AutodifficultySpawnLimit[playerscount][ZC_JOCKEY];
		FindConVar("z_charger_limit").IntValue = AutodifficultySpawnLimit[playerscount][ZC_CHARGER];
	}
	float HealthMod = hm_infected_hp_mod.FloatValue;
	if (hm_autohp_automod.IntValue > 0) HealthMod *= RDifficultyMultiplier;
	
	FindConVar("z_charger_health").IntValue = RoundToNearest(AutodifficultyHP[playerscount][ZC_CHARGER] * HealthMod);
	FindConVar("z_hunter_health").IntValue = RoundToNearest(AutodifficultyHP[playerscount][ZC_HUNTER] * HealthMod);
	FindConVar("z_gas_health").IntValue = RoundToNearest(AutodifficultyHP[playerscount][ZC_SMOKER] * HealthMod);
	FindConVar("z_exploding_health").IntValue = RoundToNearest(AutodifficultyHP[playerscount][ZC_BOOMER] * HealthMod);
	FindConVar("z_spitter_health").IntValue = RoundToNearest(AutodifficultyHP[playerscount][ZC_SPITTER] * HealthMod);
	FindConVar("z_jockey_health").IntValue = RoundToNearest(AutodifficultyHP[playerscount][ZC_JOCKEY] * HealthMod);
	FindConVar("z_witch_health").IntValue = RoundToNearest(AutodifficultyHP[playerscount][ZC_WITCH] * HealthMod);
	FindConVar("z_tank_health").IntValue = RoundToNearest(AutodifficultyHP[playerscount][ZC_TANK] * HealthMod * hm_tank_hp_mod.FloatValue);
	FindConVar("z_health").IntValue = RoundToNearest(1.0 * AutodifficultyHP[playerscount][ZC_ZOMBIE]);
	FindConVar("l4d2_ammo_witches").IntValue = RoundToNearest(1.0 * playerscount + 0.5 * 4 * RDifficultyMultiplier);
	if (l4d2_plugin_loot && hm_items_automod.IntValue > 0)
	{
		float LootMod = hm_loot_mod.FloatValue;
		FindConVar("l4d2_loot_h_drop_items").IntValue = RoundToNearest((AutodifficultyItems[playerscount][ZC_HUNTER]) * LootMod);
		FindConVar("l4d2_loot_b_drop_items").IntValue = RoundToNearest((AutodifficultyItems[playerscount][ZC_BOOMER]) * LootMod);
		FindConVar("l4d2_loot_s_drop_items").IntValue = RoundToNearest((AutodifficultyItems[playerscount][ZC_SMOKER]) * LootMod);
		FindConVar("l4d2_loot_sp_drop_items").IntValue = RoundToNearest((AutodifficultyItems[playerscount][ZC_SPITTER]) * LootMod);
		FindConVar("l4d2_loot_j_drop_items").IntValue = RoundToNearest((AutodifficultyItems[playerscount][ZC_JOCKEY]) * LootMod);
		FindConVar("l4d2_loot_t_drop_items").IntValue = RoundToNearest((AutodifficultyItems[playerscount][ZC_TANK]) * LootMod);
		if (extra_charger) FindConVar("l4d2_loot_c_drop_items").IntValue = RoundToNearest((AutodifficultyItems[playerscount][ZC_CHARGER] + hm_items_supercharger_auto.IntValue * LootMod));
		else FindConVar("l4d2_loot_c_drop_items").IntValue = RoundToNearest((AutodifficultyItems[playerscount][ZC_CHARGER]) * LootMod);
	}
	FindConVar("tongue_miss_delay").IntValue = AutodifficultyTongueMissDelay[playerscount];
	FindConVar("tongue_hit_delay").IntValue = AutodifficultyTongueHitDelay[playerscount];
	FindConVar("tongue_range").IntValue = AutodifficultyTongueRange[playerscount];
	FindConVar("smoker_pz_claw_dmg").IntValue = AutodifficultySmokerClawDmg[playerscount];
	FindConVar("jockey_pz_claw_dmg").IntValue = AutodifficultyJockeyClawDmg[playerscount];
	FindConVar("tongue_choke_damage_amount").IntValue = AutodifficultyTongueChokeDmg[playerscount];
	FindConVar("tongue_drag_damage_amount").IntValue = AutodifficultyTongueDragDmg[playerscount];
	float WeaponMod = hm_infected_hp_mod.FloatValue;
	if (hm_autohp_automod.IntValue > 0)
	{
		WeaponMod *= RDifficultyMultiplier;
	}
	if (damage_type.IntValue == 1)
	{
		FindConVar("hm_damage_ak47").IntValue = RoundToNearest(WeaponMod * Autodifficulty_ak47_Dmg[playerscount]);
		FindConVar("hm_damage_awp").IntValue = RoundToNearest(WeaponMod * Autodifficulty_awp_Dmg[playerscount]);
		FindConVar("hm_damage_m60").IntValue = RoundToNearest(WeaponMod * Autodifficulty_m60_Dmg[playerscount]);
		FindConVar("hm_damage_scout").IntValue = RoundToNearest(WeaponMod * Autodifficulty_scout_Dmg[playerscount]);
		FindConVar("hm_damage_sg552").IntValue = RoundToNearest(WeaponMod * Autodifficulty_sg552_Dmg[playerscount]);
		FindConVar("hm_damage_spas").IntValue = RoundToNearest(WeaponMod * Autodifficulty_spas_Dmg[playerscount]);
		FindConVar("hm_damage_sniper_military").IntValue = RoundToNearest(WeaponMod * Autodifficulty_sniper_military_Dmg[playerscount]);
	}
	else if (GetConVarInt(damage_type) == 2)
	{
		FindConVar("hm_damage2_ak47").IntValue = RoundToNearest(WeaponMod * Autodifficulty_ak47_Dmg[playerscount]);
		FindConVar("hm_damage2_awp").IntValue = RoundToNearest(WeaponMod * Autodifficulty_awp_Dmg[playerscount]);
		FindConVar("hm_damage2_m60").IntValue = RoundToNearest(WeaponMod * Autodifficulty_m60_Dmg[playerscount]);
		FindConVar("hm_damage2_scout").IntValue = RoundToNearest(WeaponMod * Autodifficulty_scout_Dmg[playerscount]);
		FindConVar("hm_damage2_sg552").IntValue = RoundToNearest(WeaponMod * Autodifficulty_sg552_Dmg[playerscount]);
		FindConVar("hm_damage2_spas").IntValue = RoundToNearest(WeaponMod * Autodifficulty_spas_Dmg[playerscount]);
		FindConVar("hm_damage2_sniper_military").IntValue = RoundToNearest(WeaponMod * Autodifficulty_sniper_military_Dmg[playerscount]);
	}
	FindConVar("hm_meleefix_smoker").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_Dmg[playerscount]);
	FindConVar("hm_meleefix_smoker_headshot").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_headshot_Dmg[playerscount]);
	FindConVar("hm_meleefix_boomer").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_Dmg[playerscount]);
	FindConVar("hm_meleefix_boomer_headshot").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_headshot_Dmg[playerscount]);
	FindConVar("hm_meleefix_hunter").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_Dmg[playerscount]);
	FindConVar("hm_meleefix_hunter_headshot").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_headshot_Dmg[playerscount]);
	FindConVar("hm_meleefix_jockey").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_Dmg[playerscount]);
	FindConVar("hm_meleefix_jockey_headshot").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_headshot_Dmg[playerscount]);
	FindConVar("hm_meleefix_spitter").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_Dmg[playerscount]);
	FindConVar("hm_meleefix_spitter_headshot").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_headshot_Dmg[playerscount]);
	FindConVar("hm_meleefix_charger").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_Dmg[playerscount]);
	FindConVar("hm_meleefix_charger_headshot").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_headshot_Dmg[playerscount]);
	FindConVar("hm_meleefix_tank").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_tank_Dmg[playerscount]);
	FindConVar("hm_meleefix_tank_headshot").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_tank_headshot_Dmg[playerscount]);
	FindConVar("hm_meleefix_witch").IntValue = RoundToNearest(WeaponMod * Autodifficulty_meleefix_witch_Dmg[playerscount]);
	if (playerscount > 4)
	{
		FindConVar("z_spitter_max_wait_time").IntValue = 34 - playerscount;
		FindConVar("z_vomit_interval").IntValue = 34 - playerscount;
	}
	else
	{
		FindConVar("z_spitter_max_wait_time").IntValue = 30;
		FindConVar("z_vomit_interval").IntValue = 30;
	}
}

public void cvar_maxplayers_changed(Handle hVariable, char[] strOldValue , char[] strNewValue)
{
	cvar_maxplayers = FindConVar("sv_maxplayers").IntValue + -5;
}

public Action Command_RankMod(int client, int args)
{
	float RankMod = Calculate_Rank_Mod();
	if (client)
	{
		PrintToChat(client, "\x05loc_result: \x04%f", RankMod);
	}
	else
	{
		PrintToServer("local_result: %f", RankMod);
	}
	return Plugin_Continue;
}

void ADPlayerSpawn(Event event)
{
	if (hm_autodifficulty_forcehp.IntValue < 1) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && GetClientTeam(client) == TEAM_INFECTED) switch(GetClientZC(client))
	{
		case ZC_SMOKER: SetEntityHealth(client, FindConVar("z_gas_health").IntValue);
		case ZC_BOOMER: SetEntityHealth(client, FindConVar("z_exploding_health").IntValue);
		case ZC_HUNTER: SetEntityHealth(client, FindConVar("z_hunter_health").IntValue);
		case ZC_SPITTER: SetEntityHealth(client, FindConVar("z_spitter_health").IntValue);
		case ZC_JOCKEY: SetEntityHealth(client, FindConVar("z_jockey_health").IntValue);
		case ZC_CHARGER: SetEntityHealth(client, FindConVar("z_charger_health").IntValue);
		case ZC_TANK: SetEntityHealth(client, FindConVar("z_tank_health").IntValue * 2);
	}
}

public Action Command_melee(int client, int args)
{
	if (IsClientInGame(client))
	{
		PrintToChat(client, "\x05melee damage for bosses: \x04%d \x05| melee damage for bosses (HEADSHOT): \x04%d", FindConVar("hm_meleefix_boomer").IntValue, FindConVar("hm_meleefix_boomer_headshot").IntValue);
		PrintToChat(client, "\x05melee damage for tank: \x04%d \x05| tank headshot: \x04%d \x05| witch: \x04%d", FindConVar("hm_meleefix_tank").IntValue, FindConVar("hm_meleefix_tank_headshot").IntValue, FindConVar("hm_meleefix_witch").IntValue);
	}
	return Plugin_Continue;
}

public Action Command_ammo(int client, int args)
{
	if (IsClientInGame(client))
	{
		PrintToChat(client, "\x05witches: \x04%d \x05| ammochance medbox: \x04%d \x05| ammochance healbox: \x04%d", FindConVar("l4d2_ammo_witches").IntValue, FindConVar("l4d2_ammochance_medbox").IntValue, FindConVar("l4d2_ammochance_healbox").IntValue);
	}
	return Plugin_Continue;
}

public Action Command_damage(int client, int args)
{
	if (IsClientInGame(client))
	{
		if (hm_damage_type != null)
		{
			int dmgType = hm_damage_type.IntValue;
			if (dmgType == 1)
			{
				PrintToChat(client, "\x05awp damage: \x04%d \x05| ak47 damage: \x04%d", hm_damage_awp.IntValue / 1000 * 143, hm_damage_ak47.IntValue / 1000 * 72);
				PrintToChat(client, "\x05scout damage: \x04%d \x05| m60 damage: \x04%d", hm_damage_scout.IntValue / 1000 * 112, hm_damage_m60.IntValue / 1000 * 62);
				PrintToChat(client, "\x05spas damage: \x04%d \x05| sg552 damage: \x04%d", hm_damage_spas.IntValue / 1000 * 22, hm_damage_sg552.IntValue / 1000 * 36);
			}
			else if (dmgType == 2)
			{
				PrintToChat(client, "\x05awp damage: \x04%d \x05| ak47 damage: \x04%d", hm_damage2_awp.IntValue, hm_damage2_ak47.IntValue);
				PrintToChat(client, "\x05scout damage: \x04%d \x05| m60 damage: \x04%d", hm_damage2_scout.IntValue, hm_damage2_m60.IntValue);
				PrintToChat(client, "\x05spas damage: \x04%d \x05| sg552 damage: \x04%d", hm_damage2_spas.IntValue, hm_damage2_sg552.IntValue);
			}
		}
	}
	return Plugin_Continue;
}

public Action Command_swd(int client, int args)
{
	FindConVar("hm_damage_showvalue").IntValue = 1;
	PrintToChat(client, "\x05 Pantalla de daño \x04Activada");
	return Plugin_Continue;
}

public Action Command_swdoff(int client, int args)
{
	FindConVar("hm_damage_showvalue").IntValue = 0;
	PrintToChat(client, "\x05 Pantalla de daños \x04Desactivada");
	return Plugin_Continue;
}

public Action Command_ddfull(int client, int args)
{
	Command_melee(client, args);
	Command_ammo(client, args);
	Command_damage(client, args);
	return Plugin_Continue;
}

int IsTankAlive()
{
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		if (IsClientInGame(i))
		{
			if (IsPlayerAlive(i))
			{
				if (GetClientZC(i) == ZC_TANK && !IsIncapacitated(i))
				{
					return 1;
				}
			}
		}
	}
	return 0;
}

public bool IsIncapacitated(int client)
{
	int isIncap = GetEntProp(client, Prop_Send, "m_isIncapacitated");
	if (isIncap)
	{
		return true;
	}
	return false;
}

stock int GetRealClientCount(bool inGameOnly = true)
{
	int clients = 0;
	if (inGameOnly)
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		if (IsClientInGame(i))
		{
			if (!IsFakeClient(i))
			{
				clients++;
			}
		}
	}
	return clients;
}

void UpdateServerUpTime()
{
	char str_uptime_temp[8];
	int Current_UpTime = GetTime() - UpTime;
	int Days = RoundToFloor(Current_UpTime / 86400.0);
	Current_UpTime -= Days * 86400;
	if (Days > 0)
	{
		if (Days > 1) Format(Server_UpTime, sizeof(Server_UpTime), "%d days ", Days);
		else Format(Server_UpTime, sizeof(Server_UpTime), "1 day ");
	}
	else Server_UpTime = "";
	int Hours = RoundToFloor(Current_UpTime / 3600.0);
	if (Hours < 10) Format(str_uptime_temp, sizeof(str_uptime_temp), "0%d:", Hours);
	else Format(str_uptime_temp, sizeof(str_uptime_temp), "%d:", Hours);
	StrCat(Server_UpTime, sizeof(Server_UpTime), str_uptime_temp);
	Current_UpTime -= Hours * 3600;
	FormatTime(str_uptime_temp, sizeof(str_uptime_temp), "%M:%S", Current_UpTime);
	StrCat(Server_UpTime, sizeof(Server_UpTime), str_uptime_temp);
}

public Action Command_pinfo(int client, int args)
{
	if (client > 0 && args < 1)
	{
		ShowMyPanel(client);
	}
	return Plugin_Handled;
}

int ShowMyPanel(int client)
{
	Panel panel = new Panel();
	char text[1024], sFormattedTime[24], Mapname[128];
	FormatTime(sFormattedTime, sizeof(sFormattedTime), "%m/%d/%Y - %H:%M:%S", GetTime());
	GetCurrentMap(Mapname, sizeof(Mapname));
	UpdateServerUpTime();
	Format(text, sizeof(text), "%t", "•UKSupercoop•(7.4) | UpTime: %s (panel)", Server_UpTime);
	panel.SetTitle(text, false);
	if (RDifficultyMultiplier >= 1000.0)
	{
		char MapDifficultyMultiplier[8];
		FloatToString(RDifficultyMultiplier, MapDifficultyMultiplier, sizeof(MapDifficultyMultiplier));
		Format(text, sizeof(text), "%t", "Difficulty: %s x %s | Players: %i | [%i]|[%i]|[%i] (panel)", sGameDifficulty, MapDifficultyMultiplier, GetRealClientCount(true), TeamSurvivors(), TeamDead(), TeamSpectators());
		panel.DrawText(text);
	}
	else if (RDifficultyMultiplier >= 100.0)
	{
		char MapDifficultyMultiplier[7];
		FloatToString(RDifficultyMultiplier, MapDifficultyMultiplier, sizeof(MapDifficultyMultiplier));
		Format(text, sizeof(text), "%t", "Difficulty: %s x %s | Players: %i | [%i]|[%i]|[%i] (panel)", sGameDifficulty, MapDifficultyMultiplier, GetRealClientCount(true), TeamSurvivors(), TeamDead(), TeamSpectators());
		panel.DrawText(text);
	}
	else if (RDifficultyMultiplier >= 10.0)
	{
		char MapDifficultyMultiplier[6];
		FloatToString(RDifficultyMultiplier, MapDifficultyMultiplier, sizeof(MapDifficultyMultiplier));
		Format(text, sizeof(text), "%t", "Difficulty: %s x %s | Players: %i | [%i]|[%i]|[%i] (panel)", sGameDifficulty, MapDifficultyMultiplier, GetRealClientCount(true), TeamSurvivors(), TeamDead(), TeamSpectators());
		panel.DrawText(text);
	}
	else
	{
		char MapDifficultyMultiplier[5];
		FloatToString(RDifficultyMultiplier, MapDifficultyMultiplier, sizeof(MapDifficultyMultiplier));
		Format(text, sizeof(text), "%t", "Difficulty: %s x %s | Players: %i | [%i]|[%i]|[%i] (panel)", sGameDifficulty, MapDifficultyMultiplier, GetRealClientCount(true), TeamSurvivors(), TeamDead(), TeamSpectators());
		panel.DrawText(text);
	}
	if (IsTankAlive())
	{
		char Message[256], TempMessage[64];
		Format(TempMessage, sizeof(TempMessage), "%t", "Tank HP: (panel)");
		StrCat(Message, sizeof(Message), TempMessage);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (GetClientTeam(i) == TEAM_INFECTED && !IsIncapacitated(i) && IsPlayerAlive(i) && GetClientZC(i) == ZC_TANK && GetClientHealth(i) > 0)
				{
					Format(TempMessage, sizeof(TempMessage), "%d ", GetClientHealth(i));
					StrCat(Message, sizeof(Message), TempMessage);
				}
			}
		}
		Format(TempMessage, sizeof(TempMessage), "%t", "| Witch HP: %i | Zombie HP: %i (panel)", FindConVar("z_witch_health").IntValue, FindConVar("z_health").IntValue);
		StrCat(Message, sizeof(Message), TempMessage);
		panel.DrawText(Message);
	}
	else
	{
		Format(text, sizeof(text), "%t", "Tank HP: %i | Witch HP: %i | Zombie HP: %i (panel)", GetTankHP(), FindConVar("z_witch_health").IntValue, FindConVar("z_health").IntValue);
		panel.DrawText(text);
	}
	Format(text, sizeof(text), "%t", "Hunter HP: %i | Smoker HP: %i | Boomer HP: %i (panel)", FindConVar("z_hunter_health").IntValue, FindConVar("z_gas_health").IntValue, FindConVar("z_exploding_health").IntValue);
	panel.DrawText(text);
	Format(text, sizeof(text), "%t", "Charger HP: %i | Spitter HP: %i | Jockey HP: %i (panel)", FindConVar("z_charger_health").IntValue, FindConVar("z_spitter_health").IntValue, FindConVar("z_jockey_health").IntValue);
	panel.DrawText(text);
	Format(text, sizeof(text), "%t", "Grenade Launcher Damage: %d. Server time: %s (panel)", FindConVar("grenadelauncher_damage").IntValue, sFormattedTime);
	panel.DrawText(text);
	Format(text, sizeof(text), "%t", "CurrentMap: %s (panel)", Mapname);
	panel.DrawText(text);
	panel.DrawItem("Close");
	panel.Send(client, PanelHandler, 30);
	delete panel;
	return 0;
}

public int PanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	return 0;
}

public Action cmd_Say(int client, int args)
{
	char Text[192];
	int Start = 0;
	GetCmdArgString(Text, sizeof(Text));
	int TextLen = strlen(Text);
	if (0 >= TextLen)
	{
		return Plugin_Continue;
	}
	if (Text[strlen(Text)-1] == '"')
	{
		Text[strlen(Text)-1] = '\0';
		 
		Start = 1;
	}
	return HandleCommands(client, Text[Start]);
}

public Action HandleCommands(int client, char[] Text)
{
	if (strcmp(Text, "!info2", false))
	{
		if (!(strcmp(Text, "/info2", false)))
		{
			Command_info2(client, 0);
			return Plugin_Handled;
		}
	}
	else
	{
		Command_info2(client, 0);
	}
	return Plugin_Continue;
}

public void DamageOnPluginStart()
{
	hm_damage = CreateConVar("hm_damage", "1", "Enable/Disable damage");
	hm_damage_friendly = CreateConVar("hm_damage_friendly", "0.3", "Enable/Disable ff damage");
	hm_damage_showvalue = CreateConVar("hm_damage_showvalue", "0", "Enable/Disable show damage");
	hm_damage_hunter = CreateConVar("hm_damage_hunter", "1.0", "Hunter additional damage");
	hm_damage_smoker = CreateConVar("hm_damage_smoker", "1.2", "Smoker additional damage");
	hm_damage_boomer = CreateConVar("hm_damage_boomer", "1.2", "Boomer additional damage");
	hm_damage_spitter1 = CreateConVar("hm_damage_spitter1", "1.2", "Spitter additional damage");
	hm_damage_spitter2 = CreateConVar("hm_damage_spitter2", "4", "Spitter additional damage (spit)");
	hm_damage_jockey = CreateConVar("hm_damage_jockey", "1.2", "Jockey additional damage");
	hm_damage_charger = CreateConVar("hm_damage_charger", "1.2", "Charger additional damage");
	hm_damage_tank = CreateConVar("hm_damage_tank", "1.0", "Tank additional damage");
	hm_damage_tankrock = CreateConVar("hm_damage_tankrock", "1.0", "Tank additional damage");
	hm_damage_common = CreateConVar("hm_damage_common", "0", "Common additional damage");
	hm_damage_type = CreateConVar("hm_damage_type", "2", "damage type");
	hm_damage_ak47 = CreateConVar("hm_damage_ak47", "2523", "AK47 additional damage");
	hm_damage2_ak47 = CreateConVar("hm_damage2_ak47", "140", "AK47 damage");
	hm_damage_awp = CreateConVar("hm_damage_awp", "9486", "AWP additional damage");
	hm_damage2_awp = CreateConVar("hm_damage2_awp", "700", "AWP damage");
	hm_damage_scout = CreateConVar("hm_damage_scout", "4667", "Scout additional damage");
	hm_damage2_scout = CreateConVar("hm_damage2_scout", "420", "Scout damage");
	hm_damage_m60 = CreateConVar("hm_damage_m60", "1652", "M60 additional damage");
	hm_damage2_m60 = CreateConVar("hm_damage2_m60", "85", "M60 damage");
	hm_damage_spas = CreateConVar("hm_damage_spas", "3000", "SPAS additional damage");
	hm_damage2_spas = CreateConVar("hm_damage2_spas", "60", "SPAS damage");
	hm_damage_sg552 = CreateConVar("hm_damage_sg552", "1111", "SG552 additional damage");
	hm_damage2_sg552 = CreateConVar("hm_damage2_sg552", "70", "SG552 damage");
	hm_damage_smg = CreateConVar("hm_damage_smg", "0.6", "SMG additional damage");
	hm_damage_smg_silenced = CreateConVar("hm_damage_smg_silenced", "0.6", "SMG_SILENCED additional damage");
	hm_damage_m16 = CreateConVar("hm_damage_m16", "0.6", "M16 additional damage");
	hm_damage_pumpshotgun = CreateConVar("hm_damage_pumpshotgun", "0.6", "PUMPSHOTGUN additional damage");
	hm_damage_autoshotgun = CreateConVar("hm_damage_autoshotgun", "0.6", "AUTOSHOTGUN additional damage");
	hm_damage_hunting_rifle = CreateConVar("hm_damage_hunting_rifle", "0.6", "HUNTING_RIFLE additional damage");
	hm_damage_rifle_desert = CreateConVar("hm_damage_rifle_desert", "0.6", "RIFLE_DESERT additional damage");
	hm_damage_shotgun_chrome = CreateConVar("hm_damage_shotgun_chrome", "0.6", "SHOTGUN_CHROME additional damage");
	hm_damage_smg_mp5 = CreateConVar("hm_damage_smg_mp5", "0.6", "MP5 additional damage");
	hm_damage_sniper_military = CreateConVar("hm_damage_sniper_military", "1055", "sniper military additional damage");
	hm_damage2_sniper_military = CreateConVar("hm_damage2_sniper_military", "50", "sniper military damage");
	hm_damage_pistol = CreateConVar("hm_damage_pistol", "0.6", "pistol additional damage");
	hm_damage_pistol_magnum = CreateConVar("hm_damage_pistol_magnum", "1.0", "pistol magnum additional damage");
	hm_damage_pipebomb = CreateConVar("hm_damage_pipebomb", "90", "Pipe bomb additional damage");
	MeleeDmg[ZC_SMOKER] = CreateConVar("hm_meleefix_smoker", "1000.0", "Melee damage Smoker");
	MeleeDmg[ZC_BOOMER] = CreateConVar("hm_meleefix_boomer", "1000.0", "Melee damage Boomer");
	MeleeDmg[ZC_HUNTER] = CreateConVar("hm_meleefix_hunter", "1000.0", "Melee damage Hunter");
	MeleeDmg[ZC_JOCKEY] = CreateConVar("hm_meleefix_jockey", "1000.0", "Melee damage Jockey");
	MeleeDmg[ZC_SPITTER] = CreateConVar("hm_meleefix_spitter", "1000.0", "Melee damage Spitter");
	MeleeDmg[ZC_CHARGER] = CreateConVar("hm_meleefix_charger", "1000.0", "Melee damage Charger");
	MeleeDmg[ZC_WITCH] = CreateConVar("hm_meleefix_witch", "400.0", "Melee damage Witch");
	MeleeDmg[ZC_TANK] = CreateConVar("hm_meleefix_tank", "1000.0", "Melee damage Tank");
	MeleeHeadshotDmg[ZC_SMOKER] = CreateConVar("hm_meleefix_smoker_headshot", "2000.0", "Headshot Melee damage Smoker");
	MeleeHeadshotDmg[ZC_BOOMER] = CreateConVar("hm_meleefix_boomer_headshot", "2000.0", "Headshot Melee damage Boomer");
	MeleeHeadshotDmg[ZC_HUNTER] = CreateConVar("hm_meleefix_hunter_headshot", "2000.0", "Headshot Melee damage Hunter");
	MeleeHeadshotDmg[ZC_JOCKEY] = CreateConVar("hm_meleefix_jockey_headshot", "2000.0", "Headshot Melee damage Jockey");
	MeleeHeadshotDmg[ZC_SPITTER] = CreateConVar("hm_meleefix_spitter_headshot", "2000.0", "Headshot Melee damage Spitter");
	MeleeHeadshotDmg[ZC_CHARGER] = CreateConVar("hm_meleefix_charger_headshot", "2000.0", "Headshot Melee damage Charger");
	MeleeHeadshotDmg[ZC_TANK] = CreateConVar("hm_meleefix_tank_headshot", "1000.0", "Headshot Melee damage Tank");
	HookConVarChange(MeleeDmg[ZC_SMOKER], ConVarChanged);
	HookConVarChange(MeleeDmg[ZC_BOOMER], ConVarChanged);
	HookConVarChange(MeleeDmg[ZC_HUNTER], ConVarChanged);
	HookConVarChange(MeleeDmg[ZC_JOCKEY], ConVarChanged);
	HookConVarChange(MeleeDmg[ZC_SPITTER], ConVarChanged);
	HookConVarChange(MeleeDmg[ZC_CHARGER], ConVarChanged);
	HookConVarChange(MeleeDmg[ZC_WITCH], ConVarChanged);
	HookConVarChange(MeleeDmg[ZC_TANK], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[ZC_SMOKER], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[ZC_BOOMER], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[ZC_HUNTER], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[ZC_JOCKEY], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[ZC_SPITTER], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[ZC_CHARGER], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[ZC_TANK], ConVarChanged);
	HookEvent("player_hurt", Event_DPlayerHurt, EventHookMode_Pre);
	HookEvent("witch_spawn", OnWitchSpawn_Event, EventHookMode_Post);
	HookEvent("witch_killed", OnWitchKilled_Event, EventHookMode_Post);
	ConVarsInit();
	for (int x = 1; x <= L4D_MAXPLAYERS; x++)
	{
		if (ValidClient(x))
		{
			SDKHook(x, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public void OnPluginEnd()
{
	for (int x = 1; x <= L4D_MAXPLAYERS; x++)
	{
		if (ValidClient(x))
		{
			SDKUnhook(x, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

int ValidClient(int ok)
{
	if (ok > 0 && ok <= MaxClients && IsClientConnected(ok) && IsClientInGame(ok))
	{
		return 1;
	}
	return 0;
}

public void ConVarChanged(Handle hVariable, char[] strOldValue, char[] strNewValue)
{
	ConVarsInit();
}

public void ConVarsInit()
{
	DamageBody[ZC_SMOKER] = MeleeDmg[ZC_SMOKER].FloatValue;
	DamageBody[ZC_BOOMER] = MeleeDmg[ZC_BOOMER].FloatValue;
	DamageBody[ZC_HUNTER] = MeleeDmg[ZC_HUNTER].FloatValue;
	DamageBody[ZC_JOCKEY] = MeleeDmg[ZC_JOCKEY].FloatValue;
	DamageBody[ZC_SPITTER] = MeleeDmg[ZC_SPITTER].FloatValue;
	DamageBody[ZC_CHARGER] = MeleeDmg[ZC_CHARGER].FloatValue;
	DamageBody[ZC_WITCH] = MeleeDmg[ZC_WITCH].FloatValue;
	DamageBody[ZC_TANK] = MeleeDmg[ZC_TANK].FloatValue;
	DamageHeadshot[ZC_SMOKER] = MeleeHeadshotDmg[ZC_SMOKER].FloatValue;
	DamageHeadshot[ZC_BOOMER] = MeleeHeadshotDmg[ZC_BOOMER].FloatValue;
	DamageHeadshot[ZC_HUNTER] = MeleeHeadshotDmg[ZC_HUNTER].FloatValue;
	DamageHeadshot[ZC_JOCKEY] = MeleeHeadshotDmg[ZC_JOCKEY].FloatValue;
	DamageHeadshot[ZC_SPITTER] = MeleeHeadshotDmg[ZC_SPITTER].FloatValue;
	DamageHeadshot[ZC_CHARGER] = MeleeHeadshotDmg[ZC_CHARGER].FloatValue;
	DamageHeadshot[ZC_TANK] = MeleeHeadshotDmg[ZC_TANK].FloatValue;
}

public void OnAllPluginsLoaded()
{
	g_bLmcActive = LibraryExists("LMCCore") || LibraryExists("L4D2ModelChanger");

	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	if(i != 0 && IsClientInGame(i))
	{
		SDKHook(i, SDKHook_TraceAttack, OnTraceAttack);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

void DMOnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_TraceAttack, OnTraceAttack);
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnWitchSpawn_Event(Event event, char[] name, bool dontBroadcast)
{
	if (DamageBody[ZC_WITCH] == 0.0) return;
	int witch = event.GetInt("witchid");
	if (witch < 1 || !IsValidEntity(witch)) return;
	SDKHook(witch, SDKHook_OnTakeDamage, OnWitchTakeDamage);
}

public void OnWitchKilled_Event(Event event, char[] name, bool dontBroadcast)
{
	if (DamageBody[ZC_WITCH] == 0.0) return;
	int witch = event.GetInt("witchid");
	if (witch < 1 || !IsValidEntity(witch)) return;
	SDKUnhook(witch, SDKHook_OnTakeDamage, OnWitchTakeDamage);
}

public Action OnWitchTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!damage || attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) == 2) return Plugin_Continue;
	char clsname[64];
	GetEdictClassname(inflictor, clsname, sizeof(clsname));
	if (!StrEqual(clsname, "weapon_melee", true)) return Plugin_Continue;
	damage = DamageBody[ZC_WITCH];
	return Plugin_Continue;
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (0.0 == damage || victim < 1 || victim > MaxClients || !IsClientInGame(victim) || GetClientTeam(victim) == 3 || attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) == 2) return Plugin_Continue;
	char clsname[64];
	GetEdictClassname(inflictor, clsname, sizeof(clsname));
	if (!StrEqual(clsname, "weapon_melee", true)) return Plugin_Continue;
	int zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	if ((zClass > 0 && zClass < 7) || zClass == 8)
	{
		if (0.0 == DamageBody[zClass])
		{
			return Plugin_Continue;
		}
		if (hitgroup == 1)
		{
			if (DamageHeadshot[zClass] == 0.0)
			{
				return Plugin_Continue;
			}
			damage = DamageHeadshot[zClass];
			return Plugin_Changed;
		}
		damage = DamageBody[zClass];
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (hm_damage.IntValue == 1 && !victim) return Plugin_Continue;
	if (inflictor > L4D_MAXPLAYERS || attacker > L4D_MAXPLAYERS || !attacker || damage == 0.0) return Plugin_Continue;
	char Weapon[32];
	GetClientWeapon(attacker, Weapon, sizeof(Weapon));
	float original_damage = damage;
	if (damagetype == 128)
	{
		if (StrEqual(Weapon, "weapon_boomer_claw", true))
		{
			damage = damage * hm_damage_boomer.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_charger_claw", true))
		{
			damage = damage * hm_damage_charger.FloatValue;
		}
		else if  (StrEqual(Weapon, "weapon_hunter_claw", true))
		{
			damage = damage * hm_damage_hunter.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_smoker_claw", true))
		{
			damage = damage * hm_damage_smoker.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_spitter_claw", true))
		{
			damage = damage * hm_damage_spitter1.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_jockey_claw", true))
		{
			damage = damage * hm_damage_jockey.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_tank_claw", true))
		{
			damage = damage * hm_damage_tank.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_tank_rock", true))
		{
			damage = damage * hm_damage_tankrock.FloatValue;
		}
	}
	else if (GetConVarInt(hm_damage_type) == 1)
	{
		if (StrEqual(Weapon, "weapon_rifle_ak47", true))
		{
			damage = damage * hm_damage_ak47.FloatValue / 1000;
		}
		else if (StrEqual(Weapon, "weapon_sniper_awp", true))
		{
			damage = damage * hm_damage_awp.FloatValue / 1000;
		}
		else if (StrEqual(Weapon, "weapon_sniper_scout", true))
		{
			damage = damage * hm_damage_scout.FloatValue / 1000;
		}
		else if (StrEqual(Weapon, "weapon_rifle_m60", true))
		{
			damage = damage * hm_damage_m60.FloatValue / 1000;
		}
		else if (StrEqual(Weapon, "weapon_shotgun_spas", true))
		{
			damage = damage * hm_damage_spas.FloatValue / 1000;
		}
		else if (StrEqual(Weapon, "weapon_rifle_sg552", true))
		{
			damage = damage * hm_damage_sg552.FloatValue / 1000;
		}
		else if (StrEqual(Weapon, "weapon_smg", true))
		{
			damage = damage * hm_damage_smg.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_smg_silenced", true))
		{
			damage = damage * hm_damage_smg_silenced.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_rifle", true))
		{
			damage = damage * hm_damage_m16.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_pumpshotgun", true))
		{
			damage = damage * hm_damage_pumpshotgun.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_autoshotgun", true))
		{
			damage = damage * hm_damage_autoshotgun.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_hunting_rifle", true))
		{
			damage = damage * hm_damage_hunting_rifle.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_rifle_desert", true))
		{
			damage = damage * hm_damage_rifle_desert.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_shotgun_chrome", true))
		{
			damage = damage * hm_damage_shotgun_chrome.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_smg_mp5", true))
		{
			damage = damage * hm_damage_smg_mp5.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_sniper_military", true))
		{
			damage = damage * hm_damage_sniper_military.FloatValue / 1000;
		}
		else if (StrEqual(Weapon, "weapon_pistol", true))
		{
			damage = damage * hm_damage_pistol.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_pistol_magnum", true))
		{
			damage = damage * hm_damage_pistol_magnum.FloatValue;
		}
	}
	else if (hm_damage_type.IntValue == 2)
	{
		if (StrEqual(Weapon, "weapon_rifle_ak47", true))
		{
			damage = hm_damage2_ak47.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_sniper_awp", true))
		{
			damage = hm_damage2_awp.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_sniper_scout", true))
		{
			damage = hm_damage2_scout.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_rifle_m60", true))
		{
			damage = hm_damage2_m60.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_shotgun_spas", true))
		{
			damage = hm_damage2_spas.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_rifle_sg552", true))
		{
			damage = hm_damage2_sg552.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_smg", true))
		{
			damage = damage * hm_damage_smg.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_smg_silenced", true))
		{
			damage = damage * hm_damage_smg_silenced.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_rifle", true))
		{
			damage = damage * hm_damage_m16.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_pumpshotgun", true))
		{
			damage = damage * hm_damage_pumpshotgun.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_autoshotgun", true))
		{
			damage = damage * hm_damage_autoshotgun.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_hunting_rifle", true))
		{
			damage = damage * hm_damage_hunting_rifle.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_rifle_desert", true))
		{
			damage = damage * hm_damage_rifle_desert.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_shotgun_chrome", true))
		{
			damage = damage * hm_damage_shotgun_chrome.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_smg_mp5", true))
		{
			damage = damage * hm_damage_smg_mp5.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_sniper_military", true))
		{
			damage = hm_damage2_sniper_military.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_pistol", true))
		{
			damage = damage * hm_damage_pistol.FloatValue;
		}
		else if (StrEqual(Weapon, "weapon_pistol_magnum", true))
		{
			damage = damage * hm_damage_pistol_magnum.FloatValue;
		}
	}
	else if (original_damage != damage)
	{
		if (GetClientTeam(victim) == 2 && GetClientTeam(attacker) == 2)
		{
			if (!IsPlayerIncapped(victim))
			{
				damage *= hm_damage_friendly.FloatValue;
				if (damage >= 1.0 * GetHealth(victim))
				{
					damage = 1.0 * GetHealth(victim) - 1;
				}
			}
			damage = damage * hm_damage_friendly.FloatValue * 0.5;
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void IncapTarget(int target)
{
	if (IsValidEntity(target))
	{
		int iDmgEntity = CreateEntityByName("point_hurt");
		SetEntityHealth(target, 1);
		DispatchKeyValue(target, "targetname", "bm_target");
		DispatchKeyValue(iDmgEntity, "DamageTarget", "bm_target");
		DispatchKeyValue(iDmgEntity, "Damage", "100");
		DispatchKeyValue(iDmgEntity, "DamageType", "0");
		DispatchSpawn(iDmgEntity);
		AcceptEntityInput(iDmgEntity, "Hurt", target);
		DispatchKeyValue(target, "targetname", "bm_targetoff");
		RemoveEdict(iDmgEntity);
	}
}

public Action Event_DPlayerHurt(Event event, char[] name, bool dontBroadcast)
{
	if (hm_damage.IntValue < 1) return Plugin_Continue;
	int enemy = GetClientOfUserId(event.GetInt("attacker"));
	int target = GetClientOfUserId(event.GetInt("userid"));
	int dmg_health = event.GetInt("dmg_health");
	int damagetype = event.GetInt("type");
	if ((hm_damage.IntValue < 2 && damagetype == 128) || (target && !dmg_health)) return Plugin_Continue;
	char weapon[16];
	event.GetString("weapon", weapon, sizeof(weapon), "");
	int hardmod_damage = 0;
	if (StrEqual(weapon, "insect_swarm", false)) hardmod_damage = hm_damage_spitter2.IntValue;
	else if (StrEqual(weapon, "pipe_bomb", false)) hardmod_damage = hm_damage_pipebomb.IntValue;
	else if (StrEqual(weapon, "", false)) hardmod_damage = hm_damage_common.IntValue;
	else if (hm_damage.IntValue > 1 && enemy)
	{
			if (damagetype == 128)
			{
				if (StrEqual(weapon, "boomer_claw", true)) hardmod_damage = hm_damage_boomer.IntValue;
				else if (StrEqual(weapon, "charger_claw", true)) hardmod_damage = hm_damage_charger.IntValue;
				else if (StrEqual(weapon, "hunter_claw", true)) hardmod_damage = hm_damage_hunter.IntValue;
				else if (StrEqual(weapon, "smoker_claw", true)) hardmod_damage = hm_damage_smoker.IntValue;
				else if (StrEqual(weapon, "spitter_claw", true)) hardmod_damage = hm_damage_spitter1.IntValue;
				else if (StrEqual(weapon, "jockey_claw", true)) hardmod_damage = hm_damage_jockey.IntValue;
				else if (StrEqual(weapon, "tank_claw", true)) hardmod_damage = hm_damage_tank.IntValue;
				else if (StrEqual(weapon, "tank_rock", true)) hardmod_damage = hm_damage_tankrock.IntValue;
			}
			else 
			{
				if (StrEqual(weapon, "rifle_ak47", true)) hardmod_damage = hm_damage_ak47.IntValue;
				else if (StrEqual(weapon, "sniper_awp", true)) hardmod_damage = hm_damage_awp.IntValue;
				else if (StrEqual(weapon, "sniper_scout", true)) hardmod_damage = hm_damage_scout.IntValue;
				else if (StrEqual(weapon, "rifle_m60", true)) hardmod_damage = hm_damage_m60.IntValue;
				else if (StrEqual(weapon, "shotgun_spas", true)) hardmod_damage = hm_damage_spas.IntValue;
				else if (StrEqual(weapon, "rifle_sg552", true)) hardmod_damage = hm_damage_sg552.IntValue;
				else if (StrEqual(weapon, "smg", true)) hardmod_damage = hm_damage_smg.IntValue;
				else if (StrEqual(weapon, "smg_silenced", true)) hardmod_damage = hm_damage_smg_silenced.IntValue;
				else if (StrEqual(weapon, "rifle", true)) hardmod_damage = hm_damage_m16.IntValue;
				else if (StrEqual(weapon, "pumpshotgun", true)) hardmod_damage = hm_damage_pumpshotgun.IntValue;
				else if (StrEqual(weapon, "autoshotgun", true)) hardmod_damage = hm_damage_autoshotgun.IntValue;
				else if (StrEqual(weapon, "hunting_rifle", true)) hardmod_damage = hm_damage_hunting_rifle.IntValue;
				else if (StrEqual(weapon, "rifle_desert", true)) hardmod_damage = hm_damage_rifle_desert.IntValue;
				else if (StrEqual(weapon, "shotgun_chrome", true)) hardmod_damage = hm_damage_shotgun_chrome.IntValue;
				else if (StrEqual(weapon, "smg_mp5", true)) hardmod_damage = hm_damage_smg_mp5.IntValue;
				else if (StrEqual(weapon, "sniper_military", true)) hardmod_damage = hm_damage_sniper_military.IntValue;
				else if (StrEqual(weapon, "pistol", true)) hardmod_damage = hm_damage_pistol.IntValue;
				else if (StrEqual(weapon, "pistol_magnum", true)) hardmod_damage = hm_damage_pistol_magnum.IntValue;
			}
	}
	if (hardmod_damage > 0)
	{
		if (enemy && GetClientTeam(target) == 2 && GetClientTeam(enemy) == 2)
		{
			hardmod_damage = RoundToNearest(hardmod_damage * hm_damage_friendly.FloatValue);
		}
		dmg_health = hardmod_damage + dmg_health;
		event.SetInt("dmg_health", dmg_health);
		DamageTarget(target, hardmod_damage);
	}
	if (hm_damage_showvalue.IntValue > 0)
	{
		if (IsValidClient(enemy) && !IsFakeClient(enemy))
		{
			PrintHintText(enemy, "%d", dmg_health);
			PrintToChat(enemy, "\x05(damage) \x04%d", dmg_health);
		}
		if (IsValidClient(target) && !IsFakeClient(target))
		{
			PrintHintText(target, "-%d", dmg_health);
		}
	}
	return Plugin_Continue;	
}

public void DamageTarget(any client, int damage)
{
	if (GetHealth(client) < 1) return;
	int HP = GetHealth(client);
	if (HP > damage)
	{
		SetEntityHealth(client, HP - damage);
	}
	else
	{
		if (HP > 1)
		{
			damage -= HP -1;
			SetEntityHealth(client, 1);
		}
		int TempHP = GetClientTempHealth(client);
		if (TempHP >= damage)
		{
			SetTempHealth(client, TempHP - damage);
		}
		else
		{
			if (GetClientTeam(client) == 2 && !IsGoingToDie(client))
			{
				IncapTarget(client);
			}
			else
			{
				if (hm_damage.IntValue > 2)
				{
					DamageEffect(client, 5.0);
				}
				else
				{
					SetTempHealth(client, 0);
				}
			}
		}
	}
}

void DamageEffect(int target, float damage)
{
	char tName[20];
	Format(tName, sizeof(tName), "target%d", target);
	int pointHurt = CreateEntityByName("point_hurt");
	DispatchKeyValue(target, "targetname", tName);
	DispatchKeyValueFloat(pointHurt, "Damage", damage);
	DispatchKeyValue(pointHurt, "DamageTarget", tName);
	DispatchKeyValue(pointHurt, "DamageType", "65536");
	DispatchSpawn(pointHurt);
	AcceptEntityInput(pointHurt, "Hurt");
	AcceptEntityInput(pointHurt, "Kill");
}

public int GetHealth(int client)
{
	return GetEntProp(client,  Prop_Send, "m_iHealth");
}

int GetClientTempHealth(int client)
{
	if (!client || !IsValidEntity(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || IsClientObserver(client) || GetClientTeam(client) != TEAM_SURVIVORS)
	{
		return -1;
	}
	float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	float TempHealth = 0.0;
	if (buffer <= 0.0)
	{
		TempHealth = 0.0;
	}
	else
	{
		float difference = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
		float decay = FindConVar("pain_pills_decay_rate").FloatValue;
		float constant = 1.0 / decay;
		TempHealth = buffer - difference / constant;
	}
	if (TempHealth < 0.0)
	{
		TempHealth = 0.0;
	}
	return RoundToFloor(TempHealth);
}

public void SetTempHealth(int client, int hp)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	float newOverheal = hp * 1.0;
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

public bool IsGoingToDie(int client)
{
	if (!IsValidEntity(client) || !IsValidEdict(client))
	{
		return false;
	}
	int m_isGoingToDie = GetEntProp(client, Prop_Send, "m_isGoingToDie");
	if (m_isGoingToDie > 1)
	{
		return true;
	}
	return false;
}

stock int GetLiveSurvivorsCount(bool inGameOnly)
{
	int clients = 0;
	if (inGameOnly)
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2)
			{
				if (IsPlayerAlive(i))
				{
					clients++;
				}
			}
		}
	}
	return clients;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("LMC_GetClientOverlayModel");
	CreateNative("TYSTATS_GetPoints", Native_TYSTATS_GetPoints);
	CreateNative("TYSTATS_GetRank", Native_TYSTATS_GetRank);
	return APLRes_Success;
}

public int Native_TYSTATS_GetPoints(Handle plugin, int numParams)
{
	return ClientPoints[GetNativeCell(1)];
}

public int Native_TYSTATS_GetRank(Handle plugin, int numParams)
{
	return ClientRank[GetNativeCell(1)];
}

public void OnPluginStart()
{
	LoadTranslations("l4d2_stats.phrases");
	BuildPath(Path_SM, datafilepath, sizeof(datafilepath), "configs/tystats.txt");
	ConnectDB();
	CoopAutoDiffOnPluginStart();
	DamageOnPluginStart();
	RegConsoleCmd("callvote", Callvote_Handler, "");
	hm_blockvote_kick = CreateConVar("hm_blockvote_kick", "1", "");
	hm_blockvote_map = CreateConVar("hm_blockvote_map", "1", "");
	hm_allowvote_map_players = CreateConVar("hm_allowvote_map_players", "6", "");
	hm_blockvote_lobby = CreateConVar("hm_blockvote_lobby", "1", "");
	hm_blockvote_restart = CreateConVar("hm_blockvote_restart", "1", "");
	hm_blockvote_difficulty = CreateConVar("hm_blockvote_difficulty", "0", "");
	hm_blockvote_difference = CreateConVar("hm_blockvote_difference", "0", "");
	hm_allowvote_mission = CreateConVar("hm_allowvote_mission", "21", "");
	BuildPath(Path_SM, CV_FileName, sizeof(CV_FileName), "hardmod/forbiddenmaps.txt");
	cvar_Hunter = CreateConVar("l4d2_tystats_hunter", "4", "Base score for killing a Hunter", _, true, 1.0);
	cvar_Smoker = CreateConVar("l4d2_tystats_smoker", "4", "Base score for killing a Smoker", _, true, 1.0);
	cvar_Boomer = CreateConVar("l4d2_tystats_boomer", "3", "Base score for killing a Boomer", _, true, 1.0);
	cvar_Spitter = CreateConVar("l4d2_tystats_spitter", "5", "Base score for killing a Spitter", _, true, 1.0);
	cvar_Jockey = CreateConVar("l4d2_tystats_jockey", "4", "Base score for killing a Jockey", _, true, 1.0);
	cvar_Charger = CreateConVar("l4d2_tystats_charger", "6", "Base score for killing a Charger", _, true, 1.0);
	cvar_Witch = CreateConVar("l4d2_tystats_witch", "7", "Base score for killing a Witch", _, true, 1.0);
	cvar_Tank = CreateConVar("l4d2_tystats_tank", "10", "Base score for killing a Tank", _, true, 1.0);
	cvar_Bonus = CreateConVar("l4d2_tystats_bonus", "2", "Bonus score for killing bosses", _, true, 1.0);
	cvar_SiteURL = CreateConVar("l4d_stats_siteurl", "ruscoop25.myarena.ru/l4dstats/", "Community site URL, for rank panel display");
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("heal_success", Event_HealPlayer, EventHookMode_Post);
	HookEvent("defibrillator_used", Event_DefibPlayer, EventHookMode_Post);
	HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
	HookEvent("player_now_it", Event_PlayerNowIt, EventHookMode_Post);
	HookEvent("survivor_rescued", Event_SurvivorRescued, EventHookMode_Post);
	HookEvent("award_earned", Event_Award_L4D2, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("map_transition", Event_MapTransition, EventHookMode_Post);
	HookEvent("finale_win", Event_FinalWin, EventHookMode_Post);
	HookEvent("player_disconnect", Event_Disconnect, EventHookMode_Pre);
	HookEvent("player_left_start_area", Event_StartArea, EventHookMode_Post);
	HookEvent("player_left_checkpoint", Event_StartArea, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Post);
	HookEvent("bot_player_replace", Event_BotPlayerReplace, EventHookMode_Post);
	RegConsoleCmd("sm_myrank", cmd_ShowRank, "");
	RegConsoleCmd("sm_rank", Command_RankPlayer, "sm_rank <target>");
	RegConsoleCmd("sm_top10", cmd_ShowTop10, "");
	RegConsoleCmd("sm_top15", cmd_ShowTop15, "");
	RegConsoleCmd("sm_top20", cmd_ShowTop20, "");
	RegConsoleCmd("sm_nextrank", cmd_NextRank, "");
	RegConsoleCmd("sm_ranktarget", cmd_ShowRankTarget, "");
	RegConsoleCmd("sm_showpoints", Command_totalPoints_to_all, "");
	RegConsoleCmd("sm_points", Command_Points, "");
	RegConsoleCmd("sm_playtime", Command_Playtime, "");
	RegConsoleCmd("sm_maptop", Command_MapTop, "");
	RegConsoleCmd("sm_ranksum", Command_RankSum, "");
	RegConsoleCmd("sm_city17", Command_city17l4d2, "");
	RegConsoleCmd("sm_warcelona", Command_warcelona, "");
	RegConsoleCmd("sm_symbyosys", Command_symbyosys, "");
	RegConsoleCmd("sm_one4nine", Command_one4nine, "");
	RegAdminCmd("sm_rankpluginrefresh", Command_Refresh, ADMFLAG_CHEATS, "", "");
	RegAdminCmd("sm_mapfinished", Command_MapFinished, ADMFLAG_CHEATS, "", "");
	RegAdminCmd("sm_mapnotfinished", Command_MapNotFinished, ADMFLAG_CHEATS, "", "");
	RegAdminCmd("sm_tystatsbonus", Command_Bonus, ADMFLAG_CHEATS, "", "");
	RegAdminCmd("sm_givepoints", Command_GivePoints, ADMFLAG_ROOT, "sm_givepoints <target> [Score]", "");
	RegAdminCmd("sm_rank_motd", Command_SetMotd, ADMFLAG_GENERIC, "Set Message Of The Day", "");
	RegConsoleCmd("sm_steam", Cmd_id, "id");
	RegConsoleCmd("sm_id", Cmd_id, "id");
	RegAdminCmd("sm_refresh_rank_color", Command_RefreshRankColor, ADMFLAG_CHEATS);
	g_HaveSteam_Trie = CreateTrie();
	hm_count_fails = CreateConVar("hm_count_fails", "1", "");
	hm_stats_colors = CreateConVar("hm_stats_colors", "2", "");
	hm_stats_bot_colors = CreateConVar("hm_stats_bot_colors", "1", "");
	l4d2_players_join_message_timer = CreateConVar("l4d2_players_join_message_timer", "10", "");
	l4d2_rankmod_mode = CreateConVar("l4d2_rankmod_mode", "0", "");
	l4d2_rankmod_min = CreateConVar("l4d2_rankmod_min", "0.5", "");
	l4d2_rankmod_max = CreateConVar("l4d2_rankmod_max", "1.0", "");
	l4d2_rankmod_logarithm = CreateConVar("l4d2_rankmod_logarithm", "0.008", "");
	SDifficultyMultiplier = CreateConVar("l4d2_difficulty_stats", "1.0", "");
	CreateTimer(60.0, timer_SetPlayerssPlaytime, _, TIMER_REPEAT);
	g_hUseRankCookie = RegClientCookie("glow_overlay_use_rank", "Use rank colors settings", CookieAccess_Private);
}

public void OnClientConnected(int client)
{
	g_Socket[client] = false;
	g_HaveSteam[client] = false;
	g_SteamID[client][0] = 0;
	g_ProfileID[client][0] = 0;
}

public void OnClientAuthorized(int client, const char[] steamid)
{
	if (!(StrContains(steamid, "STEAM_", false)))
	{
		strcopy(g_SteamID[client], 30, steamid);
		bool steam_client;
		if (GetTrieValue(g_HaveSteam_Trie, steamid, steam_client))
		{
			g_HaveSteam[client] = steam_client;
		}
		else
		{
			wS_GetProfileId(client);
		}
	}
	return;
}

public Action Cmd_id(int client, int args)
{
	if(args == 0)
	{
		ShowTheMenu(client);
		return Plugin_Handled;
	}
	else if(args >= 1)
	{
		char Target[64];
		GetCmdArg(1, Target, sizeof(Target));
		int itarget = FindTarget(client, Target);
		if(itarget == -1)
		{
			PrintToChat(client, "[SM] Can't find target.");
		}
		DoTheMenu(client, itarget);
	}
	return Plugin_Handled;
}

public Action ShowTheMenu(int client)
{
	Menu show = new Menu(MenuName);
	show.SetTitle("%t", "Choose a player:");
	AddTargetsToMenu(show, client, true, false);
	show.ExitButton = true;
	show.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
	
public void MenuName(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
	if(action == MenuAction_Select)
	{
		int userid, target;
		char inform[64];
		menu.GetItem(param2, inform, sizeof(inform)); 
		userid = StringToInt(inform);
		target = GetClientOfUserId(userid);
		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else
		{
		    DoTheMenu(param1, target);
		}
	}
}

public void DoTheMenu(int client, int itarget)
{
    if(client == client)
	{
		char targetname[64], targetid[64], targetid64[64], ctargetname[64],
		ctargetid[64], ctargetprofile[64], ctargetadmin[64];
		GetClientName(itarget, targetname, sizeof(targetname));
		GetClientAuthId(itarget, AuthId_Engine, targetid, sizeof(targetid));
		GetClientAuthId(itarget, AuthId_SteamID64, targetid64, sizeof(targetid64));
		if(GetUserFlagBits(itarget) & (ADMFLAG_ROOT) == (ADMFLAG_ROOT))
		{
		    Format(ctargetadmin, sizeof(ctargetadmin), "%t", "Status: Server Owner");
		}
		else if(GetUserFlagBits(itarget) & (ADMFLAG_SLAY) == (ADMFLAG_SLAY))
		{
		    Format(ctargetadmin, sizeof(ctargetadmin), "%t", "Status: Server Admin");
		}
		else
		{
		    Format(ctargetadmin, sizeof(ctargetadmin), "%t", "Status: Regular Player");
	    }
		Format(ctargetname, sizeof(ctargetname), "%t", "Name: %s", targetname);
		Format(ctargetid, sizeof(ctargetid), "ID: %s", targetid);
		Format(ctargetprofile, sizeof(ctargetprofile), "http://steamcommunity.com/profiles/%s", targetid64);
		Menu menu = new Menu(ID);
		menu.SetTitle("%t", "SteamID of %s", targetname);
		menu.AddItem("1", ctargetname, ITEMDRAW_DISABLED);
		menu.AddItem("2", ctargetid, ITEMDRAW_DISABLED);
		menu.AddItem("3", "☢UKS_Extrem☢︻┳═一☣", ITEMDRAW_DISABLED);
		menu.AddItem("4", ctargetadmin, ITEMDRAW_DISABLED);
		menu.AddItem(ctargetprofile, "Ver Perfil de Steam");
		if(StrEqual(targetid, "BOT"))
		{
			menu.RemoveItem(4);
			menu.AddItem("5", "No puedes ver el Perfil de un Bot", ITEMDRAW_DISABLED);
		}
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public void ID(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
	if(action == MenuAction_Select)
	{
		char xinfo[100];	
		menu.GetItem(param2, xinfo, sizeof(xinfo));
		if(!StrEqual(xinfo, "7"))
		{
			KeyValues kv = new KeyValues("data");
			kv.SetString("title", "Steam Profile");
			kv.SetString("msg", xinfo);
			kv.SetNum("customsvr", 1);
			kv.SetNum("type", MOTDPANEL_TYPE_URL);
			ShowVGUIPanel(client, "info", kv, true);
			kv.Close();
		}
    }
}	

bool wS_GetProfileId(int client)
{
    // Validate the client ID
    if (client < 1 || client > MAXPLAYERS)
    {
        LogError("Invalid client ID: %d", client);
        return false;
    }

    char auth[21] = "";

    // Retrieve the client's SteamID64 and validate its length
    if (GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth)) && strlen(auth) == 17)
    {
        // Calculate the index based on the 17th character of the SteamID
        int index = auth[16] - '0' - 1;

        // Validate that the index is within the expected range
        if (index >= 0 && index < MAXPLAYERS)
        {
            g_ProfileID[client][index] = '\0';
        }
        else
        {
            LogError("Index out of bounds for client %d (calculated index: %d)", client, index);
            return false;
        }
    }
    else
    {
        LogError("Failed to retrieve a valid SteamID64 for client %d: %s", client, auth);
        return false;
    }

    // Create a TCP socket for communication
    Handle socket = SocketCreate(SOCKET_TCP, OnSocketError);
    if (socket == INVALID_HANDLE)
    {
        LogError("Failed to create socket for client %d", client);
        return false;
    }

    // Set the client's UserID as an argument for the socket
    SocketSetArg(socket, GetClientUserId(client));

    // Attempt to connect to Steam Community's server
    SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, "steamcommunity.com", 80);

    return true; // Success
}  

public void OnSocketError(Handle socket, int errorType, int errorNum, any id)
{
	delete socket;
	LogError("SocketError -> errorType: %d, errorNum: %d", errorType, errorNum);
}

public void OnSocketConnected(Handle socket, any id)
{
	int client = GetClientOfUserId(id);
	if (client < 1)
	{
		delete socket;
		return;
	}
	char info[200];
	Format(info, sizeof(info), "GET /profiles/%s HTTP/1.0\r\nHost: steamcommunity.com\r\nConnection: close\r\n\r\n", g_ProfileID[client]);
	SocketSend(socket, info, -1);
}

public void OnSocketReceive(Handle socket, char[] receiveData, int dataSize, any id)
{
	if (dataSize > 0 && StrContains(receiveData, "user has not yet set", false) != -1)
	{
		wS_ClientAuthorized(socket, id, false);
	}
}

public void OnSocketDisconnected(Handle socket, any id)
{
	wS_ClientAuthorized(socket, id, true);
}

void wS_ClientAuthorized(Handle socket, int id, bool steam_client)
{
	delete socket;
	int client = GetClientOfUserId(id);
	if (client < 1)
	{
		return;
	}
	g_HaveSteam[client] = steam_client;
	g_Socket[client] = true;
	SetTrieValue(g_HaveSteam_Trie, g_SteamID[client], steam_client, true);
	return;
}

public Action timer_SetPlayerssPlaytime(Handle timer, Handle hndl)
{
	if (Rank_db != null)
	{
	    for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	    {
		    if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
		    {
			    Playtime[i] += 1;
			    PlaytimeMap[i] += 1;				
			    CheckPlayerDB(i);
			}
		}
	}
	return Plugin_Continue;
}

public void KnowRankPoints(int client)
{
	if (client && IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
	        if (Rank_db != null)
	        {
				char sQuery[104], sTeamID[24];
				GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
				Format(sQuery, sizeof(sQuery)-1, "SELECT COUNT(*) FROM players");
				SQL_TQuery(Rank_db, GetRankTotal, sQuery, client, DBPrio_Normal);
				Format(sQuery, sizeof(sQuery)-1, "SELECT points FROM players WHERE steamid = '%s'", sTeamID);
				SQL_TQuery(Rank_db, GetClientPoints, sQuery, client, DBPrio_Normal);
				CreateTimer(0.6, TimertyGetClientRank, client);
	        }
		}
	}
}

public void KnowRankKills(int client)
{
	if (client && IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
	        if (Rank_db != null)
	        {
				char sQuery[1024], sTeamID[64];
				GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
				Format(sQuery, sizeof(sQuery)-1, "SELECT kill_hunter,kill_smoker,kill_boomer,kill_spitter,kill_jockey,kill_charger,award_tankkill FROM players WHERE steamid = '%s'", sTeamID);
				SQL_TQuery(Rank_db, GetClientKills, sQuery, client, DBPrio_Normal);
	        }
		}
	}
}

public void KnowRankHeadshots(int client)
{
	if (client && IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
	        if (Rank_db != null)
	        {
				char sQuery[1024], sTeamID[64];
				GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
				Format(sQuery, sizeof(sQuery)-1, "SELECT headshots FROM players WHERE steamid = '%s'", sTeamID);
				SQL_TQuery(Rank_db, GetClientHeadshots, sQuery, client, DBPrio_Normal);
	        }
		}
	}
}

public void KnowRankPlaytime(int client)
{
	if (client && IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
	        if (Rank_db != null)
	        {
				char sQuery[512], sTeamID[64];
				GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
				Format(sQuery, sizeof(sQuery)-1, "SELECT playtime FROM players WHERE steamid = '%s'", sTeamID);
				SQL_TQuery(Rank_db, GetClientPlaytime, sQuery, client, DBPrio_Normal);
	        }
		}
	}
}

public void OnClientDisconnect(int client)
{
	DMOnClientDisconnect(client);
	g_votekick[client] = false;
	if (Join_Timer[client])
	{
		KillTimer(Join_Timer[client], false);
		Join_Timer[client] = null;
		if (Rank_db != null)
		{
			if (client)
			{
			    if (!IsFakeClient(client))
			    {				
				    NewPoints[client] = 0;
				    NewKills[client] = 0;
				    NewHeadshots[client] = 0;
				    PlaytimeMap[client] = 0;
				    KillsInfected[client] = 0;
				    ProtectedFriendlyCounter[client] = 0;
				    ClientHeadshots[client] = 0;					
			    }
	        }
		}
	}
}

public void OnClientDisconnect_Post(int client)
{
	OnClientConnected(client);
}

void UpdatePlaytimePlayers(int client)
{
	if (client && IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
	        if (Rank_db != null)
	        {
				if (Playtime[client])
				{
				    PlaytimeDB = Playtime[client] * 60;
				    char sTeamID[64], sQuery[512];
				    GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
				    Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET playtime = playtime + %i WHERE steamid = '%s'", PlaytimeDB, sTeamID);
				    SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
				    PlaytimeDB = 0;
				    Playtime[client] = 0;
				}
	        }
		}
	}
}

public Action Event_Disconnect(Event event, char[] name, bool DontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || IsFakeClient(client))
	{
		return Plugin_Continue;
	}
	char ip[16], country[48];
	if (IsClientInGame(client))
	{
		if (IsRealClient(client))
		{
			GetClientIP(client, ip, sizeof(ip), true);
			int flags = GetUserFlagBits(client);
			if (GeoipCountry(ip, country, sizeof(country)))
			{
				if (g_HaveSteam[client])
				{
					if (flags & ADMFLAG_ROOT)
					{
						CPrintToChatAll("%t {red}%N \x05[%s]", "- Owner", client, country);
					}
					else
					{
						if (flags & ADMFLAG_CUSTOM2)
						{
							CPrintToChatAll("%t {red}%N \x05[%s]", "- Admin", client, country);
						}
						else if (flags & ADMFLAG_KICK)
						{
							CPrintToChatAll("%t {red}%N \x05[%s]", "- Moderator", client, country);
						}
						else if (flags & ADMFLAG_GENERIC)
						{
							CPrintToChatAll("%t {red}%N \x05[%s]", "- VIP", client, country);
						}
						else
						{
							CPrintToChatAll("%t {blue}%N \x05[%s]", "- Player", client, country);
						}
					}
				}
				else
				{
					if (flags & ADMFLAG_ROOT)
					{
						CPrintToChatAll("%t {red}%N \x05[%s]", "- Owner", client, country);
					}
					else if (flags & ADMFLAG_CUSTOM2)
					{
						CPrintToChatAll("%t {red}%N \x05[%s]", "- Admin", client, country);
					}
					else if (flags & ADMFLAG_KICK)
					{
						CPrintToChatAll("%t {red}%N \x05[%s]", "- Moderator", client, country);
					}
					else if (flags & ADMFLAG_GENERIC)
					{
						CPrintToChatAll("%t {red}%N \x05[%s]", "- VIP", client, country);
					}
					else
					{
						CPrintToChatAll("%t {blue}%N \x05[%s]", "- Player", client, country);
					}
				}
			}
			else
			{
				if (g_HaveSteam[client])
				{
					if (flags & ADMFLAG_ROOT)
					{
						CPrintToChatAll("%t {red}%N", "- Owner", client);
					}
					else
					{
						if (flags & ADMFLAG_CUSTOM2)
						{
							CPrintToChatAll("%t {red}%N", "- Admin", client);
						}
						else if (flags & ADMFLAG_KICK)
						{
							CPrintToChatAll("%t {red}%N", "- Moderator", client);
						}
						else if (flags & ADMFLAG_GENERIC)
						{
							CPrintToChatAll("%t {red}%N", "- VIP", client);
						}
						else
						{
							CPrintToChatAll("%t {blue}%N", "- Player", client);
						}
					}
				}
				if (flags & ADMFLAG_ROOT)
				{
					CPrintToChatAll("%t {red}%N", "- Owner", client);
				}
				else if (flags & ADMFLAG_CUSTOM2)
				{
					CPrintToChatAll("%t {red}%N", "- Admin", client);
				}
				else if (flags & ADMFLAG_KICK)
				{
					CPrintToChatAll("%t {red}%N", "- Moderator", client);
				}
				else if (flags & ADMFLAG_GENERIC)
				{
					CPrintToChatAll("%t {red}%N", "- VIP", client);
				}
				else
				{
					CPrintToChatAll("%t {blue}%N", "- Player", client);
				}
			}
		}
	}
	if (!IsTimeAutodifficulty)
	{
		return Plugin_Continue;
	}
	ADPlayerTeam();
	return Plugin_Continue;
}

public Action TimertyGetClientRank(Handle timer, any client)
{
	if (client && IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
	        if (Rank_db != null)
	        {
				char sQuery[256];
				Format(sQuery, sizeof(sQuery)-1, "SELECT COUNT(*) FROM players WHERE points >=%i", ClientPoints[client]);
				SQL_TQuery(Rank_db, GetClientRank, sQuery, client, DBPrio_Normal);
			}
		}
	}
	return Plugin_Stop;
}

public void GetClientPoints(Handle owner, Handle hndl, char[] error, any client)
{
	if (client > 0)
	{
		if (hndl != null)
		{
			while (SQL_FetchRow(hndl))
			{
				ClientPoints[client] = SQL_FetchInt(hndl, 0);
			}
		}
	}
}

public void GetClientKills(Handle owner, Handle hndl, char[] error, any client)
{
	if (client > 0)
	{
		if (hndl != null)
		{
			while (SQL_FetchRow(hndl))
			{
				ClientKills[client] = SQL_FetchInt(hndl, 6) + SQL_FetchInt(hndl, 5) + SQL_FetchInt(hndl, 4) + SQL_FetchInt(hndl, 3) + SQL_FetchInt(hndl, 2) + SQL_FetchInt(hndl, 1) + SQL_FetchInt(hndl, 0);
			}
		}
	}
}
	
public void GetClientHeadshots(Handle owner, Handle hndl, char[] error, any client)
{
	if (client > 0)
	{
		if (hndl != null)
		{
			while (SQL_FetchRow(hndl))
			{
				ClientHeadshots[client] = SQL_FetchInt(hndl, 0);
			}
		}
	}
}

public void GetClientPlaytime(Handle owner, Handle hndl, char[] error, any client)
{
	if (client > 0)
	{
		if (hndl != null)
		{
			while (SQL_FetchRow(hndl))
			{
				ClientPlaytime[client] = SQL_FetchInt(hndl, 0);
			}
		}
	}
}

public void GetClientRank(Handle owner, Handle hndl, char[] error, any client)
{
	if (client > 0)
	{
		if (hndl != null)
		{
			while (SQL_FetchRow(hndl))
			{
				ClientRank[client] = SQL_FetchInt(hndl, 0);
			}
		}
	}
}

public void GetRankTotal(Handle owner, Handle hndl, char[] error, any data)
{
	if (hndl != null)
	{
		while (SQL_FetchRow(hndl))
		{
			RankTotal = SQL_FetchInt(hndl, 0);
		}
	}
}

public void updateptystatslayers()
{
	int round_fails = round_end_repeats;
	if (round_end_repeats > 3)
	{
		round_fails = 3;
	}
	if (GetRealtyClientCount(true) > 15)
	{
		tystatsbalans = 3 - round_fails;
	}
	else if (GetRealtyClientCount(true) > 8)
	{
		tystatsbalans = 2 - round_fails;
	}
	else if (GetRealtyClientCount(true) > 4)
	{
		tystatsbalans = 1 - round_fails;
	}
	else 
	{
		tystatsbalans = 0;
	}

	return;
}

public void OnMapStart()
{
	ADOnMapStart();
	IsTimeAutodifficulty = false;
	round_end_repeats = 0;
	PrecacheSound("buttons/blip1.wav", true);
	PrecacheSound("level/countdown.wav", true);
	PrecacheSound("level/bell_normal.wav", true);
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		g_votekick[i] = 0;
	}
}

public void Event_RoundStart(Event event, char[] strName, bool DontBroadcast)
{
	ADRoundStart();
	IsMapFinished = false;
	IsRoundStarted = true;
	tystatsbalans = 0;
	bonus = 0;
	MapTimingStartTime = 0.0;
	CreateTimer(6.0, TimedColortystats);
	CreateTimer(25.0, TimedAutoDifficultyInit);
}

public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	if (!IsRoundStarted)
	{
		return;
	}
	round_end_repeats += 1;
}

public Action TimedColortystats(Handle timer, any client)
{
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		if (IsValidEntity(i) && IsClientInGame(i) && !IsFakeClient(i))
		{
			RanktyConnect(i);
		}
	}
	return Plugin_Continue;
}

public Action TimedAutoDifficultyInit(Handle timer, any client)
{
	IsTimeAutodifficulty = true;
	AutoDifficultyInit();
	Autodifficulty();
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidEntity(client))
	{
	    if (!IsFakeClient(client))
	    {
	        Join_Timer[client] = CreateTimer(1.0 * l4d2_players_join_message_timer.IntValue, PlayerJoinMessage, client, 0);
	        if (Rank_db != null)
	        {
		        TKblockPunishment[client] = 0;
		        TKblockDamage[client] = 0;
		        ClientPoints[client] = 0;
		        ClientRank[client] = 0;
		        ClientKills[client] = 0;
		        NewKills[client] = 0;
		        NewHeadshots[client] = 0;
		        ProtectedFriendlyCounter[client] = 0;
		        ClientPlaytime[client] = 0;
		        Playtime[client] = 0;
		        PlaytimeMap[client] = 0;
		        KillsInfected[client] = 0;
		        NewPoints[client] = 0;
		        ClientHeadshots[client] = 0;
		        g_votekick[client] = 0;
		        CreateTimer(7.0, Timedtyclient, client);
	        }
	    }
	}
}

public Action Timedtyclient(Handle timer, any client)
{
	if (client && IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
	        if (Rank_db != null)
	        {
	            CheckPlayerDB(client);
	            KnowRankPoints(client);
	            CreateTimer(GetRandomFloat(5.5, 8.5) * 1.0, RankConnect, client);
	        }
		}
	}
	return Plugin_Stop;
}
public Action RankConnect(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
			char sName[32];
			GetClientName(client, sName, sizeof(sName)-8);
			CPrintToChat(client, "%t", "%s Rank: %i of %i. Points: %i", sName, ClientRank[client], RankTotal, ClientPoints[client]);
			RanktyConnect(client);
		}
	}
	return Plugin_Stop;
}

public Action PlayerJoinMessage(Handle timer, any client)
{
	char ip[16], country[48];
	if (IsClientInGame(client))
	{
		if (IsRealClient(client))
		{
			GetClientIP(client, ip, sizeof(ip), true);
			int flags = GetUserFlagBits(client);
			if (GeoipCountry(ip, country, sizeof(country)))
			{
				if (g_HaveSteam[client])
				{
					if (flags & ADMFLAG_ROOT)
					{
					}
					else
					{
						if (flags & ADMFLAG_CUSTOM2)
						{
							CPrintToChatAll("%t {blue}%N \x05[%s]", "+ Admin", client, country);
						}
						else if (flags & ADMFLAG_KICK)
						{
							CPrintToChatAll("%t {blue}%N \x05[%s]", "+ Moderator", client, country);
						}
						else if (flags & ADMFLAG_GENERIC)
						{
							CPrintToChatAll("%t {blue}%N \x05[%s]", "+ VIP", client, country);
						}
						else
						{
							CPrintToChatAll("%t {blue}%N \x05[%s]", "+ Player", client, country);
						}
					}
				}
				else
				{
					if (!(flags & ADMFLAG_ROOT))
					{
						if (flags & ADMFLAG_CUSTOM2)
						{
							CPrintToChatAll("%t {blue}%N \x05[%s]", "+ Admin", client, country);
						}
						else if (flags & ADMFLAG_KICK)
						{
							CPrintToChatAll("%t {blue}%N \x05[%s]", "+ Moderator", client, country);
						}
						else if (flags & ADMFLAG_GENERIC)
						{
							CPrintToChatAll("%t {blue}%N \x05[%s]", "+ VIP", client, country);
						}
						else
						{
							CPrintToChatAll("%t {blue}%N \x05[%s]", "+ Player", client, country);
						}
					}
				}
			}
			else
			{
				if (g_HaveSteam[client])
				{
					if (flags & ADMFLAG_ROOT)
					{
					}
					else
					{
						if (flags & ADMFLAG_CUSTOM2)
						{
							CPrintToChatAll("%t {blue}%N", "+ Admin", client);
						}
						else if (flags & ADMFLAG_KICK)
						{
							CPrintToChatAll("%t {blue}%N", "+ Moderator", client);
						}
						else if (flags & ADMFLAG_GENERIC)
						{
							CPrintToChatAll("%t {blue}%N", "+ VIP", client);
						}
						else
						{
							CPrintToChatAll("%t {blue}%N", "+ Player", client);
						}
					}
				}
				if (!(flags & ADMFLAG_ROOT))
				{
					if (flags & ADMFLAG_CUSTOM2)
					{
						CPrintToChatAll("%t {blue}%N", "+ Admin", client);
					}
					else if (flags & ADMFLAG_KICK)
					{
						CPrintToChatAll("%t {blue}%N", "+ Moderator", client);
					}
					else if (flags & ADMFLAG_GENERIC)
					{
						CPrintToChatAll("%t {blue}%N", "+ VIP", client);
					}
					else
					{
						CPrintToChatAll("%t {blue}%N", "+ Player", client);
					}
				}
			}
			EmitSoundToAll("buttons/blip1.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		}
	}
	Join_Timer[client] = null;
	return Plugin_Continue;
}

public void RanktyConnect(int client)
{
	if (client <= 0 || !IsClientInGame(client)) return;

	int targetEnt = client;
	int targetPlayer = client;

	if (!IsFakeClient(client) && GetClientTeam(client) != 2)
	{
		int bot = GetIdleBotOfClient(client);
		if (bot > 0)
		{
			targetEnt = bot;
			targetPlayer = client;
		}
		else
		{
			return;
		}
	}
	else if (IsFakeClient(client))
	{
		targetPlayer = GetClientOfIdleClient(client);
	}

	int colorEnt = GetRankColorTarget(targetEnt);
	if (colorEnt <= 0) return;

	if (targetPlayer > 0 && !IsFakeClient(targetPlayer))
	{
		if (GetClientTeam(targetEnt) == TEAM_SURVIVORS)
		{
			if (IsPlayerAlive(targetEnt))
			{
				if (ClientPoints[targetPlayer] >= 800000)
				{
					SetEntityRenderColor(colorEnt, 0, 0, 0, 255);
				}
				else if (ClientPoints[targetPlayer] >= 640000)
				{
					SetEntityRenderColor(colorEnt, 255, 97, 3, 255);
				}
				else if (ClientPoints[targetPlayer] >= 320000)
				{
					SetEntityRenderColor(colorEnt, 255, 0, 0, 255);
				}
				else if (ClientPoints[targetPlayer] >= 160000)
				{
					SetEntityRenderColor(colorEnt, 255, 104, 240, 255);
				}
				else if (ClientPoints[targetPlayer] >= 80000)
				{
					SetEntityRenderColor(colorEnt, 102, 25, 140, 255);
				}
				else if (ClientPoints[targetPlayer] >= 40000)
				{
					SetEntityRenderColor(colorEnt, 0, 139, 0, 255);
				}
				else if (ClientPoints[targetPlayer] >= 20000)
				{
					SetEntityRenderColor(colorEnt, 0, 0, 255, 255);
				}
				else if (ClientPoints[targetPlayer] >= 10000)
				{
					SetEntityRenderColor(colorEnt, 255, 255, 0, 255);
				}
				else if (ClientPoints[targetPlayer] >= 5000)
				{
					SetEntityRenderColor(colorEnt, 173, 255, 47, 255);
				}
			}
		}
	}
}

public void ConnectDB()
{
	if (SQL_CheckConfig(STATS))
	{
		char sError[80];
		Rank_db = SQL_Connect(STATS, true, sError, sizeof(sError)-1);
		if (Rank_db != null)
		{
			SQL_TQuery(Rank_db, ErrorDBCheck, "SET NAMES 'utf8'", 0);
		}
		else
		{
			LogError("Failed connect to database: %s", sError);
		}
	}
	else
	{
		LogError("databases.cfg missing 'l4dstats' entry!");
	}
}

public void ErrorDBCheck(Handle owner, Handle hndl, const char [] error, any data)
{
	if (hndl != null)
	{
		if (error[0] != '\0')
		{
			LogError("SQL Error: %s", error);
		}
	}
}

void CheckPlayerDB(int client)
{
	if (Rank_db != null)
	{	
	    if (client)
	    {
		    if (IsClientInGame(client))
		    {
			    if (!IsFakeClient(client))
			    {
			        char sTeamID[64], sQuery[512];
			        GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
			        Format(sQuery, sizeof(sQuery)-1, "SELECT steamid FROM players WHERE steamid = '%s'", sTeamID);
			        SQL_TQuery(Rank_db, SelectPlayer, sQuery, client, DBPrio_Normal);
			    }
		    }
	    }
	}
}

public void SelectPlayer(Handle owner, Handle hndl, char[] error, any data)
{
	int client = data;
	if (Rank_db != null)
	{	
	    if (client)
	    {
		    if (IsClientInGame(client))
		    {
			    if (hndl != null)
			    {
				    if (!SQL_GetRowCount(hndl))
				    {
				        char sTeamID[64], sQuery[512];
				        GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
				        Format(sQuery, sizeof(sQuery)-1, "INSERT IGNORE INTO players SET steamid = '%s'", sTeamID);
				        SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, DBPrio_Normal);
				    }
				    SetPlayers(client);
			    }
		    }
	    }
	}
}

public void SetPlayers(int client)
{
	if (IsClientConnected(client))
	{
		char sQuery[160], sName[32], sTeamID[24], IP[16];
		GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
		GetClientName(client, sName, sizeof(sName)-8);
		ReplaceString(sName, sizeof(sName)-8, "<", "", false);
		ReplaceString(sName, sizeof(sName)-8, ">", "", false);
		ReplaceString(sName, sizeof(sName)-8, "?", "", false);
		ReplaceString(sName, sizeof(sName)-8, ";", "", false);
		ReplaceString(sName, sizeof(sName)-8, "`", "", false);
		ReplaceString(sName, sizeof(sName)-8, "'", "", false);
		ReplaceString(sName, sizeof(sName)-8, "/", "", false);
		ReplaceString(sName, sizeof(sName)-8, "$", "", false);
		ReplaceString(sName, sizeof(sName)-8, "%", "", false);
		ReplaceString(sName, sizeof(sName)-8, "&", "", false);
		GetClientIP(client, IP, sizeof(IP), true);
		Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET lastontime = UNIX_TIMESTAMP(), ip = '%s', points = points + 0, name = '%s' WHERE steamid = '%s'", IP, sName, sTeamID);
		SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
		CreateTimer(120.0, timer_UpdateDBPlaytime, _, TIMER_REPEAT);
	}
}

public Action timer_UpdateDBPlaytime(Handle timer, Handle hndl)
{
	if (Rank_db != null)
	{
	    for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	    {
		    if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
		    {
			    UpdatePlaytimePlayers(i);
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_WitchKilled(Event event, char[] name, bool dontBroadcast)
{
	int iUserid = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidEntity(iUserid))
	{
	    if (iUserid)
	    {
	        if (!IsFakeClient(iUserid))
	        {
		        char sTeamID[64], sQuery[512];
		        GetClientAuthId(iUserid, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
		        int iPoints = cvar_Witch.IntValue + tystatsbalans + bonus;
		        Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET kill_witch = kill_witch + 1 WHERE steamid = '%s'", sTeamID);
		        NewKills[iUserid] += 1;       
		        if (IsMapFinished)
		        {
		            iPoints = 0;
		        }
		        SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
		        AddPoints(iUserid, iPoints);
	        }
	    }
	}
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	char sQuery[120], AttackerID[64];
	if (iAttacker)
	{
		int iUserid = GetClientOfUserId(event.GetInt("userid"));	
		if (iAttacker != iUserid)
		{
			if (!IsFakeClient(iAttacker))
			{
				GetClientAuthId(iAttacker, AuthId_Steam2, AttackerID, sizeof(AttackerID)-1);
				sg_buf[0] = '\0';
				event.GetString("victimname", sg_buf, sizeof(sg_buf)-1);
				int iTk = 0;
				if (iUserid > 0 && !IsFakeClient(iUserid) && GetClientTeam(iUserid) != 2 && GetClientTeam(iAttacker) != 2)
				{
					iTk = -50;
					TKblockDamage[iAttacker] = TKblockDamage[iAttacker] + 30;
					CPrintToChat(iUserid, "%t", "%N attacked %N (%i TK)", iAttacker, iUserid, TKblockDamage[iAttacker]);
					CPrintToChat(iAttacker, "%t", "%N attacked %N (%i TK)", iAttacker, iUserid, TKblockDamage[iAttacker]);
					PunishTeamkiller(iAttacker);
					AddPoints(iAttacker, iTk);
					Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET award_teamkill = award_teamkill + 1 WHERE steamid = '%s'", AttackerID);
				}
				if (sg_buf[0] == 'B')
				{	/* Boomer */
					int iPoints = cvar_Boomer.IntValue + tystatsbalans + bonus;
					Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET kill_boomer = kill_boomer + 1, kills = kills + 1 WHERE steamid = '%s'", AttackerID);
					NewKills[iAttacker] += 1;
					AddPoints(iAttacker, iPoints);
				}
				else if (sg_buf[0] == 'J')
				{	/* Jockey */
					int iPoints = cvar_Jockey.IntValue + tystatsbalans + bonus;
					Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET kill_jockey = kill_jockey + 1, kills = kills + 1 WHERE steamid = '%s'", AttackerID);
					NewKills[iAttacker] += 1;
					AddPoints(iAttacker, iPoints);
				}
				else if (sg_buf[0] == 'S')
				{
					int iPoints;
					if (sg_buf[1] == 'm')
					{	/* Smoker */
						iPoints = cvar_Smoker.IntValue + tystatsbalans + bonus;
						Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET kill_smoker = kill_smoker + 1, kills = kills + 1 WHERE steamid = '%s'", AttackerID);
						NewKills[iAttacker] += 1;
					}
					else if (sg_buf[1] == 'p')
					{	/* Spitter */
						iPoints = cvar_Spitter.IntValue + tystatsbalans + bonus; 
						Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET kill_spitter = kill_spitter + 1, kills = kills + 1 WHERE steamid = '%s'", AttackerID);
						NewKills[iAttacker] += 1;
					}
					AddPoints(iAttacker, iPoints);
				}
				else if (sg_buf[0] == 'H')
				{	/* Hunter */
					int iPoints = cvar_Hunter.IntValue + tystatsbalans + bonus;
					Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET kill_hunter = kill_hunter + 1, kills = kills + 1 WHERE steamid = '%s'", AttackerID);
					NewKills[iAttacker] += 1;
					AddPoints(iAttacker, iPoints);
				}
				else if (sg_buf[0] == 'C')
				{	/* Charger */
					int iPoints = cvar_Charger.IntValue + tystatsbalans + bonus;
					Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET kill_charger = kill_charger + 1, kills = kills + 1 WHERE steamid = '%s'", AttackerID);
					NewKills[iAttacker] += 1;
					AddPoints(iAttacker, iPoints);
				}
				else if (sg_buf[0] == 'T')
				{	/* Tank */
					int iPoints = cvar_Tank.IntValue + tystatsbalans + bonus;
					Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET award_tankkill = award_tankkill + 1 WHERE steamid = '%s'", AttackerID);
					NewKills[iAttacker] += 1;
					AddPoints(iAttacker, iPoints);
				}
				else
				    return Plugin_Continue;
				if (event.GetBool("headshot"))
				{
					Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET headshots = headshots + 1 WHERE steamid = '%s'", AttackerID);
					NewKills[iAttacker] += 1;
					NewHeadshots[iAttacker] += 1;
				}
			}
			SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));	
	if (iAttacker)
	{
		int iUserid = GetClientOfUserId(event.GetInt("userid"));	
		if (iAttacker != iUserid)
		{
			if (!IsFakeClient(iAttacker))
			{
				if (!IsFakeClient(iUserid))
				{
					if (GetClientTeam(iAttacker) == 2)
					{
						if (GetClientTeam(iUserid) == 2)
						{
							TKblockDamage[iAttacker] =  TKblockDamage[iAttacker] + 10;
							CPrintToChat(iUserid, "%t", "%N attacked %N (%i TK)", iAttacker, iUserid, TKblockDamage[iAttacker]);
							CPrintToChat(iAttacker, "%t", "%N attacked %N (%i TK)", iAttacker, iUserid, TKblockDamage[iAttacker]);
							PunishTeamkiller(iAttacker);
							if (Rank_db != null)
							{
							    char AttackerID[64], sQuery[512];
							    GetClientAuthId(iAttacker, AuthId_Steam2, AttackerID, sizeof(AttackerID)-1);
							    Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET award_fincap = award_fincap + 1 WHERE steamid = '%s'", AttackerID);
							    SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
							    int iTk = 10;
							    iTk = iTk * -1;
							    AddPoints(iAttacker, iTk);
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));	
	if (iAttacker)
	{
		int iUserid = GetClientOfUserId(event.GetInt("userid"));	
		if (iAttacker != iUserid)
		{
			if (!IsFakeClient(iAttacker))
			{
				if (!IsFakeClient(iUserid))
				{
					if (GetClientTeam(iAttacker) == 2)
					{
						if (GetClientTeam(iUserid) == 2)
						{
							int iTk = 1;
							iTk = (iTk * -event.GetInt("dmg_health")) / 3;
							if (iTk < 2)
							{
								iTk = -1;
								TKblockDamage[iAttacker] = TKblockDamage[iAttacker] + (-1 * iTk);
							}
							else
							{
								iTk = -5;
								TKblockDamage[iAttacker] = TKblockDamage[iAttacker] + (-5 * iTk);
							}
							
							CPrintToChat(iUserid, "%t", "%N attacked %N (%i TK)", iAttacker, iUserid, TKblockDamage[iAttacker]);
							CPrintToChat(iAttacker, "%t", "%N attacked %N (%i TK)", iAttacker, iUserid, TKblockDamage[iAttacker]);
							PunishTeamkiller(iAttacker);
							AddPoints(iAttacker, iTk);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_HealPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int iSubject = GetClientOfUserId(event.GetInt("subject"));	
	int iUserid = GetClientOfUserId(event.GetInt("userid"));
	int restored = event.GetInt("health_restored");
	if (!IsFakeClient(iSubject))
	{
		if (!IsFakeClient(iUserid))
		{
			char sQuery[512], GiverID[64];
			GetClientAuthId(iUserid, AuthId_Steam2, GiverID, sizeof(GiverID)-1);
			if (iSubject == iUserid)
			{
				Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET heal = heal + 1 WHERE steamid = '%s'", GiverID);
			}
			else
			{
				TKblockDamage[iUserid] = TKblockDamage[iUserid] + -16;
				if (TKblockDamage[iUserid] <= 0)
				{
				    TKblockDamage[iUserid] = 0;
				}
				if (Rank_db != null)
				{
				    if (restored > 39)
				    {
				        Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET award_medkit = award_medkit + 1 WHERE steamid = '%s'", GiverID);
				    }
				    AddPoints(iUserid, 4);
				}					
			}
			SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
		}
	}
	return Plugin_Continue;
}

public Action Event_DefibPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int iSubject = GetClientOfUserId(event.GetInt("subject"));	
	int iUserid = GetClientOfUserId(event.GetInt("userid"));

	if (iSubject > 0 && IsClientInGame(iSubject))
	{
		GrantPlayerColor(iSubject);
	}

	if (iSubject != iUserid)
	{
		if (!IsFakeClient(iSubject))
		{
			if (!IsFakeClient(iUserid))
			{
				if (Rank_db != null)
				{
					char GiverID[64], sQuery[1024];
					GetClientAuthId(iUserid, AuthId_Steam2, GiverID, sizeof(GiverID)-1);
					Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET award_defib = award_defib + 1 WHERE steamid = '%s'", GiverID);
					SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
					AddPoints(iUserid, 3);
				}
			}
		}
	}
	return Plugin_Continue;
}

public void OnDefibPlayerByMedkit(int client, int target)
{
	if (!IsFakeClient(target))
	{
		if (Rank_db != null)
		{
			char clientID[64], sQuery[1024];
			GetClientAuthId(client, AuthId_Steam2, clientID, sizeof(clientID)-1);
			Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET award_defib = award_defib + 1 WHERE steamid = '%s'", clientID);
			SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
			AddPoints(client, 3);
		}
	}
}

public Action Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int iSubject = GetClientOfUserId(event.GetInt("subject"));	
	int iUserid = GetClientOfUserId(event.GetInt("userid"));		

	if (iSubject > 0 && IsClientInGame(iSubject))
	{
		GrantPlayerColor(iSubject);
	}

	if (iSubject != iUserid)
	{
		if (!IsFakeClient(iSubject))
		{
			if (!IsFakeClient(iUserid))
			{
				TKblockDamage[iUserid] = TKblockDamage[iUserid] -8;
				if (TKblockDamage[iUserid] <= 0)
				{
					TKblockDamage[iUserid] = 0;
				}
				if (Rank_db != null)
				{
					char GiverID[64], sQuery[1024];
					GetClientAuthId(iUserid, AuthId_Steam2, GiverID, sizeof(GiverID)-1);
					Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET award_revive = award_revive + 1 WHERE steamid = '%s'", GiverID);
					SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
					AddPoints(iUserid, 2);
				}					
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerNowIt(Event event, char[] name, bool dontBroadcast)
{
	int iUserid = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int Pvomit = 0;
	if (iAttacker && IsClientConnected(iAttacker) && IsClientInGame(iAttacker) && !IsFakeClient(iAttacker) && IsClientInGame(iUserid) && !IsFakeClient(iUserid) && !event.GetBool("by_boomer"))
	{
	    if (GetClientTeam(iUserid) == 2)
	    {
	        if (iAttacker != iUserid)
	        {
	            Pvomit = -3;
	            CPrintToChatAll("%t", "%N launched vomit on %N!", iAttacker, iUserid);				
	        }
	    }				
	    else if (GetClientTeam(iUserid) == 3)
	    {
	        if (GetClientZC(iUserid) == 8)
	        {
	            Pvomit = 8;
	            CPrintToChatAll("%t", "Player %N vomit Tank", iAttacker);
	        }
		}				
	    AddPoints(iAttacker, Pvomit);
	}
	return Plugin_Continue;
}

public Action Event_SurvivorRescued(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("rescuer"));
	int target = GetClientOfUserId(event.GetInt("victim"));
	if (target > 0 && IsClientInGame(target))
	{
		GrantPlayerColor(target);
	}

	if (IsValidClient(client))
	{
		if (!IsFakeClient(client) || !IsFakeClient(target))
		{
			if (Rank_db != null)
			{
				int iPoints = 1;
				char clientID[64], sQuery[1024];
				GetClientAuthId(client, AuthId_Steam2, clientID, sizeof(clientID)-1);
				Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET award_rescue = award_rescue + 1 WHERE steamid = '%s'", clientID);
				SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
				AddPoints(client, iPoints);
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_Award_L4D2(Event event, char[] name, bool dontBroadcast)
{
	if (Rank_db != null)
	{	
	    int PlayerID = event.GetInt("userid");
	    if (PlayerID)
	    {		
	        int client = GetClientOfUserId(PlayerID);
	        if (!IsFakeClient(client))
			{
			    int target = event.GetInt("subjectentid");
			    int Recipient;
			    char AwardSQL[128], UserID[64];
			    int AwardID = event.GetInt("award");
			    GetClientAuthId(client, AuthId_Steam2, UserID, sizeof(UserID)-1);
			    if (AwardID == 67)
			    {
			        if (!target)
			        {
			            return Plugin_Continue;
			        }
			        ProtectedFriendlyCounter[client]++;
			        return Plugin_Continue;
			    }
			    else if (AwardID == 68)
			    {
			        if (!target)
			        {
			            return Plugin_Continue;
			        }
			        Recipient = GetClientOfUserId(GetClientUserId(target));
			        GivePills(client, Recipient, -1);
			        return Plugin_Continue;
			    }
			    else if (AwardID == 69)
			    {
			        if (!target)
			        {
			            return Plugin_Continue;
			        }
			        Recipient = GetClientOfUserId(GetClientUserId(target));
			        GiveAdrenaline(client, Recipient, -1);
			        return Plugin_Continue;
			    }
			    else if (AwardID == 85)
			    {
			        if (!target)
			        {
			            return Plugin_Continue;
			        }
			        Recipient = GetClientOfUserId(GetClientUserId(target));
			        PlayerIncap(client, Recipient);
			        return Plugin_Continue;
			    }
			    else if (AwardID == 81)
			    {
			        Format(AwardSQL, sizeof(AwardSQL), "award_tankkillnodeaths = award_tankkillnodeaths + 1");
			    }
			    else if (AwardID == 86)
			    {
			        Format(AwardSQL, sizeof(AwardSQL), "award_left4dead = award_left4dead + 1");
			    }
			    else if (AwardID == 95)
			    {
			        Format(AwardSQL, sizeof(AwardSQL), "award_letinsafehouse = award_letinsafehouse + 1");
			    }
			    else
			        return Plugin_Continue;
	
			    char sQuery[1024];
			    Format(sQuery, sizeof(sQuery)-1, "UPDATE players SET %s WHERE steamid = '%s'", AwardSQL, UserID);
			    SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);			    
			}
	    }
	}
	return Plugin_Continue;
}

void GivePills(int Giver, int Recipient, int PillsID)
{
	if (PillsID < 0)
	{
		PillsID = GetPlayerWeaponSlot(Recipient, 4);
	}
	if (PillsID < 0 || Pills[PillsID] == 1)
	{
		return;
	}
	Pills[PillsID] = 1;
	if (!IsFakeClient(Giver))
	{
	    char GiverID[64], sQuery2[1024];
	    GetClientAuthId(Giver, AuthId_Steam2, GiverID, sizeof(GiverID)-1);
	    Format(sQuery2, sizeof(sQuery2)-1, "UPDATE players SET award_pills = award_pills + 1 WHERE steamid = '%s'", GiverID);
	    SQL_TQuery(Rank_db, ErrorDBCheck, sQuery2, 0);
	}
}

void GiveAdrenaline(int Giver, int Recipient, int AdrenalineID)
{
	if (AdrenalineID < 0)
	{
		AdrenalineID = GetPlayerWeaponSlot(Recipient, 4);
	}
	if (AdrenalineID < 0 || Adrenaline[AdrenalineID] == 1)
	{
		return;
	}
	Adrenaline[AdrenalineID] = 1;
	if (!IsFakeClient(Giver))
	{
	    char GiverID[64], sQuery2[1024];
	    GetClientAuthId(Giver, AuthId_Steam2, GiverID, sizeof(GiverID)-1);
	    Format(sQuery2, sizeof(sQuery2)-1, "UPDATE players SET award_adrenaline = award_adrenaline + 1 WHERE steamid = '%s'", GiverID);
	    SQL_TQuery(Rank_db, ErrorDBCheck, sQuery2, 0);
	}
}
void PlayerIncap(int Attacker, int Victim)
{
	if (0 >= Victim)
	{
		return;
	}
	if (Attacker == Victim)
	{
		return;
	}
	if (!Attacker || IsFakeClient(Attacker))
	{
		return;
	}
	int AttackerTeam = GetClientTeam(Attacker);
	int VictimTeam = GetClientTeam(Victim);
	if (AttackerTeam == 2 && VictimTeam == 2)
	{
		char AttackerID[64], sQuery2[1024];
		GetClientAuthId(Attacker, AuthId_Steam2, AttackerID, sizeof(AttackerID)-1);
		Format(sQuery2, sizeof(sQuery2)-1, "UPDATE players SET award_fincap = award_fincap + 1 WHERE steamid = '%s'", AttackerID);
		SQL_TQuery(Rank_db, ErrorDBCheck, sQuery2, 0);
	}
}
     
public void PunishTeamkiller(int client)
{
	if (GetUserFlagBits(client))
	{
		return;
	}
	int BonusTK;
	if (ClientRank[client] > 1000 || ClientRank[client])
	{
		BonusTK = -45;
	}
	else if (ClientRank[client] > 100 && ClientRank[client] < 1001)
	{
		BonusTK = 0;
	}
	else if  (ClientRank[client] > 0 && ClientRank[client] < 101)
	{
		BonusTK = 30;
	}
	if (TKblockDamage[client] > TKblockmin + BonusTK)
	{
		if (TKblockDamage[client] > TKblockmax + BonusTK)
		{
			if (TKblockPunishment[client] < TKblockmax + BonusTK)
			{
				if (IsValidEntity(client) && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
				{
					char sTeamID[64];
					GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
					PrintToChatAll("%t", "%N (%s) has been banned [%i TK]", client, sTeamID, TKblockDamage[client]);
					TKblockPunishment[client] = TKblockDamage[client];                                          
					if (ClientPoints[client] <= -1000)
					{
						if (GetTime() <= LastVotebanTIME[client])
						{
							ServerCommand("sm_ban \"#%d\" \"%i\" \"%s\"", GetClientUserId(client), 40320, "Team Killer");
						}
						else
						{
							ServerCommand("sm_ban \"#%d\" \"%i\" \"%s\"", GetClientUserId(client), 20160, "Team Killer");
						}
					}
					else
					{
						if (ClientPoints[client] > -1000 && ClientPoints[client] <= -300)
						{
							if (GetTime() <= LastVotebanTIME[client])
							{
								ServerCommand("sm_ban \"#%d\" \"%i\" \"%s\"", GetClientUserId(client), 40320, "Team Killer");
							}
							else
							{
								ServerCommand("sm_ban \"#%d\" \"%i\" \"%s\"", GetClientUserId(client), 10080, "Team Killer");
							}
						}
						else if (ClientPoints[client] > -300 && ClientPoints[client] <= 0)
						{
							ServerCommand("sm_ban \"#%d\" \"%i\" \"%s\"", GetClientUserId(client), 4320, "Team Killer");
						}
						else if (0 < ClientPoints[client])
						{
							ServerCommand("sm_ban \"#%d\" \"%i\" \"%s\"", GetClientUserId(client), 720, "Team Killer");
						}
					}
					ServerCommand("sm_cancelvote");
				}
			}
		}
		else if ((TKblockDamage[client] - TKblockPunishment[client]) > TKblockmin)
		{
			if (IsValidEntity(client) && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
			{
				TKblockPunishment[client] = TKblockDamage[client];
				CPrintToChatAll("%t {red}%N %t", "Auto Voteban", client, "%i TK. (Rank: %d Points: %d)", TKblockDamage[client], ClientRank[client], ClientPoints[client]);
				ServerCommand("sm_voteban #%d TeamKiller", GetClientUserId(client));
				LastVotebanTIME[client] = GetTime();
			}
		}
	}
}

public Action cmd_ShowRank(int client, int args)
{
	if (client)
	{
		if (IsClientInGame(client))
		{
			if (Rank_db != null)
			{
				KnowRankPoints(client);
				KnowRankKills(client);
				KnowRankHeadshots(client);
				KnowRankPlaytime(client);
				CreateTimer(1.0, TimerDisplayRank, client);
			}
			else
			{
				PrintToChat(client, "Connection error.");
			}
		}
	}
	return Plugin_Handled;
}

public Action TimerDisplayRank(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
			if (Rank_db != null)
			{
				char sQuery[112];
				Format(sQuery, sizeof(sQuery)-1, "SELECT `points` FROM `players` WHERE `points` > %d ORDER BY `points` ASC LIMIT 1", ClientPoints[client]);
				SQL_TQuery(Rank_db, DisplayRank, sQuery, client);
			}
		}
	}
	return Plugin_Stop;
}

public void DisplayRank(Handle owner, Handle hndl, const char [] error, any client)
{
	if (client > 0)
	{
		if (IsClientInGame(client))
		{
			if (hndl != null)
			{
				char sBuffer[64], URL[64], playtime[128], flag[5];
				cvar_SiteURL.GetString(URL, sizeof(URL));
				int Headshots = ClientHeadshots[client], iPoints = 0;
				float HeadshotRatio = Headshots == 0 ? 0.00 : (float(Headshots)/float(ClientKills[client]))*100;
				int theTime = ClientPlaytime[client];
				int days = theTime /60/60/24;
				int hours = theTime/60/60%24;
				int minutes = theTime/60%60;
				if (hours == 0 && days == 0)
				{
					Format(playtime, sizeof(playtime), "%d min", minutes);
				}
				else if (days == 0)
				{
					Format(playtime, sizeof(playtime), "%d hour %d min", hours, minutes);
				}
				else Format(playtime, sizeof(playtime), "%d day %d hour %d min", days, hours, minutes);
				int BonusTK;
				if (ClientRank[client] > 1000 || ClientRank[client])
				{
					BonusTK = -45;
				}
				else if (ClientRank[client] > 100 && ClientRank[client] < 1001)
				{
					BonusTK = 0;
				}
				else if (ClientRank[client] > 0 && ClientRank[client] < 101)
				{
					BonusTK = 30;
				}
				int TKblockminReal = BonusTK + TKblockmin;
				int TKblockmaxReal = BonusTK + TKblockmax;
				getFlagOfPlayer(client, flag, sizeof(flag));				
				while (SQL_FetchRow(hndl))
				{
					iPoints = SQL_FetchInt(hndl, 0);
				}
				Panel hPanel = new Panel();
				Format(sBuffer, sizeof(sBuffer)-1, "Ranking  of  %N   %2s", client, flag);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "☢︻┳═一☣☢︻┳═一☢");
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "======UKS_Coop.25======");
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Rank: %d of %d", ClientRank[client], RankTotal);
				hPanel.DrawText(sBuffer);
				if (ClientRank[client] != 1)
				{
					Format(sBuffer, sizeof(sBuffer)-1, "Next Rank: %d Points required.", iPoints - ClientPoints[client]);
					hPanel.DrawText(sBuffer);
				}
				else
				{
					Format(sBuffer, sizeof(sBuffer)-1, "You are 1st. ★★Pro★★");
					hPanel.DrawText(sBuffer);
				}
				if (NewPoints[client])
				{
				    if (NewPoints[client] > 0 )
				    {
				        if (hm_count_fails.IntValue > 0)
				        {
				            Format(sBuffer, sizeof(sBuffer)-1, "Points: + %d [TK: %d] [%d]", NewPoints[client], TKblockDamage[client], ClientPoints[client]);
				        }
				        else
				        {
				            Format(sBuffer, sizeof(sBuffer)-1, "Points: + %d [%d]", NewPoints[client], ClientPoints[client]);
				        }                                      
				    }                             
				    else
				    {					
				        Format(sBuffer, sizeof(sBuffer)-1, "Points: %d [%d]", ClientPoints[client], NewPoints[client]);
				    }
				}
				else
				{				
				    Format(sBuffer, sizeof(sBuffer)-1, "Points: %d", ClientPoints[client]);						
				}					
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Killed Bosses: + %d [%d]", NewKills[client], ClientKills[client]);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Headshots: + %d [%d]" , NewHeadshots[client], Headshots);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Headshot Ratio: %.2f \%" , HeadshotRatio);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Playtime: %s", playtime);
				hPanel.DrawText(sBuffer);			
				Format(sBuffer, sizeof(sBuffer)-1, "Voteban TK: %d", TKblockminReal);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Ban TK: %d", TKblockmaxReal);
				hPanel.DrawText(sBuffer);			
				if (!StrEqual(URL, "", false))
				{
					Format(sBuffer, sizeof(sBuffer)-1, "For full stats visit:\nhttp://%s", URL);
					hPanel.DrawText(sBuffer);
					Format(sBuffer, sizeof(sBuffer)-1, "=======================");
					hPanel.DrawText(sBuffer);
					hPanel.DrawItem("Show full stats");
				}
				hPanel.DrawItem("Top 10 Players");
				hPanel.DrawItem("Top 20 Players");
				hPanel.DrawItem("Show Player Ranks");
				hPanel.DrawItem("Close");
				hPanel.Send(client, RankPanelHandlerOption, 30);
				delete hPanel;
				CreateTimer(1.0, TimedGrantPlayerColor, client);
			}
			else
			{
				PrintToChat(client, "SQL error.");
				LogError("DisplayRank %s", error);
			}
		}
	}
}

public int RankPanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	return 0;
}

public int RankPanelHandlerOption(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char URL[64];
		cvar_SiteURL.GetString(URL, sizeof(URL));
		if (!StrEqual(URL, "", false))
		{
			if (param2 == 1)
			{
				FakeClientCommand(param1, "sm_browse %s", URL);
			}
			else
			{
				if (param2 == 2)
				{
					cmd_ShowTop10(param1, 0);
				}
				else if (param2 == 3)
				{
					cmd_ShowTop20(param1, 0);
				}
				else if (param2 == 4)
				{
					DisplayRankTargetMenu(param1);
				}
			}
		}
		else
		{
			if (param2 == 1)
			{
				cmd_ShowTop10(param1, 0);
			}
			else if (param2 == 2)
			{
				cmd_ShowTop20(param1, 0);
			}
			else if (param2 == 3)
			{
				DisplayRankTargetMenu(param1);
			}
		}
	}
	return 0;
}

void DisplayRankTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Rank);
	char title[100], playername[128], identifier[64], DisplayName[64];
	Format(title, sizeof(title), "%s", "Player Ranks:");
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	for (int i = 1; i <= MaxClients; i++)
	{		
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			GetClientName(i, playername, sizeof(playername));
			Format(DisplayName, sizeof(DisplayName), "%s (%i points)", playername, ClientPoints[i]);
			Format(identifier, sizeof(identifier), "%i", i);
			menu.AddItem(identifier, DisplayName, 0);
		}
	}
	menu.Display(client, 0);
}

public void MenuHandler_Rank(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else
	{
		if (action == MenuAction_Select)
		{
			char info[32], name[32];
			int target;
			menu.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
			target = StringToInt(info, 10);
			if (target)
			{
				KnowRankKills(target);
				KnowRankHeadshots(target);
				KnowRankPlaytime(target);
				DisplayTargetRank(target, param1);
			}
			else
			{
				PrintToChat(param1, "[SM] %s", "Player no longer available");
			}
		}
	}
	return;
}

void DisplayTargetRank(int target, int sender)
{
	if (target > 0)
	{
		if (IsClientInGame(target))
		{
				char sBuffer[64], URL[64], playtime[128], flag[5];
				cvar_SiteURL.GetString(URL, sizeof(URL));
				int Headshots = ClientHeadshots[target];
				float HeadshotRatio = Headshots == 0 ? 0.00 : (float(Headshots)/float(ClientKills[target]))*100;
				int theTime = ClientPlaytime[target];
				int days = theTime /60/60/24;
				int hours = theTime/60/60%24;
				int minutes = theTime/60%60;
				if (hours == 0 && days == 0)
				{
					Format(playtime, sizeof(playtime), "%d min", minutes);
				}
				else if (days == 0)
				{
					Format(playtime, sizeof(playtime), "%d hour %d min", hours, minutes);
				}
				else Format(playtime, sizeof(playtime), "%d day %d hour %d min", days, hours, minutes);
				int BonusTK;
				if (ClientRank[target] > 1000 || ClientRank[target])
				{
					BonusTK = -45;
				}
				else if (ClientRank[target] > 100 && ClientRank[target] < 1001)
				{
					BonusTK = 0;
				}
				else if (ClientRank[target] > 0 && ClientRank[target] < 101)
				{
					BonusTK = 30;
				}
				int TKblockminReal = BonusTK + TKblockmin;
				int TKblockmaxReal = BonusTK + TKblockmax;
				getFlagOfPlayer(target, flag, sizeof(flag));				
				Panel hPanel = new Panel();
				Format(sBuffer, sizeof(sBuffer)-1, "Ranking  of  %N   %2s", target, flag);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "☢︻┳═一☣☢︻┳═一☢");
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "======UKS_Coop.25======");
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Rank: %d of %d", ClientRank[target], RankTotal);
				hPanel.DrawText(sBuffer);
				if (NewPoints[target])
				{
				    if (NewPoints[target] > 0)
				    {
				        if (hm_count_fails.IntValue > 0)
				        {
				            Format(sBuffer, sizeof(sBuffer)-1, "Points: + %d [%d] [%d]", NewPoints[target], ClientPoints[target], CalculatePoints(NewPoints[target]));
				        }
				        else
				        {
				            Format(sBuffer, sizeof(sBuffer)-1, "Points: + %d [%d]", NewPoints[target], ClientPoints[target]);
				        }                                      
				    }                             
				    else
				    {					
				        Format(sBuffer, sizeof(sBuffer)-1, "Points: %d [%d]", ClientPoints[target], NewPoints[target]);
				    }
				}
				else
				{				
				    Format(sBuffer, sizeof(sBuffer)-1, "Points: %d", ClientPoints[target]);						
				}					
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Killed Bosses: + %d [%d]", NewKills[target], ClientKills[target]);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Headshots: + %d [%d]" , NewHeadshots[target], Headshots);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Headshot Ratio: %.2f \%" , HeadshotRatio);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Playtime: %s", playtime);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "TK: %d", TKblockDamage[target]);
				hPanel.DrawText(sBuffer);				
				Format(sBuffer, sizeof(sBuffer)-1, "Voteban TK: %d", TKblockminReal);
				hPanel.DrawText(sBuffer);
				Format(sBuffer, sizeof(sBuffer)-1, "Ban TK: %d", TKblockmaxReal);
				hPanel.DrawText(sBuffer);			
				if (!StrEqual(URL, "", false))
				{
					Format(sBuffer, sizeof(sBuffer)-1, "For full stats visit:\nhttp://%s", URL);
					hPanel.DrawText(sBuffer);
					Format(sBuffer, sizeof(sBuffer)-1, "=======================");
					hPanel.DrawText(sBuffer);
					hPanel.DrawItem("Show full stats");
				}
				hPanel.DrawItem("Top 10 Players");
				hPanel.DrawItem("Top 20 Players");
				hPanel.DrawItem("Show Player Ranks");
				hPanel.DrawItem("Close");
				hPanel.Send(sender, RankPanelHandlerOption, 30);
				delete hPanel;
		}
	}
}

int getFlagOfPlayer(int client, char[] flag, int size)
{
  char ip[16], code2[3];
  GetClientIP(client, ip, sizeof(ip));
  if(GeoipCode2(ip, code2))
    {
      Format(flag, size, "[%2s]", code2);
      return true;
    }
  else
    {
      Format(flag, size, "[--]");
      return false;
    }
}

public Action cmd_ShowTop10(int client, int args)
{
	if (client)
	{
		if (IsClientInGame(client))
		{
			if (Rank_db != null)
			{
				char sQuery[104];
				Format(sQuery, sizeof(sQuery)-1, "SELECT name, points FROM players ORDER BY points DESC LIMIT 10");
				SQL_TQuery(Rank_db, DisplayTop10, sQuery, client, DBPrio_Normal);
			}
			else
			{
				PrintToChat(client, "%t", "Failed to connect to database");
			}
		}
	}
	return Plugin_Handled;
}

public void DisplayTop10(Handle owner, Handle hndl, const char [] error, any client)
{
	if (client)
	{
		if (hndl != null)
		{
			char sBuffer[64], sName[32];
			int iPoints = 0, iNumber = 0;
			Panel Top10Panel = new Panel();
			Top10Panel.SetTitle("Top 10 UKS_Coop.25");
			Format(sBuffer, sizeof(sBuffer)-1, "☢︻┳═一☣☢︻┳═一☢");
			Top10Panel.DrawText(sBuffer);
			Format(sBuffer, sizeof(sBuffer)-1, "=======================");
			Top10Panel.DrawText(sBuffer);
			while (SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, sName, sizeof(sName)-8);
				iPoints = SQL_FetchInt(hndl, 1);
				iNumber += 1;
				Format(sBuffer, sizeof(sBuffer)-1, "%d_ %s  %d Points", iNumber, sName, iPoints);
				Top10Panel.DrawText(sBuffer);
			}
			Top10Panel.DrawItem("Close");
			Top10Panel.Send(client, RankPanelHandler, 30);
			delete Top10Panel;
		}
	}
}

public Action cmd_ShowTop15(int client, int args)
{
	if (client)
	{
		if (IsClientInGame(client))
		{
			if (Rank_db != null)
			{
				char sQuery[104];
				Format(sQuery, sizeof(sQuery)-1, "SELECT name, points FROM players ORDER BY points DESC LIMIT 15");
				SQL_TQuery(Rank_db, DisplayTop15, sQuery, client, DBPrio_Normal);
			}
			else
			{
				PrintToChat(client, "%t", "Failed to connect to database");
			}
		}
	}
	return Plugin_Handled;
}

public void DisplayTop15(Handle owner, Handle hndl, const char [] error, any client)
{
	if (client)
	{
		if (hndl != null)
		{
			char sBuffer[64], sName[32];
			int iPoints = 0, iNumber = 0;
			Panel Top15Panel = new Panel();
			Top15Panel.SetTitle("Top 15 UKS_Coop.25");
			Format(sBuffer, sizeof(sBuffer)-1, "☢︻┳═一☣☢︻┳═一☢");
			Top15Panel.DrawText(sBuffer);
			Format(sBuffer, sizeof(sBuffer)-1, "=======================");
			Top15Panel.DrawText(sBuffer);
			while (SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, sName, sizeof(sName)-8);
				iPoints = SQL_FetchInt(hndl, 1);
				iNumber += 1;
				Format(sBuffer, sizeof(sBuffer)-1, "%d_ %s  %d Points", iNumber, sName, iPoints);
				Top15Panel.DrawText(sBuffer);
			}
			Top15Panel.DrawItem("Close");
			Top15Panel.Send(client, RankPanelHandler, 30);
			delete Top15Panel;
		}
	}
}

public Action cmd_ShowTop20(int client, int args)
{
	if (client)
	{
		if (IsClientInGame(client))
		{
			if (Rank_db != null)
			{
				char sQuery[104];
				Format(sQuery, sizeof(sQuery)-1, "SELECT name, points FROM players ORDER BY points DESC LIMIT 20");
				SQL_TQuery(Rank_db, DisplayTop20, sQuery, client, DBPrio_Normal);
			}
			else
			{
				PrintToChat(client, "%t", "Failed to connect to database");
			}
		}
	}
	return Plugin_Handled;
}

public void DisplayTop20(Handle owner, Handle hndl, const char [] error, any client)
{
	if (client)
	{
		if (hndl != null)
		{
			char sBuffer[64], sName[32];
			int iPoints = 0, iNumber = 0;
			Panel Top20Panel = new Panel();
			Top20Panel.SetTitle("Top 20 UKS_Coop.25");
			Format(sBuffer, sizeof(sBuffer)-1, "☢︻┳═一☣☢︻┳═一☢");
			Top20Panel.DrawText(sBuffer);
			Format(sBuffer, sizeof(sBuffer)-1, "=======================");
			Top20Panel.DrawText(sBuffer);
			while (SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, sName, sizeof(sName)-8);
				iPoints = SQL_FetchInt(hndl, 1);
				iNumber += 1;
				Format(sBuffer, sizeof(sBuffer)-1, "%d_ %s  %d Points", iNumber, sName, iPoints);
				Top20Panel.DrawText(sBuffer);
			}
			Top20Panel.DrawItem("Close");
			Top20Panel.Send(client, RankPanelHandler, 30);
			delete Top20Panel;
		}
	}
}

public Action cmd_NextRank(int client, int args)
{
	if (client)
	{
		if (IsClientInGame(client))
		{
			if (Rank_db != null)
			{
				KnowRankPoints(client);
				CreateTimer(1.2, TimerDisplayNextRank, client);
			}
			else
			{
				PrintToChat(client, "%t", "Failed to connect to database");
			}
		}
	}
	return Plugin_Handled;
}

public Action TimerDisplayNextRank(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
			if (Rank_db != null)
			{
				char steamId[64], query[1024];
				GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId), true);
				Format(query, sizeof(query), "SELECT points FROM players WHERE points > %i AND steamid <> '%s' ORDER BY points LIMIT 1", ClientPoints[client], steamId);
				SQL_TQuery(Rank_db, DisplayNextRank, query, client, DBPrio_Normal);
			}
		}
	}
	return Plugin_Stop;
}

public Action TimerDisplayFullNextRank(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
			if (Rank_db != null)
			{
				char steamId[64], query[2048], query1[1024], query2[256], query3[1024];
				GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId), true);
				Format(query1, sizeof(query1), "SELECT name,points FROM players WHERE points > %i AND steamid <> '%s' ORDER BY points ASC LIMIT 3", ClientPoints[client], steamId);
				Format(query2, sizeof(query2), "SELECT name,points FROM players WHERE steamid = '%s'", steamId);
				Format(query3, sizeof(query3), "SELECT name,points FROM players WHERE points < %i AND steamid <> '%s' ORDER BY points DESC LIMIT 3", ClientPoints[client], steamId);
				Format(query, sizeof(query), "(%s) UNION (%s) UNION (%s) ORDER BY points DESC", query1, query2, query3);
				SQL_TQuery(Rank_db, DisplayFullNextRank, query, client, DBPrio_Normal);
			}
		}
	}
	return Plugin_Stop;
}

public void DisplayNextRank(Handle owner, Handle hndl, char[] error, any client)
{
	if (client)
	{
		if (hndl != null)
		{
			char Value[64];
			int Points;
			Panel NextRankPanel = new Panel();
			NextRankPanel.SetTitle("Next Rank:", false);
			while (SQL_FetchRow(hndl))
			{
				Points = SQL_FetchInt(hndl, 0);
			}	
			if (ClientRank[client] == 1)
			{
				Format(Value, sizeof(Value), "You are 1st");
				NextRankPanel.DrawText(Value);
			}
			else
			{
				Format(Value, sizeof(Value), "Points required: %i", Points - ClientPoints[client]);
				NextRankPanel.DrawText(Value);
			}
			NextRankPanel.DrawItem("More...");
			NextRankPanel.DrawItem("Close");
			NextRankPanel.Send(client, NextRankPanelHandler, 30);
			delete NextRankPanel;
		}
	}
}

public void DisplayFullNextRank(Handle owner, Handle hndl, char[] error, any client)
{
	if (client)
	{
		if (hndl != null)
		{
			char Name[32], Value[64];
			int Points = 0;
			Panel FullNextRankPanel = new Panel();
			FullNextRankPanel.SetTitle("Next Rank List:", false);
			while (SQL_FetchRow(hndl))
			{
	            SQL_FetchString(hndl, 0, Name, 32);
	            Points = SQL_FetchInt(hndl, 1);
	            ReplaceString(Name, 32, "&lt;", "<", true);
	            ReplaceString(Name, 32, "&gt;", ">", true);
	            ReplaceString(Name, 32, "&#37;", "%", true);
	            ReplaceString(Name, 32, "&#61;", "=", true);
	            ReplaceString(Name, 32, "&#42;", "*", true);
	            Format(Value, sizeof(Value), "%i points: %s", Points, Name);
	            FullNextRankPanel.DrawText(Value);
			}
			FullNextRankPanel.DrawItem("Close");
			FullNextRankPanel.Send(client, RankPanelHandler, 30);
			delete FullNextRankPanel;
		}
	}
}

public void NextRankPanelHandler(Handle panel, MenuAction action, int client, int option)
{
	if (action != MenuAction_Select)
	{
		return;
	}
	if (option == 1)
	{
		CreateTimer(1.2, TimerDisplayFullNextRank, client);
		return;
	}
	return;
}

stock int GetRealtyClientCount(bool inGameOnly)
{
	int clients = 0;
	if (inGameOnly)
	for (int i = 1; i <= MaxClients; i++)
	{		
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			clients++;
		}
	}
	return clients;
}

Action cmd_ShowRankTarget(int client, int args)
{
	int Target = GetClientAimTarget(client, false);
	if (!IsRealClient(Target))
	{
		return Plugin_Continue;
	}	
	if (IsClientConnected(Target) && IsClientInGame(Target) && GetClientTeam(Target) == 2)
	{
		CPrintToChat(client, "%t {blue}%N %t", "Player", Target, "Rank: %d Points: %d Map points: %d", ClientRank[Target], ClientPoints[Target], NewPoints[Target]);
	}
	return Plugin_Handled;
}

Action Command_totalPoints_to_all(int client, int args)
{
	PrintTotalPointsToAll(client);
	return Plugin_Handled;
}

void PrintTotalPointsToAll(int client)
{
	CPrintToChatAll("%t {blue}%N %t", "Player", client, "Rank: %d Points: %d", ClientRank[client], ClientPoints[client]);
}

Action Command_Points(int client, int args)
{
	PrintPoints(client);
	return Plugin_Handled;
}

void PrintPoints(int client)
{
	PrintToChat(client, "%t", "Your points: %d , Your map points: %d", ClientPoints[client], NewPoints[client]);
}

Action Command_Playtime(int client, int args)
{
	PrintPlaytime(client);
	return Plugin_Handled;
}

void PrintPlaytime(int client)
{
	PrintToChat(client, "%t", "Your playtime on this map: %d", PlaytimeMap[client]);
}

Action Command_MapTop(int client, int args)
{
	PrintMapTop(client);
	return Plugin_Handled;
}

void PrintMapTop(int client)
{
	int points[32][2];
	char NameBuffer[32] = "", WorseNameBuffer[32] = "";
	int count, totalpoints, j, worse;
	j = -100000;
	worse = 100000;
	count = 0;
	totalpoints = 0;
	int topplayerrank = 0;
	int worseplayerrank = 0;
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		if (IsRealClient(i))
		{
			char clientname[32];
			GetClientName(i, clientname, sizeof(clientname));
			points[i][0] = i;
			points[i][1] = NewPoints[i];
			if (NewPoints[i] > j)
			{
				j = NewPoints[i];
				topplayerrank = ClientRank[i];
			}
			if (NewPoints[i] < worse)
			{
				worse = NewPoints[i];
				worseplayerrank = ClientRank[i];
			}
			count++;
			totalpoints += NewPoints[i];
		}
	}
	if (hm_count_fails.IntValue > 0)
	{
		PrintToChat(client, "%t", "Map total points: %d (%d)", totalpoints, CalculatePoints(totalpoints));
		CPrintToChat(client, "%t {blue}%s %t", "Map best player:", NameBuffer, "(rank: %d; points: %d (%d))", topplayerrank, j, CalculatePoints(j));
	}
	else
	{
		PrintToChat(client, "%t", "Map total points: %d", totalpoints);
		CPrintToChat(client, "%t {blue}%s %t", "Map best player:", NameBuffer, "(rank: %d; points: %d)", topplayerrank, j);
	}
	if (0 > worse)
	{
		CPrintToChat(client, "%t {blue}%s %t", "Map worst player:", WorseNameBuffer, "(rank: %d; points: %d)", worseplayerrank, worse);
	}
	if (hm_count_fails.IntValue > 0)
	{
		if (round_end_repeats)
		{
			if (!IsPrint)
			{
				IsPrint = true;
				int prct = 100 - round_end_repeats * 10;
				PrintToChatAll("%t", "It took %d attempts to finish this map!", round_end_repeats);
				PrintToChatAll("%t", "All players will receive %d%%%% of their points earned for this map.", prct);
			}
		}
		else
		{
			if (!IsPrint)
			{
				IsPrint = true;
				PrintToChatAll("%t", "The map was passed on the first try!");
				PrintToChatAll("%t", "All players will receive 100%%%% of their points earned for this map.");
			}
		}
		PrintToChat(client, "%t", "Your map points: %d (%d)", NewPoints[client], CalculatePoints(NewPoints[client]));
	}
	else
	{
		PrintToChat(client, "%t", "Your map points: %d", NewPoints[client]);
	}
}

int CalculatePoints(int points)
{
	if (hm_count_fails.IntValue < 0)
	{
		points = RoundToZero(1.0 * points * 100 - round_end_repeats * 1.0 / 100);
	}
	return points;
}

void GrantPlayerColor(int client)
{
	if (client <= 0 || !IsClientInGame(client)) return;

	int targetEnt = client;
	int targetPlayer = client;

	if (!IsFakeClient(client) && GetClientTeam(client) != 2)
	{
		int bot = GetIdleBotOfClient(client);
		if (bot > 0)
		{
			targetEnt = bot;
			targetPlayer = client;
		}
		else
		{
			return; 
		}
	}
	else if (IsFakeClient(client))
	{
		targetPlayer = GetClientOfIdleClient(client);
		if (targetPlayer <= 0)
		{
			int colorEnt = GetRankColorTarget(client);
			if (colorEnt <= 0) return;

			if (hm_stats_bot_colors.IntValue < 1)
			{
				SetEntityRenderColor(colorEnt, 255, 255, 255, 255);
			}
			else 
			{
				SetEntityRenderColor(colorEnt, 175, 175, 175, 255);
			}
			return;
		}
	}

	int colorEnt = GetRankColorTarget(targetEnt);
	if (colorEnt <= 0) return;

	if (hm_stats_colors.IntValue < 1 || GetClientTeam(targetEnt) != 2) return;
	{
		if (hm_stats_colors.IntValue == 1)
		{
			if (ClientRank[targetPlayer] > 0 && ClientRank[targetPlayer] < 51)
			{
				if (ClientRank[targetPlayer] < 4) SetEntityRenderColor(colorEnt, 160, 32, 240, 255);
				else if (ClientRank[targetPlayer] < 11) SetEntityRenderColor(colorEnt, 255, 0, 0, 255);
				else if (ClientRank[targetPlayer] < 21) SetEntityRenderColor(colorEnt, 0, 0, 255, 255);
				else if (ClientRank[targetPlayer] < 31) SetEntityRenderColor(colorEnt, 255, 255, 0, 255);
				else if (ClientRank[targetPlayer] < 41) SetEntityRenderColor(colorEnt, 0, 255, 0, 255);
				else SetEntityRenderColor(colorEnt, 173, 255, 47, 255);				
			}
			else
			{			
				SetEntityRenderColor(colorEnt, 255, 255, 255, 255);	
			}				
			return;				
		}
		if (hm_stats_colors.IntValue == 2)
		{
			if (ClientPoints[targetPlayer] > 5000)
			{
				if (ClientPoints[targetPlayer] > 5000 && ClientPoints[targetPlayer] < 10001) SetEntityRenderColor(colorEnt, 173, 255, 47, 255);
				else if (ClientPoints[targetPlayer] > 10000 && ClientPoints[targetPlayer] < 20001) SetEntityRenderColor(colorEnt, 255, 255, 0, 255);
				else if (ClientPoints[targetPlayer] > 20000 && ClientPoints[targetPlayer] < 40001) SetEntityRenderColor(colorEnt, 0, 0, 255, 255);
				else if (ClientPoints[targetPlayer] > 40000 && ClientPoints[targetPlayer] < 80001) SetEntityRenderColor(colorEnt, 0, 139, 0, 255);
				else if (ClientPoints[targetPlayer] > 80000 && ClientPoints[targetPlayer] < 160001) SetEntityRenderColor(colorEnt, 102, 25, 140, 255);
				else if (ClientPoints[targetPlayer] > 160000 && ClientPoints[targetPlayer] < 320001) SetEntityRenderColor(colorEnt, 255, 104, 240, 255);
				else if (ClientPoints[targetPlayer] > 320000 && ClientPoints[targetPlayer] < 640001) SetEntityRenderColor(colorEnt, 255, 0, 0, 255);
				else if (ClientPoints[targetPlayer] > 800000) SetEntityRenderColor(colorEnt, 0, 0, 0, 255);
				else if (ClientPoints[targetPlayer] > 640000) SetEntityRenderColor(colorEnt, 255, 97, 3, 255); 
			}
			else
			{
				SetEntityRenderColor(colorEnt, 255, 255, 255, 255);
			}
			return;
		}
		SetEntityRenderColor(colorEnt, 255, 255, 255, 255);
	}
}

public Action Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	ADPlayerSpawn(event);
	int client = GetClientOfUserId(event.GetInt("userid"));
	CreateTimer(6.0, TimedGrantPlayerColor, client);
	return Plugin_Continue;
}

public void L4D2_Supercoop_PlayerOnUnfreezed(int client)
{
	GrantPlayerColor(client);
}

public Action TimedGrantPlayerColor(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
	    if (GetClientHealth(client) < 1)
	    {
		     return Plugin_Continue;  
	    }
	    GrantPlayerColor(client);
	}
	return Plugin_Continue;	
}

int IsRealClient(int client)
{
	if (!IsValidClient(client))
	{
		return false;
	}	
	if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
	{
		if (IsClientInGame(client))
		{
			if (!IsFakeClient(client))
			{
				return true;
			}
		}
	}
	return false;
}

int IsValidClient(int client)
{
	if (!IsValidEntity(client))
	{
		return false;
	}
	
	if (client < 1 || client > MaxClients)
	{
		return false;
	}
	return true;
}

public int GetClientZC(int client)
{
	if (!IsValidEntity(client) || !IsValidEdict(client))
	{
		return 0;
	}
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

void ADPlayerTeam()
{
	int count = 0;
	for (int i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
		{
			count++;
		}
	}
	if (playerscount != count)
	{
		playerscount = count;
		if (IsTimeAutodifficulty)
		{
			Autodifficulty();
		}
	}
	updateptystatslayers();
}

public Action Event_PlayerTeam(Event event, char[] name, bool dontBroadcast)
{
	if (event.GetBool("disconnect", false))
	{
		return Plugin_Continue;
	}
	int client = GetClientOfUserId(event.GetInt("userid"));	
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	ADPlayerTeam();
	return Plugin_Continue;
}

float Calculate_Rank_Mod()
{
	float local_result = 1.0;
	switch (l4d2_rankmod_mode.IntValue)
	{
		case 0, 1, 2:
		{
			if (RankTotal < cvar_maxplayers) return SDifficultyMultiplier.FloatValue;
			float sum_low = 0.0;
			float sum_high = 0.0;
			for (int i = 1; i <= cvar_maxplayers; i++)
			{
				sum_low += Sum_Function(i * 1.0);
				sum_high += Sum_Function(RankTotal * 1.0 + 1.0 - i * 1.0);
			}
			sum_low *= 1.0 / cvar_maxplayers * 1.0;
			sum_high *= 1.0 / cvar_maxplayers * 1.0;
			float sum_current = 0.0;
			float current_player_rank = 0.0;
			float current_players_count = 0.0;
			for (int i = 1; i <= L4D_MAXPLAYERS; i++) if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVORS)
			{
				current_players_count++;
				current_player_rank = ClientRank[i] * 1.0;
				if (current_player_rank < 1.0) current_player_rank * 0.5;
				sum_current += Sum_Function(RankTotal + 1.0  - current_player_rank);
			}
			if (current_players_count < 1) return local_result;
			sum_current *= 1.0 / current_players_count * 1.0;
			float k = l4d2_rankmod_max.FloatValue - l4d2_rankmod_min.FloatValue /(sum_high - sum_low);
			float p = l4d2_rankmod_max.FloatValue - k * sum_high;
			local_result = k * sum_current + p;
			if (local_result < l4d2_rankmod_min.FloatValue)
			{
				local_result = l4d2_rankmod_min.FloatValue;
			}
			else if (local_result > l4d2_rankmod_max.FloatValue)
			{
				local_result = l4d2_rankmod_max.FloatValue;
			}
			if (l4d2_rankmod_mode.IntValue == 1) local_result += SDifficultyMultiplier.FloatValue;
			if (l4d2_rankmod_mode.IntValue == 2) local_result *= SDifficultyMultiplier.FloatValue;
			return local_result;
		}
		case 3, 4, 5:
		{
			if (RankTotal < 3600) return SDifficultyMultiplier.FloatValue;
			rank_sum = 0.0;
			int players_count = 0, then;
			for (int i = 1; i <= L4D_MAXPLAYERS; i++) if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVORS)
			{
					if (ClientRank[i] == 0  *then) rank_sum += 0.0;
					else if (ClientRank[i] <= 10 *then) rank_sum += 5.0;
					else if (ClientRank[i] <= 25 *then) rank_sum += 4.4;
					else if (ClientRank[i] <= 50 *then) rank_sum += 3.8;
					else if (ClientRank[i] <= 100 *then) rank_sum += 3.2;
					else if (ClientRank[i] <= 200 *then) rank_sum += 2.6;
					else if (ClientRank[i] <= 400 *then) rank_sum += 2.0;
					else if (ClientRank[i] <= 800 *then) rank_sum += 1.4;
					else if (ClientRank[i] <= 1600 *then) rank_sum += 0.8;
					else if (ClientRank[i] <= 3200 *then) rank_sum += 0.2;
					players_count++;
			}
			if (players_count < 1) players_count = 1;
			local_result = ((rank_sum * 1.0 - (players_count * 1.5)) / (players_count * 1.0)) / 6.0 + 0.75;
			if (local_result < l4d2_rankmod_min.FloatValue) local_result = l4d2_rankmod_min.FloatValue;
			else if (local_result > l4d2_rankmod_max.FloatValue) local_result = l4d2_rankmod_max.FloatValue;
			if (l4d2_rankmod_mode.IntValue == 4) local_result += SDifficultyMultiplier.FloatValue;
			if (l4d2_rankmod_mode.IntValue == 5) local_result *= SDifficultyMultiplier.FloatValue;
			return local_result;
		}
	}
	return SDifficultyMultiplier.FloatValue;
}

float Sum_Function(const float input_value)
{
	if (input_value == 0.0) return 0.0;
	float cvar_rankmod_logarithm = l4d2_rankmod_logarithm.FloatValue;
	if (cvar_rankmod_logarithm >= 1.0) return Logarithm(input_value, cvar_rankmod_logarithm);
	if (cvar_rankmod_logarithm >= 0.0 && cvar_rankmod_logarithm < 1.0) return input_value * cvar_rankmod_logarithm;
	if (0.0 == cvar_rankmod_logarithm) return input_value;
	if (-1.0 == cvar_rankmod_logarithm)
	{
		float x = Logarithm(input_value, 10.0);
		return x * x;
	}
	if (cvar_rankmod_logarithm == -2.0) return (input_value * input_value / ((input_value + RankTotal * 4) / (25.0 * RankTotal))) / 10.0;
	if (-3.0 == cvar_rankmod_logarithm)
	{
		float x = Logarithm(input_value, 10.0);
		return x * x / (0.001 * x + 1.11);
	}
	return input_value;
}

public Action Command_RankSum(int client, int args)
{
	if (client)
	{
		PrintToChat(client, "\x05Rank Sum: \x04%f", rank_sum);
	}
	else
	{
		PrintToServer("Rank Sum: %f", rank_sum);
	}
	return Plugin_Continue;
}

public Action Command_MapFinished(int client, int args)
{
	if (!IsMapFinished)
	{
		IsMapFinished = true;
	}
	return Plugin_Continue;
}

public Action Command_MapNotFinished(int client, int args)
{
	if (IsMapFinished)
	{
		IsMapFinished = false;
	}
	return Plugin_Continue;
}

public Action Command_Bonus(int client, int args)
{
	bonus = cvar_Bonus.IntValue;
	return Plugin_Continue;
}

public Action Event_MapTransition(Event event, char[] name, bool dontBroadcast)
{
	ADOnMapStart();
	IsTimeAutodifficulty = false;
	PrintMapPoints();
	StopMapTiming();
	return Plugin_Continue;
}

public Action Event_FinalWin(Event event, char[] name, bool dontBroadcast)
{
	PrintMapPoints();
	StopMapTiming();
	return Plugin_Continue;
}

void PrintMapPoints()
{
	IsPrint = false;
	for(int i=1;i<=MaxClients;i++)
	{
		if (IsRealClient(i))
		{
			PrintMapTop(i);
		}
	}
	return;
}

public Action Command_GivePoints(int client, int args)
{
	if (IsMapFinished)
	{
		return Plugin_Handled;
	}
	if (args == 2)
	{
		char arg[68], arg2[32], target_name[64];
		GetCmdArg(1, arg, 65);
		GetCmdArg(2, arg2, 32);
		int target_list[65], target_count, targetclient;
		bool tn_is_ml;
		int Score = StringToInt(arg2, 10);
		if (0 >= (target_count = ProcessTargetString(arg, client, target_list, 65, 0, target_name, sizeof(target_name), tn_is_ml)))
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		ReplyToCommand(client, "Point for player: %s set to: %d", target_name, Score);
		int i;
		while (i < target_count)
		{
			targetclient = target_list[i];
			AddPoints(targetclient, Score);
			i++;
		}
		return Plugin_Handled;
	}
	ReplyToCommand(client, "sm_givepoints <#userid|name> [Score]");
	return Plugin_Handled;
}

public void AddPoints(int iClient, int Score)
{		
	if (Score)
	{
		if (Rank_db != null)
		{
			char sQuery[120], sTeamID[24];
			GetClientAuthId(iClient, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
			Format(sQuery, sizeof(sQuery)-1, "UPDATE `players` SET points = points + %d WHERE `steamid` = '%s'", Score, sTeamID);
			SQL_TQuery(Rank_db, ErrorDBCheck, sQuery, 0);
			if (Score > 0)
			{
				PrintToChat(iClient, "\x04+%d", Score);
				NewPoints[iClient] += Score;
			}
			else
			{
				CPrintToChat(iClient, "{red}%d", Score);
			}
		}
	}
}

public Action Command_RankPlayer(int client, int args)
{
	if (args)
	{
		if (args == 1)
		{
			char arg[68], target_name[64];
			GetCmdArg(1, arg, 65);
			int target_list[65], target_count, targetclient;
			bool tn_is_ml;
			if (0 >= (target_count = ProcessTargetString(arg, client, target_list, 65, 0, target_name, sizeof(target_name), tn_is_ml)))
			{
				ReplyToTargetError(client, target_count);
				return Plugin_Handled;
			}
			ReplyToCommand(client, "You are currently viewing the statistics for %s", target_name);
			for(int i=1;i < target_count;i++)
			{
				targetclient = target_list[i];
				KnowRankKills(targetclient);
				KnowRankHeadshots(targetclient);
				KnowRankPlaytime(targetclient);
				DisplayTargetRank(targetclient, client);
			}
			return Plugin_Handled;
		}
		ReplyToCommand(client, "sm_rankplayer <#userid|name>");
		return Plugin_Handled;
	}
	cmd_ShowRank(client, 0);
	return Plugin_Handled;
}

public Action Command_Refresh(int client, int args)
{
	ConnectDB();
	return Plugin_Continue;
}

bool IsPlayerIncapped(int client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
	{
		return true;
	}
	return false;
}

int IsMissionAllowed(char[] map_name)
{
	int result = 1;
	File file = OpenFile(CV_FileName, "r", false, "GAME");
	if (file == null)
	{
		file.Seek(0, SEEK_SET);
		char CV_StoredMap[128];
		while (!IsEndOfFile(file))
		{
			if (file.ReadLine(CV_StoredMap, sizeof(CV_StoredMap)))
			{
				TrimString(CV_StoredMap);
				if (StrEqual(map_name, CV_StoredMap, false))
				{
					result = 0;
					delete file;
					return result;
				}
			}
			delete file;
			return result;
		}
		delete file;
		return result;
	}
	return result;
}

public Action Callvote_Handler(int client, int args)
{
	if (client == 0)
	{
		char voteName[32], initiatorName[32];
		GetClientName(client, initiatorName, sizeof(initiatorName));
		GetCmdArg(1, voteName, sizeof(voteName));
		if (strcmp(voteName,"Kick", false) == 0)
		{
			if (strcmp(voteName, "ReturnToLobby", false) == 0) 
			{
				if (strcmp(voteName, "ChangeMission", false) == 0 || strcmp(voteName, "ChangeChapter", false) == 0) 
				{
					char map_name[128];
					GetCmdArg(2, map_name, sizeof(map_name));
					if (!IsMissionAllowed(map_name))
					{
						AdminId ClientAdminId = GetUserAdmin(client);
						int flags = GetAdminFlags(ClientAdminId, Access_Effective);					
						if (flags & ADMFLAG_VOTE || flags & ADMFLAG_CHANGEMAP)
						{
							CPrintToChat(client, "%t", "Warning! This campaign is forbidden!\n\"Vote\" access granted");
							return Plugin_Continue;
						}
						PrintToChat(client, "%t", "Vote access denied [this campaign is forbidden]");
						return Plugin_Handled;
					}				
					if (GetConVarInt(hm_allowvote_map_players) >= GetRealClientCount())
					{
						PrintToChat(client, "%t", "Vote access granted");
						PrintToChatAll("%t", "%N started the voting", client);
						return Plugin_Continue;
					}
					if (hm_blockvote_map.IntValue == 1)
					{
						AdminId ClientAdminId = GetUserAdmin(client);
						int flags = GetAdminFlags(ClientAdminId, Access_Effective);						
						if ((ClientRank[client] < hm_allowvote_mission.IntValue && ClientRank[client]) || (flags & 1 || flags & 1024 || flags & 64))
						{
							PrintToChat(client, "%t", "Vote access granted");
							PrintToChatAll("%t", "%N started the voting", client);
							return Plugin_Continue;
						}
						else
						{
						PrintToChat(client, "%t", "Vote access denied [%d > %d]", ClientRank[client], hm_allowvote_mission.IntValue);
						return Plugin_Handled;
						}
					}
				}
				if (strcmp(voteName, "RestartGame", false) == 0) 
				{
					if (strcmp(voteName, "ChangeDifficulty", false) == 0) 
					{
						return Plugin_Continue;
					}
					if (hm_blockvote_difficulty.IntValue > 0)
					{
						AdminId ClientAdminId = GetUserAdmin(client);
						int flags = GetAdminFlags(ClientAdminId, Access_Effective);				
						if (flags & ADMFLAG_VOTE & ADMFLAG_CONVARS || flags & ADMFLAG_ROOT)
						{
							PrintToChat(client, "%t", "Vote access granted");
							PrintToChatAll("%t", "%N started the voting", client);
							return Plugin_Continue;
						}
						else
						{
						PrintToChat(client, "%t", "Vote access denied");
						return Plugin_Handled;
						}
					}
					else
					{
					PrintToChat(client, "%t", "Vote access granted");
					PrintToChatAll("%t", "%N started the voting", client);
					return Plugin_Continue;
					}
				}
				if (hm_blockvote_restart.IntValue)
				{
					if (hm_blockvote_restart.IntValue == 1)
					{
						AdminId ClientAdminId = GetUserAdmin(client);
						int flags = GetAdminFlags(ClientAdminId, Access_Effective);					
						if (flags & ADMFLAG_VOTE || flags & ADMFLAG_ROOT || (ClientRank[client] < 21 && ClientRank[client]))
						{
							PrintToChat(client, "%t", "Vote access granted");
							PrintToChatAll("%t", "%N started the voting", client);
							return Plugin_Continue;
						}
						else
						{
						PrintToChat(client, "%t", "Vote access denied");
						return Plugin_Handled;
						}
					}
					else
					{
					PrintToChat(client, "%t", "Vote access denied");
					return Plugin_Handled;
					}
				}
				else
				{
				PrintToChat(client, "%t", "Vote access granted");
				return Plugin_Continue;
				}
			}
			if (hm_blockvote_lobby.IntValue > 0)
			{
				PrintToChat(client, "%t", "Vote access denied");
				return Plugin_Handled;
			}
			PrintToChat(client, "%t", "Vote access granted");
			PrintToChatAll("%t", "%N started the voting", client);
			return Plugin_Continue;
		}
		return Kick_Vote_Logic(client, args);
	}
	return Plugin_Continue;
}

public Action Kick_Vote_Logic(int client, int args)
{
	char initiatorName[32], arg2[12];
	GetClientName(client, initiatorName, sizeof(initiatorName));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = GetClientOfUserId(StringToInt(arg2));	
	if (!target) return Plugin_Handled;	
	if (g_votekick[client] > 3)
	{
		PrintToChat(client, "\x05You have already voted 3 times per card!");
		PrintToChat(client, "%t", "Vote access denied");
		return Plugin_Handled;
	}
	AdminId ClientAdminId = GetUserAdmin(client);
	AdminId TargetAdminId = GetUserAdmin(target);
	int flags = GetAdminFlags(ClientAdminId, Access_Effective);
	if (hm_blockvote_kick.IntValue)
	{
		if (hm_blockvote_kick.IntValue == 1)
		{		
			if (flags & ADMFLAG_VOTE || flags & 1 || flags & ADMFLAG_ROOT || ClientRank[client] < 51)
			{
				if (ClientRank[client] - hm_blockvote_difference.IntValue >= ClientRank[target])
				{
					int flags2 = GetAdminFlags(TargetAdminId, Access_Effective);
					
					if (flags2 & ADMFLAG_GENERIC || flags2 & ADMFLAG_ROOT)
					{
						PrintToChat(client, "%t", "Vote access denied. Target is Admin");
						return Plugin_Handled;
					}
					else
					{
					PrintToChat(client, "%t", "Vote access granted");
					g_votekick[client] = g_votekick[client] + 1;
					}
				}
				else
				{
				PrintToChat(client, "%t", "Vote access denied");
				PrintToChat(client, "%t \x04[\x03%d \x05>=\x03 %d\x04]", "Vote access denied", ClientRank[client], ClientRank[target]);
				return Plugin_Handled;
				}
			}
			else
			{
			PrintToChat(client, "%t \x04[\x03%d \x05>\x03 50\x04]", "Vote access denied", ClientRank[client]);
			return Plugin_Handled;
			}
		}
		PrintToChatAll("%t", "%N started the voting", client);
		return Plugin_Continue;
	}
	PrintToChat(client, "%t", "Vote access granted");
	g_votekick[client] = g_votekick[client] + 1;
	return Plugin_Continue;
}

public Action Command_city17l4d2(int client, int args)
{
	if (client < 1)
	{
		return Plugin_Handled;
	}	
	if (hm_blockvote_map.IntValue && hm_allowvote_map_players.IntValue <= GetRealClientCount(true))
	{
		PrintToChat(client, "%t", "Vote access granted");
		PrintToChatAll("%t", "%N started the voting", client);
		ServerCommand("sm_votemap l4d2_city17_01");
		if (bStandartMap())
		{
			SaveMap();
		}
		return Plugin_Continue;
	}
	if (hm_blockvote_map.IntValue == 1)
	{
		AdminId ClientAdminId = GetUserAdmin(client);
		int flags = GetAdminFlags(ClientAdminId, Access_Effective);		
		if ((ClientRank[client] < hm_allowvote_mission.IntValue && ClientRank[client]) || (flags & ADMFLAG_VOTE || flags & ADMFLAG_CHANGEMAP))
		{
			PrintToChat(client, "%t", "Vote access granted");
			PrintToChatAll("%t", "%N started the voting", client);
			ServerCommand("sm_votemap l4d2_city17_01");
			if (bStandartMap())
			{
				SaveMap();
			}
			return Plugin_Continue;
		}
		else
		{
		PrintToChat(client, "%t", "Vote access denied [%d > %d]", ClientRank[client], hm_allowvote_mission.IntValue);
		return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action Command_warcelona(int client, int args)
{
	if (client < 1)
	{
		return Plugin_Handled;
	}	
	if (hm_blockvote_map.IntValue && hm_allowvote_map_players.IntValue >= GetRealClientCount(true))
	{
		PrintToChat(client, "%t", "Vote access granted");
		PrintToChatAll("%t", "%N started the voting", client);
		ServerCommand("sm_votemap srocchurch");
		if (bStandartMap())
		{
			SaveMap();
		}
		return Plugin_Continue;
	}
	if (hm_blockvote_map.IntValue == 1)
	{
		AdminId ClientAdminId = GetUserAdmin(client);
		int flags = GetAdminFlags(ClientAdminId, Access_Effective);
		
		if ((ClientRank[client] < hm_allowvote_mission.IntValue && ClientRank[client]) || (flags & ADMFLAG_VOTE || flags & ADMFLAG_CHANGEMAP))
		{
			PrintToChat(client, "%t", "Vote access granted");
			PrintToChatAll("%t", "%N started the voting", client);
			ServerCommand("sm_votemap srocchurch");
			if (bStandartMap())
			{
				SaveMap();
			}
			return Plugin_Continue;
		}
		else
		{
		PrintToChat(client, "%t", "Vote access denied [%d > %d]", ClientRank[client], hm_allowvote_mission.IntValue);
		return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action Command_symbyosys(int client, int args)
{
	if (client < 1)
	{
		return Plugin_Handled;
	}	
	if (hm_blockvote_map.IntValue && hm_allowvote_map_players.IntValue >= GetRealClientCount(true))
	{
		PrintToChat(client, "%t", "Vote access granted");
		PrintToChatAll("%t", "%N started the voting", client);
		ServerCommand("sm_votemap symbyosys_intro");
		if (bStandartMap())
		{
			SaveMap();
		}
		return Plugin_Continue;
	}
	if (hm_blockvote_map.IntValue == 1)
	{
		AdminId ClientAdminId = GetUserAdmin(client);
		int flags = GetAdminFlags(ClientAdminId, Access_Effective);		
		if ((ClientRank[client] < hm_allowvote_mission.IntValue && ClientRank[client]) || (flags & ADMFLAG_VOTE || flags & ADMFLAG_CHANGEMAP))
		{
			PrintToChat(client, "%t", "Vote access granted");
			PrintToChatAll("%t", "%N started the voting", client);
			ServerCommand("sm_votemap l4d2_ravenholmwar_1");
			if (bStandartMap())
			{
				SaveMap();
			}
			return Plugin_Continue;
		}
		else
		{
		PrintToChat(client, "%t", "Vote access denied [%d > %d]", ClientRank[client], hm_allowvote_mission.IntValue);
		return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action Command_one4nine(int client, int args)
{
	if (client < 1)
	{
		return Plugin_Handled;
	}	
	if (hm_blockvote_map.IntValue && hm_allowvote_map_players.IntValue >= GetRealClientCount(true))
	{
		PrintToChat(client, "%t", "Vote access granted");
		PrintToChatAll("%t", "%N started the voting", client);
		ServerCommand("sm_votemap l4d_149_1");
		if (bStandartMap())
		{
			SaveMap();
		}
		return Plugin_Continue;
	}
	if (GetConVarInt(hm_blockvote_map) == 1)
	{
		AdminId ClientAdminId = GetUserAdmin(client);
		int flags = GetAdminFlags(ClientAdminId, Access_Effective);		
		if ((ClientRank[client] < hm_allowvote_mission.IntValue && ClientRank[client]) || (flags & ADMFLAG_VOTE || flags & ADMFLAG_CHANGEMAP))
		{
			PrintToChat(client, "%t", "Vote access granted");
			PrintToChatAll("%t", "%N started the voting", client);
			ServerCommand("sm_votemap l4d_149_1");
			if (bStandartMap())
			{
				SaveMap();
			}
			return Plugin_Continue;
		}
		else
		{
		PrintToChat(client, "%t", "Vote access denied [%d > %d]", ClientRank[client], hm_allowvote_mission.IntValue);
		return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

void SaveMap()
{
	if (!FileExists("mapfinalnext_recover.txt", false, "GAME"))
	{
		File dataFileHandle = OpenFile("mapfinalnext_recover.txt", "a", false, "GAME");
		dataFileHandle.WriteLine("c1m1_hotel");
		delete dataFileHandle;
	}
	else
	{
		if (FileExists("mapfinalnext_recover.txt", false, "GAME"))
		{
			if (!DeleteFile("mapfinalnext_recover.txt", false, "DEFAULT_WRITE_PATH"))
			{
				LogError("[Mapfinalnext Map Recovery] Warning: Failed to delete \"%s\" possibly due to lacking permissions.", "mapfinalnext_recover.txt");
			}
		}
	}
	File inf = OpenFile("mapfinalnext_recover.txt", "w+", false, "GAME");
	if (inf)
	{
		char CurrentMap[256];
		GetCurrentMap(CurrentMap, sizeof(CurrentMap));
		if (bStandartMapOfCampaign())
		{
			inf.WriteLine(CurrentMap);
		}
		delete inf;
		return;
	}
	LogError("[Mapfinalnext Map Recovery] Failed to open/create file '%s'", "mapfinalnext_recover.txt");
	return;
}

public bool bStandartMapOfCampaign()
{
	char MapName[128];
	GetCurrentMap(MapName, sizeof(MapName));
	if (StrContains(MapName, "c1m1", true) > -1 || StrContains(MapName, "c1m2", true) > -1 || StrContains(MapName, "c1m3", true) > -1 || StrContains(MapName, "c1m4", true) > -1 || StrContains(MapName, "c2m1", true) > -1 || StrContains(MapName, "c2m2", true) > -1 || StrContains(MapName, "c2m3", true) > -1 || StrContains(MapName, "c2m4", true) > -1 || StrContains(MapName, "c2m5", true) > -1 || StrContains(MapName, "c3m1", true) > -1 || StrContains(MapName, "c3m2", true) > -1 || StrContains(MapName, "c3m3", true) > -1 || StrContains(MapName, "c3m4", true) > -1 || StrContains(MapName, "c4m1", true) > -1 || StrContains(MapName, "c4m2", true) > -1 || StrContains(MapName, "c4m3", true) > -1 || StrContains(MapName, "c4m4", true) > -1 || StrContains(MapName, "c4m5", true) > -1 || StrContains(MapName, "c5m1", true) > -1 || StrContains(MapName, "c5m2", true) > -1 || StrContains(MapName, "c5m3", true) > -1 || StrContains(MapName, "c5m4", true) > -1 || StrContains(MapName, "c5m5", true) > -1 || StrContains(MapName, "c6m1", true) > -1 || StrContains(MapName, "c6m2", true) > -1 || StrContains(MapName, "c6m3", true) > -1 || StrContains(MapName, "c7m1", true) > -1 || StrContains(MapName, "c7m2", true) > -1 || StrContains(MapName, "c7m3", true) > -1 || StrContains(MapName, "c8m1", true) > -1 || StrContains(MapName, "c8m2", true) > -1 || StrContains(MapName, "c8m3", true) > -1 || StrContains(MapName, "c8m4", true) > -1 || StrContains(MapName, "c8m5", true) > -1 || StrContains(MapName, "c9m1", true) > -1 || StrContains(MapName, "c9m2", true) > -1 || StrContains(MapName, "c10m1", true) > -1 || StrContains(MapName, "c10m2", true) > -1 || StrContains(MapName, "c10m3", true) > -1 || StrContains(MapName, "c10m4", true) > -1 || StrContains(MapName, "c10m5", true) > -1 || StrContains(MapName, "c11m1", true) > -1 || StrContains(MapName, "c11m2", true) > -1 || StrContains(MapName, "c11m3", true) > -1 || StrContains(MapName, "c11m4", true) > -1 || StrContains(MapName, "c11m5", true) > -1 || StrContains(MapName, "c12m1", true) > -1 || StrContains(MapName, "c12m2", true) > -1 || StrContains(MapName, "c12m3", true) > -1 || StrContains(MapName, "c12m4", true) > -1 || StrContains(MapName, "c12m5", true) > -1 || StrContains(MapName, "c13m1", true) > -1 || StrContains(MapName, "c13m2", true) > -1 || StrContains(MapName, "c13m3", true) > -1 || StrContains(MapName, "c13m4", true) > -1)
	{
		return true;
	}
	return false;
}

public void OnConfigsExecuted()
{
	ReadDb();
}

void ReadDb()
{
	ReadDbMotd();
}

void ReadDbMotd()
{
	char query[512];
	Format(query, sizeof(query), "SELECT svalue FROM server_settings WHERE sname = 'motdmessage' LIMIT 1");
	SQL_TQuery(Rank_db, ReadDbMotdCallback, query, DBPrio_Normal);
}

public void ReadDbMotdCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("ReadDbMotdCallback Query failed: %s", error);
		return;
	}

	if (SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 0, MessageOfTheDay, sizeof(MessageOfTheDay));
	}
}

public Action Command_SetMotd(int client, int args)
{
	char arg[1024];
	GetCmdArgString(arg, sizeof(arg));
	UpdateServerSettings(client, "motdmessage", arg, MOTD_TITLE);
	return Plugin_Handled;
}

bool UpdateServerSettings(int Client, char[] Key, char[] Value, char[] Desc)
{
	Handle statement;
	char error[1024], query[2048];
	if (!DoFastQuery(Client, "INSERT IGNORE INTO server_settings SET sname = '%s', svalue = ''", Key))
	{
		PrintToConsole(Client, "[RANK] %s: Setting a new MOTD value failure!", Desc);
		return false;
	}
	Format(query, sizeof(query), "UPDATE server_settings SET svalue = ? WHERE sname = '%s'", Key);
	statement = SQL_PrepareQuery(Rank_db, query, error, sizeof(error));
	if (statement == null)
	{
		bool retval = true;
		SQL_BindParamString(statement, 0, Value, false);
		if (!SQL_Execute(statement))
		{
			if (SQL_GetError(Rank_db, error, sizeof(error)))
			{
				PrintToConsole(Client, "[RANK] %s: Update failed! (Error = \"%s\")", Desc, error);
				LogError("%s: Update failed! (Error = \"%s\")", Desc, error);
			}
			else
			{
				PrintToConsole(Client, "[RANK] %s: Update failed!", Desc);
				LogError("%s: Update failed!", Desc);
			}
			retval = false;
		}
		else
		{
			PrintToConsole(Client, "[RANK] %s: Update successful!", Desc);
			if (StrEqual(Key, "motdmessage", false))
			{
				strcopy(MessageOfTheDay, sizeof(MessageOfTheDay), Value);
			}
		}
		delete statement;
		return retval;
	}
	PrintToConsole(Client, "[RANK] %s: Update failed! (Reason: Cannot create SQL statement)");
	return false;
}

bool DoFastQuery(int Client, const char[] Query, any ...)
{
	char FormattedQuery[4096], Error[1024];
	VFormat(FormattedQuery, sizeof(FormattedQuery), Query, 3);
	if (!SQL_FastQuery(Rank_db, FormattedQuery))
	{
		if (SQL_GetError(Rank_db, Error, sizeof(Error)))
		{
			PrintToConsole(Client, "Fast query failed! (Error = \"%s\") Query = \"%s\"", Error, FormattedQuery);
			LogError("Fast query failed! (Error = \"%s\") Query = \"%s\"", Error, FormattedQuery);
		}
		else
		{
			PrintToConsole(Client, "Fast query failed! Query = \"%s\"", FormattedQuery);
			LogError("Fast query failed! Query = \"%s\"", FormattedQuery);
		}
		return false;
	}
	return true;
}

public Action Event_StartArea(Event event, char[] name, bool dontBroadcast)
{
	if (bFirstMapOfCampaign())
	{
		StartMapTiming();
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "prop_door_rotating_checkpoint", true))
	{
		if (!(GetEntProp(entity, Prop_Send, "m_eDoorState")))
		{
			HookSingleEntityOutput(entity, "OnFullyOpen", OnStartSFDoorFullyOpened, true);
		}
	}
	else if (StrEqual(classname, "survivor_death_model", true))
	{
		RequestFrame(Frame_ApplyDeathModelRankColor, EntIndexToEntRef(entity));
	}
}

public void OnStartSFDoorFullyOpened(char[] output, int caller, int activator, float delay)
{
	StartMapTiming();
}

public void StartMapTiming()
{
	if (MapTimingStartTime != 0.0)
	{
		return;
	}
	MapTimingStartTime = GetEngineTime();
	for(int i=1;i<=MaxClients;i++)
	{	
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
		{
			EmitSoundToClient(i, "level/countdown.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		}
	}
	return;
}

public void StopMapTiming()
{
	if (MapTimingStartTime <= 0.0)
	{
		return;
	}
	float TotalTime = GetEngineTime() - MapTimingStartTime;
	MapTimingStartTime = -1.0;
	char TimeLabel[32];
	SetTimeLabel(TotalTime, TimeLabel, sizeof(TimeLabel));
	for(int i=1;i<=MaxClients;i++)
	{		
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
		{
			EmitSoundToClient(i, "level/bell_normal.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
			PrintToChat(i, "%t", "It took %s to finish this map!", TimeLabel);
		}
	}
	return;
}

public void SetTimeLabel(float TheSeconds, char[] TimeLabel, int maxsize)
{
	int FlooredSeconds = RoundToFloor(TheSeconds);
	int FlooredSecondsMod = FlooredSeconds % 60;
	float Seconds = TheSeconds - float(FlooredSeconds) + float(FlooredSecondsMod);
	int Minutes = (TheSeconds < 60.0 ? 0 : RoundToNearest(float(FlooredSeconds - FlooredSecondsMod) / 60));
	int MinutesMod = Minutes % 60;
	int Hours = (Minutes < 60 ? 0 : RoundToNearest(float(Minutes - MinutesMod) / 60));
	Minutes = MinutesMod;
	if (Hours > 0)
		Format(TimeLabel, maxsize, "%ih %im %.1fs", Hours, Minutes, Seconds);
	else if (Minutes > 0)
		Format(TimeLabel, maxsize, "%i min %.1f sec", Minutes, Seconds);
	else
		Format(TimeLabel, maxsize, "%.1f seconds", Seconds);
}

public bool bFirstMapOfCampaign()
{
	char MapName[128];
	GetCurrentMap(MapName, sizeof(MapName));
	if (StrContains(MapName, "c1m1", true) > -1 || StrContains(MapName, "c2m1", true) > -1 || StrContains(MapName, "c3m1", true) > -1 || StrContains(MapName, "c4m1", true) > -1 || StrContains(MapName, "c5m1", true) > -1 || StrContains(MapName, "c6m1", true) > -1 || StrContains(MapName, "c7m1", true) > -1 || StrContains(MapName, "c8m1", true) > -1 || StrContains(MapName, "c9m1", true) > -1 || StrContains(MapName, "c10m1", true) > -1 || StrContains(MapName, "c11m1", true) > -1 || StrContains(MapName, "c12m1", true) > -1 || StrContains(MapName, "c13m1", true) > -1 || StrContains(MapName, "l4d_zero01_base", true) > -1 || StrContains(MapName, "l4d_viennacalling2_1", true) > -1 || StrContains(MapName, "eu01_residential_b16", true) > -1 || StrContains(MapName, "bloodtracks_01", true) > -1 || StrContains(MapName, "l4d2_darkblood01_tanker", true) > -1 || StrContains(MapName, "l4d_dbd2dc_anna_is_gone", true) > -1 || StrContains(MapName, "cdta_01detour", true) > -1 || StrContains(MapName, "l4d_ihm01_forest", true) > -1 || StrContains(MapName, "l4d2_diescraper1_apartment_31", true) > -1 || StrContains(MapName, "l4d_149_1", true) > -1 || StrContains(MapName, "gr-mapone-7", true) > -1 || StrContains(MapName, "qe_1_cliche", true) > -1 || StrContains(MapName, "l4d2_stadium1_apartment", true) > -1 || StrContains(MapName, "eu01_residential_b09", true) > -1 || StrContains(MapName, "wth_1", true) > -1 || StrContains(MapName, "2ee_01", true) > -1 || StrContains(MapName, "l4d2_city17_01", true) > -1 || StrContains(MapName, "l4d_deathaboard01_prison", true) > -1 || StrContains(MapName, "cwm1_intro", true) > -1 || StrContains(MapName, "2ee_01_deadlybeggining", true) > -1 || StrContains(MapName, "symbyosys_intro", true) > -1 || StrContains(MapName, "hf01_theforest", true) > -1 || StrContains(MapName, "l4d2_deadcity01_riverside", true) > -1 || StrContains(MapName, "tutorial01", true) > -1 || StrContains(MapName, "tutorial_standards", true) > -1 || StrContains(MapName, "srocchurch", true) > -1 || StrContains(MapName, "l4d2_ravenholmwar_1", true) > -1)
	{
		return true;
	}
	return false;
}

public bool bStandartMap()
{
	char MapName[128];
	GetCurrentMap(MapName, sizeof(MapName));
	if (StrContains(MapName, "c1m", true) > -1 || StrContains(MapName, "c2m", true) > -1 || StrContains(MapName, "c3m", true) > -1 || StrContains(MapName, "c4m", true) > -1 || StrContains(MapName, "c5m", true) > -1 || StrContains(MapName, "c6m", true) > -1 || StrContains(MapName, "c7m", true) > -1 || StrContains(MapName, "c8m", true) > -1 || StrContains(MapName, "c9m", true) > -1 || StrContains(MapName, "c10m", true) > -1 || StrContains(MapName, "c11m", true) > -1 || StrContains(MapName, "c12m", true) > -1 || StrContains(MapName, "c13m", true) > -1)
	{
		return true;
	}
	return false;
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "LMCCore") == 0 || strcmp(name, "L4D2ModelChanger") == 0) g_bLmcActive = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "LMCCore") == 0 || strcmp(name, "L4D2ModelChanger") == 0) g_bLmcActive = false;
}

int GetRankColorTarget(int client)
{
	if (client <= 0 || !IsClientInGame(client)) return 0;

	int target = client;
	if (IsFakeClient(client))
	{
		target = GetClientOfIdleClient(client);
		if (target <= 0) return 0;
	}

	if (g_hUseRankCookie != null)
	{
		char sRank[4];
		GetClientCookie(target, g_hUseRankCookie, sRank, sizeof(sRank));
		if (sRank[0] != '\0' && strcmp(sRank, "0") == 0)
		{
			return 0;
		}
	}

	if (g_bLmcActive)
	{
		int overlay = LMC_GetClientOverlayModel(client);
		if (overlay > MaxClients)
		{
			return overlay;
		}
	}

	return client;
}

public Action Command_RefreshRankColor(int client, int args)
{
	if (args < 1) return Plugin_Handled;
	char arg[16];
	GetCmdArg(1, arg, sizeof(arg));
	int target = GetClientOfUserId(StringToInt(arg));
	if (target > 0 && IsClientInGame(target))
	{
		GrantPlayerColor(target);
	}
	return Plugin_Handled;
}

int GetClientOfIdleClient(int bot)
{
	if (HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))
	{
		int userid = GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID");
		if (userid > 0)
		{
			int owner = GetClientOfUserId(userid);
			if (owner > 0 && IsClientInGame(owner))
			{
				return owner;
			}
		}
	}
	return 0;
}

public void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (bot > 0 && IsClientInGame(bot))
	{
		CreateTimer(0.1, Timer_ApplyRankColor, GetClientUserId(bot));
	}
}

public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	if (player > 0 && IsClientInGame(player))
	{
		CreateTimer(0.1, Timer_ApplyRankColor, GetClientUserId(player));
	}
}

public Action Timer_ApplyRankColor(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0 && IsClientInGame(client))
	{
		GrantPlayerColor(client);
	}
	return Plugin_Handled;
}

int GetIdleBotOfClient(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2)
		{
			if (GetClientOfIdleClient(i) == client)
			{
				return i;
			}
		}
	}
	return 0;
}

void Frame_ApplyDeathModelRankColor(any entRef)
{
	int entity = EntRefToEntIndex(entRef);
	if (entity > 0 && IsValidEntity(entity))
	{
		int client = GetSurvivorFromDeathModel(entity);
		if (client > 0 && IsClientInGame(client))
		{
			int targetPlayer = client;
			if (IsFakeClient(client))
			{
				targetPlayer = GetClientOfIdleClient(client);
			}

			if (targetPlayer > 0 && IsClientInGame(targetPlayer))
			{
				if (g_hUseRankCookie != null)
				{
					char sRank[4];
					GetClientCookie(targetPlayer, g_hUseRankCookie, sRank, sizeof(sRank));
					if (sRank[0] != '\0' && strcmp(sRank, "0") == 0)
					{
						return;
					}
				}

				if (hm_stats_colors.IntValue >= 1)
				{
					SetEntityRenderMode(entity, RENDER_TRANSCOLOR);

					if (hm_stats_colors.IntValue == 1)
					{
						if (ClientRank[targetPlayer] > 0 && ClientRank[targetPlayer] < 51)
						{
							if (ClientRank[targetPlayer] < 4) SetEntityRenderColor(entity, 160, 32, 240, 255);
							else if (ClientRank[targetPlayer] < 11) SetEntityRenderColor(entity, 255, 0, 0, 255);
							else if (ClientRank[targetPlayer] < 21) SetEntityRenderColor(entity, 0, 0, 255, 255);
							else if (ClientRank[targetPlayer] < 31) SetEntityRenderColor(entity, 255, 255, 0, 255);
							else if (ClientRank[targetPlayer] < 41) SetEntityRenderColor(entity, 0, 255, 0, 255);
							else SetEntityRenderColor(entity, 173, 255, 47, 255);				
						}
						else
						{			
							SetEntityRenderColor(entity, 255, 255, 255, 255);	
						}				
					}
					else if (hm_stats_colors.IntValue == 2)
					{
						if (ClientPoints[targetPlayer] > 5000)
						{
							if (ClientPoints[targetPlayer] > 5000 && ClientPoints[targetPlayer] < 10001) SetEntityRenderColor(entity, 173, 255, 47, 255);
							else if (ClientPoints[targetPlayer] > 10000 && ClientPoints[targetPlayer] < 20001) SetEntityRenderColor(entity, 255, 255, 0, 255);
							else if (ClientPoints[targetPlayer] > 20000 && ClientPoints[targetPlayer] < 40001) SetEntityRenderColor(entity, 0, 0, 255, 255);
							else if (ClientPoints[targetPlayer] > 40000 && ClientPoints[targetPlayer] < 80001) SetEntityRenderColor(entity, 0, 139, 0, 255);
							else if (ClientPoints[targetPlayer] > 80000 && ClientPoints[targetPlayer] < 160001) SetEntityRenderColor(entity, 102, 25, 140, 255);
							else if (ClientPoints[targetPlayer] > 160000 && ClientPoints[targetPlayer] < 320001) SetEntityRenderColor(entity, 255, 104, 240, 255);
							else if (ClientPoints[targetPlayer] > 320000 && ClientPoints[targetPlayer] < 640001) SetEntityRenderColor(entity, 255, 0, 0, 255);
							else if (ClientPoints[targetPlayer] > 800000) SetEntityRenderColor(entity, 0, 0, 0, 255);
							else if (ClientPoints[targetPlayer] > 640000) SetEntityRenderColor(entity, 255, 97, 3, 255); 
						}
						else
						{
							SetEntityRenderColor(entity, 255, 255, 255, 255);
						}
					}
				}
			}
		}
	}
}

int GetSurvivorFromDeathModel(int iEntity) {
	int iTargetChar = GetEntProp(iEntity, Prop_Send, "m_nCharacterType");
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || GetClientTeam(i) != 2) continue;
		if(iTargetChar == GetEntProp(i, Prop_Send, "m_survivorCharacter")) return i;
	}
	return 0;
}