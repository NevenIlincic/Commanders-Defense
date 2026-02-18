use crate::{
    entities::{Bullet, GunStats, Player, Tower, Weapon, WeaponType},
    groups::{BIT_BULLET, BIT_PLAYER, NONE_GROUP, PLAYER_GROUP},
    network_protocol::ClientInput,
};
use rapier2d::control::KinematicCharacterController;
use rapier2d::geometry::CollisionEvent;
use rapier2d::pipeline::{ChannelEventCollector, QueryFilter};
use rapier2d::{glamx::vec2, prelude::*};
use serde::de;
use std::sync::mpsc::{self, Receiver, Sender};
use std::{collections::HashMap, net::SocketAddr};
pub struct GameStateModel {
    //Interni model koji omogućava da Rapier2d biblioteka mapira i računa kolizije
    //Entiteti koji postoje na Godot sceni
    pub next_player_id: u32,
    pub players: HashMap<u32, Player>,
    pub address_to_players: HashMap<SocketAddr, u32>,

    pub next_bullet_id: u32,
    pub bullets: HashMap<u32, Bullet>,

    pub towers: HashMap<u32, Tower>,

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
    pub fn new() -> Self {
        let (c_send, c_recv) = mpsc::channel();
        let (f_send, f_recv) = mpsc::channel();
        // gun_stats.insert(
        //     "pistol".to_string(),
        //     GunStats {
        //         fire_rate: 0.1,
        //         bullet_speed: 25.0,
        //         damage: 10,
        //     },
        // );

        // gun_stats.insert(
        //     "m4a1_rifle".to_string(),
        //     GunStats {
        //         fire_rate: 0.1,
        //         bullet_speed: 30.0,
        //         damage: 5,
        //     },
        // );

        Self {
            next_player_id: 1,
            players: HashMap::new(),
            address_to_players: HashMap::new(),

            next_bullet_id: 1,
            bullets: HashMap::new(),
            towers: HashMap::new(),

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
            char_controller: KinematicCharacterController::default(),
            collision_send: c_send,
            collision_recv: c_recv,
            force_send: f_send,
            force_recv: f_recv,
        }
    }

    fn add_player(&mut self, id: u32, x: f32, y: f32) {
        let new_player: Player =
            Player::new(id, x, y, &mut self.rigid_body_set, &mut self.collider_set);
        self.players.insert(id, new_player);
        println!("Igrač {} uspešno ubačen u svet na [{}, {}]", id, x, y);
    }

