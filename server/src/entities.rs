use std::{collections::HashMap, time::Instant};

use crate::{
    game_physics::GameStateModel,
    groups::{
        BIT_BULLET, BIT_PLAYER, BIT_TOWER, BULLET_GROUP, NONE_GROUP, PLAYER_GROUP, TOWER_GROUP,
        WALL_GROUP,
    },
    network_protocol::{GunEnum, KillEvent, KillFeed},
};
use rapier2d::{glamx::vec2, na::Isometry, prelude::*};

pub struct Player {
    pub id: u32,
    pub nickname: String,
    pub body_handle: RigidBodyHandle, // Vodi računa o poziciji, brzini, gravitaciji... da ne bih morao ručno
    pub collider_handle: ColliderHandle, // Kolider koji se koristi kako bi se utvrdilo da li je nešto prošlo kroz igrača
    pub vertical_velocity: f32,
    pub is_on_ground: bool,
    pub hp: i32,
    pub facing_right: bool,
    pub respawn_timer: f32,
    pub last_processed_input_id: u32,
    pub mouse_angle: f32,
    pub current_gun: GunEnum,
    pub shoot_cooldown: f32,
    pub player_inventory: HashMap<WeaponType, Weapon>,
    pub is_reloading: bool,
    pub current_ammo: i16,
    pub tower_id: Option<u32>, // Ako je gameMode sa kulama
    pub last_seen: Instant
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum WeaponType {
    PISTOL,
    M4A1Rifle,
}

impl WeaponType {
    pub fn get_type_from_str(gun_name: &GunEnum) -> Option<Self> {
        match gun_name {
            GunEnum::Pistol => Some(WeaponType::PISTOL),
            GunEnum::M4A1Rifle => Some(WeaponType::M4A1Rifle),
            _ => None,
        }
    }
}

pub enum Weapon {
    PISTOL(Gun),
    M4A1Rifle(Gun),
}

pub struct Gun {
    pub fire_rate: f32,
    pub bullet_speed: f32,
    pub damage: i32,
    pub current_ammo: i16,
    pub max_ammo: i16,
    pub is_reloading: bool,
    pub reload_time: f32,
    pub reload_time_left: f32,
}

pub struct Bullet {
    pub id: u32,
    pub owner_id: u32,
    pub body_handle: RigidBodyHandle,
    pub damage: i32,
    pub angle: f32,
    pub gun: GunEnum,
}

pub struct Tower {
    pub id: u32,
    pub owner_id: u32,
    pub position: [f32; 2], // Kule su uvek u istom položaju, moguća i kasnija zamena sa RigidBodyHandler-om
    pub hp: i32,
    pub collider_handle: ColliderHandle,
    pub can_be_damaged: bool,
    pub is_left_tower: bool
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
        gun: &GunEnum,
        bullet_speed: f32,
        bullet_damage: i32,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
    ) -> Self {
        let rigid_body = RigidBodyBuilder::dynamic()
            .translation(Vec2::new(spawn_position[0], spawn_position[1]))
            .linvel(Vec2::new(mouse_angle.cos(), mouse_angle.sin()) * bullet_speed)
            .gravity_scale(0.0)
            .lock_rotations()
            .ccd_enabled(true)
            .build();

        let body_handle = rigid_body_set.insert(rigid_body);

        let collider: Collider = ColliderBuilder::ball(0.125)
            .user_data(BIT_BULLET | id as u128)
            .active_events(ActiveEvents::COLLISION_EVENTS)
            .sensor(true)
            .collision_groups(InteractionGroups::new(
                BULLET_GROUP,
                WALL_GROUP | PLAYER_GROUP | TOWER_GROUP,
                InteractionTestMode::And,
            ))
            .build();

        collider_set.insert_with_parent(collider, body_handle, rigid_body_set);

        Self {
            id,
            owner_id,
            body_handle,
            damage: bullet_damage,
            angle: mouse_angle,
            gun: gun.clone(),
        }
    }
}

impl Player {
    pub fn new(
        id: u32,
        player_nickname: &String,
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
        let collider = ColliderBuilder::capsule_y(0.1, 0.35) //0.4
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

        let mut player_inventory: HashMap<WeaponType, Weapon> = HashMap::new();
        player_inventory.insert(
            WeaponType::PISTOL,
            Weapon::PISTOL(Gun {
                fire_rate: 0.1,
                bullet_speed: 25.0,
                damage: 10,
                current_ammo: 12,
                max_ammo: 12,
                reload_time: 2.0,
                reload_time_left: 0.0,
                is_reloading: false,
            }),
        );
        player_inventory.insert(
            WeaponType::M4A1Rifle,
            Weapon::M4A1Rifle(Gun {
                fire_rate: 0.1,
                bullet_speed: 30.0,
                damage: 5,
                current_ammo: 30,
                max_ammo: 30,
                reload_time: 3.0,
                reload_time_left: 0.0,
                is_reloading: false,
            }),
        );

        Self {
            id,
            nickname: player_nickname.clone(),
            body_handle,
            collider_handle,
            vertical_velocity: 0.0,
            is_on_ground: false,
            hp: 100,
            facing_right: true,
            respawn_timer: 0.0,
            last_processed_input_id: 0,
            mouse_angle: 0.0,
            current_gun: GunEnum::Pistol,
            shoot_cooldown: 0.2,
            player_inventory,
            is_reloading: false,
            current_ammo: 12,
            tower_id: None,
            last_seen: Instant::now()
        }
    }

