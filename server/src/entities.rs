use crate::groups::{BIT_BULLET, BULLET_GROUP, PLAYER_GROUP, WALL_GROUP};
use rapier2d::prelude::*;

pub struct Player {
    pub id: u32,
    pub body_handle: RigidBodyHandle, // Vodi računa o poziciji, brzini, gravitaciji... da ne bih morao ručno
    pub collider_handle: ColliderHandle, // Kolider koji se koristi kako bi se utvrdilo da li je nešto prošlo kroz igrača
    pub vertical_velocity: f32,
    pub is_on_ground: bool,
    pub hp: i32,
    pub facing_right: bool,
    pub respawn_timer: f32,
    pub last_processed_input_id: u32,
    pub mouse_angle: f32,
    pub current_gun: String,
    pub shoot_cooldown: f32
}

pub struct Bullet {
    pub id: u32,
    pub owner_id: u32,
    pub body_handle: RigidBodyHandle,
    pub damage: i32
}

pub struct Tower {
    pub id: u32,
    pub position: RigidBodyHandle, // Kule su uvek u istom položaju, moguća i kasnija zamena sa RigidBodyHandler-om
    pub hp: f32,
    pub collider_handle: ColliderHandle,
}

pub struct GunStats {
    pub fire_rate: f32,
    pub bullet_speed: f32,
    pub damage: i32,
}

impl Bullet {
    pub fn new(
        id: u32,
        owner_id: u32,
        spawn_position: [f32; 2],
        mouse_angle: f32,
        gun_stats: &GunStats,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
    ) -> Self {
        let bullet_speed: f32 = gun_stats.bullet_speed;
        let bullet_damage: i32 = gun_stats.damage;

        let rigid_body = RigidBodyBuilder::dynamic()
            .translation(Vec2::new(spawn_position[0], spawn_position[1]))
            .linvel(Vec2::new(mouse_angle.cos(), mouse_angle.sin()) * bullet_speed)
            .gravity_scale(0.0)
            .lock_rotations()
            .ccd_enabled(true)
            .build();

        let body_handle = rigid_body_set.insert(rigid_body);

        let collider = ColliderBuilder::ball(0.125)
            .user_data(BIT_BULLET | id as u128)
            .active_events(ActiveEvents::COLLISION_EVENTS)
            .sensor(true)
            .collision_groups(InteractionGroups::new(
                BULLET_GROUP,
                WALL_GROUP | PLAYER_GROUP,
                InteractionTestMode::And,
            ))
            .build();

        collider_set.insert_with_parent(collider, body_handle, rigid_body_set);

        Self {
            id,
            owner_id,
            body_handle,
            damage: bullet_damage
        }
    }
}