    pub fn handle_client_input(&mut self, input: ClientInput, ip_address: SocketAddr) {
        if let Some(ref cmd) = input.command {
            if cmd == "DISCONNECT" {
                println!("Brisanje igrača na zahtev: {:?}", ip_address);
                self.remove_player_by_addr(ip_address);
                return;
            }
        }
        //Dobavljanje igraca
        let player_id: u32 = if let Some(&id) = self.address_to_players.get(&ip_address) {
            id as u32
        } else {
            let new_player_id: u32 = self.next_player_id;
            self.next_player_id += 1;
            self.add_player(new_player_id, 10.0, 10.0);
            self.address_to_players.insert(ip_address, new_player_id);
            println!("NOVI IGRAC!");
            new_player_id
        };

        //Obrada input-a
        if let Some(player) = self.players.get_mut(&player_id) {
            if player.last_processed_input_id >= input.input_id {
                return;
            }
            player.last_processed_input_id = input.input_id; // player je vlasnik input_id

            if player.respawn_timer > 0.0 {
                player.mouse_angle = input.mouse_angle;
                return;
            }
            let mut reset_reloads: bool = false;

            if let Some(rb) = self.rigid_body_set.get_mut(player.body_handle) {
                let speed = 10.0;
                let mut x_vel = 0.0;

                if input.move_left {
                    x_vel -= speed;
                }
                if input.move_right {
                    x_vel += speed;
                }
                if player.current_gun != input.gun {
                    player.shoot_cooldown = 0.2;
                    reset_reloads = true;
                }
                player.current_gun = input.gun; // player je vlasnik gun
                player.mouse_angle = input.mouse_angle; // player je vlasnik mouse_angle
                if input.mouse_angle.cos() > 0.0 {
                    player.facing_right = true;
                } else {
                    player.facing_right = false;
                }

                let current_vel = rb.linvel();
                rb.set_linvel(vec2(x_vel, current_vel.y), true);

                //GRAVITACIJA
                if (input.jump && player.is_on_ground) {
                    rb.set_linvel(vec2(x_vel, -12.0), true);
                    player.is_on_ground = false;
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

            if reset_reloads{
                gun.is_reloading = false;
                gun.reload_time_left = 0.0;
            }

            if let Some(ref cmd) = input.command {
                if cmd == "RELOAD" {
                    if !gun.is_reloading && gun.current_ammo < gun.max_ammo {
                        gun.is_reloading = true;
                        gun.reload_time_left = gun.reload_time;
                        println!("Server: Reload započet!");
                    }
                }
            }
            player.is_reloading = gun.is_reloading;
            player.current_ammo = gun.current_ammo;
            if (input.shoot
                && player.shoot_cooldown <= 0.0
                && !gun.is_reloading
                && gun.current_ammo > 0)
            {
                if let Some(bullet_positon) = input.bullet_spawn_position {
                    player.shoot_cooldown = gun.fire_rate;
                    gun.current_ammo -= 1;
                    println!("{}/{}", gun.current_ammo, gun.max_ammo);
                    let new_bullet_id: u32 = self.next_bullet_id;
                    self.next_bullet_id += 1;
                    let created_bullet: Bullet = Bullet::new(
                        new_bullet_id,
                        player_id,
                        bullet_positon,
                        input.mouse_angle,
                        &player.current_gun,
                        gun.bullet_speed,
                        gun.damage,
                        &mut self.rigid_body_set,
                        &mut self.collider_set,
                    );
                    self.bullets.insert(created_bullet.id, created_bullet);
                }
            }
        }
    }

    fn remove_player_by_addr(&mut self, ip_address: SocketAddr) {
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
            }
        }
    }

    pub fn update(&mut self) {
        let delta = 0.016;
        for player in self.players.values_mut() {
            player.check_for_shoot_cooldown(delta);
            player.check_for_respawn(delta, &mut self.rigid_body_set, &mut self.collider_set);
            player.check_gun_reload(delta);
        }

        let gravity = vec2(0.0, 15.0); //(0.0, 15.0)
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

        self.check_grounded_status();
        self.handle_object_collisions();
    }

    fn check_grounded_status(&mut self) {
        for player in self.players.values_mut() {
            player.check_is_on_ground(
                &mut self.rigid_body_set,
                &mut self.collider_set,
                &mut self.broad_phase,
                &mut self.narrow_phase,
            );
        }
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
                let player_id = (target_data ^ BIT_PLAYER) as u32;

                if let Some(player) = self.players.get_mut(&player_id) {
                    if let Some(bullet) = self.bullets.get(&bullet_id) {
                        if bullet.owner_id != player.id {
                            // Ako je pogodio neprijatelja
                            player.check_is_alive(
                                bullet.damage,
                                &mut self.rigid_body_set,
                                &mut self.collider_set,
                            );
                            println!("Igrač {} pogođen! Preostali HP: {}", player_id, player.hp);
                            self.remove_bullet(bullet_id);
                        }
                    }
                }
            } else {
                println!("Metak {} je udario u prepreku/zid.", bullet_id);
                self.remove_bullet(bullet_id);
                //DODATI I OVDE ZA KULU !!!!!!
            }
        }
    }

    fn remove_bullet(&mut self, bullet_id: u32) {
        if let Some(bullet) = self.bullets.remove(&bullet_id) {
            self.rigid_body_set.remove(
                bullet.body_handle,
                &mut self.island_manager,
                &mut self.collider_set,
                &mut self.impulse_joint_set,
                &mut self.multibody_joint_set,
                true,
            );
            println!("Metak {} obrisan iz sveta.", bullet_id);
        }
    }
}
