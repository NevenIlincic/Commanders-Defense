use crate::{
    entities::{Bullet, GunStats, Player, Tower, Weapon, WeaponType},
    groups::{BIT_BULLET, BIT_PLAYER, BIT_TOWER, BULLET_GROUP, NONE_GROUP, PLAYER_GROUP},
    level_loader::{LevelLoader, SpawnPosition, TowerPosition},
    lobby::{self, GameModeSettings, Lobby, LobbyHandler, LobbyPlayer},
    network_protocol::{
        BulletDestroy, BulletEvent, BulletSnapshot, ClientInput, CommandEnum, GameEnd, GameState, KillEvent, KillFeed, PlayerSkin, ServerMessage, TowerDamaged, TowerEvent, TowerSnapshot
    },
    rest_api::service::RestService,
};
use rand::Rng;
use rapier2d::{control::CharacterLength, geometry::CollisionEvent};
use rapier2d::{control::KinematicCharacterController, parry::query::DefaultQueryDispatcher};
use rapier2d::{glamx::vec2, prelude::*};
use rapier2d::{
    na::{Isometry, Isometry2},
    pipeline::{ChannelEventCollector, QueryFilter},
};
use serde::de;
use std::{collections::HashMap, net::SocketAddr};
use std::{
    sync::{
        Arc,
        mpsc::{self, Receiver, Sender},
    },
    time::Instant,
};
use tokio::{net::UdpSocket, sync::Mutex};
pub struct GameStateModel {
    //Interni model koji omogućava da Rapier2d biblioteka mapira i računa kolizije
    //Entiteti koji postoje na Godot sceni
    pub lobby_id: u32,
    pub next_player_id: u32,
    pub players: HashMap<u32, Player>,
    pub address_to_players: HashMap<SocketAddr, u32>,
    pub max_players: u8,

    pub next_bullet_id: u32,
    pub bullets: HashMap<u32, Bullet>,
    pub bullet_events: Vec<BulletEvent>,

    pub next_tower_id: u32,
    pub towers: HashMap<u32, Tower>,
    pub tower_events: Vec<TowerEvent>,

    pub players_score: HashMap<u32, u8>, //player_id, score(kills)
    pub kill_feed: KillFeed,

    pub lobby: Arc<Mutex<Lobby>>,
    pub socket: Arc<UdpSocket>,
    pub level_loader: LevelLoader,
    pub spawn_positions: Vec<SpawnPosition>,
    pub tower_positions: Vec<TowerPosition>,

    pub time_to_reset: f32,
    pub is_game_finished: bool,
    pub is_game_suspended: bool,
    pub lobby_settings: GameModeSettings,
    pub winner_id: u32,

    //Neophodno kako bi Rapier2d biblioteka optimizovala i mogla da vrši neophodno računanje
    pub rigid_body_set: RigidBodySet,
    pub collider_set: ColliderSet,
    pub physics_pipeline: PhysicsPipeline,
    pub island_manager: IslandManager,
    pub broad_phase: DefaultBroadPhase,
    pub narrow_phase: NarrowPhase,
    pub impulse_joint_set: ImpulseJointSet,
    pub multibody_joint_set: MultibodyJointSet,
    pub ccd_solver: CCDSolver,
    pub integration_parameters: IntegrationParameters,
    pub char_controller: KinematicCharacterController,
    pub collision_send: Sender<CollisionEvent>,
    pub collision_recv: Receiver<CollisionEvent>,
    // Dodajemo i ovo:
    pub force_send: Sender<ContactForceEvent>,
    pub force_recv: Receiver<ContactForceEvent>,
}

