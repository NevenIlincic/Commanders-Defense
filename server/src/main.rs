mod entities;
mod game_physics;
mod groups;
mod level_loader;
mod lobby;
mod network_protocol;
mod rest_api;

use crate::{
    level_loader::LevelLoader,
    lobby::LobbyHandler,
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
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::{net::UdpSocket, sync::mpsc::error::TrySendError, time::interval};

use dotenvy::dotenv;
use game_physics::GameStateModel;
use sqlx::postgres::PgPoolOptions; // Dodaj ovo na vrh
use std::env;
use tokio::{
    sync::Mutex,
    sync::MutexGuard,
    time::{Duration, sleep},
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();

    let database_url =
        env::var("DATABASE_URL").expect("DATABASE_URL mora biti postavljen u .env fajlu");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;

    println!("Uspešno povezan na bazu podataka!");

    let socket: Arc<UdpSocket> = Arc::new(UdpSocket::bind("0.0.0.0:8080").await?);
    println!("Server pokrenut na 8080!");

    let mut lobby_handler: Arc<Mutex<LobbyHandler>> =
        Arc::new(Mutex::new(LobbyHandler::new(&socket)));
    // {
    //     let mut handler = lobby_handler.lock().await;
    //     handler.create_lobby(2, &socket);
    // }

    let socket_udp = Arc::clone(&socket);
    let handler_udp = Arc::clone(&lobby_handler);

    //REST CONTROLLER za ENDPOINTE!
    let mut rest_controller: RestController = RestController::new(Arc::clone(&lobby_handler), pool);
    rest_controller.run_rest_thread();

    //TASK ZA SLUSANJE UDP KANALA
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
                                    if let Err(e) = tx.0.try_send((addr, input)) {
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

        loop {
            interval.tick().await;
            let mut handler = state_cleaning.lock().await;
            let sada = std::time::Instant::now();
            let timeout = std::time::Duration::from_secs(60);

            handler.logged_in_users.retain(|id, last_seen| {
                if sada.duration_since(*last_seen) > timeout {
                    println!("CLEANER: Igrač {} izbačen zbog neaktivnosti.", id);
                    false
                } else {
                    true
                }
            });
        }
    });
    loop {}
}
