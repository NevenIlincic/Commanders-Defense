use std::{
    clone,
    collections::{HashMap, HashSet},
    hash::Hash,
    net::SocketAddr,
    sync::{Arc, atomic::Ordering},
    time::Instant,
};

use axum::extract::ws::Message;
use rapier2d::math::Vec2;
use serde::{Deserialize, Serialize};
use tokio::{
    net::UdpSocket,
    sync::{Mutex, mpsc},
};

use crate::{
    TOTAL_SENT_BYTES,
    entities::Bullet,
    game_physics::GameStateModel,
    lobby,
    network_protocol::{
        BulletSnapshot, ClientInput, GameEnd, GameState, KillFeed, LobbyRoomInfo, PlayerSkin,
        PlayerSnapshot, ServerMessage, TowerSnapshot,
    },
    rest_api::service::RestService,
};

pub enum LobbyCommand {
    RegisterMatch {
        addresses: Vec<SocketAddr>,
        game_tx: mpsc::Sender<(SocketAddr, ClientInput)>,
        game_cmd_tx: mpsc::Sender<SocketAddr>,
    },
    CleanUpMatch {
        addresses: Vec<SocketAddr>,
    },
}

pub struct LobbyHandler {
    pub next_lobby_id: u32,
    pub lobbies: HashMap<u32, Arc<Mutex<Lobby>>>,
    pub players_sessions: HashMap<
        SocketAddr,
        (
            mpsc::Sender<(SocketAddr, ClientInput)>,
            mpsc::Sender<SocketAddr>,
        ),
    >, //Svi igraci koji su u startovanim partijama (UDP protokol)
    pub socket: Arc<UdpSocket>,
    pub logged_in_users: HashMap<u32, Instant>, //Svi ulogovani korisnici i vreme poslednjeg heartbita
    pub cmd_tx: mpsc::UnboundedSender<LobbyCommand>,
}

impl LobbyHandler {
    pub fn new(udp_socket: &Arc<UdpSocket>, cmd_tx: mpsc::UnboundedSender<LobbyCommand>) -> Self {
        Self {
            next_lobby_id: 1,
            lobbies: HashMap::new(),
            players_sessions: HashMap::new(),
            // websocket_sessions: HashMap::new(),
            socket: Arc::clone(&udp_socket),
            logged_in_users: HashMap::new(),
            cmd_tx,
        }
    }

    pub async fn create_lobby(
        &mut self,
        player_id: u32,
        max_players: u8,
        host_address: SocketAddr,
        nickname: String,
        game_mode_number: u8,
        password: Option<String>,
    ) -> (u32, u32) {
        let new_lobby: Lobby = Lobby::new(
            self.next_lobby_id,
            max_players,
            host_address,
            &self.socket,
            game_mode_number,
            password.clone(),
        );
        let lobby_arc = Arc::new(Mutex::new(new_lobby));
        self.lobbies.insert(self.next_lobby_id, lobby_arc.clone());
        let created_lobby_id: u32 = self.next_lobby_id;
        {
            let mut lobby = lobby_arc.lock().await;
            match lobby.add_player(player_id, host_address, nickname, password) {
                Ok(_) => println!("Host uspesno dodat u lobi"),
                Err(e) => eprintln!("Greska pri dodavanju hosta: {}", e),
            }
        }
        self.next_lobby_id += 1;

        (created_lobby_id, player_id)
    }
}

pub struct Lobby {
    pub id: u32,
    pub winner_id: u32,
    pub next_player_id: u32,
    pub host_addr: SocketAddr,
    pub players: HashMap<SocketAddr, LobbyPlayer>,
    pub websocket_sessions: HashMap<u32, mpsc::UnboundedSender<Message>>, //Svi igraci u startovanim partijama (WebSocket)

    pub players_id_map: HashMap<
        u32,
        (
            LobbyPlayer,
            mpsc::UnboundedSender<(u32, String, u8)>, //player_id, player_nickname, skin_index
        ),
    >,
    pub max_players: u8,
    pub is_started: bool,
    pub socket: Arc<UdpSocket>,
    pub game_mode: GameModeSettings, //pub selected_map: String
    pub password: Option<String>,
    pub sender_receiver_channel: (
        mpsc::UnboundedSender<(u32, String, u8)>,
        Option<mpsc::UnboundedReceiver<(u32, String, u8)>>,
    ),
}

