use crate::groups::{BIT_BULLET, BIT_PLAYER, BULLET_GROUP, NONE_GROUP, PLAYER_GROUP, WALL_GROUP};
use rapier2d::{glamx::vec2, prelude::*};

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
    pub shoot_cooldown: f32,
}

pub struct Bullet {
    pub id: u32,
    pub owner_id: u32,
    pub body_handle: RigidBodyHandle,
    pub damage: i32,
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
            damage: bullet_damage,
        }
    }
}

impl Player {
    pub fn new(
        id: u32,
        x: f32,
        y: f32,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
    ) -> Self {
        let rigid_body = RigidBodyBuilder::dynamic()
            .translation(vec2(x, y))
            .lock_rotations()
            .can_sleep(false)
            .build();

        let body_handle = rigid_body_set.insert(rigid_body);

        //HitBox
        let collider = ColliderBuilder::capsule_y(0.1, 0.4)
            .user_data(BIT_PLAYER | id as u128)
            .collision_groups(InteractionGroups::new(
                PLAYER_GROUP,
                Group::all(),
                InteractionTestMode::And,
            ))
            .restitution(0.0)
            .friction(0.0)
            .build();

        let collider_handle =
            collider_set.insert_with_parent(collider, body_handle, rigid_body_set);

        Self {
            id,
            body_handle,
            collider_handle,
            vertical_velocity: 0.0,
            is_on_ground: false,
            hp: 100,
            facing_right: true,
            respawn_timer: 0.0,
            last_processed_input_id: 0,
            mouse_angle: 0.0,
            current_gun: String::from("pistol"),
            shoot_cooldown: 0.2,
        }
    }

    pub fn check_is_alive(
        &mut self,
        bullet_damage: i32,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
    ) {
        self.hp -= bullet_damage;
        if (self.hp <= 0) {
            self.respawn_timer = 3.0;
            if let Some(collider) = collider_set.get_mut(self.collider_handle) {
                collider.set_collision_groups(InteractionGroups::new(
                    NONE_GROUP,
                    NONE_GROUP,
                    InteractionTestMode::And,
                ));
            }
            if let Some(rb) = rigid_body_set.get_mut(self.body_handle) {
                rb.set_linvel(vec2(0.0, 0.0), true);
                rb.set_gravity_scale(0.0, true);
                rb.set_translation(rb.translation(), true);
            }
        }
    }

    pub fn check_for_respawn(
        &mut self,
        delta: f32,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
    ) {
        if self.respawn_timer > 0.0 {
            self.respawn_timer -= delta;

            if self.respawn_timer <= 0.0 {
                self.respawn_timer = 0.0;

                self.hp = 100;

                if let Some(collider) = collider_set.get_mut(self.collider_handle) {
                    collider.set_collision_groups(InteractionGroups::new(
                        PLAYER_GROUP,
                        Group::all(),
                        InteractionTestMode::And,
                    ));
                }

                if let Some(rb) = rigid_body_set.get_mut(self.body_handle) {
                    rb.set_linvel(Vec2::new(0.0, 0.0), true);
                    rb.set_gravity_scale(1.0, true);
                    rb.set_translation(Vec2::new(10.0, 5.0), true);
                }

                println!("Igrač {} se vratio u igru!", self.id);
            }
        }
    }

    pub fn check_for_shoot_cooldown(&mut self, delta: f32) {
        if self.shoot_cooldown > 0.0 {
            self.shoot_cooldown -= delta;
        }
    }
}
