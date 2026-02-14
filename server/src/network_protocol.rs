use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct ClientInput { // Klijent šalje ovo svaki tick, na kraju svakog _proccess(delta) poziva
    pub input_id: u32,   // Kako bi klijent znao da li treba da "ponovi" neke inpute ako ima kašnjenja
    pub move_left: bool,
    pub move_right: bool,
    pub jump: bool,
    pub shoot: bool,
    pub mouse_angle: f32,
    pub command: Option<String>
}

#[derive(Serialize, Deserialize)]
pub struct GameState {
    pub players: Vec<PlayerSnapshot> // Šalje se vektor zbog manje količine podataka
    // pub bullets: Vec<BulletSnapshot>,
    // pub towers: Vec<TowerSnapshot>,
}

#[derive(Serialize, Deserialize)]
pub struct PlayerSnapshot {
    pub id: u32,
    pub position: [f32; 2],
    pub hp: f32,
    pub facing_right: bool, 
    pub is_on_ground: bool,
    pub respawn_timer: f32,
    pub last_processed_input_id: u32
}

#[derive(Serialize, Deserialize)]
pub struct BulletSnapshot {
    pub id: u32,
    pub position: [f32; 2],
    pub angle: f32
}

#[derive(Serialize, Deserialize)]
pub struct TowerSnapshot {
    pub id: u32,
    pub hp: f32,
}