use axum::{async_trait, extract::FromRequestParts, http::{StatusCode, request::Parts}};
use axum_extra::{TypedHeader, headers::{Authorization, authorization::Bearer}};
use chrono::{Duration, Utc};
use jsonwebtoken::{Algorithm, DecodingKey, EncodingKey, Header, Validation, decode, encode};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};



static JWT_SECRET: Lazy<Vec<u8>> = Lazy::new(|| {
    std::env::var("JWT_SECRET")
        .expect("JWT_SECRET nije postavljen!")
        .into_bytes()
});

pub struct JWTHandler;

impl JWTHandler {
    pub fn create_jwt(player_id: u32, player_nickname: String) -> String {
        let now = Utc::now();
        let expire = now + Duration::hours(24);
   
        let claims = Claims {
            id: player_id,
            nickname: player_nickname,
            iat: now.timestamp() as usize,
            exp: expire.timestamp() as usize,
        };

        encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(&JWT_SECRET),
        )
        .unwrap()
    }

    pub fn validate_jwt(token: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
        decode::<Claims>(
            token,
            &DecodingKey::from_secret(&JWT_SECRET),
            &Validation::new(Algorithm::HS256),
        )
        .map(|data| data.claims)
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub id: u32,
    pub nickname: String,
    pub exp: usize,
    pub iat: usize,
}

#[async_trait]
impl<S> FromRequestParts<S> for Claims
where
    S: Send + Sync,
{
    type Rejection = StatusCode;

    //Funkcija koja proverava postojanje tokena
    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        //println!("--- NOVI HTTP ZAHTEV ---");
        
        let auth_header = parts.headers.get("Authorization");
        
        match auth_header {
            Some(value) => {
                let auth_str = value.to_str().unwrap_or("Nije validan string");
                //println!("Pronađen Authorization header: {}", auth_str);

                if let Some(token) = auth_str.strip_prefix("Bearer ") {
                    match JWTHandler::validate_jwt(token) {
                        Ok(claims) => {
                            //println!("Token uspešno dekodiran za: {}", claims.nickname);
                            Ok(claims)
                        },
                        Err(e) => {
                            println!("JWT Greška pri dekodiranju: {:?}", e);
                            Err(StatusCode::UNAUTHORIZED)
                        }
                    }
                } else {
                    println!("Greška: Header ne počinje sa 'Bearer '");
                    Err(StatusCode::UNAUTHORIZED)
                }
            },
            None => {
                println!("Greška: Authorization header POTPUNO FALI u zahtevu!");
                Err(StatusCode::UNAUTHORIZED)
            }
        }
    }
}

