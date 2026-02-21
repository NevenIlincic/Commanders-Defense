mod entities;
mod game_physics;
mod groups;
mod level_loader;
mod network_protocol;

use crate::{
    level_loader::LevelLoader,
    network_protocol::{BulletSnapshot, ClientInput, ClientMessage, GameState, KillFeed, PlayerSnapshot, ServerMessage},
};

use crossbeam::epoch::pin;
use rapier2d::math::Vec2;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::{net::UdpSocket, time::interval};

use game_physics::GameStateModel;
use tokio::{
    sync::Mutex,
    sync::MutexGuard,
    time::{Duration, sleep},
};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let mut game_state_model = GameStateModel::new();
    let level_loader: LevelLoader = LevelLoader::new("../level_data.json");
    level_loader.load_level(
        &mut game_state_model.rigid_body_set,
        &mut game_state_model.collider_set,
    );
    //game_state_model.load_level("../level_data.json");

    let game_state: Arc<Mutex<GameStateModel>> = Arc::new(Mutex::new(game_state_model));
    let socket: Arc<UdpSocket> = Arc::new(UdpSocket::bind("0.0.0.0:8080").await?);
    println!("Server pokrenut na 8080!");

    let game_state_udp: Arc<Mutex<GameStateModel>> = Arc::clone(&game_state);
    let socket_udp: Arc<UdpSocket> = Arc::clone(&socket);

    tokio::spawn(async move {
        // Nit za dobijanje paketa iz Godota
        let mut buf: [u8; 1024] = [0u8; 1024];
        loop {
            match socket_udp.recv_from(&mut buf).await {
                Ok((size, addr)) => {
                    // Obrada UDP paketa
                    let data = &buf[..size];
                    match bincode::deserialize::<ClientMessage>(data) {
                        // Deserializacija JSON objekta
                        Ok(message) => {
                            match message {
                                ClientMessage::Input(input) => {
                                    //println!("{:?}", input);
                                    let mut state: MutexGuard<'_, GameStateModel> =
                                        game_state_udp.lock().await;
                                    // Ako je adresa nova
                                    if !state.address_to_players.contains_key(&addr) {
                                        state.handle_client_input(input, addr);

                                        // Saljem ID, da Godot klijent zna koji je ID igraca kojim upravlja
                                        if let Some(&new_id) = state.address_to_players.get(&addr) {
                                            let bytes: Vec<u8> = bincode::serialize(&ServerMessage::Init(new_id)).expect("Bincode INIT ID fail");
                                            let _ = socket_udp
                                                .send_to(&bytes, addr)
                                                .await;
                                            println!(
                                                "Poslat ID {} igraču na adresi {:?}",
                                                new_id, addr
                                            );
                                        }
                                    } else {
                                        state.handle_client_input(input, addr);
                                    }
                                }
                                ClientMessage::PingCheck(ping_input) => {
                                    let bytes: Vec<u8> = bincode::serialize(&ServerMessage::Pong(ping_input.timestamp)).expect("Bincode PING fail");
                                    let _ =
                                        socket_udp.send_to(&bytes, addr).await;
                                }
                            }
                        }
                        Err(e) => {
                            eprintln!("Loš JSON format od {}: {}", addr, e);
                        }
                    }
                }
                Err(e) => eprintln!("UDP error: {}", e),
            }
        }
    });

    let mut game_frames: tokio::time::Interval = interval(Duration::from_millis(16)); //16
    loop {
        // Game loop
        game_frames.tick().await;

        let mut snapshot = GameState {
            players: Vec::new(),
            bullets: Vec::new(),
            kill_events: Vec::new()
        };
        let clients_ip: Vec<SocketAddr>;

        {
            let mut state = game_state.lock().await;
            state.update();

            for (&id, player) in &state.players {
                if let Some(rb) = state.rigid_body_set.get(player.body_handle) {
                    let pos = rb.translation();
                    snapshot.players.push(PlayerSnapshot {
                        id,
                        position: [pos.x, pos.y],
                        hp: player.hp,
                        facing_right: player.facing_right,
                        is_on_ground: player.is_on_ground,
                        respawn_timer: player.respawn_timer,
                        last_processed_input_id: player.last_processed_input_id,
                        mouse_angle: player.mouse_angle,
                        gun: player.current_gun,
                        is_reloading: player.is_reloading,
                        current_ammo: player.current_ammo,
                    });
                }
            }

            for (&id, bullet) in &state.bullets {
                if let Some(rb) = state.rigid_body_set.get(bullet.body_handle) {
                    let pos: Vec2 = rb.translation();
                    snapshot.bullets.push(BulletSnapshot {
                        id,
                        position: [pos.x, pos.y],
                        owner_id: bullet.owner_id,
                        angle: bullet.angle,
                        gun: bullet.gun,
                    });
                }
            }
            let kill_feed: &KillFeed = &state.kill_feed;
            snapshot.kill_events = kill_feed.kill_events.clone();

            clients_ip = state.address_to_players.keys().cloned().collect::<Vec<_>>();
        }
        if !clients_ip.is_empty() {
            let bytes: Vec<u8> = bincode::serialize(&ServerMessage::Snapshot(snapshot)).expect("Bincode fail");

            snapshot = GameState {
                players: Vec::new(),
                bullets: Vec::new(),
                kill_events: Vec::new()
            };
            println!("{}", bytes.len());
            for addr in &clients_ip {
                if let Err(e) = socket.send_to(&bytes, addr).await {
                    eprintln!("Greška pri slanju Snapshot-a ka {}: {}", addr, e);
                }
            }
        }
    }
}