impl GameStateModel {
    pub fn new(
        udp_socket: Arc<UdpSocket>,
        lobby_settings: GameModeSettings,
        lobby: Arc<Mutex<Lobby>>,
        lobby_id: u32,
        max_players: u8,
    ) -> Self {
        let selected_map_index: u8 = match &lobby_settings {
            GameModeSettings::TOWERS(settings) => settings.selected_map,
            GameModeSettings::FFA(settings) => settings.selected_map,
        };
        let selected_map: &str = match selected_map_index {
            0 => "Grassy_Field_1.json",
            1 => "Grassy_Field_2.json",
            _ => "",
        };
        let (c_send, c_recv) = mpsc::channel();
        let (f_send, f_recv) = mpsc::channel();
        let level_path = format!("../maps/{}", selected_map);
        let level_loader: LevelLoader = LevelLoader::new(&level_path);
        let mut controller = KinematicCharacterController::default();
        controller.slide = true;
        Self {
            lobby_id,

            next_player_id: 1,
            players: HashMap::new(),
            address_to_players: HashMap::new(),
            max_players,

            next_bullet_id: 1,
            bullets: HashMap::new(),
            bullet_events: Vec::new(),

            //Tower Game Mode
            next_tower_id: 1,
            towers: HashMap::new(),
            tower_events: Vec::new(),

            //FFA Game Mode
            players_score: HashMap::new(),

            kill_feed: KillFeed::new(),

            // lobby_handler,
            lobby,
            socket: udp_socket,
            level_loader,
            spawn_positions: Vec::new(),
            tower_positions: Vec::new(),

            time_to_reset: 3.0,
            is_game_finished: false,
            is_game_suspended: false,
            lobby_settings,
            winner_id: 0,

            rigid_body_set: RigidBodySet::new(),
            collider_set: ColliderSet::new(),
            physics_pipeline: PhysicsPipeline::new(),
            island_manager: IslandManager::new(),
            broad_phase: DefaultBroadPhase::new(),
            narrow_phase: NarrowPhase::new(),
            impulse_joint_set: ImpulseJointSet::new(),
            multibody_joint_set: MultibodyJointSet::new(),
            ccd_solver: CCDSolver::new(),
            integration_parameters: IntegrationParameters::default(),
            char_controller: controller,
            collision_send: c_send,
            collision_recv: c_recv,
            force_send: f_send,
            force_recv: f_recv,
        }
    }

    pub fn load_level(&mut self) {
        self.level_loader.load_level(
            &mut self.rigid_body_set,
            &mut self.collider_set,
            &mut self.spawn_positions,
            &mut self.tower_positions,
        );
    }

    pub fn get_random_spawn_position(&self) -> SpawnPosition {
        let mut rng: rand::prelude::ThreadRng = rand::thread_rng();
        let random_index: usize = rng.gen_range(0..self.spawn_positions.len());
        let random_spawn_position: &SpawnPosition = self.spawn_positions.get(random_index).unwrap();
        SpawnPosition {
            x: random_spawn_position.x,
            y: random_spawn_position.y,
        }
    }

    pub fn add_player(
        &mut self,
        id: u32,
        player_nickname: &String,
        x: f32,
        y: f32,
        player_skin: u8,
    ) {
        if self.players.len() < self.max_players as usize {
            let spawn_position: SpawnPosition = self.get_random_spawn_position();
            let mut new_player: Player = Player::new(
                id,
                player_nickname,
                spawn_position.x,
                spawn_position.y,
                &mut self.rigid_body_set,
                &mut self.collider_set,
                player_skin,
            );

            new_player.tower_id = Some(self.next_tower_id);
            self.players.insert(id, new_player);
            if !self.players_score.contains_key(&id) {
                self.players_score.insert(id, 0);
            }
            println!("Igrač {} uspešno ubačen u svet na [{}, {}]", id, x, y);
            // Dodavanje kule
            if self.towers.len() == 0 {
                self.add_tower(
                    id,
                    self.tower_positions[0].x,
                    self.tower_positions[0].y,
                    true,
                );
            } else if self.towers.len() == 1 {
                self.add_tower(
                    id,
                    self.tower_positions[1].x,
                    self.tower_positions[1].y,
                    false,
                );
            }
        }
    }

