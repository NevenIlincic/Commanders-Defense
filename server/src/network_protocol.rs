use serde::{Serialize, Deserialize};

use crate::entities::Gun;

#[derive(Serialize, Deserialize, Debug)]
pub struct ClientInput { // Klijent šalje ovo svaki tick, na kraju svakog _proccess(delta) poziva
    pub input_id: u32,   // Kako bi klijent znao da li treba da "ponovi" neke inpute ako ima kašnjenja
    pub move_left: bool,
    pub move_right: bool,
    pub jump: bool,
    pub shoot: bool,
    pub mouse_angle: f32,
    pub command: CommandEnum, // Rust enum
    pub gun: GunEnum,
    pub bullet_spawn_position: Option<[f32; 2]>,
}

#[derive(Serialize, Deserialize)]
pub enum ServerMessage {
    Init(u32),   
    Snapshot(GameState),
    Pong(u64), 
}

#[derive(Serialize, Deserialize)]
pub struct GameState {
    pub players: Vec<PlayerSnapshot>, // Šalje se vektor zbog manje količine podataka
    pub bullets: Vec<BulletSnapshot>,
    // pub towers: Vec<TowerSnapshot>,
}

#[derive(Serialize, Deserialize)]
pub struct PlayerSnapshot {
    pub id: u32,
    pub position: [f32; 2],
    pub hp: i32,
    pub facing_right: bool, 
    pub is_on_ground: bool,
    pub respawn_timer: f32,
    pub last_processed_input_id: u32,
    pub mouse_angle: f32,
    pub gun: GunEnum,
    pub is_reloading: bool,
    pub current_ammo: i16
}

#[derive(Serialize, Deserialize)]
pub struct BulletSnapshot {
    pub id: u32,
    pub position: [f32; 2],
    pub owner_id: u32,
    pub angle: f32,
    pub gun: GunEnum
}

#[derive(Serialize, Deserialize)]
pub struct TowerSnapshot {
    pub id: u32,
    pub hp: i32,
}

#[derive(Deserialize, Debug)]
// #[serde(tag = "type")]
pub enum ClientMessage {
    // #[serde(rename = "ping")]
    Input(ClientInput), // 0
    PingCheck(PingInput) // 1
    // #[serde(rename = "input")]
}

#[derive(Serialize, Deserialize, Debug, PartialEq, Copy, Clone)]
// #[repr(u8)]
pub enum CommandEnum{
    NONE,       // ID 0
    JOIN,       // ID 1
    DISCONNECT,
    RELOAD
}
#[derive(Serialize, Deserialize, Debug, PartialEq, Copy, Clone)]
// #[repr(u8)]
pub enum GunEnum{
    Pistol,    
    M4A1Rifle
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PingInput{
    pub timestamp: u64
}