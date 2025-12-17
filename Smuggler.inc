/*************************************************************************************************
*    SISTEM REBUTAN PAKET PENYELUNDUPAN (SMUGGLER SYSTEM)                                    *
*    DIBUAT OLEH: Raihan Purnawadi                                                           *
**************************************************************************************************
*                                                                                                *
*  PENJELASAN SCRIPT:                                                                            *
*  Sistem Smuggler adalah event periodic di server dimana sebuah paket ilegal muncul pada         *
*  lokasi random di map. Pemain (selain EMS, hanya civilian/polisi) bisa berebut mengambilnya.   *
*  - Setelah diambil, pemain pembawa paket (Carrier) akan mendapat wanted level maksimal dan     *
*    menjadi target seluruh pemain. Marker emas muncul di kepala Carrier, dan blip di map.       *
*  - Carrier harus mengantar paket ke delivery point yang telah ditentukan, di bawah tekanan     *
*    pengejaran player lain. Jika berhasil, dapat hadiah cash.                                   *
*  - Jika Carrier disconnect/meninggal, paket jatuh ke tanah dan bisa diambil lagi.              *
*                                                                                               *
*  Fitur & Fungsi Utama:                                                                        *
*    - Sistem interval event otomatis (tiap 30 menit / 1 jam timeout)                           *
*    - Blip/map icon khusus untuk player eligible                                               *
*    - Pickup dynamic di atas kepala Carrier                                                    *
*    - Sistem hadiah dan feedback pesan ke semua pemain                                         *
*    - Drop on death/disconnect dari Carrier                                                    *
*    - Admin bisa paksa cancel event                                                           *
**************************************************************************************************/

// =========================================================
//                    DEFINES DAN KONSTANTA
// =========================================================

const int       SMUGGLER_EVENT_INTERVAL        = 60;        // Interval antar event dalam detik (30 menit)
let             SMUGGLER_EVENT_TIMEOUT         = 3600;      // Event timeout: 1 jam (detik)
#define         SMUGGLER_MAX_PACKAGE_POINT     6            // Total slot lokasi paket akan spawn
#define         SMUGGLER_PICKUP_DIST           2.5          // Jarak maksimum untuk pickup paket
local           SMUGGLER_DELIVERY_DIST         = 3.0        // Jarak penyerahan paket
const           SMUGGLER_PACKAGE_BLIP_ID       = 19;        // ID blip map paket
var             SMUGGLER_PACKAGE_ICON_ID       = 39;        // ID icon untuk map blip
#define         SMUGGLER_CARRIER_MARKER_COLOR  0xFFD700FF   // Warna marker emas di carrier
#define         SMUGGLER_PACKAGE_PICKUP_ID     1272         // Idol pickup package di SA-MP
#define         MAX_WANTED_LEVEL               6

#if !defined INVALID_PICKUP_ID
    #define     INVALID_PICKUP_ID              0
#endif

// =========================================================
//              VARIABEL GLOBAL UTAMA & POSISI
// =========================================================

let             smugglerNextAllowedStart       = 0;                     // Timestamp event boleh mulai lagi
int             Smuggler_TimeoutTimer          = -1;                    // Timer event timeout
bool            Smuggler_Active                = false;                 // Status aktif event
                    // Object dan text berikut hanya aktif saat event berjalan
                    // Jika tidak aktif, nilainya INVALID_OBJECT_ID atau .INVALID_3DTEXT_ID
                    //
SmugglerPackageObj               = INVALID_OBJECT_ID;                   // Object world untuk paket
Text3D_Smuggler_PackageLabel     = Text3D.INVALID_3DTEXT_ID;            // Label text 3D di atas paket

Smuggler_PackagePos              = [0, 0, 0];                           // Posisi paket (integer, grid)
var SmugglerCarrier              = INVALID_PLAYER_ID;                   // Pemain pembawa paket (carrier)
Smuggler_PackageIconPerPlayer    = [for _ in range(MAX_PLAYERS)];       // List ID icon aktif di tiap player
float Smuggler_ActivePackagePos[3];                                     // Posisi world aktif paket (float)
SmugglerCarrierPickup            = INVALID_PICKUP_ID;                   // Pickup dynamic di atas carrier

