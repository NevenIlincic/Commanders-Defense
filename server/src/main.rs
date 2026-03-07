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
    }, rest_api::controller::RestController,
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

    let mut lobby_handler: Arc<Mutex<LobbyHandler>> = Arc::new(Mutex::new(LobbyHandler::new(&socket)));
    // {
    //     let mut handler = lobby_handler.lock().await;
    //     handler.create_lobby(2, &socket);
    // }

    let socket_udp = Arc::clone(&socket);
    let handler_udp = Arc::clone(&lobby_handler);

    //REST CONTROLLER za ENDPOINTE!
    let mut rest_controller: RestController = RestController::new(Arc::clone(&lobby_handler));
    rest_controller.run_rest_thread();

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
                            _ => {}
                        }
                    }
                }
                Err(e) => eprintln!("UDP error: {}", e),
            }
        }
    });

    loop {}
    
}
