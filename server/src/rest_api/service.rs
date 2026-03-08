use std::{net::SocketAddr, sync::Arc};

use axum::{
    body::{Body, Bytes},
    extract::{ConnectInfo, State},
    http::{Response, StatusCode},
    response::IntoResponse,
};
use tokio::sync::Mutex;

use crate::{
    lobby::{Lobby, LobbyHandler},
    network_protocol::{
        ClientMessage, CreateLobbyRequest, JoinRequest, LobbiesInfo, LobbyRoomInfo, ServerMessage,
        StartLobbyRequest,
    },
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

        let mut lobby_handler: tokio::sync::MutexGuard<'_, LobbyHandler> = state.lock().await;
        match lobby_handler.add_player_to_lobby(payload.lobby_id, player_udp_addr, payload.nickname)
        {
            Some(player_id) => {
                let Some(lobby) = lobby_handler.lobbies.get(&payload.lobby_id) else {
                    return StatusCode::NOT_FOUND.into_response();
                };

                for player_address in lobby.players.keys() {
                    let response_bytes = RestService::get_lobby_info_bytes(lobby).unwrap();
                    let _ = lobby_handler
                        .socket
                        .send_to(&response_bytes, player_address)
                        .await;
                }
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

        let response_bytes = match bincode::serialize(&ServerMessage::CreatedLobbyResponse(
            created_lobby_id,
            player_host_id,
        )) {
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
        } else {
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

        if let Some(started_lobby) = lobby_handler.lobbies.get(&start_request.lobby_id) {
            for player_address in started_lobby.players.keys() {
                let bytes = bincode::serialize(&ServerMessage::GameStarted(true)).unwrap();
                let _ = lobby_handler.socket.send_to(&bytes, player_address).await;
            }
        }

        (StatusCode::OK, response_bytes).into_response()
    }

    pub async fn change_is_player_ready(
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

        let ClientMessage::PlayerReady(found_lobby_id, found_player_id) = payload else {
            return StatusCode::NOT_FOUND.into_response();
        };

        let mut lobby_handler = state.lock().await;
        if let Some(lobby) = lobby_handler.lobbies.get_mut(&found_lobby_id) {
            if let Some(player) = lobby.players_id_map.get_mut(&found_player_id) {
                player.is_ready = !player.is_ready;
            }
        } else {
            return StatusCode::NOT_FOUND.into_response();
        };

        let Some(lobby) = lobby_handler.lobbies.get(&found_lobby_id) else {
            return StatusCode::NOT_FOUND.into_response();
        };

        for player_address in lobby.players.keys() {
            let response_bytes = RestService::get_lobby_info_bytes(lobby).unwrap();
            let _ = lobby_handler
                .socket
                .send_to(&response_bytes, player_address)
                .await;
        }

        let response_bytes = RestService::get_lobby_info_bytes(lobby);
        (StatusCode::OK, response_bytes).into_response()
    }

    pub async fn get_current_lobby_info(
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

        let ClientMessage::GetLobbyInfo(lobby_id) = payload else {
            return StatusCode::NOT_FOUND.into_response();
        };

        let mut lobby_handler = state.lock().await;
        let Some(lobby) = lobby_handler.lobbies.get(&lobby_id) else {
            return StatusCode::NOT_FOUND.into_response();
        };

        let response_bytes = RestService::get_lobby_info_bytes(lobby);

        (StatusCode::OK, response_bytes).into_response()
    }

    fn get_lobby_info_bytes(lobby: &Lobby) -> Result<Vec<u8>, Response<Body>> {
        let response_bytes =
            bincode::serialize(&ServerMessage::LobbyInfo(LobbyRoomInfo::new(&lobby)))
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response());
        response_bytes
    }
}