    fn add_tower(&mut self, owner_id: u32, x: f32, y: f32, is_left_tower: bool) {
        let tower_max_hp = match &self.lobby_settings {
            GameModeSettings::TOWERS(settings) => settings.towers_max_hp,
            _ => {
                return;
            }
        };

        let new_tower: Tower = Tower::new(
            self.next_tower_id,
            owner_id,
            x,
            y,
            tower_max_hp,
            is_left_tower,
            &mut self.rigid_body_set,
            &mut self.collider_set,
        );
        self.towers.insert(self.next_tower_id, new_tower);
        self.tower_events.push(TowerEvent::CREATED(TowerSnapshot { id: self.next_tower_id, owner_id: owner_id, hp: tower_max_hp, is_left_tower }));
        self.next_tower_id += 1;
        //println!("KULA DODATA!");
    }

    pub async fn handle_client_input(&mut self, input: ClientInput, ip_address: SocketAddr) {
        //Dobavljanje igraca
        let player_id: u32 = if let Some(&id) = self.address_to_players.get(&ip_address) {
            id as u32
        } else {
            return;
        };

        //Obrada input-a
        if let Some(player) = self.players.get_mut(&player_id) {
            player.last_seen = Instant::now();

            if player.last_processed_input_id >= input.input_id {
                return;
            }
            player.last_processed_input_id = input.input_id; // player je vlasnik input_id

            if player.respawn_timer > 0.0 {
                player.mouse_angle = input.mouse_angle;
                return;
            }
            let mut reset_reloads: bool = false;
            let mut player_position_x: f32 = 0.0;
            let mut player_position_y: f32 = 0.0;
            if let Some(rb) = self.rigid_body_set.get_mut(player.body_handle) {
                let speed = 10.0;
                let mut x_vel = 0.0;
                player_position_x = rb.position().translation.x;
                player_position_y = rb.position().translation.y;

                player.horizontal_velocity = 0.0;
                if input.move_left {
                    player.horizontal_velocity -= speed;
                }
                if input.move_right {
                    player.horizontal_velocity += speed;
                }
                if player.current_gun != input.gun {
                    player.shoot_cooldown = 0.2;
                    reset_reloads = true;
                }
                player.current_gun = input.gun;
                player.mouse_angle = input.mouse_angle;
                if input.mouse_angle.cos() > 0.0 {
                    player.facing_right = true;
                } else {
                    player.facing_right = false;
                }

                //GRAVITACIJA
                if (input.jump && player.is_on_ground && player.vertical_velocity >= 0.0) {
                    player.vertical_velocity = -12.0;
                    player.is_on_ground = false;
                    rb.translation().y -= 0.3125;
                }
            }

            let Some(weapon_type_enum) = WeaponType::get_type_from_str(&player.current_gun) else {
                return;
            };
            let Some(weapon_enum) = player.player_inventory.get_mut(&weapon_type_enum) else {
                return;
            };

            let mut gun = match weapon_enum {
                Weapon::PISTOL(gun) => gun,
                Weapon::M4A1Rifle(gun) => gun,
            };

            if reset_reloads {
                gun.is_reloading = false;
                gun.reload_time_left = 0.0;
            }
            if input.command == CommandEnum::RELOAD {
                //println!("Primljena komanda: {:?}", input.command);
                if !gun.is_reloading && gun.current_ammo < gun.max_ammo {
                    gun.is_reloading = true;
                    gun.reload_time_left = gun.reload_time;
                    //println!("Server: Reload započet!");
                }
            }
            player.is_reloading = gun.is_reloading;
            player.current_ammo = gun.current_ammo;
            if (input.shoot
                && player.shoot_cooldown <= 0.0
                && !gun.is_reloading
                && gun.current_ammo > 0)
            {
                player.shoot_cooldown = gun.fire_rate;
                gun.current_ammo -= 1;
                //println!("{}/{}", gun.current_ammo, gun.max_ammo);
                let new_bullet_id: u32 = self.next_bullet_id;
                self.next_bullet_id += 1;
                let created_bullet: Bullet = Bullet::new(
                    new_bullet_id,
                    player_id,
                    input.mouse_angle,
                    &player.current_gun,
                    [player_position_x, player_position_y],
                    player.facing_right,
                    gun.bullet_speed,
                    gun.damage,
                    &mut self.rigid_body_set,
                    &mut self.collider_set,
                );
                self.bullets.insert(created_bullet.id, created_bullet);
                self.bullet_events
                    .push(BulletEvent::CREATED(BulletSnapshot {
                        id: created_bullet.id,
                        position: created_bullet.spawn_position,
                        owner_id: created_bullet.owner_id,
                        angle: created_bullet.angle,
                        gun: created_bullet.gun,
                    }));
            }
        }
    }

