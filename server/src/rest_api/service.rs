use std::{net::SocketAddr, sync::Arc};

use axum::{
    body::Bytes,
    extract::{ConnectInfo, State},
    http::StatusCode,
    response::IntoResponse,
};
use tokio::sync::Mutex;

use crate::{
    lobby::LobbyHandler,
    network_protocol::{ClientMessage, CreateLobbyRequest, JoinRequest, LobbiesInfo, ServerMessage, StartLobbyRequest},
};

pub struct RestService;

impl RestService {
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

    pub async fn create_lobby(
        State(state): State<Arc<Mutex<LobbyHandler>>>,
        ConnectInfo(addr): ConnectInfo<SocketAddr>,
        body: Bytes,
    ) -> impl IntoResponse {
        let payload: CreateLobbyRequest = match bincode::deserialize(&body) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("Bincode greška: {:?}", e);
                return StatusCode::BAD_REQUEST.into_response();
            }
        };

        let mut player_udp_addr = addr;
        player_udp_addr.set_port(payload.udp_port);

        let mut lobby_handler = state.lock().await;
        let (created_lobby_id, player_host_id): (u32, u32) =
            lobby_handler.create_lobby(2, player_udp_addr, payload.nickname);

        let response_bytes =
            match bincode::serialize(&ServerMessage::CreatedLobbyResponse(created_lobby_id, player_host_id)) {
                Ok(bytes) => bytes,
                Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
            };

        (StatusCode::OK, response_bytes).into_response()
    }

    pub async fn get_lobbies_list(
        State(state): State<Arc<Mutex<LobbyHandler>>>,
    ) -> impl IntoResponse {
        let lobby_handler = state.lock().await;
        let response_bytes = match bincode::serialize(&ServerMessage::LobbiesList(
            LobbiesInfo::new(&lobby_handler),
        )) {
            Ok(bytes) => bytes,
            Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        };

        (StatusCode::OK, response_bytes).into_response()
    }

    pub async fn start_lobby(
        State(state): State<Arc<Mutex<LobbyHandler>>>,
        body: Bytes,
    ) -> impl IntoResponse {
        let payload: ClientMessage = match bincode::deserialize(&body) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("Bincode greška: {:?}", e);
                return StatusCode::BAD_REQUEST.into_response();
            }
        };

        let start_request: StartLobbyRequest = if let ClientMessage::LobbyStart(request) = payload {
            request
        }else{
            return StatusCode::BAD_REQUEST.into_response();
        };
        let mut lobby_handler = state.lock().await;
        lobby_handler.start_lobby(start_request.lobby_id, start_request.player_id);
        let response_bytes = match bincode::serialize(&ServerMessage::LobbiesList(
            LobbiesInfo::new(&lobby_handler),
        )) {
            Ok(bytes) => bytes,
            Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        };

        (StatusCode::OK, response_bytes).into_response()
    }
}
