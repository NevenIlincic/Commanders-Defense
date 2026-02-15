use crate::{
    entities::{Bullet, Player, Tower},
    level_loader::{LevelData, RectCollider},
    network_protocol::ClientInput,
};
use rapier2d::control::KinematicCharacterController;
use rapier2d::pipeline::QueryFilter;
use rapier2d::pipeline::QueryPipeline;

use rapier2d::{glamx::vec2, prelude::*};
use std::{collections::HashMap, hash::Hash, net::SocketAddr};
use tokio::runtime::Id;
pub struct GameStateModel {
    //Interni model koji omogućava da Rapier2d biblioteka mapira i računa kolizije
    //Entiteti koji postoje na Godot sceni
    pub next_player_id: u32,
    pub players: HashMap<u32, Player>,
    pub address_to_players: HashMap<SocketAddr, u32>,
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
}

impl GameStateModel {
    pub fn new() -> Self {
        Self {
            next_player_id: 1,
            players: HashMap::new(),
            address_to_players: HashMap::new(),
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
        }
    }

    pub fn load_level(&mut self, path: &str) {
        let file_content = std::fs::read_to_string(path).expect("Ne mogu da učitam nivo");
        let level: LevelData = serde_json::from_str(&file_content).unwrap();

        for col in &level.colliders {
            let static_body = RigidBodyBuilder::fixed()
                .translation(Vec2::new(col.x, col.y))
                .build();

            let handle = self.rigid_body_set.insert(static_body);

            let collider = ColliderBuilder::cuboid(col.width / 2.0, col.height / 2.0)
                .friction(0.0)
                .restitution(0.0)
                .build();

            self.collider_set
                .insert_with_parent(collider, handle, &mut self.rigid_body_set);
        }
        println!("Nivo učitan: {} kolajdera ubačeno.", level.colliders.len());
    }

    fn add_player(&mut self, id: u32, x: f32, y: f32) {
        let rigid_body = RigidBodyBuilder::dynamic()
            .translation(vec2(x, y))
            .lock_rotations()
            .can_sleep(false)
            .build();

        let body_handle = self.rigid_body_set.insert(rigid_body);

        //HitBox
        let collider = ColliderBuilder::capsule_y(0.1, 0.4)
            .restitution(0.0)
            .friction(0.0)
            .build();

        let collider_handle =
            self.collider_set
                .insert_with_parent(collider, body_handle, &mut self.rigid_body_set);

        let new_player = Player {
            id,
            body_handle,
            collider_handle,
            vertical_velocity: 0.0,
            is_on_ground: false,
            hp: 100.0,
            facing_right: true,
            respawn_timer: 0.0,
            last_processed_input_id: 0,
        };

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
            player.last_processed_input_id = input.input_id;

            if let Some(rb) = self.rigid_body_set.get_mut(player.body_handle) {
                let speed = 10.0;
                let mut x_vel = 0.0;

                if input.move_left {
                    x_vel -= speed;
                    player.facing_right = false //Izmeniti u zavisnosti od ugla misa!
                }
                if input.move_right {
                    x_vel += speed;
                    player.facing_right = true
                }

                let current_vel = rb.linvel();
                rb.set_linvel(vec2(x_vel, current_vel.y), true);

                //GRAVITACIJA
                if (input.jump && player.is_on_ground) {
                    rb.set_linvel(vec2(x_vel, -12.0), true);
                    player.is_on_ground = false;
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
        let gravity = vec2(0.0, 15.0); //(0.0, 15.0)

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
            &(),
        );

        self.check_grounded_status();
    }

    fn check_grounded_status(&mut self) {
        for player in self.players.values_mut() {
            if let Some(rb) = self.rigid_body_set.get(player.body_handle) {
                let pos = rb.translation();

                let filter = QueryFilter::default().exclude_rigid_body(player.body_handle);

                let query_pipeline = self.broad_phase.as_query_pipeline(
                    self.narrow_phase.query_dispatcher(),
                    &self.rigid_body_set,
                    &self.collider_set,
                    filter,
                );
                let ray = Ray::new(vec2(pos.x, pos.y + 0.4), vec2(0.0, 1.0));

                player.is_on_ground = query_pipeline.cast_ray(&ray, 0.15, true).is_some();
            }
        }
    }
}