    pub fn remove_player_by_addr(&mut self, ip_address: SocketAddr) {
        if let Some(player_id) = self.address_to_players.remove(&ip_address) {
            if let Some(player) = self.players.remove(&player_id) {
                self.rigid_body_set.remove(
                    player.body_handle,
                    &mut self.island_manager,
                    &mut self.collider_set,
                    &mut self.impulse_joint_set,
                    &mut self.multibody_joint_set,
                    true,
                );

                let tower_id = player.tower_id.unwrap();
                if let Some(tower) = self.towers.remove(&tower_id) {
                    self.collider_set.remove(
                        tower.collider_handle,
                        &mut self.island_manager,
                        &mut self.rigid_body_set,
                        true,
                    );
                }
                //self.players_score.remove(&player.id);
            }
        }
    }

    pub fn update(&mut self, delta: f32) {
        let custom_gravity = vec2(0.0, 15.0);

        for player in self.players.values_mut() {
            player.handle_movement(
                custom_gravity,
                delta,
                &mut self.rigid_body_set,
                &mut self.collider_set,
                &self.broad_phase,
                &self.narrow_phase,
                self.char_controller,
            );
            player.check_for_shoot_cooldown(delta);
            player.check_for_respawn(
                delta,
                &mut self.rigid_body_set,
                &mut self.collider_set,
                &mut self.towers,
                &self.spawn_positions,
            );
            player.check_gun_reload(delta);
        }

        if self.is_game_finished {
            self.time_to_reset -= delta;
            if self.time_to_reset <= 0.0 {
                return;
            }
        }

        let gravity = vec2(0.0, 0.0); //(0.0, 15.0)
        let event_handler =
            ChannelEventCollector::new(self.collision_send.clone(), self.force_send.clone());
        self.physics_pipeline.step(
            gravity,
            &self.integration_parameters,
            &mut self.island_manager,
            &mut self.broad_phase,
            &mut self.narrow_phase,
            &mut self.rigid_body_set,
            &mut self.collider_set,
            &mut self.impulse_joint_set,
            &mut self.multibody_joint_set,
            &mut self.ccd_solver,
            &(),
            &event_handler,
        );

        self.handle_object_collisions();
    }

    fn handle_object_collisions(&mut self) {
        while let Ok(event) = self.collision_recv.try_recv() {
            match event {
                CollisionEvent::Started(handle1, handle2, _) => {
                    let data1 = self.collider_set.get(handle1).map(|c| c.user_data);
                    let data2 = self.collider_set.get(handle2).map(|c| c.user_data);

                    if let (Some(d1), Some(d2)) = (data1, data2) {
                        self.process_collision(handle1, d1, handle2, d2);
                    }
                }
                CollisionEvent::Stopped(_, _, _) => {}
            }
        }
    }

    fn process_collision(&mut self, h1: ColliderHandle, d1: u128, h2: ColliderHandle, d2: u128) {
        self.check_hit(h1, d1, h2, d2);
        self.check_hit(h2, d2, h1, d1);
    }

