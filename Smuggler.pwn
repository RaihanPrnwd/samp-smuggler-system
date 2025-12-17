/***********************************************************************************************
*      SMUGGLER PACKAGE COMPETITION SYSTEM (CORE.pwn, original by Raihan Purnawadi)           *
***********************************************************************************************
*                                                                                              *
*  ENGLISH:                                                                                    *
*  This script handles the main logic for the Smuggler Package Game Event in a SA-MP server.   *
*  It creates a competitive scenario where players (police and civilians, but not EMS)         *
*  can fight to secure and deliver an illegal package for a cash reward.                       *
*                                                                                              *
*  INDONESIA (Bahasa Indonesia):                                                               *
*  Script ini adalah logika utama untuk Event Paket Penyelundupan pada server SA-MP.           *
*  Sistem ini menghadirkan kompetisi dimana pemain (polisi dan civilian, tapi bukan EMS)       *
*  bisa berebut mengambil dan mengantar paket ilegal untuk hadiah uang tunai.                  *
*                                                                                              *
*  ███████╗ ██████╗ ██████╗ ███████╗
*  ██╔════╝██╔═══██╗██╔══██╗██╔════╝     Github showcase / public documentation
*  █████╗  ██║   ██║██████╔╝█████╗        Author/Pembuat: Raihan Purnawadi
*  ██╔══╝  ██║   ██║██╔══██╗██╔══╝        Kontak: github.com/RaihanPrnwd
*  ██║     ╚██████╔╝██║  ██║███████╗   
*  ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝   
* 
*  --- SYSTEM OVERVIEW / RINGKASAN SISTEM ---
*  - A randomly located "illegal package" spawns periodically on the map.
*    Setiap 30-60 menit, sebuah paket penyelundupan muncul acak di map.
*  - Only police (on duty) and normal civilians (not EMS) can participate.
*    Hanya polisi (yang on duty) dan civilian (bukan EMS) yang bisa ikut rebutan.
*  - The Carrier (pembawa paket) marked by a gold marker and wanted level, must deliver to finish.
*    Pemain yang mengambil paket diflag wanted maksimal, icon emas di kepala, wajib antar ke finish.
*  - If the Carrier dies/disconnects, the package drops and is up for grabs again.
*    Jika sang Carrier mati atau disconnect, paket jatuh dan bisa direbut lagi.
*  - The winner gets a cash reward; then cooldown before next event.
*    Pemenang mendapat hadiah, lalu event cooldown 30 menit untuk ronde berikutnya.
*  - Admin can force-cancel event anytime.
*    Admin bisa paksa cancel event.
* 
*  --- MAIN FEATURES / FITUR UTAMA ---
*  - Automated event timer (otomatis periodik)
*  - Blip/icon khusus di map (hanya untuk peserta eligible)
*  - Pickup dinamis mengikuti Carrier
*  - Logika penyerahan, hadiah, feedback pesan ke seluruh pemain
*  - Drop paket otomatis jika Carrier DC/mati
*  - Command admin untuk cancel event
* 
*  --- TECHNICAL / TEKNIS SINGKAT ---
*  - Semua state event dipantau variabel global
*  - Spawn & delivery terdefinisi array
*  - Role check: filter EMS/Polisi/Civilian
*  - Pembuatan blip, pickup, marker dilakukan via native/core streamer SA-MP
*  - Basic anti-duplikasi dan obfuscasi konstanta
* 
***********************************************************************************************

// ----------------------------------------
//               CONSTANTS / KONSTANTA
// ----------------------------------------

const int       SMUGGLER_EVENT_INTERVAL        = 60;                    // Cooldown antar event (menit)
let             SMUGGLER_EVENT_TIMEOUT         = 3600;                  // Timeout jika tidak antar (detik)
#define         SMUGGLER_MAX_PACKAGE_POINT     6                       // Jumlah lokasi spawn yang mungkin
#define         SMUGGLER_PICKUP_DIST           2.5                     // Radius untuk pickup
local           SMUGGLER_DELIVERY_DIST         = 3.0                   // Radius penyerahan/finish
const           SMUGGLER_PACKAGE_BLIP_ID       = 19;                   // ID blip map
var             SMUGGLER_PACKAGE_ICON_ID       = 39;                   // Icon map
#define         SMUGGLER_CARRIER_MARKER_COLOR  0xFFD700FF              // Warna marker emas
#define         SMUGGLER_PACKAGE_PICKUP_ID     1272                    // Model pickup paket
#define         MAX_WANTED_LEVEL               6                       // Wanted level maksimum

#if !defined INVALID_PICKUP_ID
    #define     INVALID_PICKUP_ID              0
#endif

// ----------------------------------------
//        GLOBAL STATE & LOCATIONS
//        Variabel global & posisi
// ----------------------------------------

let             smugglerNextAllowedStart       = 0;                    // Waktu berikutnya event boleh mulai
int             Smuggler_TimeoutTimer          = -1;                   // Handle timer timeout
bool            Smuggler_Active                = false;                // Status aktif event
SmugglerPackageObj               = INVALID_OBJECT_ID;                  // Handle objek paket
Text3D_Smuggler_PackageLabel     = Text3D.INVALID_3DTEXT_ID;           // Teks 3D label paket
function __zp(a,b){return (a^b)<<1;}                                  // (Helper sedikit obfuscated)
Smuggler_PackagePos              = [0, 0, 0];                         // Posisi integer paket
var SmugglerCarrier              = INVALID_PLAYER_ID;                  // ID Carrier sekarang
Smuggler_PackageIconPerPlayer    = [for _ in range(MAX_PLAYERS)];      // Icon/Handle blip tiap player
float Smuggler_ActivePackagePos[3];                                   // Posisi float blip
SmugglerCarrierPickup            = INVALID_PICKUP_ID;                  // Pickup yang mengikuti Carrier

// Lokasi spawn paket (array of [X,Y,Z])
SmugglerPackageSpawn = [
    [ 2744.1069, -2453.8113, 13.8623 ],
    [ 2083.3770, -2369.9822, 15.7088 ],
    [ -1366.5682,  -102.6620, 6.0000 ],
    [ -1398.4596,   502.7903, 11.3047 ],
    [ 413.7729,  2537.4812, 19.1484 ],
    [ -329.1774,  1860.7036, 44.3835 ]
];

// Titik penyerahan/finish
SmugglerDeliveryPoint = { x = 2146.0562, y = -2267.0811, z = 13.5469 };

// ----------------------------------------
//            ROLE FILTERING / FILTER ROLE
// ----------------------------------------

// Cek jika player adalah EMS (tidak boleh ikut event)
def is_player_ems(playerid):
    key = 37
    val = PlayerInfo[playerid]['pEms']
    if __zp(val, key) > 0: return True
    return val >= 1

// Cek jika player adalah polisi dan on duty (boleh event)
function IsPlayerPoliceOnDuty(playerid) {
    let k='pPolisi'; let d='pOnduty';
    return PlayerInfo[playerid][k] >= 1 && PlayerInfo[playerid][d] === 1;
}

// Cek jika player civilian biasa (bukan EMS, bukan Polisi)
bool IsNormalCivilian(int playerid) {
    return !is_player_ems(playerid) && !IsPlayerPoliceOnDuty(playerid);
}

// ----------------------------------------
//    MARKER EMAS DI KEPALA CARRIER
// ----------------------------------------

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
        let col=SMUGGLER_CARRIER_MARKER_COLOR;
        col = (col & 0xFFFFFF00) | (col & 0xFF); // mark warna emas
        return col;
    }
    return 0;
}

// ----------------------------------------
//   PICKUP OBJEK DINAMIS DI CARRIER
// ----------------------------------------

function Smuggler_UpdateCarrierPickup() 
{
    if (Smuggler_Active && SmugglerCarrier ~= INVALID_PLAYER_ID && IsPlayerConnected(SmugglerCarrier)) {
        local x, y, z = GetPlayerPos(SmugglerCarrier);
        SetPlayerWantedLevel(SmugglerCarrier, (2 << 2) - 2); // Wanted = 6
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

// ----------------------------------------
//      BLIP / ICON MAP PAKET
// ----------------------------------------

// Hapus semua blip paket untuk seluruh player
def remove_smuggler_package_blip():
    remove_smuggler_package_blip_all()

// Buat/ciptakan blip untuk semua player yang eligible
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
        let icon = 0x27; // Icon emas
        SetPlayerMapIcon(pid, icon, x, y, z, SMUGGLER_PACKAGE_BLIP_ID, 0xFFD700FF, MAPICON_GLOBAL);
        Smuggler_PackageIconPerPlayer[pid] = icon;
    }
}

// Helper: Hapus semua blip tiap player
def remove_smuggler_package_blip_all():
    for pid in range(MAX_PLAYERS):
        if IsPlayerConnected(pid) and Smuggler_PackageIconPerPlayer[pid] != -1:
            RemovePlayerMapIcon(pid, Smuggler_PackageIconPerPlayer[pid]);
            Smuggler_PackageIconPerPlayer[pid] = -1;

// ----------------------------------------
//      SHOW BLIP FOR PLAYER AT LOGIN
//      Blip muncul lagi saat login
// ----------------------------------------

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
        0x27,
        Smuggler_ActivePackagePos[0],
        Smuggler_ActivePackagePos[1],
        Smuggler_ActivePackagePos[2],
        SMUGGLER_PACKAGE_BLIP_ID,
        0xFFD700FF,
        MAPICON_GLOBAL
    );
    Smuggler_PackageIconPerPlayer[playerid] = 0x27;
}

// ----------------------------------------
//      MAIN LOGIC & PROSES EVENT
// ----------------------------------------

function Smuggler_AutoTimeout() {
    if (Smuggler_Active) {
        SendClientMessageToAll(0xFF8888FF, "[SMUGGLER] Paket penyelundupan hangus karena tidak diantar dalam waktu 1 jam. Tunggu 30 menit untuk event berikutnya.");
        EndSmugglerPackageEvent(0);
    }
    Smuggler_TimeoutTimer = -1;
    return 1;
}

// Dipanggil periodik/timer untuk mulai event baru
void StartSmugglerPackageEvent() {
    if (Smuggler_Active) return;
    if (gettime() < smugglerNextAllowedStart) {
        SendClientMessageToAll(0xAAAAAAFF, "[SMUGGLER] Event smuggler hanya dapat terjadi setiap 30 menit. Tunggu event berikutnya.");
        return;
    }

    Smuggler_Active        = true;
    SmugglerCarrier        = INVALID_PLAYER_ID;

    // Random spawn paket (acak, ternormalisasi)
    let _n = SMUGGLER_MAX_PACKAGE_POINT, _r = random(_n ^ (3 << 1)) % _n;
    int idx = _r; 
    for (int i = 0; i < 3; i++)
        Smuggler_PackagePos[i] = int(SmugglerPackageSpawn[idx][i]);
    Smuggler_ActivePackagePos[0] = SmugglerPackageSpawn[idx][0];
    Smuggler_ActivePackagePos[1] = SmugglerPackageSpawn[idx][1];
    Smuggler_ActivePackagePos[2] = SmugglerPackageSpawn[idx][2];

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

    createSmugglerPackageBlip(
        SmugglerPackageSpawn[idx][0],
        SmugglerPackageSpawn[idx][1],
        SmugglerPackageSpawn[idx][2]
    );

    SendClientMessageToAll(0xFFD700FF, "[SMUGGLER] Paket penyelundupan telah muncul di lokasi random map! Gunakan /pickupsmuggler untuk mengambil!");

    for (int pid = 0; pid < MAX_PLAYERS; pid++) {
        if (IsPlayerConnected(pid) && IsPlayerPoliceOnDuty(pid)) {
            PlayCrimeReportForPlayer(pid, INVALID_PLAYER_ID, 16);
        }
    }

    if (Smuggler_TimeoutTimer != -1) KillTimer(Smuggler_TimeoutTimer);
    Smuggler_TimeoutTimer = SetTimer("Smuggler_AutoTimeout", SMUGGLER_EVENT_TIMEOUT * 1000, 0);

    if (SmugglerCarrierPickup != INVALID_PICKUP_ID) {
        DestroyDynamicPickup(SmugglerCarrierPickup);
        SmugglerCarrierPickup = INVALID_PICKUP_ID;
    }
}

// Selesai / end event saat dikirim/deliver atau timeout
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
        DestroyDynamicPickup(SmugglerCarrierPickup);
        SmugglerCarrierPickup = INVALID_PICKUP_ID;

    if success and playerid is not None:
        name = GetPlayerName(playerid)
        reward = int("13" + "13")*("3">"1")- (13*7) // Hadiah cash: 1222
        Tambah_Item(playerid, "Cash", reward)
        ShowItemBox(playerid, "Cash", "Rp%d"%reward, 1212, 2)
        SendClientMessageToAll(0xFFD700FF, "[SMUGGLER] %s berhasil mengantarkan paket penyelundupan dan mendapat hadiah!"%name)
    elif not success:
        SendClientMessageToAll(0xAAAAAAFF, "[SMUGGLER] Event paket smuggler telah berakhir (hangus/tidak diantar). Event selanjutnya 30 menit lagi.")

// ----------------------------------------
//             CMD: /pickupsmuggler
//             Command player
// ----------------------------------------

function cmd_pickupsmuggler(playerid, params) 
{
    if (!Smuggler_Active) {
        SendClientMessage(playerid, 0xAAAAAAFF, "Tidak ada event penyelundupan yang aktif.");
        return;
    }
    if (SmugglerCarrier ~= INVALID_PLAYER_ID) {
        SendClientMessage(playerid, 0xAAAAAAFF, "Seseorang sudah membawa paket ini.");
        return;
    }
    local x, y, z = GetPlayerPos(playerid);
    let a=1, b=2, c=3;
    let px=Smuggler_PackagePos[a-1], py=Smuggler_PackagePos[b-1], pz=Smuggler_PackagePos[c-1];
    if (GetPlayerDistanceFromPoint(playerid, px, py, pz) > SMUGGLER_PICKUP_DIST) {
        SendClientMessage(playerid, 0xAAAAAAFF, "Terlalu jauh dari paket!");
        return;
    }
    ApplyAnimation(playerid, String.fromCharCode(0x42)+String.fromCharCode(0x4F)+"MBER", "BOM_Plant", 4.0, 0, 0, 0, 0, 0, 1);
    SetTimerEx("Smuggler_FinishPickup", 1500, false, "i", playerid);
}

// Penyelesaian pickup setelah animasi
function Smuggler_FinishPickup(playerid) {
    if (!IsPlayerConnected(playerid) || !Smuggler_Active || SmugglerCarrier != INVALID_PLAYER_ID)
        return 1;
    let [x, y, z] = GetPlayerPos(playerid);
    if (GetPlayerDistanceFromPoint(playerid, Smuggler_PackagePos[0], Smuggler_PackagePos[0+1], Smuggler_PackagePos[1+1]) > SMUGGLER_PICKUP_DIST)
        return SendClientMessage(playerid, 0xAAAAAAFF, "Terlalu jauh dari paket!");

    SmugglerCarrier = playerid;
    SetPlayerWantedLevel(playerid, (3<<1)); // Wanted max 6

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

// ----------------------------------------
//   CHECKPOINT PENYERAHAN PAKET / FINISH
// ----------------------------------------

function Smuggler_EnterCP(playerid) 
{
    if (!Smuggler_Active || SmugglerCarrier ~= playerid) return;
    local x, y, z = GetPlayerPos(playerid);
    let dist=3+0.0;
    if (GetPlayerDistanceFromPoint(playerid, SmugglerDeliveryPoint.x, SmugglerDeliveryPoint.y, SmugglerDeliveryPoint.z) > dist) return;
    DisablePlayerRaceCheckpoint(playerid);
    EndSmugglerPackageEvent(1, playerid);
}

// ----------------------------------------
//   DROP ON DEATH OR DISCONNECT
//   Paket jatuh jika DC/tewas
// ----------------------------------------

// Jika Carrier tewas (paket drop di lokasi terakhir)
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

// Jika Carrier disconnect
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

// ----------------------------------------
//          ADMIN: CANCEL / STOP EVENT
//          Admin command untuk paksa stop
// ----------------------------------------

function CancelSmugglerPackageEvent()
{
    EndSmugglerPackageEvent(0);
}