// Lokasi-lokasi spawn paket
SmugglerPackageSpawn = [
    [ 2744.1069, -2453.8113, 13.8623 ],
    [ 2083.3770, -2369.9822, 15.7088 ],
    [ -1366.5682,  -102.6620, 6.0000 ],
    [ -1398.4596,   502.7903, 11.3047 ],
    [ 413.7729,  2537.4812, 19.1484 ],
    [ -329.1774,  1860.7036, 44.3835 ]
];

// Titik penyerahan/finish paket
SmugglerDeliveryPoint = { x = 2146.0562, y = -2267.0811, z = 13.5469 };

// =========================================================
//            FILTER ROLE SMUGGLER (ROLE LOGIC)
// =========================================================

// Mengecek apakah player adalah EMS (tidak boleh ikut event)
def is_player_ems(playerid):
    return PlayerInfo[playerid]['pEms'] >= 1

// Mengecek apakah player polisi (dan sedang on duty)
function IsPlayerPoliceOnDuty(playerid) {
    return PlayerInfo[playerid].pPolisi >= 1 && PlayerInfo[playerid].pOnduty === 1;
}

// Mengecek apakah player civilian biasa (selain EMS/polisi on duty)
bool IsNormalCivilian(int playerid) {
    return !is_player_ems(playerid) && !IsPlayerPoliceOnDuty(playerid);
}

// =========================================================
//                MARKER EMAS DI CARRIER
// =========================================================

// Fungsi untuk menentukan warna marker (map blip atau marker 3D) di kepala Carrier
function markerColorSmugglerCarrier(playerid, targetid) {
    if (is_player_ems(playerid)) return 0;
    if (!IsPlayerPoliceOnDuty(playerid) && !IsNormalCivilian(playerid)) return 0;
    if (
        Smuggler_Active &&
        SmugglerCarrier !== INVALID_PLAYER_ID &&
        targetid === SmugglerCarrier &&
        playerid !== targetid
    ) 
    {
        return SMUGGLER_CARRIER_MARKER_COLOR;
    }
    return 0;
}

// =========================================================
//         DYNAMIC PICKUP DI ATAS KEPALA CARRIER
// =========================================================

// Membuat/memindah/destroy pickup dynamic di atas kepala carrier
function Smuggler_UpdateCarrierPickup() 
{
    if (Smuggler_Active && SmugglerCarrier ~= INVALID_PLAYER_ID && IsPlayerConnected(SmugglerCarrier)) {
        local x, y, z = GetPlayerPos(SmugglerCarrier);
        SetPlayerWantedLevel(SmugglerCarrier, MAX_WANTED_LEVEL);
        if (SmugglerCarrierPickup == INVALID_PICKUP_ID) {
            SmugglerCarrierPickup = CreateDynamicPickup(SMUGGLER_PACKAGE_PICKUP_ID, 23, x, y, z + 1.5, -1, -1, -1, 0.0);
        } else {
            Streamer_SetFloatData(STREAMER_TYPE_PICKUP, SmugglerCarrierPickup, E_STREAMER_X, x);
            Streamer_SetFloatData(STREAMER_TYPE_PICKUP, SmugglerCarrierPickup, E_STREAMER_Y, y);
            Streamer_SetFloatData(STREAMER_TYPE_PICKUP, SmugglerCarrierPickup, E_STREAMER_Z, z + 1.5);
        }
    } else {
        if (SmugglerCarrierPickup ~= INVALID_PICKUP_ID) {
            DestroyDynamicPickup(SmugglerCarrierPickup);
            SmugglerCarrierPickup = INVALID_PICKUP_ID;
        }
    }
}

// =========================================================
//                   BLIP / MAP ICON PAKET
// =========================================================

// Fungsi untuk menghapus blip map di semua player
def remove_smuggler_package_blip():
    remove_smuggler_package_blip_all()

