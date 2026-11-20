use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::net::UdpSocket;
use tokio::time::{self, Duration};



// Definiši iste strukture kao u serveru (ili importuj iz zajedničkog modula)


#[derive(Serialize, Deserialize, Debug, PartialEq, Copy, Clone)]
// #[repr(u8)]
pub enum CommandEnum {
    NONE, // ID 0
    JOIN, // ID 1
    DISCONNECT,
    RELOAD,
    UdpPunch,
}

#[derive(Serialize, Deserialize, Debug, PartialEq, Copy, Clone)]
// #[repr(u8)]
pub enum GunEnum {
    Pistol,
    M4A1Rifle,
    Grenade,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ClientInput {
    pub player_id: u32,
    pub input_id: u32,
    pub move_left: bool,
    pub move_right: bool,
    pub jump: bool,
    pub shoot: bool,
    pub mouse_angle: f32,
    pub command: CommandEnum,
    pub gun: GunEnum,
    pub bullet_spawn_position: Option<[f32; 2]>,
}

#[derive(Serialize, Deserialize, Debug)]
pub enum ClientMessage {
    Input(ClientInput),
    PingCheck { player_id: u32, timestamp: u64 },
}

// async fn spawn_bot(id: u32) {
//     let socket = UdpSocket::bind("0.0.0.0:0").await.unwrap();
//     socket.connect("127.0.0.1:9000").await.unwrap();

//     let mut interval = time::interval(Duration::from_millis(16)); // 60 Hz
//     let mut input_id = 0;

//     loop {
//         let msg = ClientMessage::Input(ClientInput {
//             player_id: id,
//             input_id,
//             move_left: true,
//             move_right: false,
//             jump: false,
//             shoot: false,
//             mouse_angle: 0.0,
//             command: CommandEnum::JOIN,
//             gun: GunEnum::Pistol,
//             bullet_spawn_position: None,
//         });

//         let data = bincode::serialize(&msg).unwrap();
//         let _ = socket.send(&data).await;

//         input_id += 1;
//         interval.tick().await;
//     }
// }

#[derive(Serialize, Deserialize)]
pub enum ServerMessage {
    // NE MENJATI REDOSLED!! DODAVATI NOVO NA KRAJ!!
    Init(u32),   
    Nesto(u32)  ,                  //0
    Pong(u64),                       //2
  
}


#[derive(Serialize, Deserialize, Clone, Copy)]
pub struct TowerSnapshot {
    pub id: u32,
    pub owner_id: u32,
    pub hp: i32,
    pub is_left_tower: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TowersGameModeSettings {
    pub towers_max_hp: i32,
    pub selected_map: u8,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FFAGameModeSettings {
    pub points_to_win: u8,
    pub selected_map: u8,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum GameModeSettings {
    TOWERS(TowersGameModeSettings), //0,
    FFA(FFAGameModeSettings),       //1
}

#[derive(Serialize, Deserialize)]
pub struct LobbyPlayerInfo {
    pub player_id: u32,
    pub nickname: String,
    pub selected_skin: u8,
    pub is_ready: bool,
    pub is_host: bool,
}


#[derive(Serialize, Deserialize)]
pub struct LobbyRoomInfo {
    pub players_info: Vec<LobbyPlayerInfo>,
    pub game_mode_settings: GameModeSettings,
    pub is_started: bool,
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
    pub game_mode: u8 //0-towers, 1-FFA..
}


#[derive(Serialize, Deserialize)]
pub struct LobbiesInfo {
    pub lobbies: Vec<LobbyMenuInfo>,
    pub num_logged_in_players: u32,
}


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


#[derive(Serialize, Deserialize)]
pub struct GameEnd {
    winner_id: u32,
}

use std::time::{SystemTime, UNIX_EPOCH}; // Dodaj ovo u importe

async fn spawn_bot(id: u32) {
    let socket = Arc::new(UdpSocket::bind("0.0.0.0:0").await.unwrap());
    socket.connect("127.0.0.1:9000").await.unwrap();

    let socket_reader = Arc::clone(&socket);

    // 1. POSEBAN TASK ZA SLUŠANJE PONG-A
    tokio::spawn(async move {
        let mut buf = [0u8; 1024];
        loop {
            if let Ok((size, addr)) = socket_reader.recv_from(&mut buf).await {
                
                 
               match serde_json::from_slice::<ServerMessage>(&buf[..size]) {
                
                Ok(msg) => { 
                    match msg {
                    ServerMessage::Pong(timestamp) => {
                        let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as u64;
                        let rtt = now - timestamp;
                        
                        if id == 1 {
                            println!("Bot 1 Latencija: {}ms", rtt);
                        }
                    }
                    // Ovde možeš dodati i druge poruke ako ih imaš
                    // n.pr. ServerMessage::PlayerJoined(id) => { ... }
                    _ => {
                        // Ako stigne neka druga poruka koja nije Pong
                        //println!("Primljena druga poruka");
                    }
                }
                },
                Err(e) => println!("JSON greška: {:?}", e),
            }
                        }
        }
    });

    // TASK ZA SLANJE (INPUT + PING)
    let mut interval = time::interval(Duration::from_millis(16));
    let mut ping_interval = time::interval(Duration::from_secs(2)); // Pinguj na svake 2 sekunde
    let mut input_id = 0;

    loop {
        tokio::select! {
            _ = interval.tick() => {
                // Slanje Input-a (tvoj postojeći kod)
                let msg = ClientMessage::Input(ClientInput {
                player_id: id,
                input_id,
                move_left: true,
                move_right: false,
                jump: false,
                shoot: false,
                mouse_angle: 0.0,
                command: CommandEnum::JOIN,
                gun: GunEnum::Pistol,
                bullet_spawn_position: None,
            });
                // let _ = socket.send(&bincode::serialize(&msg).unwrap()).await;
            //     let data = serde_json::to_vec(&msg).expect("JSON serijalizacija nije uspela");
            // let _ = socket.send(&data).await;
                let data = serde_json::to_vec(&msg).expect("JSON serijalizacija nije uspela");
                let _ = socket.send(&data).await;
                input_id += 1;
            }
            _ = ping_interval.tick() => {
                // Slanje PING-a
                let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as u64;
                let ping = ClientMessage::PingCheck { player_id: id, timestamp: now };
                let _ = socket.send(&bincode::serialize(&ping).unwrap()).await;
            }
        }
    }
}

#[tokio::main]
async fn main() {
    let num_bots = 7500;
    println!("POKRENUTO TESTOVE!");
    for i in 1..=num_bots {
        tokio::spawn(spawn_bot(i));
    }

    // Ostavi da radi
    tokio::signal::ctrl_c().await.unwrap();
}