impl Lobby {
    pub fn new(
        id: u32,
        max_players: u8,
        host_addr: SocketAddr,
        udp_socket: &Arc<UdpSocket>,
        game_mode: u8,
        password: Option<String>,
    ) -> Self {
        let players: HashMap<SocketAddr, LobbyPlayer> = HashMap::new();
        let players_id_map: HashMap<u32, (LobbyPlayer, mpsc::UnboundedSender<(u32, String, u8)>)> =
            HashMap::new();
        let selected_game_mode: GameModeSettings = match game_mode {
            0 => GameModeSettings::TOWERS((TowersGameModeSettings::new())),
            _ => GameModeSettings::FFA((FFAGameModeSettings::new())),
        };

        let websocket_sessions: HashMap<u32, mpsc::UnboundedSender<Message>> = HashMap::new();

        let (cmd_tx, cmd_rx) = mpsc::unbounded_channel::<(u32, String, u8)>();
        Self {
            id,
            winner_id: 0,
            next_player_id: 1,
            host_addr,
            players,
            websocket_sessions,
            players_id_map,
            max_players,
            is_started: false,
            socket: Arc::clone(&udp_socket),
            game_mode: selected_game_mode,
            password,
            sender_receiver_channel: (cmd_tx, Some(cmd_rx)),
        }
    }

    pub fn add_player(
        &mut self,
        player_id: u32,
        player_addr: SocketAddr,
        nickname: String,
        password: Option<String>,
    ) -> Result<(), String> {
        //Ako lobi ima postavljenu sifru
        if let Some(lobby_set_password) = &self.password {
            //Da li sam ja poslao sifru
            if let Some(entered_password) = password {
                if entered_password != *lobby_set_password {
                    return Err("Wrong password!".into());
                }
            } else {
                return Err("No lobby password sent!".into());
            }
        }
        match self.game_mode {
            GameModeSettings::FFA(_) => {
                if self.players.len() >= self.max_players as usize {
                    return Err("Lobby is full!".into());
                }
            }
            GameModeSettings::TOWERS(_) => {
                if (self.players.len() >= self.max_players as usize || self.is_started) {
                    return Err("Lobby is full!".into());
                }
            }
        }

        let is_host = { player_addr == self.host_addr };
        let new_player: LobbyPlayer = LobbyPlayer {
            player_id,
            addr: player_addr,
            nickname,
            is_ready: false,
            is_host,
            selected_skin: 0,
        };
        self.players.insert(player_addr, new_player.clone());
        self.players_id_map.insert(
            player_id,
            (new_player, self.sender_receiver_channel.0.clone()),
        );
        Ok(())
        //Igraca u web_socket_sessions dodajem u handle_ws_session u RestService
    }