    pub fn check_is_alive(
        &mut self,
        bullet: &Bullet,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
        kill_feed: &mut KillFeed,
        towers: &mut HashMap<u32, Tower>,
    ) {
        self.hp -= bullet.damage;
        if self.hp <= 0 {
            // Ako je igrac eliminisan
            self.respawn_timer = 5.0;

            kill_feed.add_kill_feed(bullet.owner_id, self.id, bullet.gun);

            if let Some(player_tower_id) = self.tower_id {
                if let Some(player_tower) = towers.get_mut(&player_tower_id) {
                    player_tower.can_be_damaged = true;
                }
            }

            if let Some(collider) = collider_set.get_mut(self.collider_handle) {
                collider.set_collision_groups(InteractionGroups::new(
                    NONE_GROUP,
                    WALL_GROUP,
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
        towers: &mut HashMap<u32, Tower>,
    ) {
        if self.respawn_timer > 0.0 {
            self.respawn_timer -= delta;

            if self.respawn_timer <= 0.0 {
                // Ako je igrac oziveo
                self.respawn_timer = 0.0;

                self.hp = 100;
                self.refill_all_weapon_ammo();

                if let Some(player_tower_id) = self.tower_id {
                    if let Some(player_tower) = towers.get_mut(&player_tower_id) {
                        player_tower.can_be_damaged = false;
                    }
                }

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

    pub fn check_is_on_ground(
        &mut self,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
        broad_phase: &mut DefaultBroadPhase,
        narrow_phase: &mut NarrowPhase,
    ) {
        if let Some(rb) = rigid_body_set.get(self.body_handle) {
            let pos = rb.translation();

            let filter = QueryFilter::default()
                .exclude_rigid_body(self.body_handle)
                .groups(InteractionGroups::new(
                    Group::all(),
                    Group::all() ^ BULLET_GROUP,
                    InteractionTestMode::And,
                ));

            let query_pipeline = broad_phase.as_query_pipeline(
                narrow_phase.query_dispatcher(),
                &rigid_body_set,
                &collider_set,
                filter,
            );
            let ray = Ray::new(vec2(pos.x, pos.y + 0.4), vec2(0.0, 1.0));

            self.is_on_ground = query_pipeline.cast_ray(&ray, 0.15, true).is_some();
        }
    }

    pub fn check_gun_reload(&mut self, delta: f32) {
        let Some(weapon_type_enum) = WeaponType::get_type_from_str(&self.current_gun) else {
            return;
        };
        let Some(weapon_enum) = self.player_inventory.get_mut(&weapon_type_enum) else {
            return;
        };

        let mut gun = match weapon_enum {
            Weapon::PISTOL(gun) => gun,
            Weapon::M4A1Rifle(gun) => gun,
        };

        if gun.current_ammo <= 0 && !gun.is_reloading {
            gun.is_reloading = true;
            gun.reload_time_left = gun.reload_time;
        }

        if gun.is_reloading {
            gun.reload_time_left -= delta;
            if gun.reload_time_left <= 0.0 {
                gun.current_ammo = gun.max_ammo;
                self.current_ammo = gun.current_ammo;
                gun.is_reloading = false;
                gun.reload_time_left = 0.0;
                println!("Server: Oružje dopunjeno!");
            }
        }
    }

    pub fn refill_all_weapon_ammo(&mut self){
        for weapon in self.player_inventory.values_mut(){
            let mut gun: &mut Gun = match weapon{
                Weapon::PISTOL(pistol) => {pistol},
                Weapon::M4A1Rifle(m4a1_rifle) => {m4a1_rifle}
            };
            gun.current_ammo = gun.max_ammo;
        }
    }
}

impl Tower {
    pub fn new(
        id: u32,
        owner_id: u32,
        x: f32,
        y: f32,
        hp: i32,
        is_left_tower: bool,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
    ) -> Self {
        let rigid_body = RigidBodyBuilder::fixed()
            .translation(vec2(x, y))
            .lock_rotations()
            .can_sleep(false)
            .build();

        let body_handle = rigid_body_set.insert(rigid_body);

        let radius = 3.5; // Sirina 64px
        let half_height = 10.5; // (2 * 6.5) + (2 * 1.0) = 15 units (480px)

        //HitBox
        let collider = ColliderBuilder::capsule_y(half_height, radius) // Visina 224px, sirina 64px
            .user_data(BIT_TOWER | id as u128)
            .collision_groups(InteractionGroups::new(
                TOWER_GROUP,
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
            owner_id,
            position: [x, y],
            hp, //2000
            collider_handle,
            can_be_damaged: false,
            is_left_tower
        }
    }
}
