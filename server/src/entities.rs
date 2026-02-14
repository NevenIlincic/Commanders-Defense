use rapier2d::prelude::*;

pub struct Player {
    pub id: u32,
    pub body_handle: RigidBodyHandle, // Vodi računa o poziciji, brzini, gravitaciji... da ne bih morao ručno
    pub collider_handle: ColliderHandle, // Kolider koji se koristi kako bi se utvrdilo da li je nešto prošlo kroz igrača
    pub vertical_velocity: f32,
    pub is_on_ground: bool,
    pub hp: f32,
    pub facing_right: bool,
    pub respawn_timer: f32,
    pub last_input_id: u32
}

pub struct Bullet {
    pub id: u32,
    pub owner_id: u32,
    pub body_handle: RigidBodyHandle
}

pub struct Tower {
    pub id: u32,
    pub position: RigidBodyHandle, // Kule su uvek u istom položaju, moguća i kasnija zamena sa RigidBodyHandler-om
    pub hp: f32,
    pub collider_handle: ColliderHandle
}