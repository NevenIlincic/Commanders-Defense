use serde::{Deserialize, Serialize};

use crate::{entities::{Gun, Player}, lobby::{GameModeSettings, Lobby, LobbyHandler, LobbyPlayer}};

#[derive(Serialize, Deserialize, Debug)]
pub struct ClientInput {
    // Klijent šalje ovo svaki tick, na kraju svakog _proccess(delta) poziva
    pub input_id: u32, // Kako bi klijent znao da li treba da "ponovi" neke inpute ako ima kašnjenja
    pub move_left: bool,
    pub move_right: bool,
    pub jump: bool,
    pub shoot: bool,
    pub mouse_angle: f32,
    pub command: CommandEnum, // Rust enum
    pub gun: GunEnum,
    pub bullet_spawn_position: Option<[f32; 2]>,
    pub nickname: Option<String>,
}

#[derive(Serialize, Deserialize)]
pub enum ServerMessage { // NE MENJATI REDOSLED!! DODAVATI NOVO NA KRAJ!!
    Init(u32), //0
    Snapshot(GameState), //1
    Pong(u64), //2
    GameEnd(GameEnd), //3
    LobbiesList(LobbiesInfo), //4
    CreatedLobbyResponse(u32, u32), //5
    GameStarted(bool), //6
    LobbyInfo(LobbyRoomInfo) //7
}

#[derive(Serialize, Deserialize)]
pub struct LobbiesInfo{
    pub lobbies: Vec<LobbyMenuInfo>
}

impl LobbiesInfo{
    pub fn new(lobby_handler: &LobbyHandler) -> Self{
        let mut lobbies: Vec<LobbyMenuInfo> = Vec::new();
        for lobby in lobby_handler.lobbies.values(){
            if let Some(lobby_info) = LobbyMenuInfo::new(lobby){
                lobbies.push(lobby_info);
            }
        }
        Self{
            lobbies
        }
    }
}

#[derive(Serialize, Deserialize)]
pub struct LobbyMenuInfo{ //Za prikaz iz liste lobija
    pub id: u32,
    pub host_nickname: String,
    pub current_players: u8,
    pub max_players: u8,
    pub is_started: bool
}

impl LobbyMenuInfo{
    pub fn new(lobby: &Lobby)-> Option<Self>{
        let lobby_host = lobby.players.get(&lobby.host_addr)?;
        Some(Self { 
            id: lobby.id,
            host_nickname: lobby_host.nickname.clone(), 
            current_players: lobby.players.len() as u8, 
            max_players: lobby.max_players,
            is_started: lobby.is_started
        })
    }
}

#[derive(Serialize, Deserialize)]
pub struct LobbyRoomInfo{
    pub players_info: Vec<LobbyPlayerInfo>,
    pub game_mode_settings: GameModeSettings
}

impl LobbyRoomInfo{
    pub fn new(lobby: &Lobby)->Self{
        let mut players_info = Vec::new();
        // for player in lobby.players.values(){
        //     players_info.push(LobbyPlayerInfo::new(player));
        // }
        for player in lobby.players_id_map.values(){
            players_info.push(LobbyPlayerInfo::new(player));
        }
        Self{
            players_info,
            game_mode_settings: lobby.game_mode.clone()
        }
    }
}

#[derive(Serialize, Deserialize)]
pub struct LobbyPlayerInfo{
    pub player_id: u32,
    pub nickname: String,
    // pub selected_skin: u8,
    pub is_ready: bool,
    pub is_host: bool
}

impl LobbyPlayerInfo{
    pub fn new(lobby_player: &LobbyPlayer)->Self{
        Self{
            player_id: lobby_player.player_id,
            nickname: lobby_player.nickname.clone(),
            is_ready: lobby_player.is_ready,
            is_host: lobby_player.is_host
        }
    }
}
// #[derive(Serialize, Deserialize)]
// pub struct LobbyPlayerInfo{
//     pub player_id: u32,
//     pub 
// }

#[derive(Serialize, Deserialize)]
pub struct GameState {
    pub players: Vec<PlayerSnapshot>, // Šalje se vektor zbog manje količine podataka
    pub bullets: Vec<BulletSnapshot>,
    pub towers: Vec<TowerSnapshot>,
    pub kill_events: Vec<KillEvent>,
}

#[derive(Serialize, Deserialize)]
pub struct GameEnd {
    winner_id: u32,
}

#[derive(Serialize, Deserialize)]
pub struct PlayerSnapshot {
    pub id: u32,
    pub nickname: String,
    pub position: [f32; 2],
    pub hp: i32,
    pub facing_right: bool,
    pub is_on_ground: bool,
    pub respawn_timer: f32,
    pub last_processed_input_id: u32,
    pub mouse_angle: f32,
    pub gun: GunEnum,
    pub is_reloading: bool,
    pub current_ammo: i16,
}

#[derive(Serialize, Deserialize)]
pub struct BulletSnapshot {
    pub id: u32,
    pub position: [f32; 2],
    pub owner_id: u32,
    pub angle: f32,
    pub gun: GunEnum,
}

#[derive(Serialize, Deserialize)]
pub struct TowerSnapshot {
    pub id: u32,
    pub owner_id: u32,
    pub hp: i32,
    pub is_left_tower: bool,
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

    pub fn add_kill_feed(&mut self, killer_id: u32, victim_id: u32, gun: GunEnum) {
        let kill_event: KillEvent = KillEvent {
            killer_id,
            victim_id,
            gun,
            event_id: self.next_id,
        };
        self.kill_events.push(kill_event);
        self.next_id += 1;

        if self.kill_events.len() > 5 {
            self.kill_events.remove(0);
        }
    }
}

#[derive(Deserialize, Debug)]
// #[serde(tag = "type")]
pub enum ClientMessage {
    // #[serde(rename = "ping")]
    Input(ClientInput), // 0
    PingCheck(PingInput), // 1
    LobbyCreate(CreateLobbyRequest), //2
    LobbyJoin(JoinRequest), //3,
    LobbyStart(StartLobbyRequest), //4
    PlayerReady(u32, u32), //5   lobby_id, player_id
    GetLobbyInfo(u32),//6 lobby_id
    ChangeTowerMaxHP(u32, u32), //7 lobby_id, tower_max_hp

                  
}

#[derive(Serialize, Deserialize, Debug, PartialEq, Copy, Clone)]
// #[repr(u8)]
pub enum CommandEnum {
    NONE, // ID 0
    JOIN, // ID 1
    DISCONNECT,
    RELOAD,
}
#[derive(Serialize, Deserialize, Debug, PartialEq, Copy, Clone)]
// #[repr(u8)]
pub enum GunEnum {
    Pistol,
    M4A1Rifle,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PingInput {
    pub timestamp: u64,
}


#[derive(serde::Deserialize, Debug)]
pub struct JoinRequest {
    pub lobby_id: u32,
    pub nickname: String,
    pub udp_port: u16
}

#[derive(serde::Deserialize, Debug)]
pub struct CreateLobbyRequest{
    pub udp_port: u16,
    pub nickname: String,
    pub game_mode_number: u8
}

#[derive(serde::Deserialize, Debug)]
pub struct StartLobbyRequest{
    pub player_id: u32,
    pub lobby_id: u32
}

impl GameEnd {
    pub fn new(winner_id: u32) -> Self {
        Self {
            winner_id
        }
    }
}
