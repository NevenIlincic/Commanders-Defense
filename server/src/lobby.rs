use std::{collections::HashMap, hash::Hash, net::SocketAddr, sync::Arc};

use rapier2d::math::Vec2;
use tokio::{net::UdpSocket, sync::Mutex, sync::mpsc};
use serde::{Deserialize, Serialize};

use crate::{
    entities::Bullet,
    game_physics::GameStateModel,
    lobby,
    network_protocol::{
        BulletSnapshot, ClientInput, GameState, KillFeed, PlayerSnapshot, ServerMessage,
        TowerSnapshot,
    },
};

pub struct LobbyHandler {
    pub next_lobby_id: u32,
    pub lobbies: HashMap<u32, Lobby>,
    pub players_sessions: HashMap<SocketAddr, mpsc::Sender<(SocketAddr, ClientInput)>>, //Svi igraci koji su u startovanim partijama (zbog UDP protokola)
    pub socket: Arc<UdpSocket>
}

impl LobbyHandler {
    pub fn new(udp_socket: &Arc<UdpSocket>) -> Self {
        Self {
            next_lobby_id: 1,
            lobbies: HashMap::new(),
            players_sessions: HashMap::new(),
            socket: Arc::clone(&udp_socket)
        }
    }

    pub fn create_lobby(
        &mut self,
        max_players: u8,
        host_address: SocketAddr,
        nickname: String,
        game_mode_number: u8
    ) -> (u32, u32) {
        let new_lobby: Lobby = Lobby::new(self.next_lobby_id, max_players, host_address, &self.socket, game_mode_number);
        self.lobbies.insert(self.next_lobby_id, new_lobby);
        let Some(host_player_id) = self.add_player_to_lobby(self.next_lobby_id, host_address, nickname)else{panic!()};
        self.next_lobby_id += 1;

        (self.next_lobby_id - 1, host_player_id)
    }

    pub fn start_lobby(&mut self, lobby_id: u32, host_player_id: u32) {
        if let Some(lobby) = self.lobbies.get_mut(&lobby_id) {
            if let Some(host_player) = lobby.players.get(&lobby.host_addr){
                if host_player.player_id != host_player_id{
                    return;
                }
            }
            if lobby.is_started {
                return;
            }

            lobby.is_started = true;

            let (tx, mut rx) = mpsc::channel::<(SocketAddr, ClientInput)>(100);
            for address in lobby.players.keys() {
                self.players_sessions.insert(*address, tx.clone());
            }
            let socket_clone = Arc::clone(&lobby.socket);
            let players_clone = lobby.players.clone();
            let lobby_id_clone = lobby_id;
            let lobby_game_mode_settings_clone: GameModeSettings = lobby.game_mode.clone();

            tokio::spawn(async move {
                println!("Lobi {} startovan!", lobby_id_clone);

                let mut game_state_model = GameStateModel::new(Arc::clone(&socket_clone), lobby_game_mode_settings_clone);
                game_state_model.load_level();
                for (addr, lobby_p) in players_clone {
                    game_state_model.add_player(lobby_p.player_id, &lobby_p.nickname, 10.0, 10.0);
                    game_state_model
                        .address_to_players
                        .insert(addr, lobby_p.player_id);
                }

                let mut interval = tokio::time::interval(std::time::Duration::from_millis(16));
                loop {
                    interval.tick().await;

                    while let Ok((addr, input)) = rx.try_recv() {
                        game_state_model.handle_client_input(input, addr);
                    }

                    game_state_model.update();

                    if game_state_model.is_game_finished && game_state_model.time_to_reset <= 0.0 {
                        break;
                    }

                    //Glavni loop partije
                    let mut snapshot = GameState {
                        players: Vec::new(),
                        bullets: Vec::new(),
                        towers: Vec::new(),
                        kill_events: Vec::new(),
                    };
                    let clients_ip: Vec<SocketAddr>;

                    for (&id, player) in &game_state_model.players {
                        if let Some(rb) = game_state_model.rigid_body_set.get(player.body_handle) {
                            let pos = rb.translation();
                            snapshot.players.push(PlayerSnapshot {
                                id,
                                nickname: player.nickname.clone(),
                                position: [pos.x, pos.y],
                                hp: player.hp,
                                facing_right: player.facing_right,
                                is_on_ground: player.is_on_ground,
                                respawn_timer: player.respawn_timer,
                                last_processed_input_id: player.last_processed_input_id,
                                mouse_angle: player.mouse_angle,
                                gun: player.current_gun,
                                is_reloading: player.is_reloading,
                                current_ammo: player.current_ammo,
                            });
                        }
                    }

                    for (&id, bullet) in &game_state_model.bullets {
                        if let Some(rb) = game_state_model.rigid_body_set.get(bullet.body_handle) {
                            let pos: Vec2 = rb.translation();
                            snapshot.bullets.push(BulletSnapshot {
                                id,
                                position: [pos.x, pos.y],
                                owner_id: bullet.owner_id,
                                angle: bullet.angle,
                                gun: bullet.gun,
                            });
                        }
                    }

                    for (&id, tower) in &game_state_model.towers {
                        snapshot.towers.push(TowerSnapshot {
                            id,
                            owner_id: tower.owner_id,
                            hp: tower.hp,
                            is_left_tower: tower.is_left_tower,
                        });
                    }

                    let kill_feed: &KillFeed = &game_state_model.kill_feed;
                    snapshot.kill_events = kill_feed.kill_events.clone();

                    clients_ip = game_state_model
                        .address_to_players
                        .keys()
                        .cloned()
                        .collect::<Vec<_>>();

                    if !clients_ip.is_empty() {
                        let bytes: Vec<u8> = bincode::serialize(&ServerMessage::Snapshot(snapshot))
                            .expect("Bincode fail");

                        //println!("{}", bytes.len());
                        for addr in &clients_ip {
                            if let Err(e) = socket_clone.send_to(&bytes, addr).await {
                                eprintln!("Greška pri slanju Snapshot-a ka {}: {}", addr, e);
                            }
                        }
                    }
                }
            });
        }
    }

