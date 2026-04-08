use std::{net::SocketAddr, sync::{Arc}};

use axum::{
    Router, ServiceExt, body::Bytes, extract::{ConnectInfo, State}, http::StatusCode, response::IntoResponse, routing::{Route, get, post}
};
use tokio::sync::{RwLock};

use crate::{lobby::LobbyHandler, network_protocol::ClientMessage, rest_api::service::RestService};

#[derive(Clone)]
pub struct AppState {
    pub lobby_handler: Arc<RwLock<LobbyHandler>>,
    pub connection_pool: sqlx::PgPool
}

pub struct RestController {
    pub lobby_handler: Arc<RwLock<LobbyHandler>>,
    db_pool: sqlx::PgPool
}

impl RestController {
    pub fn new(handler: Arc<RwLock<LobbyHandler>>, db_pool: sqlx::PgPool) -> Self {
        Self {
            lobby_handler: handler,
            db_pool
        }
    }

    pub fn run_rest_thread(&mut self) {
        let app = self.define_end_points();
        tokio::spawn(async move {
            let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await.unwrap();
            axum::serve(
                listener,
                app.into_make_service_with_connect_info::<SocketAddr>(),
            )
            .await
            .unwrap();
        });
    }

    fn define_end_points(&self) -> Router {
        let lobby_handler: Arc<RwLock<LobbyHandler>> = Arc::clone(&self.lobby_handler);
        let connection_pool: sqlx::Pool<sqlx::Postgres> = self.db_pool.clone();

        let app = Router::new()
            .route("/register", post(RestService::register))
            .route("/login", post(RestService::login))
            .route("/log-out", post(RestService::logout))
            .route("/heartbeat", post(RestService::handle_player_heartbeat))
            .route("/join", post(RestService::handle_lobby_join))
            .route("/lobbies", get(RestService::get_lobbies_list))
            .route("/create-lobby", post(RestService::create_lobby))
            .route("/get-lobby-info", post(RestService::get_current_lobby_info))
            .route("/leave-lobby", post(RestService::leave_lobby))
            .route("/join-started-lobby", post(RestService::handle_started_lobby_join))
            .route("/ws", get(RestService::ws_handler))
            // .with_state(Arc::clone(&self.lobby_handler));
            .with_state(AppState{lobby_handler, connection_pool});
            // .into_make_service_with_connect_info::<SocketAddr>(); IMAM VEC U MAIN-U

        app
    }
}