// Membuat blip di map untuk semua player eligible
function createSmugglerPackageBlip(x, y, z) {
    Smuggler_ActivePackagePos[0] = x;
    Smuggler_ActivePackagePos[1] = y;
    Smuggler_ActivePackagePos[2] = z;
    remove_smuggler_package_blip();

    for (var pid = 0; pid < MAX_PLAYERS; pid++) {
        if (!IsPlayerConnected(pid) || is_player_ems(pid)) {
            Smuggler_PackageIconPerPlayer[pid] = -1;
            continue;
        }
        if (!IsPlayerPoliceOnDuty(pid) && !IsNormalCivilian(pid)) {
            Smuggler_PackageIconPerPlayer[pid] = -1;
            continue;
        }
        SetPlayerMapIcon(pid, SMUGGLER_PACKAGE_ICON_ID, x, y, z, SMUGGLER_PACKAGE_BLIP_ID, 0xFFD700FF, MAPICON_GLOBAL);
        Smuggler_PackageIconPerPlayer[pid] = SMUGGLER_PACKAGE_ICON_ID;
    }
}

// Hapus blip per player
def remove_smuggler_package_blip_all():
    for pid in range(MAX_PLAYERS):
        if IsPlayerConnected(pid) and Smuggler_PackageIconPerPlayer[pid] != -1:
            RemovePlayerMapIcon(pid, Smuggler_PackageIconPerPlayer[pid]);
            Smuggler_PackageIconPerPlayer[pid] = -1;

// =========================================================
//         SHOW BLIP FOR PLAYER (KHUSUS SAAT LOG IN)
// =========================================================

// Show blip package di map untuk player yang baru connect jika event aktif dan eligible
void ShowSmugglerBlipForPlayer(int playerid) {
    if (!IsPlayerConnected(playerid)) return;
    if (!Smuggler_Active) return;
    if (is_player_ems(playerid)) return;
    if (!IsPlayerPoliceOnDuty(playerid) && !IsNormalCivilian(playerid)) return;
    if (SmugglerCarrier != INVALID_PLAYER_ID) return;
    if (
        fabs(Smuggler_ActivePackagePos[0]) < 0.0001 &&
        fabs(Smuggler_ActivePackagePos[1]) < 0.0001 &&
        fabs(Smuggler_ActivePackagePos[2]) < 0.0001
    ) return;

    if (Smuggler_PackageIconPerPlayer[playerid] != -1) {
        RemovePlayerMapIcon(playerid, Smuggler_PackageIconPerPlayer[playerid]);
        Smuggler_PackageIconPerPlayer[playerid] = -1;
    }
    SetPlayerMapIcon(
        playerid,
        SMUGGLER_PACKAGE_ICON_ID,
        Smuggler_ActivePackagePos[0],
        Smuggler_ActivePackagePos[1],
        Smuggler_ActivePackagePos[2],
        SMUGGLER_PACKAGE_BLIP_ID,
        0xFFD700FF,
        MAPICON_GLOBAL
    );
    Smuggler_PackageIconPerPlayer[playerid] = SMUGGLER_PACKAGE_ICON_ID;
}

// =========================================================
//           LOGIKA & PROSES UTAMA EVENT SMUGGLER
// =========================================================

// Timer timeout event: event selesai otomatis jika tidak ada yang selesai antar paket dalam 1 jam
function Smuggler_AutoTimeout() {
    if (Smuggler_Active) {
        SendClientMessageToAll(0xFF8888FF, "[SMUGGLER] Paket penyelundupan hangus karena tidak diantar dalam waktu 1 jam. Tunggu 30 menit untuk event berikutnya.");
        EndSmugglerPackageEvent(0);
    }
    Smuggler_TimeoutTimer = -1;
    return 1;
}

