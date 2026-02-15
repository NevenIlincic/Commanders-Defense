use serde::Deserialize;

#[derive(Deserialize)]
pub struct LevelData {
    pub colliders: Vec<RectCollider>,
}

#[derive(Deserialize)]
pub struct RectCollider {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}