    pub async fn start_lobby(
        &mut self,
        state: Arc<Mutex<Self>>,
        lobby_id: u32,
        host_player_id: u32,
        lobby_handler_tx: mpsc::UnboundedSender<LobbyCommand>,
    ) {
        if self.is_started {
            return;
        }

        if let Some(host_player) = self.players.get(&self.host_addr) {
            if host_player.player_id != host_player_id {
                return;
            }
        }

        self.is_started = true;

        let (cmd_tx, mut cmd_rx) = mpsc::channel::<(SocketAddr)>(100);
        let (tx, mut rx) = mpsc::channel::<(SocketAddr, ClientInput)>(100);

        let addresses: Vec<SocketAddr> = self.players.keys().cloned().collect();

        //Javiti lobby handleru da treba da doda u listu players_session
        let _ = lobby_handler_tx.send(LobbyCommand::RegisterMatch {
            addresses,
            game_tx: tx.clone(),
            game_cmd_tx: cmd_tx.clone(),
        });

        let (new_tx, new_rx) = mpsc::unbounded_channel::<(u32, String, u8)>();
        self.sender_receiver_channel.1 = Some(new_rx);
        self.sender_receiver_channel.0 = new_tx.clone();

        // Dodavanje novih sendera vec postojecim igracima u lobiju
        for player_session in self.players_id_map.values_mut() {
            player_session.1 = new_tx.clone();
        }

        let socket_clone: Arc<UdpSocket> = Arc::clone(&self.socket);
        let players_clone: HashMap<u32, (LobbyPlayer, mpsc::UnboundedSender<(u32, String, u8)>)> =
            self.players_id_map.clone();
        let lobby_id_clone: u32 = lobby_id;
        let lobby_game_mode_settings_clone: GameModeSettings = self.game_mode.clone();
        let lobby_max_players_clone: u8 = self.max_players;

        let receiver = self.sender_receiver_channel.1.take();
        let tx_clone = tx.clone();
        let cmd_tx_clone = cmd_tx.clone();
        let lobby_handler_tx_clone = lobby_handler_tx.clone();

        let lobby_thread_reference: Arc<Mutex<Lobby>> = Arc::clone(&state);
        tokio::spawn(async move {
            let mut rx_inner = receiver.expect("Receiver mora postojati pri pokretanju!");
            let mut game_state_model = GameStateModel::new(
                Arc::clone(&socket_clone),
                lobby_game_mode_settings_clone,
                lobby_thread_reference.clone(),
                lobby_id,
                lobby_max_players_clone,
            );
            game_state_model.load_level();
            for (addr, lobby_player_data) in players_clone {
                game_state_model.add_player(
                    lobby_player_data.0.player_id,
                    &lobby_player_data.0.nickname,
                    10.0,
                    10.0,
                    lobby_player_data.0.selected_skin,
                );
                game_state_model
                    .address_to_players
                    .insert(lobby_player_data.0.addr, lobby_player_data.0.player_id);
            }

            let physics_tick_rate: f64 = 1.0 / 60.0;
            let mut interval = tokio::time::interval(std::time::Duration::from_secs_f64(physics_tick_rate));
            interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
            let mut network_tick_rate: u8 = 3;
            loop {
                interval.tick().await;

                while let Ok((addr, input)) = rx.try_recv() {
                    game_state_model.handle_client_input(input, addr).await;
                }
                while let Ok(addr) = cmd_rx.try_recv() {
                    game_state_model.check_for_disconnection(addr).await;
                }
                while let Ok(data) = rx_inner.try_recv() {
                    let (id, nickname, skin) = data;
                    {
                        let player_address = {
                            let lobby = lobby_thread_reference.lock().await;
                            lobby.players_id_map.get(&id).map(|info| info.0.addr)
                        };
                        if let Some(player_address) = player_address {
                            let _ = lobby_handler_tx_clone.send(LobbyCommand::RegisterMatch {
                                addresses: vec![player_address],
                                game_tx: tx_clone.clone(),
                                game_cmd_tx: cmd_tx_clone.clone(),
                            });

                            game_state_model
                                .address_to_players
                                .insert(player_address, id);
                            game_state_model.add_player(id, &nickname, 10.0, 10.0, skin);
                        }
                    }
                }

                game_state_model.update(physics_tick_rate as f32);
                network_tick_rate += 1;
                if network_tick_rate >= 3 {
                    network_tick_rate = 0;

                    // && game_state_model.time_to_reset <= 0.0
                    if game_state_model.is_game_finished {
                        println!("BREKNUO!");
                        break;
                    }

                    //Glavni loop partije
                    let mut snapshot = GameState {
                        players: Vec::new(),
                        bullet_events: Vec::new(),
                        towers: Vec::new(),
                        //kill_events: Vec::new(),
                    };
                    let clients_ip: Vec<SocketAddr>;

                    for (&id, player) in &game_state_model.players {
                        if let Some(rb) = game_state_model.rigid_body_set.get(player.body_handle) {
                            let Some(player_score) = game_state_model.players_score.get(&id) else {
                                continue;
                            };
                            let pos = rb.translation();
                            let flags: u8 = PlayerSnapshot::create_flags(player.facing_right, player.is_on_ground, player.is_reloading);
                            snapshot.players.push(PlayerSnapshot {
                                id,
                                nickname: player.nickname.clone(),
                                position: [pos.x, pos.y],
                                hp: player.hp,
                                flags,
                                respawn_timer: player.respawn_timer,
                                last_processed_input_id: player.last_processed_input_id,
                                mouse_angle: player.mouse_angle,
                                gun: player.current_gun,
                                current_ammo: player.current_ammo,
                                selected_skin: player.player_skin,
                                num_kills: *player_score,
                                velocity: [player.horizontal_velocity, player.vertical_velocity]
                            });
                        }
                    }

                    snapshot.bullet_events = game_state_model.bullet_events.clone();
                    game_state_model.bullet_events = Vec::new();
                    
                    // for (&id, bullet) in &game_state_model.bullets {
                    //     if let Some(rb) = game_state_model.rigid_body_set.get(bullet.body_handle) {
                    //         let pos: Vec2 = rb.translation();
                    //         snapshot.bullets.push(BulletSnapshot {
                    //             id,
                    //             position: [pos.x, pos.y],
                    //             owner_id: bullet.owner_id,
                    //             angle: bullet.angle,
                    //             gun: bullet.gun,
                    //         });
                    //     }
                    // }

                    for (&id, tower) in &game_state_model.towers {
                        snapshot.towers.push(TowerSnapshot {
                            id,
                            owner_id: tower.owner_id,
                            hp: tower.hp,
                            is_left_tower: tower.is_left_tower,
                        });
                    }

                    // let kill_feed: &KillFeed = &game_state_model.kill_feed;
                    // snapshot.kill_events = kill_feed.kill_events.clone();

                    clients_ip = game_state_model
                        .address_to_players
                        .keys()
                        .cloned()
                        .collect::<Vec<_>>();

                    if !clients_ip.is_empty() {
                        let bytes: Vec<u8> = bincode::serialize(&ServerMessage::Snapshot(snapshot))
                            .expect("Bincode fail");
                        TOTAL_SENT_BYTES.fetch_add(bytes.len() as u64, Ordering::Relaxed);

                        for addr in &clients_ip {
                            if let Err(e) = socket_clone.send_to(&bytes, addr).await {
                                eprintln!("Greska pri slanju Snapshot-a ka {}: {}", addr, e);
                            }
                        }
                    }
                }
            }

            /////KADA SE PARTIJA ZAVRSI

            // Resetovanje lobija
            {
                let mut lobby: tokio::sync::MutexGuard<'_, Lobby> =
                    lobby_thread_reference.lock().await;
                lobby.is_started = false;
                for player_tuple in lobby.players_id_map.values_mut() {
                    let mut player = &mut player_tuple.0;
                    player.is_ready = false;
                }

                let players_id: Vec<u32> = lobby.players_id_map.keys().cloned().collect();

                let bytes_winner =
                    RestService::get_game_winner_id(game_state_model.winner_id).unwrap();

                let msg_winner: Message = Message::Binary(bytes_winner.clone());

                for player_id in players_id {
                    if let Some(ws_tx) = lobby.websocket_sessions.get(&player_id) {
                        let _ = ws_tx.send(msg_winner.clone());
                    }
                }
            }

            let all_addresses: Vec<SocketAddr> = game_state_model
                .address_to_players
                .keys()
                .cloned()
                .collect();

            //Na kraju, dodajem u red za brisenja aktivnih igraca
            let _ = lobby_handler_tx_clone.send(LobbyCommand::CleanUpMatch {
                addresses: all_addresses,
            });
        });
    }
}

#[derive(Clone)]
pub struct LobbyPlayer {
    pub player_id: u32,
    pub addr: SocketAddr,
    pub nickname: String,
    pub is_ready: bool,
    pub is_host: bool,
    pub selected_skin: u8,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum GameModeSettings {
    TOWERS(TowersGameModeSettings), //0,
    FFA(FFAGameModeSettings),       //1
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TowersGameModeSettings {
    pub towers_max_hp: i32,
    pub selected_map: u8,
}

impl TowersGameModeSettings {
    pub fn new() -> Self {
        Self {
            towers_max_hp: 2000,
            selected_map: 0,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FFAGameModeSettings {
    pub points_to_win: u8,
    pub selected_map: u8,
}

impl FFAGameModeSettings {
    pub fn new() -> Self {
        Self {
            points_to_win: 25,
            selected_map: 0,
        }
    }
}
