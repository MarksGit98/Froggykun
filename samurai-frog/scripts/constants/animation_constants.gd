extends RefCounted
class_name AnimationConstants

# Player animation tree nodes and clips.
const PLAYER_MOVE: StringName = &"Move"
const PLAYER_FALL: StringName = &"fall"
const PLAYER_WALL_CONTACT: StringName = &"wall_contact"
const PLAYER_WALL_SLIDE: StringName = &"wall_slide"
const PLAYER_JUMP_START: StringName = &"jump_start"
const PLAYER_JUMP: StringName = &"jump"
const PLAYER_JUMP_TRANSITION: StringName = &"jump_transition"
const PLAYER_WALL_JUMP: StringName = &"wall_jump"
const PLAYER_ATTACK_1: StringName = &"attack_1"
const PLAYER_ATTACK_2: StringName = &"attack_2"
const PLAYER_ATTACK_3: StringName = &"attack_3"
const PLAYER_AIR_ATTACK: StringName = &"air_attack"
const PLAYER_DASH: StringName = &"dash"
const PLAYER_DEFEND_QUEUE: StringName = &"queue_defense"
const PLAYER_DEFEND_SUCCESS: StringName = &"defend"
const PLAYER_DEATH: StringName = &"death"

# Player gameplay state names that route animation behavior.
const PLAYER_STATE_ATTACKING: StringName = &"Attacking"
const PLAYER_STATE_GROUNDED: StringName = &"Grounded"
const PLAYER_STATE_FALLING: StringName = &"Falling"
const PLAYER_STATE_JUMPING: StringName = &"Jumping"
const PLAYER_STATE_WALLED: StringName = &"Walled"
const PLAYER_STATE_DASHING: StringName = &"Dashing"
const PLAYER_STATE_DEFEND: StringName = &"Defend"
const PLAYER_STATE_DEAD: StringName = &"Dead"


# Enemy animation tree nodes and clips.
const ENEMY_MOVE: StringName = &"Move"
const ENEMY_ATTACK: StringName = &"Attack"
const ENEMY_DEATH: StringName = &"Death"
const ENEMY_TAKE_HIT_STATE: StringName = &"TakeHit"
const ENEMY_TAKE_HIT_CLIP: StringName = &"Take Hit"