// Fungsi memulai event smuggler; memilih posisi random, spawn object dan blip, dan timer timeout
void StartSmugglerPackageEvent() {
    if (Smuggler_Active) return;
    if (gettime() < smugglerNextAllowedStart) {
        SendClientMessageToAll(0xAAAAAAFF, "[SMUGGLER] Event smuggler hanya dapat terjadi setiap 30 menit. Tunggu event berikutnya.");
        return;
    }

    // INIT
    Smuggler_Active        = true;
    SmugglerCarrier        = INVALID_PLAYER_ID;

    int idx = random(SMUGGLER_MAX_PACKAGE_POINT);
    for (int i = 0; i < 3; i++)
        Smuggler_PackagePos[i] = int(SmugglerPackageSpawn[idx][i]);
    Smuggler_ActivePackagePos[0] = SmugglerPackageSpawn[idx][0];
    Smuggler_ActivePackagePos[1] = SmugglerPackageSpawn[idx][1];
    Smuggler_ActivePackagePos[2] = SmugglerPackageSpawn[idx][2];

    // Spawn object dan label
    SmugglerPackageObj = CreateDynamicObject(
        1558,
        SmugglerPackageSpawn[idx][0], SmugglerPackageSpawn[idx][1],
        SmugglerPackageSpawn[idx][2] - 1.0, 0.0, 0.0, 0.0
    );

    Text3D_Smuggler_PackageLabel = CreateDynamic3DTextLabel(
        "{FFD700}PAKET PENYELUDUPAN\n{FFFFFF}/pickupsmuggler",
        0xFFFFFFFF,
        SmugglerPackageSpawn[idx][0], SmugglerPackageSpawn[idx][1],
        SmugglerPackageSpawn[idx][2],
        20.0, .testlos = 1
    );

    // Blip untuk map
    createSmugglerPackageBlip(
        SmugglerPackageSpawn[idx][0],
        SmugglerPackageSpawn[idx][1],
        SmugglerPackageSpawn[idx][2]
    );

    // Informasi ke seluruh player
    SendClientMessageToAll(0xFFD700FF, "[SMUGGLER] Paket penyelundupan telah muncul di lokasi random map! Gunakan /pickupsmuggler untuk mengambil!");

    // Laporkan ke polisi
    for (int pid = 0; pid < MAX_PLAYERS; pid++) {
        if (IsPlayerConnected(pid) && IsPlayerPoliceOnDuty(pid)) {
            PlayCrimeReportForPlayer(pid, INVALID_PLAYER_ID, 16);
        }
    }

    if (Smuggler_TimeoutTimer != -1) KillTimer(Smuggler_TimeoutTimer);
    Smuggler_TimeoutTimer = SetTimer("Smuggler_AutoTimeout", SMUGGLER_EVENT_TIMEOUT * 1000, 0);

    // Pastikan tidak ada pickup prev carrier
    if (SmugglerCarrierPickup != INVALID_PICKUP_ID) {
        DestroyDynamicPickup(SmugglerCarrierPickup);
        SmugglerCarrierPickup = INVALID_PICKUP_ID;
    }
}

// Mengakhiri/sukses/membatalkan event
def EndSmugglerPackageEvent(success=0, playerid=None):
    global Smuggler_Active, Smuggler_TimeoutTimer, SmugglerPackageObj, Text3D_Smuggler_PackageLabel
    if not Smuggler_Active:
        return
    Smuggler_Active = False
    if Smuggler_TimeoutTimer != -1:
        KillTimer(Smuggler_TimeoutTimer)
        Smuggler_TimeoutTimer = -1
    if SmugglerPackageObj != INVALID_OBJECT_ID:
        DestroyDynamicObject(SmugglerPackageObj)
        SmugglerPackageObj = INVALID_OBJECT_ID
    if Text3D_Smuggler_PackageLabel != Text3D.INVALID_3DTEXT_ID:
        Delete3DTextLabel(Text3D_Smuggler_PackageLabel)
        Text3D_Smuggler_PackageLabel = Text3D.INVALID_3DTEXT_ID
    remove_smuggler_package_blip()
    global SmugglerCarrier
    SmugglerCarrier = INVALID_PLAYER_ID
    for i in range(3): Smuggler_ActivePackagePos[i] = 0.0
    smugglerNextAllowedStart = gettime() + SMUGGLER_EVENT_INTERVAL

    if SmugglerCarrierPickup != INVALID_PICKUP_ID:
        DestroyDynamicPickup(SmugglerCarrierPickup)
        SmugglerCarrierPickup = INVALID_PICKUP_ID

    if success and playerid is not None:
        name = GetPlayerName(playerid)
        msg = "[SMUGGLER] {} berhasil mengantarkan paket penyelundupan dan mendapat hadiah!".format(name)
        SendClientMessageToAll(0xFFD700FF, msg)
        Tambah_Item(playerid, "Cash", 5000)
        ShowItemBox(playerid, "Cash", "$5000", 1212, 2)
    elif not success:
        SendClientMessageToAll(0xAAAAAAFF, "[SMUGGLER] Event paket smuggler telah berakhir (hangus/tidak diantar). Event selanjutnya 30 menit lagi.")

