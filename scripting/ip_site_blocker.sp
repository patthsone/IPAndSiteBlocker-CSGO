#include <sourcemod>
#tryinclude <materialadmin>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name        = "IP & Site Blocker",
    author      = "PattHs",
    description = "Block IP, domains, banwords with MaterialAdmin support",
    version     = "0.0.4",
    url         = "https://discord.gg/VmJzFBD6wf"
};

bool g_bHasMA = false;
bool g_bEnableIP = true;
bool g_bEnableDomain = true;
bool g_bEnableBanWords = true;
bool g_bLogEnabled = true;
int g_iPunishType = 1;
char g_sPunishCmd[256] = "sm_gag #%i 60";
int g_iMuteTime = 60;
int g_iBanTime = 60;
int g_iMABanType = 1;
int g_iMAMuteType = 3;

ArrayList g_hWhitelistIP;
ArrayList g_hWhitelistDomains;
ArrayList g_hBanWords;

char g_sPrefix[64];

#if defined _materialadmin_included
public void __pl_materialadmin_SetNTVOptional()
{
    MarkNativeAsOptional("MASetClientMuteType");
    MarkNativeAsOptional("MABanPlayer");
}
#endif

public void OnPluginStart()
{
    g_bHasMA = LibraryExists("materialadmin");

    CreateConVar("sm_isb_version", "1.0", "IP & Site Blocker version", FCVAR_SPONLY|FCVAR_NOTIFY);
    CreateConVar("sm_isb_enable_ip", "1", "Enable IP blocking (1=on,0=off)");
    CreateConVar("sm_isb_enable_domain", "1", "Enable domain blocking (1=on,0=off)");
    CreateConVar("sm_isb_enable_banwords", "1", "Enable banwords filter (1=on,0=off)");
    CreateConVar("sm_isb_log", "1", "Log violations (1=yes,0=no)");
    CreateConVar("sm_isb_punish_type", "1", "Punishment: 1=warn,2=kick,3=mute(sm_gag),4=ban,5=custom,11=MA mute,12=MA ban");
    CreateConVar("sm_isb_punish_cmd", "sm_gag #%i 60", "Custom command for type 5, use {steamid64},{ip},{name},#%i");
    CreateConVar("sm_isb_mute_time", "60", "Mute time in minutes (type 3 & 11)");
    CreateConVar("sm_isb_ban_time", "60", "Ban time in minutes (type 4 & 12, 0=permanent)");
    CreateConVar("sm_isb_ma_ban_type", "1", "MA ban type: 1=SteamID,2=IP");
    CreateConVar("sm_isb_ma_mute_type", "3", "MA mute type: 1=voice,2=text,3=both");
    AutoExecConfig(true, "ip_site_blocker");

    RegAdminCmd("sm_isb_reload", Command_Reload, ADMFLAG_CONFIG, "Reload configs and lists");

    LoadTranslations("ip_site_blocker.phrases");
    Format(g_sPrefix, sizeof(g_sPrefix), "%t", "Prefix");

    CreateDirectories();
    LoadLists();

    AddCommandListener(OnSayCommand, "say");
    AddCommandListener(OnSayCommand, "say_team");
    HookEvent("player_changename", Event_OnChangeName);
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "materialadmin")) g_bHasMA = true;
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "materialadmin")) g_bHasMA = false;
}

public void OnConfigsExecuted()
{
    g_bEnableIP       = GetConVarBool(FindConVar("sm_isb_enable_ip"));
    g_bEnableDomain   = GetConVarBool(FindConVar("sm_isb_enable_domain"));
    g_bEnableBanWords = GetConVarBool(FindConVar("sm_isb_enable_banwords"));
    g_bLogEnabled     = GetConVarBool(FindConVar("sm_isb_log"));
    g_iPunishType     = GetConVarInt(FindConVar("sm_isb_punish_type"));
    GetConVarString(FindConVar("sm_isb_punish_cmd"), g_sPunishCmd, sizeof(g_sPunishCmd));
    g_iMuteTime       = GetConVarInt(FindConVar("sm_isb_mute_time"));
    g_iBanTime        = GetConVarInt(FindConVar("sm_isb_ban_time"));
    g_iMABanType      = GetConVarInt(FindConVar("sm_isb_ma_ban_type"));
    g_iMAMuteType     = GetConVarInt(FindConVar("sm_isb_ma_mute_type"));
}

