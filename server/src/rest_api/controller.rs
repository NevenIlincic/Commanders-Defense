use std::{net::SocketAddr, sync::Arc};

use axum::{
    Router, ServiceExt, body::Bytes, extract::{ConnectInfo, State}, http::StatusCode, response::IntoResponse, routing::{Route, get, post}
};
use tokio::sync::Mutex;

use crate::{lobby::LobbyHandler, network_protocol::ClientMessage, rest_api::service::RestService};

pub struct RestController {
    pub lobby_handler: Arc<Mutex<LobbyHandler>>,
}

impl RestController {
    pub fn new(handler: Arc<Mutex<LobbyHandler>>) -> Self {
        Self {
            lobby_handler: handler,
        }
    }

    pub fn run_rest_thread(&mut self) {
        let app = self.define_end_points();
        tokio::spawn(async move {
            let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
            axum::serve(
                listener,
                app.into_make_service_with_connect_info::<SocketAddr>(),
            )
            .await
            .unwrap();
        });
    }

    fn define_end_points(&self) -> Router {
        let app = Router::new()
            .route("/join", post(RestService::handle_lobby_join))
            .route("/lobbies", get(RestService::get_lobbies_list))
            .route("/create-lobby", post(RestService::create_lobby))
            .route("/get-lobby-info", post(RestService::get_current_lobby_info))
            .route("/start-lobby", post(RestService::start_lobby))
            .route("/player-ready", post(RestService::change_is_player_ready)) // Menja u lobiju da li je igrac spreman ili ne
            .route("/change-tower-max-hp", post(RestService::change_tower_max_hp))
            .route("/change-player-skin", post(RestService::change_player_skin))
            .route("/leave-lobby", post(RestService::leave_lobby))
            .with_state(Arc::clone(&self.lobby_handler));

        app
    }
}