    pub fn add_player_to_lobby(
        &mut self,
        lobby_id: u32,
        addr: SocketAddr,
        nickname: String,
    ) -> Option<u32> {
        let mut should_start = false;
        let mut new_id = 0;

        {
            if let Some(found_lobby) = self.lobbies.get_mut(&lobby_id) {
                if found_lobby.players.len() >= found_lobby.max_players as usize {
                    return None;
                }
                new_id += (found_lobby.players.len() + 1) as u32;
                found_lobby.add_player(new_id, addr, nickname);

                if found_lobby.players.len() == found_lobby.max_players as usize {
                    should_start = true;
                }
            } else {
                return None;
            }
        }

        Some(new_id)
    }
}

pub struct Lobby {
    pub id: u32,
    pub host_addr: SocketAddr,
    pub players: HashMap<SocketAddr, LobbyPlayer>,
    pub players_id_map: HashMap<u32, LobbyPlayer>,
    pub max_players: u8,
    pub is_started: bool,
    pub socket: Arc<UdpSocket>,
    pub game_mode: GameModeSettings
    //pub selected_map: String
}

impl Lobby {
    pub fn new(
        id: u32,
        max_players: u8,
        host_addr: SocketAddr,
        udp_socket: &Arc<UdpSocket>,
        game_mode: u8
    ) -> Self {
        let players: HashMap<SocketAddr, LobbyPlayer> = HashMap::new();
        let players_id_map: HashMap<u32, LobbyPlayer> = HashMap::new();
        let selected_game_mode: GameModeSettings = match game_mode{
            0 => { GameModeSettings::TOWERS((TowersGameModeSettings::new()))}
            _ => { GameModeSettings::FFA()}
        };
        Self {
            id,
            host_addr,
            players,
            players_id_map,
            max_players,
            is_started: false,
            socket: Arc::clone(&udp_socket),
            game_mode: selected_game_mode
        }
    }

    pub fn add_player(&mut self, player_id: u32, player_addr: SocketAddr, nickname: String) {
        let is_host = {player_addr == self.host_addr }; 
        let new_player: LobbyPlayer = LobbyPlayer {
            player_id,
            addr: player_addr,
            nickname,
            is_ready: false,
            is_host
        };
        self.players.insert(player_addr, new_player.clone());
        self.players_id_map.insert(player_id, new_player);
    }
}

#[derive(Clone)]
pub struct LobbyPlayer {
    pub player_id: u32,
    pub addr: SocketAddr,
    pub nickname: String,
    pub is_ready: bool,
    pub is_host: bool
}

#[derive(Deserialize, Debug, Clone)]
pub enum GameModeSettings{
    TOWERS(TowersGameModeSettings), //0,
    FFA()
}

#[derive(Deserialize, Debug, Clone)]
pub struct TowersGameModeSettings{
    pub towers_max_hp: i32,
    pub selected_map: String
}

impl TowersGameModeSettings{
    pub fn new() -> Self{
        Self{
            towers_max_hp: 2000,
            selected_map: String::from("Map_1")
        }
    }
}