void CreateDirectories()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/ip_site_blocker");
    if (!DirExists(path)) CreateDirectory(path, 755);

    BuildPath(Path_SM, path, sizeof(path), "configs/ip_site_blocker/whitelist_ip.txt");
    if (!FileExists(path))
    {
        File f = OpenFile(path, "w");
        f.WriteLine("127.0.0.1:27015");
        f.Close();
    }

    BuildPath(Path_SM, path, sizeof(path), "configs/ip_site_blocker/whitelist_domains.txt");
    if (!FileExists(path))
    {
        File f = OpenFile(path, "w");
        f.WriteLine("example.com");
        f.Close();
    }

    BuildPath(Path_SM, path, sizeof(path), "configs/ip_site_blocker/banwords.txt");
    if (!FileExists(path))
    {
        File f = OpenFile(path, "w");
        f.WriteLine("test");
        f.Close();
    }
}

void LoadLists()
{
    if (g_hWhitelistIP != null) delete g_hWhitelistIP;
    g_hWhitelistIP = new ArrayList(64);
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/ip_site_blocker/whitelist_ip.txt");
    File f = OpenFile(path, "r");
    if (f != null)
    {
        char line[64];
        while (!f.EndOfFile() && f.ReadLine(line, sizeof(line)))
        {
            TrimString(line);
            if (line[0] == '\0' || line[0] == ';' || line[0] == '/') continue;
            g_hWhitelistIP.PushString(line);
        }
        f.Close();
    }

    if (g_hWhitelistDomains != null) delete g_hWhitelistDomains;
    g_hWhitelistDomains = new ArrayList(128);
    BuildPath(Path_SM, path, sizeof(path), "configs/ip_site_blocker/whitelist_domains.txt");
    f = OpenFile(path, "r");
    if (f != null)
    {
        char line[128];
        while (!f.EndOfFile() && f.ReadLine(line, sizeof(line)))
        {
            TrimString(line);
            if (line[0] == '\0' || line[0] == ';' || line[0] == '/') continue;
            StringToLower(line);
            g_hWhitelistDomains.PushString(line);
        }
        f.Close();
    }

    if (g_hBanWords != null) delete g_hBanWords;
    g_hBanWords = new ArrayList(64);
    BuildPath(Path_SM, path, sizeof(path), "configs/ip_site_blocker/banwords.txt");
    f = OpenFile(path, "r");
    if (f != null)
    {
        char line[64];
        while (!f.EndOfFile() && f.ReadLine(line, sizeof(line)))
        {
            TrimString(line);
            if (line[0] == '\0' || line[0] == ';' || line[0] == '/') continue;
            StringToLower(line);
            g_hBanWords.PushString(line);
        }
        f.Close();
    }

    if (g_bLogEnabled)
    {
        LogToFileEx("addons/sourcemod/logs/ip_site_blocker.log", "Loaded lists: IP=%d, Domains=%d, BanWords=%d",
            g_hWhitelistIP.Length, g_hWhitelistDomains.Length, g_hBanWords.Length);
    }
}

public Action Command_Reload(int client, int args)
{
    LoadLists();
    OnConfigsExecuted();
    ReplyToCommand(client, "[ISB] Reloaded");
    return Plugin_Handled;
}

