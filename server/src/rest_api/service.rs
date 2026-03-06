use std::{net::SocketAddr, sync::Arc};

use axum::{body::Bytes, extract::{ConnectInfo, State}, http::StatusCode, response::IntoResponse};
use tokio::sync::Mutex;

use crate::{lobby::LobbyHandler, network_protocol::JoinRequest};

pub struct RestService;

impl RestService{
    pub async fn handle_lobby_join(
        State(state): State<Arc<Mutex<LobbyHandler>>>,
        ConnectInfo(addr): ConnectInfo<SocketAddr>,
        body: Bytes,
    ) -> impl IntoResponse {
        let payload: JoinRequest = match bincode::deserialize(&body) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("Bincode greška: {:?}", e);
                return StatusCode::BAD_REQUEST.into_response();
            }
        };

        let mut player_udp_addr = addr;
        player_udp_addr.set_port(payload.udp_port);

        println!("{}", player_udp_addr);

        let mut h = state.lock().await;
        match h.add_player_to_lobby(payload.lobby_id, player_udp_addr, payload.nickname) {
            Some(player_id) => {
                let resp = bincode::serialize(&player_id).unwrap();
                (StatusCode::OK, resp).into_response()
            }
            None => StatusCode::BAD_REQUEST.into_response(),
        }
    }
}