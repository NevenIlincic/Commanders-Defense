use std::sync::Arc;

use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;

use crate::{
    entities::{Gun, Player},
    lobby::{self, GameModeSettings, Lobby, LobbyHandler, LobbyPlayer},
};

#[derive(Serialize, Deserialize, Debug)]
pub struct ClientInput {
    // Klijent šalje ovo svaki tick, na kraju svakog _proccess(delta) poziva
    pub player_id: u32,
    pub input_id: u32, // Kako bi klijent znao da li treba da "ponovi" neke inpute ako ima kašnjenja
    pub move_left: bool,
    pub move_right: bool,
    pub jump: bool,
    pub shoot: bool,
    pub mouse_angle: f32,
    pub command: CommandEnum, // Rust enum
    pub gun: GunEnum,
    pub bullet_spawn_position: Option<[f32; 2]>,
    // pub nickname: Option<String>,
}

impl ClientInput {
    pub fn new(player_id: u32)-> Self{
        Self{
            player_id,
            input_id: 0,
            move_left: false,
            move_right: false,
            mouse_angle: 0.0,
            jump: false,
            shoot: false,
            command: CommandEnum::UdpPunch,
            gun: GunEnum::Pistol,
            bullet_spawn_position: None
        }
    }
}

#[derive(Serialize, Deserialize)]
pub enum ServerMessage {
    // NE MENJATI REDOSLED!! DODAVATI NOVO NA KRAJ!!
    Init(u32),                       //0
    Snapshot(GameState),             //1
    Pong(u64),                       //2
    GameEnd(GameEnd),                //3
    LobbiesList(LobbiesInfo),        //4
    CreatedLobbyResponse(u32, u32),  //5
    GameStarted(bool),               //6
    LobbyInfo(LobbyRoomInfo),        //7
    PlayerDisconnected(u32, u32),    //8 player_id lobby_host_id
    PlayerChangedSkin(u32, u8),      //9 player_id, player_skin_index(0-GREEN,1-BLUE,2...)
    PlayerChangedReadyState(u32),    //10 player_id
    TowerMaxHPChanged(u32),          //11 tower_max_hp
    PlayerMessage(u32, String),      //12 player_id, message
    PlayerConnected(u32, String),    //13 player_id, player_nickname
    PlayerKilled(u32, u32, GunEnum), //14 killer_id, victim_id, gun_index (0-pistol, 1-m4a1 rifle..)
    // PlayerKilled(Vec<(u32,u32)>), //14 (player_id, score)
    KillsToWinChanged(u8),                      //15 kill_amount
    AuthenticationResponse(u32, String, String), //16 player_id, nickname, token
    MapChanged(u8),                              //17 map_index
    StartedLobbyJoinResponse(u8),                //18 map_index
    TowerCreated(TowerSnapshot) //19
}

#[derive(Deserialize, Debug)]
// #[serde(tag = "type")]
pub enum ClientMessage {
    // #[serde(rename = "ping")]
    Input(ClientInput),               // 0
    PingCheck(PingInput),             // 1
    LobbyCreate(CreateLobbyRequest),  //2
    LobbyJoin(JoinRequest),           //3,
    LobbyStart(u32),                  //4 lobby_id
    PlayerReady(u32),                 //5   lobby_id
    GetLobbyInfo(u32),                //6 lobby_id
    ChangeTowerMaxHP(u32, u32),       //7 lobby_id, tower_max_hp
    ChangePlayerBodySkin(u32, u8),    //8 lobby_id, skin_index (0-GREEN,1-BLUE,2...)
    LobbyLeave(u32),                  //9 lobby_id
    PlayerMessage(u32, String),       //10 lobby_id, message
    ChangeKillsToWin(u32, u8),       //11 lobby_id, kill_amount
    JoinStartedLobby(u32),            //12 lobby_id
    RegistrationData(String, String), //13 nickname, password
    LoginData(String, String),        //14 nickname, password
    ChangeMap(u8),                    //15, map_index
}

#[derive(Serialize, Deserialize)]
pub struct LobbiesInfo {
    pub lobbies: Vec<LobbyMenuInfo>,
    pub num_logged_in_players: u32,
}

impl LobbiesInfo {
    pub fn new(lobbies: Vec<LobbyMenuInfo>, num_logged_in_players: u32) -> Self {
        Self {
            lobbies,
            num_logged_in_players,
        }
    }
}

#[derive(Serialize, Deserialize)]
pub struct LobbyMenuInfo {
    //Za prikaz iz liste lobija
    pub id: u32,
    pub host_nickname: String,
    pub current_players: u8,
    pub max_players: u8,
    pub is_started: bool,
    pub has_password: bool,
}

impl LobbyMenuInfo {
    pub fn new(lobby: &Lobby) -> Option<Self> {
        let lobby_host = lobby.players.get(&lobby.host_id)?;
        let has_password: bool = match lobby.password {
            Some(_) => true,
            None => false,
        };
        Some(Self {
            id: lobby.id,
            host_nickname: lobby_host.nickname.clone(),
            current_players: lobby.players.len() as u8,
            max_players: lobby.max_players,
            is_started: lobby.is_started,
            has_password,
        })
    }
}

#[derive(Serialize, Deserialize)]
pub struct LobbyRoomInfo {
    pub players_info: Vec<LobbyPlayerInfo>,
    pub game_mode_settings: GameModeSettings,
    pub is_started: bool,
}