public Action OnSayCommand(int client, const char[] command, int argc)
{
    if (client == 0 || !IsClientInGame(client)) return Plugin_Continue;
    
    char msg[256];
    GetCmdArgString(msg, sizeof(msg));
    StripQuotes(msg);
    TrimString(msg);
    
    int idx = 0;
    while (idx < strlen(msg) && msg[idx] == ' ') idx++;
    if (idx < strlen(msg) && (msg[idx] == '!' || msg[idx] == '/'))
        return Plugin_Continue;
    
    if (IsViolation(msg))
    {
        PunishClient(client, msg);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public void Event_OnChangeName(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!client) return;
    char newname[MAX_NAME_LENGTH];
    event.GetString("newname", newname, sizeof(newname));
    if (IsViolation(newname))
    {
        if (g_iPunishType == 1)
            PrintToChat(client, "%s %t", g_sPrefix, "HaveBanInName");
        else
            KickClient(client, "%t", "KickReason");
    }
}


void RemoveSpaces(const char[] input, char[] output, int maxlen)
{
    int j = 0;
    for (int i = 0; input[i] != '\0' && j < maxlen - 1; i++)
    {
        if (input[i] != ' ')
            output[j++] = input[i];
    }
    output[j] = '\0';
}

bool IsViolation(const char[] text)
{
    char buf[512];
    strcopy(buf, sizeof(buf), text);
    StringToLower(buf);
    

    char noSpaces[512];
    RemoveSpaces(buf, noSpaces, sizeof(noSpaces));
    
    if (g_bEnableIP && ContainsIP(noSpaces)) return true;
    if (g_bEnableDomain && ContainsDomain(noSpaces)) return true;

    if (g_bEnableBanWords && ContainsBanWord(buf)) return true;
    return false;
}

bool ContainsIP(const char[] text)
{
    char buf[512];
    strcopy(buf, sizeof(buf), text);
    StringToLower(buf);

    int len = strlen(buf);
    for (int i = 0; i < len; i++)
    {
        if (IsCharNumeric(buf[i]))
        {
            int j = i, dots = 0;
            while (j < len && (IsCharNumeric(buf[j]) || buf[j] == '.' || buf[j] == ':'))
            {
                if (buf[j] == '.') dots++;
                j++;
            }
            if (dots == 3)
            {
                char found[64];
                strcopy(found, j - i + 1, buf[i]);
                
                int portPos = -1;
                for (int k = 0; k < strlen(found); k++)
                {
                    if (found[k] == ':')
                    {
                        portPos = k;
                        break;
                    }
                }
                if (portPos != -1)
                    found[portPos] = '\0';
                
                bool whitelisted = false;
                for (int k = 0; k < g_hWhitelistIP.Length; k++)
                {
                    char wl[64];
                    g_hWhitelistIP.GetString(k, wl, sizeof(wl));
                    StringToLower(wl);
                    
                    int wlPortPos = -1;
                    for (int p = 0; p < strlen(wl); p++)
                    {
                        if (wl[p] == ':')
                        {
                            wlPortPos = p;
                            break;
                        }
                    }
                    if (wlPortPos != -1)
                        wl[wlPortPos] = '\0';
                    
                    if (StrEqual(found, wl, false))
                    {
                        whitelisted = true;
                        break;
                    }
                }
                if (!whitelisted)
                {
                    if (g_bLogEnabled)
                        LogToFileEx("addons/sourcemod/logs/ip_site_blocker.log", "Blocked IP: %s", found);
                    return true;
                }
            }
            i = j;
        }
    }
    return false;
}

bool ContainsDomain(const char[] text)
{
    char buf[512];
    strcopy(buf, sizeof(buf), text);
    StringToLower(buf);

    int len = strlen(buf);
    for (int i = 0; i < len; i++)
    {
        if (IsCharAlpha(buf[i]) || IsCharNumeric(buf[i]))
        {
            int start = i;
            while (start > 0 && (IsCharAlpha(buf[start-1]) || IsCharNumeric(buf[start-1]) || buf[start-1] == '-' || buf[start-1] == '.'))
                start--;
            int end = i;
            while (end < len && (IsCharAlpha(buf[end]) || IsCharNumeric(buf[end]) || buf[end] == '-' || buf[end] == '.'))
                end++;
            if (end > start)
            {
                char candidate[128];
                strcopy(candidate, end - start + 1, buf[start]);
                if (StrContains(candidate, ".") != -1)
                {
                    bool white = false;
                    for (int k = 0; k < g_hWhitelistDomains.Length; k++)
                    {
                        char wl[128];
                        g_hWhitelistDomains.GetString(k, wl, sizeof(wl));
                        if (StrEqual(candidate, wl, false)) { white = true; break; }
                    }
                    if (!white)
                    {
                        if (g_bLogEnabled) 
                            LogToFileEx("addons/sourcemod/logs/ip_site_blocker.log", "Blocked domain: %s", candidate);
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

bool ContainsBanWord(const char[] text)
{
    char buf[512];
    strcopy(buf, sizeof(buf), text);
    StringToLower(buf);
    for (int i = 0; i < g_hBanWords.Length; i++)
    {
        char bw[64];
        g_hBanWords.GetString(i, bw, sizeof(bw));
        if (StrContains(buf, bw) != -1) return true;
    }
    return false;
}

void PunishClient(int client, const char[] violationText, bool bFromName = false)
{
    if (client == 0 || !IsClientInGame(client)) return;

    char sid[32], name[MAX_NAME_LENGTH], ip[16];
    GetClientAuthId(client, AuthId_SteamID64, sid, sizeof(sid));
    GetClientName(client, name, sizeof(name));
    GetClientIP(client, ip, sizeof(ip));

    if (g_bLogEnabled)
    {
        LogToFileEx("addons/sourcemod/logs/ip_site_blocker.log", "%s (%s|%s): %s [%s]",
            name, sid, ip, violationText, bFromName ? "NAME" : "CHAT");
    }

    if (g_iPunishType == 1)
    {
        PrintToChat(client, "%s %t", g_sPrefix, bFromName ? "HaveBanInName" : "HaveBanInChat");
    }
    else if (g_iPunishType == 2)
    {
        KickClient(client, "%t", "KickReason");
    }
    else if (g_iPunishType == 3)
    {
        ServerCommand("sm_gag #%i %i", GetClientUserId(client), g_iMuteTime);
        PrintToChat(client, "%s %t", g_sPrefix, "MutedByGag", g_iMuteTime);
    }
    else if (g_iPunishType == 4)
    {
        BanClient(client, g_iBanTime, BANFLAG_AUTO, "Ban", "Forbidden content", "ISB");
    }
    else if (g_iPunishType == 5)
    {
        char cmd[256];
        strcopy(cmd, sizeof(cmd), g_sPunishCmd);
        ReplaceString(cmd, sizeof(cmd), "{steamid64}", sid);
        ReplaceString(cmd, sizeof(cmd), "{ip}", ip);
        ReplaceString(cmd, sizeof(cmd), "{name}", name);
        char formatted[256];
        Format(formatted, sizeof(formatted), cmd, GetClientUserId(client));
        ServerCommand(formatted);
    }
#if defined _materialadmin_included
    else if (g_iPunishType == 11 && g_bHasMA)
    {
        char reason[128];
        Format(reason, sizeof(reason), "Auto mute: %s", violationText);
        MASetClientMuteType(0, client, reason, g_iMAMuteType, g_iMuteTime);
        PrintToChat(client, "%s %t", g_sPrefix, "MutedByMA", g_iMuteTime);
    }
    else if (g_iPunishType == 12 && g_bHasMA)
    {
        char reason[128];
        Format(reason, sizeof(reason), "Auto ban: %s", violationText);
        MABanPlayer(0, client, g_iMABanType, g_iBanTime, reason);
        PrintToChat(client, "%s %t", g_sPrefix, "BannedByMA", g_iBanTime);
    }
#endif
}

void StringToLower(char[] str)
{
    for (int i = 0; str[i]; i++) str[i] = CharToLower(str[i]);
}