    fn check_hit(
        &mut self,
        bullet_handle: ColliderHandle,
        bullet_data: u128,
        target_handle: ColliderHandle,
        target_data: u128,
    ) {
        if (bullet_data & BIT_BULLET) != 0 {
            //Ako je metak
            let bullet_id = (bullet_data ^ BIT_BULLET) as u32;

            if (target_data & BIT_PLAYER) != 0 {
                /// Ako je metak pogodio nekog igraca
                let player_id = (target_data ^ BIT_PLAYER) as u32;

                if let Some(player) = self.players.get_mut(&player_id) {
                    if let Some(bullet) = self.bullets.get(&bullet_id) {
                        if bullet.owner_id != player.id {
                            // Ako je pogodio neprijatelja
                            if !self.is_game_finished {
                                let players_id: Vec<u32> =
                                    self.players_score.keys().cloned().collect();
                                player.check_is_alive(
                                    bullet,
                                    &mut self.rigid_body_set,
                                    &mut self.collider_set,
                                    &mut self.kill_feed,
                                    &mut self.towers,
                                    players_id,
                                    &mut self.players_score,
                                    self.lobby.clone(),
                                    &mut self.is_game_finished,
                                    &mut self.winner_id,
                                    &self.lobby_settings,
                                );
                                println!(
                                   "Igrač {} pogođen! Preostali HP: {}",
                                    player_id, player.hp
                                );
                                self.remove_bullet(bullet_id);
                            }
                        }
                    }
                }
            } else if (target_data & BIT_TOWER) != 0 {
                //Ako je metak pogodio neku kulu
                let tower_id = (target_data ^ BIT_TOWER) as u32;
                if let Some(checking_tower) = self.towers.get_mut(&tower_id) {
                    if let Some(bullet) = self.bullets.get(&bullet_id) {
                        if (bullet.owner_id != checking_tower.owner_id)
                            && (checking_tower.can_be_damaged)
                        {
                            if !self.is_game_finished {
                                // Ako je igrac pogodio tudju kulu
                                checking_tower.hp -= bullet.damage;
                                // println!("KULA HP: {}", checking_tower.hp);
                                self.tower_events.push(TowerEvent::DAMAGED(TowerDamaged { id: tower_id, owner_id: bullet.owner_id, hp: checking_tower.hp }));
                                // Ako je necija kula/hangar unisten
                                if checking_tower.hp <= 0 {
                                    self.is_game_finished = true;
                                    let winner_id = bullet.owner_id;
                                    let socket = self.socket.clone(); // Socket mora biti Arc<UdpSocket> da bi se klonirao
                                    let addresses: Vec<_> =
                                        self.address_to_players.keys().cloned().collect();

                                    self.winner_id = winner_id;
                                  
                                }
                            }
                        }
                    }
                }
                self.remove_bullet(bullet_id);
            } else {
                // println!("Metak {} je udario u prepreku/zid.", bullet_id);
                self.remove_bullet(bullet_id);
            }
        }
    }

    fn remove_bullet(&mut self, bullet_id: u32) {
        if let Some(bullet) = self.bullets.remove(&bullet_id) {
            let destroyed_position = {
                let rb = self.rigid_body_set.get(bullet.body_handle).unwrap();
                let x = rb.translation().x;
                let y: f32 = rb.translation().y;
                [x, y]
            };
            self.rigid_body_set.remove(
                bullet.body_handle,
                &mut self.island_manager,
                &mut self.collider_set,
                &mut self.impulse_joint_set,
                &mut self.multibody_joint_set,
                true,
            );
            self.bullet_events
                .push(BulletEvent::DESTROYED(BulletDestroy {
                    id: bullet_id,
                    position: destroyed_position,
                }));
            //println!("Metak {} obrisan iz sveta.", bullet_id);
        }
    }

    pub async fn check_for_disconnection(&mut self, player_address: SocketAddr) {
        println!("U DISKONEKCIJI SAM!");
        self.remove_player_by_addr(player_address);
        if self.address_to_players.len() == 1 {
            let Some(winner_id) = self.address_to_players.values().next() else {
                return;
            };
            self.winner_id = *winner_id;
            self.is_game_finished = true;
        }
    }
}
