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
    pub last_processed_input_id: u32,
    pub mouse_angle: f32,
    pub current_gun: String
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


impl Bullet{
    pub fn new(id: u32, owner_id: u32, spawn_position: [f32; 2], direction: [f32; 2], speed: f32, rigid_body_set: &mut RigidBodySet, collider_set: &mut ColliderSet,   ) -> Self{
        let rigid_body = RigidBodyBuilder::dynamic()
            .translation(Vec2::new(spawn_position[0], spawn_position[1]))
            .linvel(Vec2::new(direction[0], direction[1]) * speed)
            .gravity_scale(0.0) 
            .lock_rotations()   
            .ccd_enabled(true)   
            .build();

        let body_handle = rigid_body_set.insert(rigid_body);

        let collider = ColliderBuilder::ball(0.1)
            .sensor(true) 
            .build();

        collider_set.insert_with_parent(collider, body_handle, rigid_body_set);

        Self {
            id,
            owner_id,
            body_handle,
        }
    }
}