use std::{collections::HashMap, net::SocketAddr, sync::Arc, time::Instant};

use crate::{
    game_physics::GameStateModel,
    groups::{
        BIT_BULLET, BIT_PLAYER, BIT_TOWER, BULLET_GROUP, NONE_GROUP, PLAYER_GROUP, TOWER_GROUP,
        WALL_GROUP,
    },
    level_loader::SpawnPosition,
    lobby::{GameModeSettings, Lobby, LobbyHandler, TowersGameModeSettings},
    network_protocol::{GunEnum, KillEvent, KillFeed, PlayerSkin},
    rest_api::service::RestService,
};
use rand::Rng;
use rapier2d::{control::KinematicCharacterController, glamx::vec2, na::Isometry, prelude::*};
use tokio::sync::Mutex;

pub struct Player {
    pub id: u32,
    pub nickname: String,
    pub body_handle: RigidBodyHandle, // Vodi računa o poziciji, brzini, gravitaciji... da ne bih morao ručno
    pub collider_handle: ColliderHandle, // Kolider koji se koristi kako bi se utvrdilo da li je nešto prošlo kroz igrača
    pub vertical_velocity: f32,
    pub horizontal_velocity: f32,
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
    pub last_seen: Instant,
    pub player_skin: u8, //0-GREEN, 1-BLUE, 2...
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

#[derive(Clone, Copy)]
pub struct Bullet {
    pub id: u32,
    pub owner_id: u32,
    pub body_handle: RigidBodyHandle,
    pub damage: i32,
    pub angle: f32,
    pub gun: GunEnum,
    pub spawn_position: [f32; 2]
}

pub struct Tower {
    pub id: u32,
    pub owner_id: u32,
    pub position: [f32; 2], // Kule su uvek u istom položaju, moguća i kasnija zamena sa RigidBodyHandler-om
    pub hp: i32,
    pub collider_handle: ColliderHandle,
    pub can_be_damaged: bool,
    pub is_left_tower: bool,
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
        mouse_angle: f32,
        gun: &GunEnum,
        player_position: [f32; 2],
        is_facing_right: bool,
        bullet_speed: f32,
        bullet_damage: i32,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
    ) -> Self {
        let [spawn_position_x, spawn_position_y] = Bullet::calculate_bullet_spawn_position(
            player_position,
            mouse_angle,
            is_facing_right,
            gun,
        );
        let rigid_body = RigidBodyBuilder::dynamic()
            .translation(Vec2::new(spawn_position_x, spawn_position_y))
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
            spawn_position: [spawn_position_x, spawn_position_y]
        }
    }

    pub fn calculate_bullet_spawn_position(
        player_pos: [f32; 2],
        angle: f32,
        facing_right: bool,
        gun: &GunEnum,
    ) -> [f32; 2] {
        let (mut ox, mut oy) = match gun {
            GunEnum::Pistol => (0.625, -0.078125),
            GunEnum::M4A1Rifle => (0.67638, -0.1079),
        };
        if !facing_right {
            oy = -oy;
        }
        // x' = x * cos(a) - y * sin(a)
        // y' = x * sin(a) + y * cos(a)

        let rotated_x = ox * angle.cos() - oy * angle.sin();
        let rotated_y = ox * angle.sin() + oy * angle.cos();

        [player_pos[0] + rotated_x, player_pos[1] + rotated_y]
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
        player_skin: u8,
    ) -> Self {
        let rigid_body = RigidBodyBuilder::kinematic_position_based()
            .translation(vec2(x, y))
            .lock_rotations()
            .can_sleep(false)
            .build();

        let body_handle = rigid_body_set.insert(rigid_body);

        //HitBox
        let collider = ColliderBuilder::cuboid(0.24, 0.5) //0.4 //0.24
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
            horizontal_velocity: 0.0,
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
            last_seen: Instant::now(),
            player_skin,
        }
    }

    pub fn check_is_alive(
        &mut self,
        bullet: &Bullet,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
        kill_feed: &mut KillFeed,
        towers: &mut HashMap<u32, Tower>,
        players_ids: Vec<u32>,
        players_score: &mut HashMap<u32, u8>,
        lobby: Arc<Mutex<Lobby>>,
        is_game_finished: &mut bool,
        winner_id: &mut u32,
        lobby_settings: &GameModeSettings,
    ) {
        self.hp -= bullet.damage;
        if self.hp <= 0 {
            // Ako je igrac eliminisan
            self.respawn_timer = 5.0;

            // kill_feed.add_kill_feed(bullet.owner_id, self.id, bullet.gun);

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

            //Azuriraj tabelu (scoreboard)
            let current_score = players_score.entry(bullet.owner_id).or_insert(0);
            *current_score += 1;

            if let GameModeSettings::FFA(settings) = lobby_settings {
                if *current_score >= settings.points_to_win {
                    *is_game_finished = true;
                    *winner_id = bullet.owner_id;
                }
            }

            let lobby_arc = lobby.clone();
            let ids_clone = players_ids.clone();
            let score_clone = players_score.clone();
            let killer_id: u32 = bullet.owner_id;
            let victim_id: u32 = self.id;
            let gun: GunEnum = bullet.gun;

            tokio::spawn(async move {
                let mut lobby = lobby_arc.lock().await;
                RestService::send_scoreboard_update(&mut lobby, killer_id, victim_id, gun);
            });
        }
    }

    pub fn check_for_respawn(
        &mut self,
        delta: f32,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
        towers: &mut HashMap<u32, Tower>,
        spawn_positions: &Vec<SpawnPosition>,
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

                //Dobavljanje nasumicne spawn pozicije
                let mut rng: rand::prelude::ThreadRng = rand::thread_rng();
                let random_index: usize = rng.gen_range(0..spawn_positions.len());
                let random_spawn_position: &SpawnPosition =
                    spawn_positions.get(random_index).unwrap();

                if let Some(rb) = rigid_body_set.get_mut(self.body_handle) {
                    rb.set_linvel(Vec2::new(0.0, 0.0), true);
                    rb.set_gravity_scale(1.0, true);
                    rb.set_translation(
                        Vec2::new(random_spawn_position.x, random_spawn_position.y),
                        true,
                    );
                }

                //println!("Igrac {} se vratio u igru!", self.id);
            }
        }
    }

    pub fn check_for_shoot_cooldown(&mut self, delta: f32) {
        if self.shoot_cooldown > 0.0 {
            self.shoot_cooldown -= delta;
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
                //println!("Server: Oružje dopunjeno!");
            }
        }
    }

    pub fn refill_all_weapon_ammo(&mut self) {
        for weapon in self.player_inventory.values_mut() {
            let mut gun: &mut Gun = match weapon {
                Weapon::PISTOL(pistol) => pistol,
                Weapon::M4A1Rifle(m4a1_rifle) => m4a1_rifle,
            };
            gun.current_ammo = gun.max_ammo;
        }
    }

    pub fn handle_movement(
        &mut self,
        custom_gravity: Vec2,
        delta: f32,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
        broad_phase: &BroadPhaseBvh,
        narrow_phase: &NarrowPhase,
        char_controller: KinematicCharacterController
    ) {
        let mut translation_to_apply = None;
        {
            let filter = QueryFilter::default()
                .exclude_rigid_body(self.body_handle)
                .groups(InteractionGroups::new(
                    Group::all(),
                    Group::all() ^ BULLET_GROUP ^ PLAYER_GROUP,
                    InteractionTestMode::And,
                ));

            let queries = broad_phase.as_query_pipeline(
                narrow_phase.query_dispatcher(),
                &rigid_body_set,
                &collider_set,
                filter,
            );
            //let player = self.players.get_mut(&player_id).expect("Player not found");

            if self.is_on_ground && self.vertical_velocity >= 0.0 {
                self.vertical_velocity = 0.0;
            }

            self.vertical_velocity += custom_gravity.y * delta;
            if self.vertical_velocity > 12.0 {
                self.vertical_velocity = 12.0;
            }

            if let Some(rb) = rigid_body_set.get(self.body_handle) {
                let collider_handle = rb.colliders()[0];
                let collider = &collider_set[collider_handle];

                let horizontal = vec2(self.horizontal_velocity * delta, 0.0);

                let result_x = char_controller.move_shape(
                    delta,
                    &queries,
                    collider.shape(),
                    rb.position(),
                    horizontal,
                    |_| {},
                );

                let pos_after_x = rb.position().translation + result_x.translation;

                let mut temp_pose = Pose::new(Vec2::new(pos_after_x.x, pos_after_x.y), 0.0);

                let vertical = vec2(0.0, self.vertical_velocity * delta);

                self.is_on_ground = false;
                let mut hit_ceiling = false;

                let result_y = char_controller.move_shape(
                    delta,
                    &queries,
                    collider.shape(),
                    &temp_pose,
                    vertical,
                    |collision| {
                        let normal = collision.hit.normal1;

                        if normal.y < -0.5 {
                            if self.vertical_velocity >= 0.0 {
                                self.is_on_ground = true;
                                self.vertical_velocity = 0.0;
                            }
                        }
                        if normal.y > 0.5 {
                            if self.vertical_velocity < 0.0 {
                                hit_ceiling = true;
                            }
                        }
                    },
                );

                let mut final_translation = result_x.translation + result_y.translation;

                if hit_ceiling {
                    self.vertical_velocity = 0.0;
                    final_translation.y += 0.05;
                }

                translation_to_apply = Some(final_translation);
            }
        }

        if let Some(translation) = translation_to_apply {
            let rb_mut = rigid_body_set.get_mut(self.body_handle).unwrap();
            let new_pos = rb_mut.position().translation + translation;
            rb_mut.set_next_kinematic_translation(new_pos.into());
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

        let half_width = 3.875;
        let half_height = 3.4375;

        //HitBox
        let collider = ColliderBuilder::cuboid(half_width, half_height) // Visina 224px, sirina 64px
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
            is_left_tower,
        }
    }
}
