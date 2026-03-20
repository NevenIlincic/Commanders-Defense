use core::num;
use std::{net::SocketAddr, sync::Arc, time::Instant};

use axum::{
    body::{Body, Bytes},
    extract::{
        ConnectInfo, State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    http::{HeaderMap, Response, StatusCode},
    response::IntoResponse,
    serve::Serve,
};
use bcrypt::{DEFAULT_COST, hash, verify};
use futures_util::{SinkExt, StreamExt, lock};
use std::collections::HashMap;
use tokio::sync::{Mutex, mpsc};

use crate::{
    entities::Player,
    lobby::{self, GameModeSettings, Lobby, LobbyCommand, LobbyHandler, LobbyPlayer},
    network_protocol::{
        ClientMessage, CreateLobbyRequest, GameEnd, JoinRequest, LobbiesInfo, LobbyMenuInfo,
        LobbyRoomInfo, PlayerSkin, ServerMessage, StartLobbyRequest,
    },
    rest_api::{
        controller::AppState,
        jwt_handler::{Claims, JWTHandler},
    },
};

pub struct RestService;

impl RestService {
    pub async fn register(State(state): State<AppState>, body: Bytes) -> impl IntoResponse {
        let payload: ClientMessage = match bincode::deserialize(&body) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("Bincode greška: {:?}", e);
                return StatusCode::BAD_REQUEST.into_response();
            }
        };

        let ClientMessage::RegistrationData(nickname, password) = payload else {
            return StatusCode::BAD_REQUEST.into_response();
        };

        let hashed_password = match hash(&password, DEFAULT_COST) {
            Ok(h) => h,
            Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        };

        let result = sqlx::query!(
            "INSERT INTO players (nickname, password) VALUES ($1, $2) RETURNING id, nickname",
            nickname,
            hashed_password
        )
        .fetch_one(&state.connection_pool)
        .await;

        match result {
            Ok(record) => {
                println!("Igrač {} registrovan sa ID: {}", record.nickname, record.id);
                {
                    let mut handler = state.lobby_handler.lock().await;
                    handler
                        .logged_in_users
                        .insert(record.id as u32, Instant::now());
                }
                let token: String =
                    JWTHandler::create_jwt(record.id as u32, record.nickname.clone());
                let response =
                    ServerMessage::AuthenticationResponse(record.id as u32, record.nickname, token);
                let response_bytes = bincode::serialize(&response).unwrap();
                (StatusCode::CREATED, response_bytes).into_response()
            }
            Err(e) => {
                if e.to_string().contains("unique constraint") {
                    return (StatusCode::CONFLICT, "Nadimak je zauzet").into_response();
                }
                StatusCode::INTERNAL_SERVER_ERROR.into_response()
            }
        }
    }

    pub async fn login(State(state): State<AppState>, body: Bytes) -> impl IntoResponse {
        let payload: ClientMessage = match bincode::deserialize(&body) {
            Ok(p) => p,
            Err(_) => return StatusCode::BAD_REQUEST.into_response(),
        };

        let ClientMessage::LoginData(nickname, password) = payload else {
            return StatusCode::BAD_REQUEST.into_response();
        };

        let result = sqlx::query!(
            "SELECT id, password FROM players WHERE nickname = $1",
            nickname
        )
        .fetch_optional(&state.connection_pool)
        .await;

        match result {
            Ok(Some(record)) => {
                let is_valid = verify(&password, &record.password).unwrap_or(false);

                if is_valid {
                    {
                        let mut handler = state.lobby_handler.lock().await;
                        let player_id: &u32 = &(record.id as u32);
                        if handler.logged_in_users.contains_key(player_id) {
                            return StatusCode::CONFLICT.into_response();
                        } else {
                            handler.logged_in_users.insert(*player_id, Instant::now());
                        }
                    }
                    println!("Igrač {} se uspešno ulogovao.", nickname);

                    let token: String = JWTHandler::create_jwt(record.id as u32, nickname.clone());
                    let response =
                        ServerMessage::AuthenticationResponse(record.id as u32, nickname, token);
                    let response_bytes = bincode::serialize(&response).unwrap();
                    (StatusCode::OK, response_bytes).into_response()
                } else {
                    (
                        StatusCode::UNAUTHORIZED,
                        "Pogrešno korisničko ime ili lozinka",
                    )
                        .into_response()
                }
            }
            Ok(None) => (
                StatusCode::UNAUTHORIZED,
                "Pogrešno korisničko ime ili lozinka",
            )
                .into_response(),
            Err(e) => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        }
    }

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
        State(state): State<AppState>,
        ConnectInfo(addr): ConnectInfo<SocketAddr>,
        user: Claims,
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

        let lobby_arc = {
            let lobby_handler: tokio::sync::MutexGuard<'_, LobbyHandler> =
                state.lobby_handler.lock().await;
            lobby_handler.lobbies.get(&payload.lobby_id).cloned()
        };
        let Some(lobby_arc) = lobby_arc else {
            return StatusCode::BAD_REQUEST.into_response();
        };
        {
            let mut lobby = lobby_arc.lock().await;
            if let Err(e) = lobby.add_player(
                user.id,
                player_udp_addr,
                user.nickname.clone(),
                payload.lobby_password,
            ) {
                return (StatusCode::FORBIDDEN, e).into_response();
            }

            let server_message = ServerMessage::PlayerConnected(user.id, user.nickname);
            let bytes = bincode::serialize(&server_message).ok().unwrap();

            let update_msg = Message::Binary(bytes);

            for (&player_id_to_send, ws_tx) in &lobby.websocket_sessions {
                if player_id_to_send == user.id {
                    continue;
                }
                let _ = ws_tx.send(update_msg.clone());
            }
        }
        (StatusCode::OK).into_response()
    }

    pub async fn handle_started_lobby_join(
        State(state): State<AppState>,
        user: Claims,
        body: Bytes,
    ) -> impl IntoResponse {
        let payload: ClientMessage = match bincode::deserialize(&body) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("Bincode greška: {:?}", e);
                return StatusCode::BAD_REQUEST.into_response();
            }
        };

        let ClientMessage::JoinStartedLobby(lobby_id) = payload else {
            return StatusCode::BAD_REQUEST.into_response();
        };

        let lobby_arc = {
            let mut lobby_handler: tokio::sync::MutexGuard<'_, LobbyHandler> =
                state.lobby_handler.lock().await;
            lobby_handler.lobbies.get(&lobby_id).cloned()
        };
        let Some(lobby_arc) = lobby_arc else {
            return StatusCode::BAD_REQUEST.into_response();
        };

        let lobby = lobby_arc.lock().await;

        if let Some(found_player) = lobby.players_id_map.get(&user.id) {
            let (id, nickname, player_skin_index) = (
                found_player.0.player_id,
                found_player.0.nickname.clone(),
                found_player.0.selected_skin,
            );
            let tx_channel = found_player.1.clone();
            if let Err(e) = tx_channel.send((id, nickname, player_skin_index)) {
                eprintln!("Error sending started_lobby_join command: {}", e);
            }
            return StatusCode::OK.into_response();
        } else {
            return StatusCode::NOT_FOUND.into_response();
        }
    }

    pub async fn create_lobby(
        State(state): State<AppState>,
        ConnectInfo(addr): ConnectInfo<SocketAddr>,
        user: Claims,
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
        let (created_lobby_id, player_host_id): (u32, u32) = {
            let mut lobby_handler = state.lobby_handler.lock().await;
            let (lobby_id, player_host_id): (u32, u32) = {
                lobby_handler
                    .create_lobby(
                        user.id,
                        payload.max_players,
                        player_udp_addr,
                        payload.nickname,
                        payload.game_mode_number,
                        payload.lobby_password,
                    )
                    .await
            };
            (lobby_id, player_host_id)
        };
        let response_bytes = match bincode::serialize(&ServerMessage::CreatedLobbyResponse(
            created_lobby_id,
            player_host_id,
        )) {
            Ok(bytes) => bytes,
            Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        };

        (StatusCode::OK, response_bytes).into_response()
    }

    pub async fn get_lobbies_list(State(state): State<AppState>) -> impl IntoResponse {
        let (lobby_arcs, num_logged_in_users) = {
            let lobby_handler = state.lobby_handler.lock().await;
            let lobbies_arcs: Vec<_> = lobby_handler.lobbies.values().cloned().collect();
            let num_logged_in_users = lobby_handler.logged_in_users.len() as u32;
            (lobbies_arcs, num_logged_in_users)
        };

        let mut lobbies_menu_info_list: Vec<LobbyMenuInfo> = Vec::with_capacity(lobby_arcs.len());
        for arc in lobby_arcs {
            let lobby = arc.lock().await;
            if let Some(info) = LobbyMenuInfo::new(&lobby) {
                lobbies_menu_info_list.push(info);
            }
        }

        let lobbies_info: LobbiesInfo =
            LobbiesInfo::new(lobbies_menu_info_list, num_logged_in_users);

        let response_bytes = match bincode::serialize(&ServerMessage::LobbiesList(lobbies_info)) {
            Ok(bytes) => bytes,
            Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        };

        (StatusCode::OK, response_bytes).into_response()
    }

    pub async fn start_lobby(
        lobby_arc: Arc<Mutex<Lobby>>,
        lobby_id: u32,
        player_id: u32,
        lobby_handler_tx: mpsc::UnboundedSender<LobbyCommand>,
    ) {
        {
            let mut lobby = lobby_arc.lock().await;

            if let Some(player) = lobby.players_id_map.get(&player_id) {
                if !player.0.is_host {
                    return;
                }
            }
            if matches!(lobby.game_mode, GameModeSettings::TOWERS(..)) {
                if lobby.players.len() < 2 {
                    return;
                }
            }

            for player in lobby.players_id_map.values() {
                if !player.0.is_ready {
                    return;
                }
            }
            lobby
                .start_lobby(lobby_arc.clone(), lobby_id, player_id, lobby_handler_tx)
                .await;
        }

        let bytes = bincode::serialize(&ServerMessage::GameStarted(true)).unwrap();
        let update_msg = Message::Binary(bytes);

        {
            let lobby = lobby_arc.lock().await;
            for ws_tx in lobby.websocket_sessions.values() {
                let _ = ws_tx.send(update_msg.clone());
            }
        }
    }

    pub async fn leave_lobby(
        State(state): State<AppState>,
        user: Claims,
        body: Bytes,
    ) -> impl IntoResponse {
        let payload: ClientMessage = match bincode::deserialize(&body) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("Bincode greška: {:?}", e);
                return StatusCode::BAD_REQUEST.into_response();
            }
        };

        let ClientMessage::LobbyLeave(lobby_id) = payload else {
            return StatusCode::BAD_REQUEST.into_response();
        };

        let lobby_arc = {
            let lobby_handler: tokio::sync::MutexGuard<'_, LobbyHandler> =
                state.lobby_handler.lock().await;
            lobby_handler.lobbies.get(&lobby_id).cloned()
        };
        let Some(lobby_arc) = lobby_arc else {
            return StatusCode::BAD_REQUEST.into_response();
        };

        //BLOK ZA LOBBY
        let (num_players_left, disconnected_player_address) = {
            let mut lobby = lobby_arc.lock().await;

            let mut lobby_host_id: u32 = {
                let Some(lobby_host) = lobby.players.get(&lobby.host_addr) else {
                    return StatusCode::NOT_FOUND.into_response();
                };
                lobby_host.player_id
            };

            let Some(disconnected_player) = lobby.players_id_map.remove(&user.id) else {
                return StatusCode::BAD_REQUEST.into_response();
            };
            let disconnected_player_address = disconnected_player.0.addr;
            lobby.players.remove(&disconnected_player_address);
            lobby.websocket_sessions.remove(&user.id);

            let is_lobby_empty: bool = lobby.players.is_empty();

            if !is_lobby_empty && lobby.host_addr == disconnected_player_address {
                let (new_addr, new_id) = {
                    let new_host = lobby
                        .players_id_map
                        .values_mut()
                        .next()
                        .ok_or(StatusCode::BAD_REQUEST)
                        .unwrap();

                    new_host.0.is_host = true;
                    (new_host.0.addr, new_host.0.player_id)
                };
                lobby.host_addr = new_addr;
                lobby_host_id = new_id;
            }

            if lobby.is_started && lobby.players_id_map.len() == 1 {
                if let Some(winner) = lobby.players_id_map.values().next() {
                    lobby.winner_id = winner.0.player_id;
                }
            }

            let num_players_left = lobby.players_id_map.len();

            let server_message = ServerMessage::PlayerDisconnected(user.id, lobby_host_id);
            let Some(response_bytes) = bincode::serialize(&server_message).ok() else {
                return StatusCode::BAD_REQUEST.into_response();
            };
            let update_msg = Message::Binary(response_bytes.clone());

            for (&player_id_to_send, ws_tx) in &lobby.websocket_sessions {
                let _ = ws_tx.send(update_msg.clone());
            }
            (num_players_left, disconnected_player_address)
        };

        //BLOK ZA LOBBY HANDLER
        {
            let mut lobby_handler = state.lobby_handler.lock().await;
            if num_players_left == 0 {
                lobby_handler.lobbies.remove(&lobby_id);
            }

            if let Some(tx) = lobby_handler
                .players_sessions
                .get(&disconnected_player_address)
            {
                if let Err(e) = tx.1.try_send(disconnected_player_address) {
                    println!("GRESSKA!");
                }
                lobby_handler
                    .players_sessions
                    .remove(&disconnected_player_address);
            }
        }
        return (StatusCode::OK).into_response();
    }

    pub async fn leave_lobby_body(
        lobby_handler: Arc<Mutex<LobbyHandler>>,
        lobby_id: u32,
        player_id: u32,
    ) {
        let lobby_arc = {
            let lobby_handler: tokio::sync::MutexGuard<'_, LobbyHandler> =
                lobby_handler.lock().await;
            lobby_handler.lobbies.get(&lobby_id).cloned()
        };
        let Some(lobby_arc) = lobby_arc else {
            return;
        };

        //BLOK ZA LOBBY
        let (num_players_left, disconnected_player_address) = {
            let mut lobby = lobby_arc.lock().await;

            let mut lobby_host_id: u32 = {
                let Some(lobby_host) = lobby.players.get(&lobby.host_addr) else {
                    return;
                };
                lobby_host.player_id
            };

            let Some(disconnected_player) = lobby.players_id_map.remove(&player_id) else {
                return;
            };
            let disconnected_player_address = disconnected_player.0.addr;
            lobby.players.remove(&disconnected_player_address);

            let is_lobby_empty = lobby.players.is_empty();

            if !is_lobby_empty && lobby.host_addr == disconnected_player_address {
                let (new_addr, new_id) = {
                    let new_host = lobby
                        .players_id_map
                        .values_mut()
                        .next()
                        .ok_or(return)
                        .unwrap();

                    new_host.0.is_host = true;
                    (new_host.0.addr, new_host.0.player_id)
                };
                lobby.host_addr = new_addr;
                lobby_host_id = new_id;
            }

            if lobby.is_started && lobby.players_id_map.len() == 1 {
                if let Some(winner) = lobby.players_id_map.values().next() {
                    lobby.winner_id = winner.0.player_id;
                }
            }

            let num_players_left = lobby.players_id_map.len();

            let server_message = ServerMessage::PlayerDisconnected(player_id, lobby_host_id);
            let response_bytes = bincode::serialize(&server_message).ok().unwrap();
            let update_msg = Message::Binary(response_bytes.clone());

            for (&player_id_to_send, ws_tx) in &lobby.websocket_sessions {
                let _ = ws_tx.send(update_msg.clone());
            }
            (num_players_left, disconnected_player_address)
        };

        {
            let mut lobby_handler = lobby_handler.lock().await;
            if num_players_left == 0 {
                lobby_handler.lobbies.remove(&lobby_id);
            }

            if let Some(tx) = lobby_handler
                .players_sessions
                .get(&disconnected_player_address)
            {
                if let Err(e) = tx.1.try_send(disconnected_player_address) {
                    println!("GRESSKA!");
                }
                lobby_handler
                    .players_sessions
                    .remove(&disconnected_player_address);
            }
        }
    }

    fn change_is_player_ready(lobby: &mut Lobby, lobby_id: u32, player_id: u32) {
        let Some(player) = lobby.players_id_map.get_mut(&player_id) else {
            return;
        };

        player.0.is_ready = !player.0.is_ready;

        let server_message = ServerMessage::PlayerChangedReadyState(player_id);
        let bytes = bincode::serialize(&server_message).ok().unwrap();

        let update_msg = Message::Binary(bytes.clone());
        for (&player_id_to_send, ws_tx) in &lobby.websocket_sessions {
            if player_id_to_send == player_id {
                continue;
            }
            let _ = ws_tx.send(update_msg.clone());
        }
    }

    fn change_player_skin(lobby: &mut Lobby, lobby_id: u32, player_id: u32, new_skin: u8) {
        let Some(player) = lobby.players_id_map.get_mut(&player_id) else {
            return;
        };
        player.0.selected_skin = new_skin;

        let server_message = ServerMessage::PlayerChangedSkin(player_id, player.0.selected_skin);
        let bytes = bincode::serialize(&server_message).ok().unwrap();

        let update_msg = Message::Binary(bytes);

        for (&player_id_to_send, ws_tx) in &lobby.websocket_sessions {
            if player_id_to_send == player_id {
                continue;
            }
            let _ = ws_tx.send(update_msg.clone());
        }
    }

    pub async fn get_current_lobby_info(
        State(state): State<AppState>,
        user: Claims,
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

        let lobby_arc = {
            let lobby_handler: tokio::sync::MutexGuard<'_, LobbyHandler> =
                state.lobby_handler.lock().await;
            lobby_handler.lobbies.get(&lobby_id).cloned()
        };
        let Some(lobby_arc) = lobby_arc else {
            return StatusCode::NOT_FOUND.into_response();
        };

        let response_bytes = {
            let lobby = lobby_arc.lock().await;
            let response_bytes = match RestService::get_lobby_info_bytes(&lobby) {
                Ok(bytes) => bytes,
                Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
            };
            response_bytes
        };

        (StatusCode::OK, response_bytes).into_response()
    }

    fn change_tower_max_hp(lobby: &mut Lobby, lobby_id: u32, tower_max_hp: u32, player_id: u32) {
        if let GameModeSettings::TOWERS(lobby_settings) = &mut lobby.game_mode {
            lobby_settings.towers_max_hp = tower_max_hp as i32;
        }

        let server_message = ServerMessage::TowerMaxHPChanged(tower_max_hp);
        let bytes = bincode::serialize(&server_message).ok().unwrap();

        let update_msg = Message::Binary(bytes);
        for (&player_id_to_send, ws_tx) in &lobby.websocket_sessions {
            if player_id_to_send == player_id {
                continue;
            }
            let _ = ws_tx.send(update_msg.clone());
        }
    }

    fn send_player_message(
        lobby: &mut Lobby,
        lobby_id: u32,
        player_id: u32,
        player_message: String,
    ) {
        let server_message = ServerMessage::PlayerMessage(player_id, player_message);
        let bytes = bincode::serialize(&server_message).ok().unwrap();

        let update_msg = Message::Binary(bytes);
        for (&player_id_to_send, ws_tx) in &lobby.websocket_sessions {
            if player_id_to_send == player_id {
                continue;
            }
            let _ = ws_tx.send(update_msg.clone());
        }
    }

    //FFA
    async fn change_kill_amount_for_win(
        state: Arc<Mutex<LobbyHandler>>,
        lobby_id: u32,
        kill_amount_for_win: u32,
        player_id: u32,
    ) {
        let lobby_arc = {
            let lobby_handler: tokio::sync::MutexGuard<'_, LobbyHandler> = state.lock().await;
            lobby_handler.lobbies.get(&lobby_id).cloned()
        };
        let Some(lobby_arc) = lobby_arc else {
            return;
        };
        let mut lobby = lobby_arc.lock().await;

        if let GameModeSettings::FFA(lobby_settings) = &mut lobby.game_mode {
            lobby_settings.points_to_win = kill_amount_for_win;
        }

        let server_message = ServerMessage::KillsToWinChanged(kill_amount_for_win);
        let bytes = bincode::serialize(&server_message).ok().unwrap();

        let update_msg = Message::Binary(bytes);
        for (&player_id_to_send, ws_tx) in &lobby.websocket_sessions {
            if player_id_to_send == player_id {
                continue;
            }
            let _ = ws_tx.send(update_msg.clone());
        }
    }

    pub async fn handle_player_heartbeat(
        State(state): State<AppState>,
        user: Claims,
    ) -> impl IntoResponse {
        let mut lobby_handler = state.lobby_handler.lock().await;
        lobby_handler
            .logged_in_users
            .insert(user.id, Instant::now());

        StatusCode::OK.into_response()
    }

    pub async fn logout(State(state): State<AppState>, user: Claims) -> impl IntoResponse {
        let mut lobby_handler = state.lobby_handler.lock().await;
        lobby_handler.logged_in_users.remove(&user.id);
        println!(
            "TRENUTNO ULOGOVANIH IGRACA: {}",
            lobby_handler.logged_in_users.len()
        );

        StatusCode::OK.into_response()
    }
    pub async fn ws_handler(
        ws: WebSocketUpgrade,
        headers: HeaderMap,
        State(state): State<AppState>,
        ConnectInfo(addr): ConnectInfo<SocketAddr>,
        user: Claims,
    ) -> impl IntoResponse {
        println!("Novi pokušaj WebSocket povezivanja sa adrese: {}", addr);
        println!("ID: {}", user.id);
        let lobby_id = headers
            .get("x-lobby-id")
            .and_then(|h| h.to_str().ok())
            .and_then(|s| s.parse::<u32>().ok())
            .unwrap_or(0);
        println!("ID LOBIJA: {}", lobby_id);

        ws.on_upgrade(move |socket| Self::handle_ws_session(socket, state, addr, user, lobby_id))
    }

    async fn handle_ws_session(
        socket: WebSocket,
        state: AppState,
        addr: SocketAddr,
        user: Claims,
        lobby_id: u32,
    ) {
        let (mut sender, mut receiver) = socket.split();
        let (tx, mut rx) = mpsc::unbounded_channel::<Message>();

        let (lobby_arc, lobby_handler_tx) = {
            let handler = state.lobby_handler.lock().await;
            (
                handler.lobbies.get(&lobby_id).cloned(),
                handler.cmd_tx.clone(), // Uzimamo sender koji handler čuva
            )
        };

        let Some(lobby_arc) = lobby_arc else {
            return;
        };
        {
            let mut lobby = lobby_arc.lock().await;
            lobby.websocket_sessions.insert(user.id, tx);
        }

        let send_task = tokio::spawn(async move {
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
                        ClientMessage::ChangePlayerBodySkin(l_id, skin) => {
                            let mut lobby = lobby_arc.lock().await;
                            Self::change_player_skin(&mut lobby, l_id, user.id, skin)
                        }
                        ClientMessage::PlayerReady(lobby_id) => {
                            let mut lobby = lobby_arc.lock().await;
                            Self::change_is_player_ready(&mut lobby, lobby_id, user.id)
                        }
                        ClientMessage::ChangeTowerMaxHP(lobby_id, tower_max_hp) => {
                            let mut lobby = lobby_arc.lock().await;
                            Self::change_tower_max_hp(&mut lobby, lobby_id, tower_max_hp, user.id)
                        }
                        ClientMessage::LobbyStart(lobby_id) => {
                            Self::start_lobby(
                                lobby_arc.clone(),
                                lobby_id,
                                user.id,
                                lobby_handler_tx.clone(),
                            )
                            .await;
                        }
                        ClientMessage::PlayerMessage(lobby_id, player_message) => {
                            let mut lobby = lobby_arc.lock().await;
                            Self::send_player_message(&mut lobby, lobby_id, user.id, player_message)
                        }
                        ClientMessage::ChangeKillsToWin(lobby_id, kill_amount) => {
                            Self::change_kill_amount_for_win(
                                state.lobby_handler.clone(),
                                lobby_id,
                                kill_amount,
                                user.id,
                            )
                            .await;
                        }
                        _ => println!("Druga poruka..."),
                    }
                }
            }
        }

        send_task.abort();

        println!("Čišćenje podataka za igrača: {}", user.id);

        {
            let mut lobby = lobby_arc.lock().await;
            lobby.websocket_sessions.remove(&user.id);
        }
        {
            Self::leave_lobby_body(state.lobby_handler.clone(), lobby_id, user.id).await;
        }
        println!("Igrač se diskonektovao: {}", addr);
    }

    pub fn send_scoreboard_update(
        lobby: &mut Lobby,
        player_ids: Vec<u32>,
        scores: &HashMap<u32, u32>,
        lobby_id: u32,
    ) {
        let mut scores_vector: Vec<(u32, u32)> = Vec::new();
        for (player_id, score) in scores {
            scores_vector.push((*player_id, *score));
        }
        let server_message = ServerMessage::PlayerKilled(scores_vector);
        let bytes = bincode::serialize(&server_message).ok().unwrap();

        let update_msg = Message::Binary(bytes);
        for (&player_id_to_send, ws_tx) in &lobby.websocket_sessions {
            let _ = ws_tx.send(update_msg.clone());
        }
    }
}
