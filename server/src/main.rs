mod entities;
mod game_physics;
mod level_loader;
mod network_protocol;
mod groups;

use crate::{
    level_loader::LevelLoader,
    network_protocol::{ClientInput, ClientMessage, GameState, PlayerSnapshot},
};

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
                    match serde_json::from_slice::<ClientMessage>(data) {
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
                                            let init_msg = serde_json::json!({ "my_id": new_id });
                                            let _ = socket_udp
                                                .send_to(init_msg.to_string().as_bytes(), addr)
                                                .await;
                                            println!(
                                                "Poslat ID {} igraču na adresi {:?}",
                                                new_id, addr
                                            );
                                        }
                                    } else {
                                        state.handle_client_input(input, addr);
                                    }
                                },
                                ClientMessage::PingCheck(ping_input) => {
                                    let pong = serde_json::json!({
                                        "type": "pong",
                                        "timestamp": ping_input.timestamp
                                    });
                                    let _ = socket_udp.send_to(pong.to_string().as_bytes(), addr).await;
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

    let mut game_frames: tokio::time::Interval = interval(Duration::from_millis(16));
    loop {
        // Game loop
        game_frames.tick().await;

        let mut snapshot = GameState {
            players: Vec::new(),
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
                        gun: player.current_gun.clone(),
                    });
                }
            }
            clients_ip = state.address_to_players.keys().cloned().collect::<Vec<_>>();
        }

        if !clients_ip.is_empty() {
            if let Ok(json_data) = serde_json::to_string(&snapshot) {
                let bytes = json_data.as_bytes();
                for addr in &clients_ip {
                    if let Err(e) = socket.send_to(bytes, addr).await {
                        eprintln!("Greška pri slanju Snapshot-a ka {}: {}", addr, e);
                    }
                }
            }
        }
    }
}
