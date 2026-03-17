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
            sub: ClaimsData { id: player_id, nickname: player_nickname },
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
    pub sub: ClaimsData,
    pub exp: usize,
    pub iat: usize,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ClaimsData {
    id: u32,
    nickname: String,
}