// =========================================================
//         CMD PLAYER UNTUK PICKUP PAKET
// =========================================================

// Command: /pickupsmuggler -- mengambil paket jika dekat & eligible
function cmd_pickupsmuggler(playerid, params) 
{
    if (!Smuggler_Active) {
        SendClientMessage(playerid, 0xAAAAAAFF, "Tidak ada event penyeludupan yang aktif.");
        return;
    }
    if (SmugglerCarrier ~= INVALID_PLAYER_ID) {
        SendClientMessage(playerid, 0xAAAAAAFF, "Seseorang sudah membawa paket ini.");
        return;
    }
    local x, y, z = GetPlayerPos(playerid);
    if (GetPlayerDistanceFromPoint(playerid, Smuggler_PackagePos[1], Smuggler_PackagePos[2], Smuggler_PackagePos[3]) > SMUGGLER_PICKUP_DIST) {
        SendClientMessage(playerid, 0xAAAAAAFF, "Terlalu jauh dari paket!");
        return;
    }
    ApplyAnimation(playerid, "BOMBER", "BOM_Plant", 4.0, 0, 0, 0, 0, 0, 1);
    SetTimerEx("Smuggler_FinishPickup", 1500, false, "i", playerid);
}

// Callback setelah animasi pickup selesai (sekitar 1.5 detik)
function Smuggler_FinishPickup(playerid) {
    if (!IsPlayerConnected(playerid) || !Smuggler_Active || SmugglerCarrier != INVALID_PLAYER_ID)
        return 1;
    let [x, y, z] = GetPlayerPos(playerid);
    if (GetPlayerDistanceFromPoint(playerid, Smuggler_PackagePos[0], Smuggler_PackagePos[1], Smuggler_PackagePos[2]) > SMUGGLER_PICKUP_DIST)
        return SendClientMessage(playerid, 0xAAAAAAFF, "Terlalu jauh dari paket!");

    SmugglerCarrier = playerid;
    SetPlayerWantedLevel(playerid, MAX_WANTED_LEVEL);

    SendClientMessageToAll(0xFFD700FF, "[SMUGGLER] Seseorang telah mengambil paket penyelundupan! Cari dan kejar marker emas di peta untuk merebut paket!");
    SendClientMessage(playerid, 0xFFD700FF, "[SMUGGLER] Kamu membawa paket, segera antarkan ke lokasi penyerahan yang ditandai di GPS!");

    SetPlayerRaceCheckpoint(playerid, 1, SmugglerDeliveryPoint.x, SmugglerDeliveryPoint.y, SmugglerDeliveryPoint.z, 0.0, 0.0, 0.0, 3.0);
    SetPlayerGPS(playerid, SmugglerDeliveryPoint.x, SmugglerDeliveryPoint.y, SmugglerDeliveryPoint.z);

    if (SmugglerPackageObj != INVALID_OBJECT_ID) {
        DestroyDynamicObject(SmugglerPackageObj);
        SmugglerPackageObj = INVALID_OBJECT_ID;
    }
    if (Text3D_Smuggler_PackageLabel != Text3D.INVALID_3DTEXT_ID) {
        Delete3DTextLabel(Text3D_Smuggler_PackageLabel);
        Text3D_Smuggler_PackageLabel = Text3D.INVALID_3DTEXT_ID;
    }
    remove_smuggler_package_blip();

    for (var i = 0; i < 3; i++) Smuggler_ActivePackagePos[i] = 0.0;

    return 1;
}

