use rapier2d::geometry::Group;

pub const NONE_GROUP: Group = Group::NONE;
pub const WALL_GROUP: Group = Group::GROUP_1;  
pub const PLAYER_GROUP: Group = Group::GROUP_2;   
pub const BULLET_GROUP: Group = Group::GROUP_3;
pub const TOWER_GROUP: Group = Group::GROUP_4;
pub const GRENADE_GROUP: Group = Group::GROUP_5;

pub const BIT_BULLET: u128 = 1 << 127;
pub const BIT_WALL: u128 = 1 << 126;
pub const BIT_PLAYER: u128 = 1 << 125;
pub const BIT_TOWER: u128 = 1 << 124;
pub const BIT_GRENADE: u128 = 1 << 123;