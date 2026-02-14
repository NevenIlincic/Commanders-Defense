mod entities;
mod game_physics;
mod network_protocol;

use crate::network_protocol::ClientInput;

use std::sync::Arc;
use std::net::SocketAddr;
use tokio::{net::UdpSocket, time::interval};

use tokio::{sync::Mutex, time::{Duration, sleep}, sync::MutexGuard};
use game_physics::{GameStateModel};

#[tokio::main]
async fn main() -> std::io::Result<()>{
    let game_state: Arc<Mutex<GameStateModel>> = Arc::new(Mutex::new(GameStateModel::new()));
    let socket: Arc<UdpSocket> = Arc::new(UdpSocket::bind("0.0.0.0:8080").await?);
    println!("Server pokrenut na 8080!");

    let game_state_udp: Arc<Mutex<GameStateModel>> = Arc::clone(&game_state);
    let socket_udp: Arc<UdpSocket> = Arc::clone(&socket);

    tokio::spawn(async move { // Nit za dobijanje paketa iz Godota
        let mut buf: [u8; 1024] = [0u8; 1024];
        loop {
            match socket_udp.recv_from(&mut buf).await {
                Ok((size, addr)) => { // Obrada UDP paketa
                    let data = &buf[..size];
                    match serde_json::from_slice::<ClientInput>(data) { // Deserializacija JSON objekta
                        Ok(input) => {
                            println!("{:?}", input);
                            let mut state: MutexGuard<'_, GameStateModel> = game_state_udp.lock().await;
                            state.handle_client_input(input, addr);
                            
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
    loop { //Game loop
        game_frames.tick().await;

        //let mut state: MutexGuard<'_, GameStateModel> = game_state.lock().await;
        // state.update();

    }
}
