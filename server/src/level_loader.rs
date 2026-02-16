use serde::Deserialize;
use rapier2d::{math::Vec2, prelude::{ColliderBuilder, ColliderSet, RigidBodyBuilder, RigidBodySet}};

#[derive(Deserialize)]
pub struct LevelLoader {
    pub colliders: Vec<RectCollider>,
}

#[derive(Deserialize)]
pub struct RectCollider {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

impl LevelLoader{
    pub fn new(path: &str) -> Self{
        let file_content = std::fs::read_to_string(path).expect("Ne mogu da učitam nivo");
        let level_data: LevelLoader = serde_json::from_str(&file_content).unwrap();
        level_data
    }

    pub fn load_level(&self, rigid_body_set: &mut RigidBodySet, collider_set: &mut ColliderSet){
        for col in &self.colliders {
            let static_body = RigidBodyBuilder::fixed()
                .translation(Vec2::new(col.x, col.y))
                .build();

            let handle = rigid_body_set.insert(static_body);

            let collider = ColliderBuilder::cuboid(col.width / 2.0, col.height / 2.0)
                .friction(0.0)
                .restitution(0.0)
                .build();

            collider_set
                .insert_with_parent(collider, handle,  rigid_body_set);
        }
        println!("Nivo učitan: {} kolajdera ubačeno.", self.colliders.len());
    }
}