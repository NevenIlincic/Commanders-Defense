use std::{net::SocketAddr, sync::Arc};

use axum::{
    body::{Body, Bytes},
    extract::{
        ConnectInfo, State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    http::{Response, StatusCode},
    response::IntoResponse,
    serve::Serve,
};
use futures_util::{SinkExt, StreamExt};
use tokio::sync::{Mutex, mpsc};

use crate::{
    entities::Player,
    lobby::{self, GameModeSettings, Lobby, LobbyHandler, LobbyPlayer},
    network_protocol::{
        ClientMessage, CreateLobbyRequest, GameEnd, JoinRequest, LobbiesInfo, LobbyRoomInfo,
        PlayerSkin, ServerMessage, StartLobbyRequest,
    },
};

pub struct RestService;

impl RestService {
    pub fn get_lobby_info_bytes(lobby: &Lobby) -> Result<Vec<u8>, Response<Body>> {
        let response_bytes =
            bincode::serialize(&ServerMessage::LobbyInfo(LobbyRoomInfo::new(&lobby)))
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response());
        response_bytes
    }

    pub fn get_game_winner_id(winner_id: u32) -> Result<Vec<u8>, StatusCode> {
        let response_bytes = bincode::serialize(&ServerMessage::GameEnd(GameEnd::new(winner_id)))
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
        response_bytes
    }

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
        // println!("AADDRESSA : {}", addr);
        player_udp_addr.set_port(payload.udp_port);

        // println!("{}", player_udp_addr);

        let mut lobby_handler: tokio::sync::MutexGuard<'_, LobbyHandler> = state.lock().await;
        match lobby_handler.add_player_to_lobby(payload.lobby_id, player_udp_addr, payload.nickname, payload.lobby_password)
        {
            Some(player_id) => {
                let Some(lobby) = lobby_handler.lobbies.get(&payload.lobby_id) else {
                    return StatusCode::NOT_FOUND.into_response();
                };
                let Some(joined_player) = lobby.players_id_map.get(&player_id) else {
                    return StatusCode::NOT_FOUND.into_response();
                };

                let server_message =
                    ServerMessage::PlayerConnected(player_id, joined_player.nickname.clone());
                let bytes = bincode::serialize(&server_message).ok().unwrap();

                let update_msg = Message::Binary(bytes);

                for player_id_to_send in lobby.players_id_map.keys() {
                    if player_id == *player_id_to_send {
                        continue;
                    }
                    if let Some(ws_tx) = lobby_handler.websocket_sessions.get(&player_id_to_send) {
                        let _ = ws_tx.send(update_msg.clone());
                    }
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
        let (created_lobby_id, player_host_id): (u32, u32) = lobby_handler.create_lobby(
            10,
            player_udp_addr,
            payload.nickname,
            payload.game_mode_number,
            payload.lobby_password
        );

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

    pub async fn start_lobby(state: Arc<Mutex<LobbyHandler>>, start_request: StartLobbyRequest) {
        let mut lobby_handler = state.lock().await;
        let players_id: Vec<u32> =
            if let Some(lobby) = lobby_handler.lobbies.get(&start_request.lobby_id) {
                if let Some(player) = lobby.players_id_map.get(&start_request.player_id) {
                    if !player.is_host {
                        return;
                    }
                }
                if matches!(lobby.game_mode, GameModeSettings::TOWERS(..)) {
                    if lobby.players.len() < 2 {
                        return;
                    }
                }

                for player in lobby.players_id_map.values() {
                    if !player.is_ready {
                        return;
                    }
                }
                let players_id: Vec<u32> = lobby.players_id_map.keys().cloned().collect();
                players_id
            } else {
                return;
            };
        lobby_handler.start_lobby(
            state.clone(),
            start_request.lobby_id,
            start_request.player_id,
        );
        let bytes = bincode::serialize(&ServerMessage::GameStarted(true)).unwrap();
        let update_msg = Message::Binary(bytes);

        for player_id in players_id {
            if let Some(ws_tx) = lobby_handler.websocket_sessions.get(&player_id) {
                let _ = ws_tx.send(update_msg.clone());
            }
        }
    }

    pub async fn leave_lobby(
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

        let ClientMessage::LobbyLeave(lobby_id, player_id) = payload else {
            return StatusCode::BAD_REQUEST.into_response();
        };
        let mut lobby_handler = state.lock().await;
        let Some(lobby) = lobby_handler.lobbies.get_mut(&lobby_id) else {
            return StatusCode::BAD_REQUEST.into_response();
        };

        let mut lobby_host_id: u32 = {
            let Some(lobby_host) = lobby.players.get(&lobby.host_addr) else {
                return StatusCode::NOT_FOUND.into_response();
            };
            lobby_host.player_id
        };

        let Some(disconnected_player) = lobby.players_id_map.remove(&player_id) else {
            return StatusCode::BAD_REQUEST.into_response();
        };
        let disconnected_player_address = disconnected_player.addr;
        lobby.players.remove(&disconnected_player_address);

        let is_lobby_empty = lobby.players.is_empty();

        if !is_lobby_empty && lobby.host_addr == disconnected_player_address {
            if let Some(new_host) = lobby.players_id_map.values_mut().next() {
                lobby.host_addr = new_host.addr;
                new_host.is_host = true;
                lobby_host_id = new_host.player_id;
            }
        }

        if lobby.is_started && lobby.players_id_map.len() == 1 {
            if let Some(winner) = lobby.players_id_map.values().next() {
                lobby.winner_id = winner.player_id;
            }
        }

        let num_left_players = lobby.players_id_map.len();
        let is_game_finished = num_left_players <= 1;

        let server_message = ServerMessage::PlayerDisconnected(player_id, lobby_host_id);
        let Some(response_bytes) = bincode::serialize(&server_message).ok() else {
            return StatusCode::BAD_REQUEST.into_response();
        };
        let update_msg = Message::Binary(response_bytes.clone());
        let players_to_get_message: Vec<u32> = lobby.players_id_map.keys().cloned().collect();

        for player_id in players_to_get_message {
            if let Some(ws_tx) = lobby_handler.websocket_sessions.get(&player_id) {
                let _ = ws_tx.send(update_msg.clone());
            }
        }

        if num_left_players == 0 {
            lobby_handler.lobbies.remove(&lobby_id);
        }

        if let Some(tx) = lobby_handler
            .players_sessions
            .get(&disconnected_player_address)
        {
            if let Err(e) = tx.1.try_send(disconnected_player_address) {
                println!("GRESSKA!");
            }
        }
        return (StatusCode::OK).into_response();
    }

    pub fn leave_lobby_body(
        lobby_handler: &mut LobbyHandler,
        lobby_id: u32,
        player_id: u32,
    ) -> Option<bool> {
        let lobby = lobby_handler.lobbies.get_mut(&lobby_id)?;

        let mut lobby_host_id: u32 = {
            let Some(lobby_host) = lobby.players.get(&lobby.host_addr) else {
                return None;
            };
            lobby_host.player_id
        };

        let disconnected_player = lobby.players_id_map.remove(&player_id)?;
        let disconnected_player_address = disconnected_player.addr;
        lobby.players.remove(&disconnected_player_address);

        let is_lobby_empty = lobby.players.is_empty();

        if !is_lobby_empty && lobby.host_addr == disconnected_player_address {
            if let Some(new_host) = lobby.players_id_map.values_mut().next() {
                lobby.host_addr = new_host.addr;
                new_host.is_host = true;
                lobby_host_id = new_host.player_id;
            }
        }

        if lobby.is_started && lobby.players_id_map.len() == 1 {
            if let Some(winner) = lobby.players_id_map.values().next() {
                lobby.winner_id = winner.player_id;
            }
        }

        let num_left_players = lobby.players_id_map.len();
        let is_game_finished = num_left_players <= 1;

        let server_message = ServerMessage::PlayerDisconnected(player_id, lobby_host_id);
        let response_bytes = bincode::serialize(&server_message).ok()?;
        let update_msg = Message::Binary(response_bytes.clone());
        let players_to_get_message: Vec<u32> = lobby.players_id_map.keys().cloned().collect();

        for player_id in players_to_get_message {
            if let Some(ws_tx) = lobby_handler.websocket_sessions.get(&player_id) {
                let _ = ws_tx.send(update_msg.clone());
            }
        }

        if num_left_players == 0 {
            lobby_handler.lobbies.remove(&lobby_id);
        }

        if let Some(tx) = lobby_handler
            .players_sessions
            .get(&disconnected_player_address)
        {
            if let Err(e) = tx.1.try_send(disconnected_player_address) {
                println!("GRESSKA")
                // match e {
                //     TrySendError::Closed(_) => {
                //         handler.players_sessions.remove(&addr);
                //         println!("Sesija ugašena za {:?} - lobi task je završen.", addr);
                //     }
                //     TrySendError::Full(_) => {
                //         eprintln!("Lobi kanal je pun, paket od {:?} je preskočen.", addr);
                //     }
                // }
            }
        }

        Some((is_game_finished))
    }

    async fn change_is_player_ready(
        state: Arc<Mutex<LobbyHandler>>,
        lobby_id: u32,
        player_id: u32,
    ) {
        let mut lobby_handler = state.lock().await;
        let players_id = {
            let Some(lobby) = lobby_handler.lobbies.get_mut(&lobby_id) else {
                return;
            };

            let Some(player) = lobby.players_id_map.get_mut(&player_id) else {
                return;
            };

            player.is_ready = !player.is_ready;
            let players_id: Vec<_> = lobby.players_id_map.keys().cloned().collect();

            players_id
        };

        let server_message = ServerMessage::PlayerChangedReadyState(player_id);
        let bytes = bincode::serialize(&server_message).ok().unwrap();

        let update_msg = Message::Binary(bytes.clone());
        for player_id in players_id {
            if let Some(ws_tx) = lobby_handler.websocket_sessions.get(&player_id) {
                let _ = ws_tx.send(update_msg.clone());
            }
        }
    }

    async fn change_player_skin(
        state: Arc<Mutex<LobbyHandler>>,
        lobby_id: u32,
        player_id: u32,
        new_skin: PlayerSkin,
    ) {
        let mut lobby_handler = state.lock().await;

        let Some(lobby) = lobby_handler.lobbies.get_mut(&lobby_id) else {
            return;
        };

        let Some(player) = lobby.players_id_map.get_mut(&player_id) else {
            return;
        };
        for p in lobby.players.values_mut() {
            if p.player_id == player.player_id {
                p.selected_skin = new_skin.clone();
            }
        }
        player.selected_skin = new_skin;

        let server_message =
            ServerMessage::PlayerChangedSkin(player_id, player.selected_skin.clone());
        let bytes = bincode::serialize(&server_message).ok().unwrap();

        let player_ids: Vec<_> = lobby.players_id_map.keys().cloned().collect();

        let update_msg = Message::Binary(bytes);

        for player_id in player_ids {
            if let Some(ws_tx) = lobby_handler.websocket_sessions.get(&player_id) {
                let _ = ws_tx.send(update_msg.clone());
            }
        }
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

    async fn change_tower_max_hp(
        state: Arc<Mutex<LobbyHandler>>,
        lobby_id: u32,
        tower_max_hp: u32,
    ) {
        let mut lobby_handler = state.lock().await;

        let players_id: Vec<u32> = {
            let Some(found_lobby) = lobby_handler.lobbies.get_mut(&lobby_id) else {
                return;
            };
            if let GameModeSettings::TOWERS(lobby_settings) = &mut found_lobby.game_mode {
                lobby_settings.towers_max_hp = tower_max_hp as i32;
            }
            let players_id: Vec<_> = found_lobby.players_id_map.keys().cloned().collect();

            players_id
        };
        let server_message = ServerMessage::TowerMaxHPChanged(tower_max_hp);
        let bytes = bincode::serialize(&server_message).ok().unwrap();

        let update_msg = Message::Binary(bytes);
        for player_id in players_id {
            if let Some(ws_tx) = lobby_handler.websocket_sessions.get(&player_id) {
                let _ = ws_tx.send(update_msg.clone());
            }
        }
    }

    async fn send_player_message(
        state: Arc<Mutex<LobbyHandler>>,
        lobby_id: u32,
        player_id: u32,
        player_message: String,
    ) {
        let mut lobby_handler = state.lock().await;

        let players_id: Vec<u32> = {
            let Some(found_lobby) = lobby_handler.lobbies.get_mut(&lobby_id) else {
                return;
            };
            let players_id: Vec<_> = found_lobby.players_id_map.keys().cloned().collect();
            players_id
        };

        let server_message = ServerMessage::PlayerMessage(player_id, player_message);
        let bytes = bincode::serialize(&server_message).ok().unwrap();

        let update_msg = Message::Binary(bytes);
        for player_id_to_send in players_id {
            if player_id == player_id_to_send {
                continue;
            }
            if let Some(ws_tx) = lobby_handler.websocket_sessions.get(&player_id_to_send) {
                let _ = ws_tx.send(update_msg.clone());
            }
        }
    }

    pub async fn ws_handler(
        ws: WebSocketUpgrade,
        State(state): State<Arc<Mutex<LobbyHandler>>>,
        ConnectInfo(addr): ConnectInfo<SocketAddr>,
    ) -> impl IntoResponse {
        println!("Novi pokušaj WebSocket povezivanja sa adrese: {}", addr);
        ws.on_upgrade(move |socket| Self::handle_ws_session(socket, state, addr))
    }

    async fn handle_ws_session(
        socket: WebSocket,
        state: Arc<Mutex<LobbyHandler>>,
        addr: SocketAddr,
    ) {
        let mut current_player_id: Option<u32> = None;
        let (mut sender, mut receiver) = socket.split();
        let (tx, mut rx) = mpsc::unbounded_channel::<Message>();
        {
            let mut handler = state.lock().await;
            let id: u32 = handler.next_player_id - 1;
            handler.websocket_sessions.insert(id, tx);
            current_player_id = Some(handler.next_player_id - 1);
        }

        let mut send_task = tokio::spawn(async move {
            while let Some(msg) = rx.recv().await {
                if sender.send(msg).await.is_err() {
                    break;
                }
            }
        });

        //ODGOVOR SA KLIJENTA
        while let Some(Ok(msg)) = receiver.next().await {
            if let Message::Binary(bin_data) = msg {
                if let Ok(payload) = bincode::deserialize::<ClientMessage>(&bin_data) {
                    match payload {
                        ClientMessage::ChangePlayerBodySkin(l_id, p_id, skin) => {
                            Self::change_player_skin(state.clone(), l_id, p_id, skin).await;
                        }
                        ClientMessage::PlayerReady(lobby_id, player_id) => {
                            Self::change_is_player_ready(state.clone(), lobby_id, player_id).await;
                        }
                        ClientMessage::ChangeTowerMaxHP(lobby_id, tower_max_hp) => {
                            Self::change_tower_max_hp(state.clone(), lobby_id, tower_max_hp).await;
                        }
                        ClientMessage::LobbyStart(request) => {
                            Self::start_lobby(state.clone(), request).await;
                        }
                        ClientMessage::PlayerMessage(lobby_id, player_id, player_message) => {
                            Self::send_player_message(
                                state.clone(),
                                lobby_id,
                                player_id,
                                player_message,
                            )
                            .await;
                        }
                        _ => println!("Druga poruka..."),
                    }
                }
            }
        }

        send_task.abort();
        if let Some(player_id) = current_player_id {
            println!("Čišćenje podataka za igrača: {}", player_id);
            let mut handler = state.lock().await;

            let lobby_id: Option<u32> = 'search: {
                for lobby in handler.lobbies.values() {
                    for player in lobby.players_id_map.keys() {
                        if *player == player_id {
                            break 'search Some(lobby.id);
                        }
                    }
                }
                None
            };
            if let Some(found_lobby_id) = lobby_id {
                Self::leave_lobby_body(&mut handler, found_lobby_id, player_id);
            }
        }

        println!("Igrač se diskonektovao: {}", addr);
    }
}
