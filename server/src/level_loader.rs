use rapier2d::{
    math::Vec2,
    prelude::{ColliderBuilder, ColliderSet, RigidBodyBuilder, RigidBodySet},
};
use serde::Deserialize;

use crate::groups::BIT_WALL;

#[derive(Deserialize)]
pub struct LevelLoader {
    pub colliders: Vec<RectCollider>,
    pub spawn_positions: Vec<SpawnPosition>,
    pub tower_positions: Vec<TowerPosition>,
}

#[derive(Deserialize)]
pub struct RectCollider {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}
#[derive(Deserialize)]
pub struct SpawnPosition {
    pub x: f32,
    pub y: f32,
}
#[derive(Deserialize)]
pub struct TowerPosition {
    pub x: f32,
    pub y: f32,
}

impl LevelLoader {
    pub fn new(path: &str) -> Self {
        let file_content = std::fs::read_to_string(path).expect("Ne mogu da učitam nivo");
        let level_data: LevelLoader = serde_json::from_str(&file_content).unwrap();
        level_data
    }

    pub fn load_level(
        &self,
        rigid_body_set: &mut RigidBodySet,
        collider_set: &mut ColliderSet,
        spawn_positions: &mut Vec<SpawnPosition>,
        tower_positions: &mut Vec<TowerPosition>
    ) {
        for col in &self.colliders {
            let static_body = RigidBodyBuilder::fixed()
                .translation(Vec2::new(col.x, col.y))
                .build();

            let handle = rigid_body_set.insert(static_body);

            let collider = ColliderBuilder::cuboid(col.width / 2.0, col.height / 2.0)
                .user_data(BIT_WALL)
                .friction(0.0)
                .restitution(0.0)
                .build();

            collider_set.insert_with_parent(collider, handle, rigid_body_set);
        }

        for spawn_position in &self.spawn_positions {
            spawn_positions.push(SpawnPosition {
                x: spawn_position.x,
                y: spawn_position.y,
            });
        }
        for tower_position in &self.tower_positions{
            tower_positions.push(TowerPosition { x: tower_position.x, y: tower_position.y });
        }
        println!("Nivo ucitan: {} kolajdera ubaceno.", self.colliders.len());
    }
}
