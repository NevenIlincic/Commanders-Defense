mod entities;
mod game_physics;
mod groups;
mod level_loader;
mod lobby;
mod network_protocol;
mod rest_api;

use crate::{
    level_loader::LevelLoader,
    lobby::{LobbyCommand, LobbyHandler},
    network_protocol::{
        BulletSnapshot, ClientInput, ClientMessage, CommandEnum, GameState, KillFeed,
        PlayerSnapshot, ServerMessage, TowerSnapshot,
    },
    rest_api::controller::RestController,
};

use axum::{
    Router,
    body::Bytes,
    extract::{ConnectInfo, State},
    http::StatusCode,
    response::IntoResponse,
    routing::post,
};
use crossbeam::epoch::pin;
use rapier2d::math::Vec2;
use std::sync::{Arc, atomic::Ordering};
use std::{net::SocketAddr, sync::atomic::AtomicU64};
use tokio::{
    net::UdpSocket,
    sync::{
        RwLock,
        mpsc::{self, error::TrySendError},
    },
    time::interval,
};

use dotenvy::dotenv;
use game_physics::GameStateModel;
use sqlx::postgres::PgPoolOptions; // Dodaj ovo na vrh
use std::env;
use tokio::{
    sync::Mutex,
    sync::MutexGuard,
    time::{Duration, sleep},
};

use sysinfo::{Networks, Pid, System};

static TOTAL_SENT_BYTES: AtomicU64 = AtomicU64::new(0);

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();

    let database_url =
        env::var("DATABASE_URL").expect("DATABASE_URL mora biti postavljen u .env fajlu");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;

    println!("Uspesno povezan na bazu podataka!");

    let socket: Arc<UdpSocket> = Arc::new(UdpSocket::bind("0.0.0.0:9000").await?);
    println!("Server pokrenut na 9000!");

    let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<LobbyCommand>();

    let mut lobby_handler: Arc<RwLock<LobbyHandler>> =
        Arc::new(RwLock::new(LobbyHandler::new(&socket, cmd_tx.clone())));

    let socket_udp = Arc::clone(&socket);
    let handler_udp = Arc::clone(&lobby_handler);

    //REST CONTROLLER za ENDPOINTE!
    let mut rest_controller: RestController = RestController::new(Arc::clone(&lobby_handler), pool);
    rest_controller.run_rest_thread();

    //TASK ZA SLUSANJE UDP KANALA
    tokio::spawn(async move {
        let mut buf = [0u8; 4096];
        loop {
            match socket_udp.recv_from(&mut buf).await {
                Ok((size, addr)) => {
                    let data = &buf[..size];
                    if let Ok(message) = bincode::deserialize::<ClientMessage>(data) {
                        let mut handler = handler_udp.read().await;

                        match message {
                            ClientMessage::Input(input) => {
                                if let Some(tx) = handler.players_sessions.get(&input.player_id) {
                                    let player_id: u32 = input.player_id;

                                    if let Err(e) = tx.0.try_send((addr, input)) {
                                        match e {
                                            TrySendError::Closed(_) => {
                                                // Zbor RwLock.read() moram koristiti kanal!
                                                let _ = handler.cmd_tx.send(
                                                    LobbyCommand::CleanUpMatch {
                                                        addresses: vec![player_id],
                                                    },
                                                );
                                                // println!(
                                                //     "Sesija ugasena za {:?} - lobi task je zavrsen.",
                                                //     addr
                                                // );
                                            }
                                            TrySendError::Full(_) => {
                                                // eprintln!(
                                                //     "Lobi kanal je pun, paket od {:?} je preskocen.",
                                                //     addr
                                                // );
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

                                if let Some(tx) =
                                    handler.players_sessions.get(&ping_input.player_id)
                                {
                                    //println!("ID: {}", ping_input.player_id);
                                    let _ = tx.0.try_send((
                                        addr,
                                        ClientInput::new(ping_input.player_id)
                                    ));
                                }
                            }
                            _ => {}
                        }
                    }
                }
                Err(e) => eprintln!("UDP error: {}", e),
            }
        }
    });

    //TASK ZA BRISANJE DISKONEKTOVANIH IGRACA (u slucaju da se igrac nije sam diskonektovao)
    let state_cleaning = Arc::clone(&lobby_handler);
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(30));
        let timeout = std::time::Duration::from_secs(30);
        loop {
            interval.tick().await;
            let now = std::time::Instant::now();
            let mut handler = state_cleaning.write().await;

            handler.logged_in_users.retain(|id, last_seen| {
                if now.duration_since(*last_seen) > timeout {
                    //println!("CLEANER: Igrac {} izbacen zbog neaktivnosti.", id);
                    false
                } else {
                    true
                }
            });
        }
    });

    let player_session_handler = Arc::clone(&lobby_handler);
    tokio::spawn(async move {
        //println!("Lobby Manager Task pokrenut.");
        while let Some(cmd) = cmd_rx.recv().await {
            //Zakljucava se samo kada stigne poruka!
            let mut handler = player_session_handler.write().await;

            match cmd {
                LobbyCommand::RegisterMatch {
                    addresses,
                    game_tx,
                    game_cmd_tx,
                } => {
                    for id in addresses {
                        handler
                            .players_sessions
                            .insert(id, (game_tx.clone(), game_cmd_tx.clone()));
                    }
                }
                LobbyCommand::CleanUpMatch { addresses } => {
                    for addr in addresses {
                        handler.players_sessions.remove(&addr);
                    }
                }
            }
        }
    });

    tokio::spawn(async move {
        // println!("Monitor resursa pokrenut.");
        loop {
            let total_sent = TOTAL_SENT_BYTES.swap(0, Ordering::Relaxed); // Uzmi vrednost i resetuj na 0
            let kb_per_second = (total_sent as f64 / 1024.0);
            print!("\rIZLAZNI PODACI: {} KB/s", kb_per_second);
            use std::io::{self, Write};
            io::stdout().flush().unwrap();
            tokio::time::sleep(Duration::from_millis(1000)).await; // Osvezava na svake 2 sekunde
        }
    });

    //println!("Server je aktivan. Pritisni Ctrl+C za gasenje.");
    tokio::signal::ctrl_c().await?;

    //println!("Server se gasi...");
    Ok(())
}
