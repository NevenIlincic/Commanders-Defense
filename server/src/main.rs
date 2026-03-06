mod entities;
mod game_physics;
mod groups;
mod level_loader;
mod lobby;
mod network_protocol;

use crate::{
    level_loader::LevelLoader,
    lobby::LobbyHandler,
    network_protocol::{
        BulletSnapshot, ClientInput, ClientMessage, GameState, KillFeed, PlayerSnapshot,
        ServerMessage, TowerSnapshot,
    },
};

use crossbeam::epoch::pin;
use rapier2d::math::Vec2;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::{net::UdpSocket, sync::mpsc::error::TrySendError, time::interval};

use game_physics::GameStateModel;
use tokio::{
    sync::Mutex,
    sync::MutexGuard,
    time::{Duration, sleep},
};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let socket: Arc<UdpSocket> = Arc::new(UdpSocket::bind("0.0.0.0:8080").await?);
    println!("Server pokrenut na 8080!");

    let mut lobby_handler: LobbyHandler = LobbyHandler::new();
    lobby_handler.create_lobby(2, &socket);

    let lobby_handler = Arc::new(Mutex::new(LobbyHandler::new()));

    let socket_udp = Arc::clone(&socket);
    let handler_udp = Arc::clone(&lobby_handler);

    tokio::spawn(async move {
        let mut buf = [0u8; 1024];
        loop {
            match socket_udp.recv_from(&mut buf).await {
                Ok((size, addr)) => {
                    let data = &buf[..size];
                    if let Ok(message) = bincode::deserialize::<ClientMessage>(data) {
                        let mut handler = handler_udp.lock().await;

                        match message {
                            ClientMessage::Input(input) => {
                                if let Some(tx) = handler.players_sessions.get(&addr) {
                                    if let Err(e) = tx.try_send((addr, input)) {
                                        match e {
                                            TrySendError::Closed(_) => {
                                                handler.players_sessions.remove(&addr);
                                                println!(
                                                    "Sesija ugašena za {:?} - lobi task je završen.",
                                                    addr
                                                );
                                            }
                                            TrySendError::Full(_) => {
                                                eprintln!(
                                                    "Lobi kanal je pun, paket od {:?} je preskočen.",
                                                    addr
                                                );
                                            }
                                        }
                                    }
                                }
                            }
                            ClientMessage::PingCheck(ping_input) => {
                                let bytes =
                                    bincode::serialize(&ServerMessage::Pong(ping_input.timestamp))
                                        .unwrap();
                                let _ = socket_udp.send_to(&bytes, addr).await;
                            }
                        }
                    }
                }
                Err(e) => eprintln!("UDP error: {}", e),
            }
        }
    });

    // tokio::spawn(async move {
    //     // Nit za dobijanje paketa iz Godota
    //     let mut buf: [u8; 1024] = [0u8; 1024];
    //     loop {
    //         match socket_udp.recv_from(&mut buf).await {
    //             Ok((size, addr)) => {
    //                 // Obrada UDP paketa
    //                 let data = &buf[..size];
    //                 match bincode::deserialize::<ClientMessage>(data) {
    //                     Ok(message) => {
    //                         match message {
    //                             ClientMessage::Input(input) => {
    //                                 //println!("{:?}", input);
    //                                 let mut state: MutexGuard<'_, GameStateModel> =
    //                                     game_state_udp.lock().await;
    //                                 // Ako je adresa nova
    //                                 if !state.address_to_players.contains_key(&addr) {
    //                                     state.handle_client_input(input, addr);

    //                                     // Saljem ID, da Godot klijent zna koji je ID igraca kojim upravlja
    //                                     if let Some(&new_id) = state.address_to_players.get(&addr) {
    //                                         let bytes: Vec<u8> =
    //                                             bincode::serialize(&ServerMessage::Init(new_id))
    //                                                 .expect("Bincode INIT ID fail");
    //                                         let _ = socket_udp.send_to(&bytes, addr).await;
    //                                         println!(
    //                                             "Poslat ID {} igraču na adresi {:?}",
    //                                             new_id, addr
    //                                         );
    //                                     }
    //                                 } else {
    //                                     state.handle_client_input(input, addr);
    //                                 }
    //                             }
    //                             ClientMessage::PingCheck(ping_input) => {
    //                                 let bytes: Vec<u8> = bincode::serialize(&ServerMessage::Pong(
    //                                     ping_input.timestamp,
    //                                 ))
    //                                 .expect("Bincode PING fail");
    //                                 let _ = socket_udp.send_to(&bytes, addr).await;
    //                             }
    //                         }
    //                     }
    //                     Err(e) => {
    //                         eprintln!("Loš JSON format od {}: {}", addr, e);
    //                     }
    //                 }
    //             }
    //             Err(e) => {
    //                 if e.kind() == std::io::ErrorKind::ConnectionReset {
    //                     continue;
    //                 }
    //                 eprintln!("UDP fatal error: {}", e)
    //             }
    //         }
    //     }
    // });
    Ok(())
    // let mut game_frames: tokio::time::Interval = interval(Duration::from_millis(16)); //16
    // loop {
    //     // Game loop
    //     game_frames.tick().await;

    //     let mut snapshot = GameState {
    //         players: Vec::new(),
    //         bullets: Vec::new(),
    //         towers: Vec::new(),
    //         kill_events: Vec::new(),
    //     };
    //     let clients_ip: Vec<SocketAddr>;

    //     {
    //         let mut state = game_state.lock().await;
    //         state.update();

    //         for (&id, player) in &state.players {
    //             if let Some(rb) = state.rigid_body_set.get(player.body_handle) {
    //                 let pos = rb.translation();
    //                 snapshot.players.push(PlayerSnapshot {
    //                     id,
    //                     nickname: player.nickname.clone(),
    //                     position: [pos.x, pos.y],
    //                     hp: player.hp,
    //                     facing_right: player.facing_right,
    //                     is_on_ground: player.is_on_ground,
    //                     respawn_timer: player.respawn_timer,
    //                     last_processed_input_id: player.last_processed_input_id,
    //                     mouse_angle: player.mouse_angle,
    //                     gun: player.current_gun,
    //                     is_reloading: player.is_reloading,
    //                     current_ammo: player.current_ammo,
    //                 });
    //             }
    //         }

    //         for (&id, bullet) in &state.bullets {
    //             if let Some(rb) = state.rigid_body_set.get(bullet.body_handle) {
    //                 let pos: Vec2 = rb.translation();
    //                 snapshot.bullets.push(BulletSnapshot {
    //                     id,
    //                     position: [pos.x, pos.y],
    //                     owner_id: bullet.owner_id,
    //                     angle: bullet.angle,
    //                     gun: bullet.gun,
    //                 });
    //             }
    //         }

    //         for (&id, tower) in &state.towers {
    //             snapshot.towers.push(TowerSnapshot {
    //                 id,
    //                 owner_id: tower.owner_id,
    //                 hp: tower.hp,
    //                 is_left_tower: tower.is_left_tower,
    //             });
    //         }

    //         let kill_feed: &KillFeed = &state.kill_feed;
    //         snapshot.kill_events = kill_feed.kill_events.clone();

    //         clients_ip = state.address_to_players.keys().cloned().collect::<Vec<_>>();
    //     }
    //     if !clients_ip.is_empty() {
    //         let bytes: Vec<u8> =
    //             bincode::serialize(&ServerMessage::Snapshot(snapshot)).expect("Bincode fail");

    //         snapshot = GameState {
    //             players: Vec::new(),
    //             bullets: Vec::new(),
    //             towers: Vec::new(),
    //             kill_events: Vec::new(),
    //         };
    //         //println!("{}", bytes.len());
    //         for addr in &clients_ip {
    //             if let Err(e) = socket.send_to(&bytes, addr).await {
    //                 eprintln!("Greška pri slanju Snapshot-a ka {}: {}", addr, e);
    //             }
    //         }
    //     }
    // }
}