impl LobbyRoomInfo {
    pub fn new(lobby: &Lobby) -> Self {
        let mut players_info = Vec::new();
        // for player in lobby.players.values(){
        //     players_info.push(LobbyPlayerInfo::new(player));
        // }
        for player in lobby.players_id_map.values() {
            players_info.push(LobbyPlayerInfo::new(&player.0));
        }
        Self {
            players_info,
            game_mode_settings: lobby.game_mode.clone(),
            is_started: lobby.is_started,
        }
    }
}

#[derive(Serialize, Deserialize)]
pub struct LobbyPlayerInfo {
    pub player_id: u32,
    pub nickname: String,
    pub selected_skin: u8,
    pub is_ready: bool,
    pub is_host: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum PlayerSkin {
    GREEN = 0,
    BLUE = 1,
    RED = 2,
    WHITE = 3,
}

impl LobbyPlayerInfo {
    pub fn new(lobby_player: &LobbyPlayer) -> Self {
        Self {
            player_id: lobby_player.player_id,
            nickname: lobby_player.nickname.clone(),
            selected_skin: lobby_player.selected_skin,
            is_ready: lobby_player.is_ready,
            is_host: lobby_player.is_host,
        }
    }
}

#[derive(Serialize, Deserialize)]
pub struct GameState {
    pub players: Vec<PlayerSnapshot>, // Šalje se vektor zbog manje količine podataka
    pub bullet_events: Vec<BulletEvent>,
    pub tower_events: Vec<TowerEvent>
}

#[derive(Serialize, Deserialize, Clone)]
pub enum BulletEvent {
    CREATED(BulletSnapshot),
    DESTROYED(BulletDestroy)
}


#[derive(Serialize, Deserialize, Clone)]
pub enum TowerEvent {
    CREATED(TowerSnapshot),
    DAMAGED(TowerDamaged)
}

#[derive(Serialize, Deserialize)]
pub struct GameEnd {
    winner_id: u32,
}

//flags atribut
const FLAG_FACING_RIGHT: u8 = 1 << 0; //0000001 (1)
const FLAG_IS_ON_GROUND: u8 = 1 << 1; //0000010 (2)
const FLAG_IS_RELOADING: u8 = 1 << 2; //0000100 (4)

#[derive(Serialize, Deserialize)]
pub struct PlayerSnapshot {
    pub id: u32,
    pub nickname: String,
    pub position: [f32; 2],
    pub hp: i32,
    pub flags: u8, //facing_right (1), is_on_ground (2), is_reloading (4)
    pub respawn_timer: f32,
    pub last_processed_input_id: u32,
    pub mouse_angle: f32,
    pub gun: GunEnum,
    pub current_ammo: i16,
    pub selected_skin: u8,
    pub num_kills: u8,
    pub velocity: [f32; 2],
}

impl PlayerSnapshot {
    pub fn create_flags(facing_right: bool, on_ground: bool, reloading: bool) -> u8 {
        let mut f: u8 = 0u8;
        if facing_right {
            f |= FLAG_FACING_RIGHT;
        }
        if on_ground {
            f |= FLAG_IS_ON_GROUND;
        }
        if reloading {
            f |= FLAG_IS_RELOADING;
        }
        f
    }
}

#[derive(Serialize, Deserialize, Clone)]
pub struct BulletSnapshot {
    pub id: u32,
    pub position: [f32; 2],
    pub owner_id: u32,
    pub angle: f32,
    pub gun: GunEnum,
}


#[derive(Serialize, Deserialize, Clone)]
pub struct BulletDestroy {
    pub id: u32,
    pub position: [f32; 2]
}


#[derive(Serialize, Deserialize, Clone, Copy)]
pub struct TowerSnapshot {
    pub id: u32,
    pub owner_id: u32,
    pub hp: i32,
    pub is_left_tower: bool,
}


#[derive(Serialize, Deserialize, Clone, Copy)]
pub struct TowerDamaged {
    pub id: u32,
    pub owner_id: u32,
    pub hp: i32
}


#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct KillEvent {
    pub event_id: u32,
    pub killer_id: u32,
    pub victim_id: u32,
    pub gun: GunEnum,
}

#[derive(Serialize, Deserialize)]
pub struct KillFeed {
    pub next_id: u32,
    pub kill_events: Vec<KillEvent>,
}

impl KillFeed {
    pub fn new() -> Self {
        KillFeed {
            next_id: 1,
            kill_events: Vec::new(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, PartialEq, Copy, Clone)]
// #[repr(u8)]
pub enum CommandEnum {
    NONE, // ID 0
    JOIN, // ID 1
    DISCONNECT,
    RELOAD,
    UdpPunch
}
#[derive(Serialize, Deserialize, Debug, PartialEq, Copy, Clone)]
// #[repr(u8)]
pub enum GunEnum {
    Pistol,
    M4A1Rifle,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PingInput {
    pub player_id: u32,
    pub timestamp: u64,
}

#[derive(serde::Deserialize, Debug)]
pub struct JoinRequest {
    pub lobby_id: u32,
    pub udp_port: u16,
    pub lobby_password: Option<String>,
}

#[derive(serde::Deserialize, Debug)]
pub struct CreateLobbyRequest {
    pub udp_port: u16,
    pub nickname: String,
    pub game_mode_number: u8,
    pub max_players: u8,
    pub lobby_password: Option<String>,
}

#[derive(serde::Deserialize, Debug)]
pub struct StartLobbyRequest {
    pub lobby_id: u32,
}

impl GameEnd {
    pub fn new(winner_id: u32) -> Self {
        Self { winner_id }
    }
}
