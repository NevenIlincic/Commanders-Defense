
use std::{collections::HashMap, net::SocketAddr, sync::Arc};

use tokio::net::UdpSocket;

use crate::{game_physics::GameStateModel, network_protocol::ClientInput};

pub struct LobbyHandler{
    pub next_lobby_id: u32,
    pub lobbies: HashMap<u32, Lobby>,
    pub socket: Arc<UdpSocket>
}

/// KORISTITI KASNIJE !!!!

impl LobbyHandler{
    pub fn new(socket: Arc<UdpSocket>) -> Self{
        Self{
            next_lobby_id: 0,
            lobbies: HashMap::new(),
            socket: Arc::clone(&socket)
        }
    }

    pub fn create_lobby(&mut self){
        let new_lobby: Lobby = Lobby::new(self.next_lobby_id, &self.socket);
        self.lobbies.insert(self.next_lobby_id, new_lobby);
        self.next_lobby_id += 1;
    }
}


pub struct Lobby{
    pub id: u32,
    pub game_state: GameStateModel,
    pub address_to_players: HashMap<SocketAddr, u32>,
    pub socket: Arc<UdpSocket>
}

impl Lobby{
    pub fn new(id: u32, socket: &Arc<UdpSocket>)-> Self{
        let address_to_players: HashMap<SocketAddr, u32> = HashMap::new();
        let game_state_model = GameStateModel::new(Arc::clone(&socket));
        Self{
            id,
            game_state: game_state_model,
            address_to_players,
            socket: Arc::clone(&socket)
        }
    }

    pub fn reset_lobby(&mut self){
        self.game_state = GameStateModel::new(Arc::clone(&self.socket));
    }

    pub fn handle_client_input(&mut self, input: ClientInput, ip_address: SocketAddr){
        self.game_state.handle_client_input(input, ip_address);
    }
}
