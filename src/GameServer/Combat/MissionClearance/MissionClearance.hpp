#pragma once
#include <unordered_set>

#include "src/pch.hpp"
#include "src/Database/Database.hpp"
#include "src/Config/Config.hpp"
#include "src/GameServer/Storage/ClientConnectionsData/ClientConnectionsData.hpp"
#include "src/GameServer/Combat/MissionAlerts/SendAlert.hpp"
#include "src/Utils/Logger/Logger.hpp"

#include <cmath>
#include <map>
#include <string>

namespace MissionClearance {

inline std::map<int, int> g_factoryPlanned;
inline int   g_kills          = 0;
inline float g_requiredPct    = 0.90f;
inline bool  g_unlocked       = false;
inline bool  g_hit25          = false;
inline bool  g_hit50          = false;
inline bool  g_hit75          = false;
inline DWORD g_lastRejectMs   = 0;
inline bool  g_announced      = false;
inline std::unordered_set<void*> g_bossBarrierPtrs; // tracks volumes ever seen as boss barriers
inline int   g_planCount       = 0;

inline bool IsTickOrWasp(int botId) {
        // Colony Ticks & Detonator Spiders
        // Colony Wasp Mk2 (1544) only -- regular Colony Wasps (1535/1584/1610) ARE counted
        // Dive Bombers
        static const int kExcludedIds[] = {
                1463, 1537, 1629, 1672, 334, 767, 732, 765, 766,
                1544,                   1644, 1617, 1652, 1560,
                1319                    // Support Scanner
        };
        for (int id : kExcludedIds) { if (botId == id) return true; }
        return false;
}

inline int GetTotalPlanned() {
        int sum = 0;
        for (const auto& kv : g_factoryPlanned) sum += kv.second;
        return (sum > 0) ? sum : 1;
}

inline void BroadcastInstanceChat(const wchar_t* text) {
        for (const auto& kv : GClientConnectionsData) {
                if (kv.second.bClosed) continue;
                UNetConnection* conn = (UNetConnection*)(uintptr_t)(uint32_t)kv.first;
                if (conn) {
                        SendAlert::SendText(conn, text, 1, 0, 4.0f);
                }
        }
}

inline void Reset() {
        g_factoryPlanned.clear();
        g_kills        = 0;
        g_requiredPct  = 0.90f; // Global default 90%
        g_unlocked     = false;
        g_hit25        = false;
        g_hit50        = false;
        g_hit75        = false;
        g_lastRejectMs = 0;
        g_announced    = false;
        g_planCount    = 0;
        g_bossBarrierPtrs.clear();

        const std::string mapName = Config::GetMapNameChar();
        sqlite3* db = Database::GetConnection();
        if (db && !mapName.empty()) {
                sqlite3_stmt* stmt = nullptr;
                if (sqlite3_prepare_v2(db,
                        "SELECT required_pct FROM mod_map_clear_requirements WHERE map_name = ? LIMIT 1;",
                        -1, &stmt, nullptr) == SQLITE_OK) {
                        sqlite3_bind_text(stmt, 1, mapName.c_str(), -1, SQLITE_TRANSIENT);
                        if (sqlite3_step(stmt) == SQLITE_ROW) {
                                float val = (float)sqlite3_column_double(stmt, 0);
                                if (val > 0.0f && val <= 1.0f) {
                                        g_requiredPct = val;
                                }
                        }
                        sqlite3_finalize(stmt);
                }
        }

        Logger::Log("debug", "[MissionClearance] Reset for map '%s': required_pct=%.2f\n",
                mapName.c_str(), g_requiredPct);

}

inline bool IsExcludedTable(int tid) {
        // CP: Alarm (33), Initial Boss Adds (46), Follow-up Wave (59), CPLab03 Follow-up (65)
        // Colony: Guardian Boss (170) -- same logic as CP table 46, boss tier not trash.
        // Tick/Wasp Incubators (163/188) are NOT excluded: destroying them counts toward
        // 80%; Colony Ticks and Colony Wasp Mk2 are excluded per-bot-id in IsTickOrWasp.
        // 10015 = SDColony03 boss-room adds (factory 13841) -- same logic as table 46.
        // 10015=SDColony03, 10016=SDColony04, 10028/10029/10036=Bolonov's boss room
        return (tid == 33 || tid == 46 || tid == 59 || tid == 65 || tid == 170 || tid == 10015 || tid == 10016 || tid == 10028 || tid == 10029 || tid == 10036 || tid == 10067 || tid == 10068 || tid == 10071 || tid == 10078 || tid == 10091 || tid == 10092 || tid == 10093 || tid == 10094 || tid == 10002 || tid == 10122 || tid == 10003 || tid == 10004 || tid == 10005 || tid == 51 || tid == 10095);
}


inline void AnnounceIfReady() {
    if (g_announced) return;
    // Only announce on actual mission maps (start with '1P_', 'CTR_', 'Raid_' etc.)
    // Skip home maps like Dome3_VR_Arena_P
    {
        std::string mn = Config::GetMapNameChar();
        if (mn.empty() || mn.find("Arena") != std::string::npos ||
            mn.find("Dome") != std::string::npos || mn.find("VR") != std::string::npos) return;
    }
    g_announced = true;
    static const std::map<int, std::wstring> kDiffNames = {
        {1029, L"MEDIUM"}, {1030, L"HIGH"}, {1259, L"MAX"}, {1471, L"UMAX"}
    };
    static const std::map<std::string, std::wstring> kFriendlyNames = {
        {"1P_CPFactory01_P", L"Weapon Manufacturing Plant"},
        {"1P_CPFactory02_P", L"Android Assembly Plant"},
        {"1P_CPFactory03_P", L"Central Industrial Complex"},
        {"1P_CPFactory04_P", L"Recycling Plant 37"},
        {"1P_CPFactory05_P", L"Waste Management Center"},
        {"1P_CPLab01_P",     L"Sector 20 Agent Inception Center"},
        {"1P_CPLab02_P",     L"Remote Operations Control Center"},
        {"1P_CPLab03",       L"Embryonic Agent Testing Lab"},
        {"1P_CPLab04_P",     L"Advanced Weaponry Research Lab"},
        {"1P_CPLab05_P",     L"Bio-Tech Testing Facility"},
        {"1P_CPMine01_P",    L"Unobtanium Mine LV-426"},
        {"1P_CPMine02_P",    L"Mineral Extraction Site A-31"},
        {"1P_CPMine03_P",    L"Uranium Mining Complex"},
        {"1P_CPMine04_P",    L"Titanium Processing Site"},
        {"1P_CPMine05_P",    L"Alumina Mine 1138"},
        {"1P_SDColony01_P",  L"Recursive Colony Node 1393"},
        {"1P_SDColony02_P",  L"Bolonov's Entourage"},
        {"1P_SDColony03_P",  L"Recursive Colony Nest"},
        {"1p_SDColony04_P",  L"Recursive Communications"},
        {"1P_SDColony05_P",  L"Terminus Water Station"},
        {"1P_SDColony06_P",  L"28 Nights Later"},
        {"1P_SDDweller01_P", L"Canyon Encampment"},
        {"1P_SDDweller02_P", L"Shifting Sands"},
        {"1P_SDDweller03_P", L"Dweller Hideout"},
    };
    std::string mapName2 = Config::GetMapNameChar();
    int diffId = Config::GetDifficultyValueId();
    auto diffIt = kDiffNames.find(diffId);
    std::wstring diffName = (diffIt != kDiffNames.end()) ? diffIt->second : L"UNKNOWN";
    auto fnIt = kFriendlyNames.find(mapName2);
    std::wstring friendly = (fnIt != kFriendlyNames.end()) ? fnIt->second : L"";
    std::wstring line1 = diffName + L": " + std::wstring(mapName2.begin(), mapName2.end());
    BroadcastInstanceChat(line1.c_str());
    if (!friendly.empty()) BroadcastInstanceChat(friendly.c_str());
    wchar_t line3[64];
    swprintf_s(line3, L"Requires %d%% Clearance for Boss Room", (int)std::round(g_requiredPct * 100.0f));
    BroadcastInstanceChat(line3);
}

inline void SetFactoryPlannedCount(int factoryId, int validCount) {
        g_factoryPlanned[factoryId] = validCount;
        Logger::Log("debug", "[MissionClearance] Factory %d updated %d valid planned mobs (totalPlanned=%d)\n",
                factoryId, validCount, GetTotalPlanned());
}

inline void OnPawnKilled(ATgPawn* pawn) {
        if (!pawn || !pawn->r_bIsBot) return;

        const int botId = pawn->r_nProfileId;
        // Ticks, wasps, and dive bombers NEVER count towards kills
        if (IsTickOrWasp(botId)) return;

        if (!pawn->Controller) return;
        ATgAIController* aic = (ATgAIController*)pawn->Controller;
        // Must belong to a valid map factory (ignores summons/Factory 0)
        if (!aic->m_pFactory || aic->m_pFactory->m_nMapObjectId <= 0) return;
        if (aic->m_pFactory->bSpawnOnAlarm) return;
        if (IsExcludedTable(aic->m_pFactory->nSpawnTableId)) return;

        // Announce mission name and clearance requirement on first kill
        if (!g_announced) {
            g_announced = true;
            static const std::map<int, std::wstring> kDiffNames = {
                {1029, L"MEDIUM"}, {1030, L"HIGH"}, {1259, L"MAX"}, {1471, L"UMAX"}
            };
            static const std::map<std::string, std::wstring> kFriendlyNames = {
                {"1P_CPFactory01_P", L"Weapon Manufacturing Plant"},
                {"1P_CPFactory02_P", L"Android Assembly Plant"},
                {"1P_CPFactory03_P", L"Central Industrial Complex"},
                {"1P_CPFactory04_P", L"Recycling Plant 37"},
                {"1P_CPFactory05_P", L"Waste Management Center"},
                {"1P_CPLab01_P",     L"Sector 20 Agent Inception Center"},
                {"1P_CPLab02_P",     L"Remote Operations Control Center"},
                {"1P_CPLab03",       L"Embryonic Agent Testing Lab"},
                {"1P_CPLab04_P",     L"Advanced Weaponry Research Lab"},
                {"1P_CPLab05_P",     L"Bio-Tech Testing Facility"},
                {"1P_CPMine01_P",    L"Unobtanium Mine LV-426"},
                {"1P_CPMine02_P",    L"Mineral Extraction Site A-31"},
                {"1P_CPMine03_P",    L"Uranium Mining Complex"},
                {"1P_CPMine04_P",    L"Titanium Processing Site"},
                {"1P_CPMine05_P",    L"Alumina Mine 1138"},
                {"1P_SDColony01_P",  L"Recursive Colony Node 1393"},
                {"1P_SDColony02_P",  L"Bolonov's Entourage"},
                {"1P_SDColony03_P",  L"Recursive Colony Nest"},
                {"1p_SDColony04_P",  L"Recursive Communications"},
                {"1P_SDColony05_P",  L"Terminus Water Station"},
                {"1P_SDColony06_P",  L"28 Nights Later"},
                {"1P_SDDweller01_P", L"Canyon Encampment"},
                {"1P_SDDweller02_P", L"Shifting Sands"},
                {"1P_SDDweller03_P", L"Dweller Hideout"},
            };
            std::string mapName2 = Config::GetMapNameChar();
            int diffId = Config::GetDifficultyValueId();
            auto diffIt = kDiffNames.find(diffId);
            std::wstring diffName = (diffIt != kDiffNames.end()) ? diffIt->second : L"UNKNOWN";
            auto fnIt = kFriendlyNames.find(mapName2);
            std::wstring friendly = (fnIt != kFriendlyNames.end()) ? fnIt->second : L"";
            std::wstring line1 = diffName + L": " + std::wstring(mapName2.begin(), mapName2.end());
            BroadcastInstanceChat(line1.c_str());
            if (!friendly.empty()) BroadcastInstanceChat(friendly.c_str());
            wchar_t line3[64];
            swprintf_s(line3, L"Requires %d%% Clearance", (int)std::round(g_requiredPct * 100.0f));
            BroadcastInstanceChat(line3);
        }

        g_kills++;
        const int total = GetTotalPlanned();
        const float pct = (float)g_kills / (float)total;

        Logger::Log("debug", "[MissionClearance] Kill: %d/%d (%.1f%%) [Target=%.0f%%]\n",
                g_kills, total, pct * 100.0f, g_requiredPct * 100.0f);

        if (pct >= 0.25f && !g_hit25) {
                g_hit25 = true;
                wchar_t buf[64];
                swprintf_s(buf, L"[Clearance: 25%% (%d/%d)]", g_kills, total);
                BroadcastInstanceChat(buf);
        }
        if (pct >= 0.50f && !g_hit50) {
                g_hit50 = true;
                wchar_t buf[64];
                swprintf_s(buf, L"[Clearance: 50%% (%d/%d)]", g_kills, total);
                BroadcastInstanceChat(buf);
        }
        if (pct >= 0.75f && !g_hit75) {
                g_hit75 = true;
                wchar_t buf[64];
                swprintf_s(buf, L"[Clearance: 75%% (%d/%d)]", g_kills, total);
                BroadcastInstanceChat(buf);
        }
        if (pct >= g_requiredPct && !g_unlocked) {
                g_unlocked = true;
                BroadcastInstanceChat(L"[SECURITY OVERRIDDEN: Boss Chamber Accessible!]");
                SendAlert::BroadcastText(L"[SECURITY OVERRIDDEN: Boss Chamber Accessible!]",
                                         /*priority=*/2, /*type=*/1, 4.0f);
        }
}

inline bool CanEnterBossChamber(ATgPawn* player) {
        if (g_unlocked) return true;

        const int total = GetTotalPlanned();
        const float pct = (float)g_kills / (float)total;

        if (pct >= g_requiredPct) {
                g_unlocked = true;
                return true;
        }

        if (player) {
                DWORD now = GetTickCount();
                if (now - g_lastRejectMs > 2500) {
                        g_lastRejectMs = now;
                        wchar_t msg[128];
                        swprintf_s(msg, L"[SECURITY LOCKDOWN: Cleared %d%%/%d%% - Eliminate More Enemies]",
                                   (int)(pct * 100.0f), (int)(g_requiredPct * 100.0f));
                        for (const auto& kv : GClientConnectionsData) {
                                if (kv.second.Pawn == (ATgPawn_Character*)player && !kv.second.bClosed) {
                                        UNetConnection* conn = (UNetConnection*)(uintptr_t)(uint32_t)kv.first;
                                        if (conn) {
                                                SendAlert::SendText(conn, msg, 2, 2, 3.0f);
                                        }
                                        break;
                                }
                        }
                }
        }

        return false;
}

} // namespace MissionClearance
