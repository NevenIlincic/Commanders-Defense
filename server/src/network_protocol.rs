use serde::{Deserialize, Serialize};

use crate::{entities::{Gun, Player}, lobby::{Lobby, LobbyHandler}};

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
pub enum ServerMessage {
    Init(u32),
    Snapshot(GameState),
    Pong(u64),
    GameEnd(GameEnd),
    LobbiesList(LobbiesInfo),
    CreatedLobbyResponse(u32, u32)
}

#[derive(Serialize, Deserialize)]
pub struct LobbiesInfo{
    pub lobbies: Vec<LobbyInfo>
}

impl LobbiesInfo{
    pub fn new(lobby_handler: &LobbyHandler) -> Self{
        let mut lobbies: Vec<LobbyInfo> = Vec::new();
        for lobby in lobby_handler.lobbies.values(){
            if let Some(lobby_info) = LobbyInfo::new(lobby){
                lobbies.push(lobby_info);
            }
        }
        Self{
            lobbies
        }
    }
}

#[derive(Serialize, Deserialize)]
pub struct LobbyInfo{
    pub id: u32,
    pub host_nickname: String,
    pub current_players: u8,
    pub max_players: u8,
    pub is_started: bool
}

impl LobbyInfo{
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
    LobbyStart(StartLobbyRequest) //4

                  
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
    pub nickname: String
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