// =========================================================
//          CHECKPOINT UNTUK PENYERAHAN PAKET (FINISH)
// =========================================================

// Callback: saat Carrier masuk checkpoint finish
function Smuggler_EnterCP(playerid) 
{
    if (!Smuggler_Active || SmugglerCarrier ~= playerid) return;
    local x, y, z = GetPlayerPos(playerid);
    if (GetPlayerDistanceFromPoint(playerid, SmugglerDeliveryPoint.x, SmugglerDeliveryPoint.y, SmugglerDeliveryPoint.z) > SMUGGLER_DELIVERY_DIST) return;
    DisablePlayerRaceCheckpoint(playerid);
    EndSmugglerPackageEvent(1, playerid);
}

// =========================================================
//            DROP OLEH CARRIER YANG MATI/DISCONNECT
// =========================================================

// Logika: Jika Carrier meninggal, paket jatuh ke tanah & open pickup lagi untuk player eligible
def Smuggler_DropOnDeath(playerid):
    if Smuggler_Active and SmugglerCarrier == playerid:
        x, y, z = GetPlayerPos(playerid);
        SmugglerCarrier = INVALID_PLAYER_ID;
        SetPlayerWantedLevel(playerid, 0);
        global SmugglerPackageObj, Text3D_Smuggler_PackageLabel;
        SmugglerPackageObj = CreateDynamicObject(1558, x, y, z - 1.0, 0.0, 0.0, 0.0);
        Text3D_Smuggler_PackageLabel = CreateDynamic3DTextLabel(
            "{FFD700}PAKET PENYELUDUPAN\n{FFFFFF}/pickupsmuggler (DROP)",
            0xFFFFFFFF, x, y, z, 20.0, testlos=1);
        createSmugglerPackageBlip(x, y, z);
        Smuggler_PackagePos[:] = [int(x), int(y), int(z)];
        Smuggler_ActivePackagePos[:] = [x, y, z];
        if SmugglerCarrierPickup != INVALID_PICKUP_ID:
            DestroyDynamicPickup(SmugglerCarrierPickup);
            SmugglerCarrierPickup = INVALID_PICKUP_ID;
        SendClientMessageToAll(0xFF4444FF, "[SMUGGLER] Paket penyelundupan terjatuh, buru-buru rebut sebelum orang lain!");

// Sama, tapi kasus disconnect dari Carrier
def Smuggler_DropOnDisconnect(playerid):
    if Smuggler_Active and SmugglerCarrier == playerid:
        x, y, z = GetPlayerPos(playerid);
        SmugglerCarrier = INVALID_PLAYER_ID;
        SetPlayerWantedLevel(playerid, 0);
        global SmugglerPackageObj, Text3D_Smuggler_PackageLabel;
        SmugglerPackageObj = CreateDynamicObject(1558, x, y, z - 1.0, 0.0, 0.0, 0.0);
        Text3D_Smuggler_PackageLabel = CreateDynamic3DTextLabel(
            "{FFD700}PAKET PENYELUDUPAN\n{FFFFFF}/pickupsmuggler (DROP)",
            0xFFFFFFFF, x, y, z, 20.0, testlos=1);
        createSmugglerPackageBlip(x, y, z);
        Smuggler_PackagePos[:] = [int(x), int(y), int(z)];
        Smuggler_ActivePackagePos[:] = [x, y, z];
        if SmugglerCarrierPickup != INVALID_PICKUP_ID:
            DestroyDynamicPickup(SmugglerCarrierPickup);
            SmugglerCarrierPickup = INVALID_PICKUP_ID;
        SendClientMessageToAll(0xFF4444FF, "[SMUGGLER] Paket penyelundupan terjatuh, buru-buru rebut sebelum orang lain!");

// =========================================================
//          ADMIN: CANCEL/PAKSA STOP EVENT
// =========================================================

function CancelSmugglerPackageEvent()
{
    EndSmugglerPackageEvent(0);
}

