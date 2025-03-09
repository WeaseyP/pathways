package pathways

import rl "vendor:raylib"
import "core:math/rand"
import "core:time"
import "core:math"
import "core:fmt"

SCREEN_SIZE :: 1280
SMALLEST_SIZE :: 10
NUM_STARS :: 10000
NUM_ENEMIES :: 500
WORLD_SIZE :: 10000

CAMERA_DEADZONE :: 250.0

STATIC_MAX_SPEED :: 20
MAX_ACCELERATION :: 4000.0
MAX_VELOCITY :: 2000.0
FRICTION :: 0.9

// Define a star for the background
Star :: struct {
    pos: rl.Vector2,
    size: f32,
    color: rl.Color,
}
stars: [NUM_STARS]Star;

Sword :: struct {
    pos: rl.Vector2,
    offset: rl.Vector2,  // Position relative to the player
    size: rl.Vector2,    // Width and height
    angle: f32,          // Rotation angle (in radians)
    starting_angle: f32, // Save starting angle of sword attack (in radians)
    attacking: bool,     // If true, the sword is swinging
    attack_speed: f32,   // How fast the sword moves (in radians per frame)
    attacked: bool,
    damage: [dynamic]f32,
}

sword: Sword

Player :: struct{
    pos: rl.Vector2,
    velocity: rl.Vector2,
    base_size: rl.Vector2,
    current_size: rl.Vector2,
    max_speed: f32,
    sword: Sword,
    health: f32,
    health_lost: f32,
    imortal_timer: f32,
    score: f32,
}
player: Player

Basic_Enemy :: struct{
    pos: rl.Vector2,
    velocity: rl.Vector2,
    radius: f32,
    max_speed: f32,
    hit: bool,
    hit_distance: rl.Vector2,
    health: f32,
    health_lost: f32
}
basic_enemies: [dynamic]Basic_Enemy


Damage_Ticker :: struct{
    pos: rl.Vector2,
    move_speed: f32,
    damage: f32,
    alpha: f32,
}

damage_ticker: [dynamic]Damage_Ticker
camera: rl.Camera2D

game_over: bool


restart:: proc() {
    
    for i := 0; i < NUM_STARS; i += 1 {
        stars[i] = Star{
            pos = {
                f32(rand.int_max(WORLD_SIZE)),
                f32(rand.int_max(WORLD_SIZE))
            },
            size = f32(rand.int_max(3)+1),
            color = rl.WHITE, // Or vary color if you prefer
        }
    }

    for i := 0; i < NUM_ENEMIES; i += 1 {
        basic_enemy := Basic_Enemy{
            pos = {
                f32(rand.int_max(WORLD_SIZE)),
                f32(rand.int_max(WORLD_SIZE))
            },
            velocity = {0,0},
            radius = 20,
            max_speed = 20,
            hit = false,
            hit_distance = {0,0},
            health = 10,
            health_lost = 0,
        }
        append(&basic_enemies, basic_enemy)
    }
    game_over = false

    starting_pos := f32(WORLD_SIZE/2)
    player = Player{
        pos = {starting_pos, starting_pos},
        velocity = {0,0},
        base_size = {70,70},
        current_size = {70,70},
        max_speed = 400,
        sword = Sword{
            pos = {
                starting_pos + 70 / 2 + math.cos_f32(rl.DEG2RAD * 0) * 45,
                starting_pos + 70 / 2 + math.sin_f32(rl.DEG2RAD * 0) * 45,
            },
            offset = {0, 100},   // Start on the right
            size = {120, 10},    // Sword size
            angle = 0,        // Start pointing left
            attacking = false,
            attack_speed = 6.0, // Adjust attcurrent_sizeack speed
            damage = {}
        },
        score = 0,
        health = 100,
        health_lost = 0,
        imortal_timer = 0,
    }

    // Initialize Camera2D:
    camera = rl.Camera2D{
        target = player.pos,
        offset = {SCREEN_SIZE/2, SCREEN_SIZE/2},
        rotation = 0,
        zoom = 1.0,
    }

}

update_enemy :: proc(enemy: ^Basic_Enemy, dt: f32){
        // Handle acceleration
        enemy.velocity.x += enemy.velocity.x * dt * FRICTION
        enemy.velocity.y += enemy.velocity.y * dt * FRICTION
    
        // Apply max velocity clamp to ensure the enemy doesn't exceed max speed
        enemy.velocity.x = clamp(enemy.velocity.x, -enemy.max_speed, enemy.max_speed)
        enemy.velocity.y = clamp(enemy.velocity.y, -enemy.max_speed, enemy.max_speed)
    
        // Update position based on velocity
        enemy.pos.x += enemy.velocity.x * dt
        enemy.pos.y += enemy.velocity.y * dt
        
        // Clamp position to prevent going out of bounds
        enemy.pos.x = clamp(enemy.pos.x, 0, WORLD_SIZE - enemy.radius)
        enemy.pos.y = clamp(enemy.pos.y, 0, WORLD_SIZE - enemy.radius)

        enemy.health = 10 + player.score / 100
        enemy.max_speed = 6.0 + player.score / 1000
        enemy.radius = 20 + player.score / 1000
}

update_player :: proc(player: ^Player, dt: f32) {
    // Handle acceleration
    player.velocity.x += player.velocity.x * dt * FRICTION
    player.velocity.y += player.velocity.y * dt * FRICTION

    // Apply max velocity clamp to ensure the player doesn't exceed max speed
    player.velocity.x = clamp(player.velocity.x, -MAX_VELOCITY, MAX_VELOCITY)
    player.velocity.y = clamp(player.velocity.y, -MAX_VELOCITY, MAX_VELOCITY)

    // Update position based on velocity
    player.pos.x += player.velocity.x * dt
    player.pos.y += player.velocity.y * dt
    
    // Clamp position to prevent going out of bounds
    player.pos.x = clamp(player.pos.x, 0, WORLD_SIZE - player.current_size.x)
    player.pos.y = clamp(player.pos.y, 0, WORLD_SIZE - player.current_size.y)

    player.sword.attack_speed = 6.0 + player.score / 100
    player.health = 100 + player.score / 1000    
    player.sword.size.x = 120.0 + player.score / 10000
    player.sword.size.y = 10.0 + player.score / 100000
    player.max_speed = 400.0 + player.score / 1000000
    player.base_size = {70+ player.score / 10000000, 70 + player.score / 1000000}


    // Update player size based on velocity (stretch based on movement)
    update_size(player)

    // Update sword if it's attacking
    update_sword(player)
}

// Refactor the size update logic into its own function for clarity
update_size :: proc(player: ^Player) {
    // Calculate stretch factor based on velocity
    stretch_factor_x := abs(player.velocity.x) * 0.1
    stretch_factor_y := abs(player.velocity.y) * 0.1

    // Apply stretch to the player size
    player.current_size.x = player.base_size.x - stretch_factor_x
    player.current_size.y = player.base_size.y - stretch_factor_y

    // Ensure the player size does not go below a minimum size
    if player.current_size.x < SMALLEST_SIZE {
        player.current_size.x = SMALLEST_SIZE
    }
    if player.current_size.y < SMALLEST_SIZE {
        player.current_size.y = SMALLEST_SIZE
    }
}

// Refactor the sword update logic into a function to make it easier to maintain
update_sword :: proc(player: ^Player) {
    //if attacking
    if player.sword.attacking && player.sword.attacked{
        player.sword.angle += player.sword.attack_speed  // Rotate the sword
        // Reset attack when it reaches a full rotation
        if player.sword.angle > player.sword.starting_angle+180 {
            player.sword.attacking = false
            player.sword.attacked = false
        }
    }
    else if player.sword.attacking && !player.sword.attacked{
        player.sword.angle -= player.sword.attack_speed  // Rotate the sword

        // Reset attack when it reaches a full rotation
        if player.sword.angle < player.sword.starting_angle-180 {
            player.sword.attacking = false
            player.sword.attacked = true
        }

    }
    else{
        // Calculate the angle of movement (in degrees)
        angle := math.atan2(player.velocity.y, player.velocity.x) * rl.RAD2DEG
            // Normalize the angle to be between 0 and 360 degrees
        if angle < 0 {
            angle = 360
        }
        if angle >= 360 {
            angle = 0
        }
    //    if player.sword.angle < 0 {
    // //       player.sword.angle = 360
     //   }
       // if player.sword.angle >= 0 {
       //     player.sword.angle = 0
        //}
    
        // Adjust the sword's angle to be 45 degrees relative to the movement direction
        if(player.sword.angle < angle + 45.0){
            player.sword.angle += player.sword.attack_speed
        } // You can adjust this value to be + or - as needed
        if(player.sword.angle > angle + 45.0){
            player.sword.angle -= player.sword.attack_speed
        }
    }
    player.sword.pos = rl.Vector2{
        player.pos.x + player.current_size.x / 2 + math.cos(rl.DEG2RAD * player.sword.angle) * 40,
        player.pos.y + player.current_size.y / 2 + math.sin(rl.DEG2RAD * player.sword.angle) * 40,
    }

}

apply_input_velocity :: proc(player: ^Player, dt: f32) {
    // Acceleration when moving in directions
    if rl.IsKeyDown(.A) {
        player.velocity.x -= MAX_ACCELERATION * dt
    }
    if rl.IsKeyDown(.D) {
        player.velocity.x += MAX_ACCELERATION * dt
    }
    if rl.IsKeyDown(.W) {
        player.velocity.y -= MAX_ACCELERATION * dt
    }
    if rl.IsKeyDown(.S) {
        player.velocity.y += MAX_ACCELERATION * dt
    }
    if rl.IsKeyPressed(.Q) {
        player.velocity.y *= -1
    }
    if rl.IsKeyPressed(.E) {
        player.velocity.y *= 2
    }
    if rl.IsKeyPressed(.Z) {
        player.velocity.x *= -1
    }
    if rl.IsKeyPressed(.C) {
        player.velocity.x *= 2
    }


    // Apply smooth friction/damping to velocity when there's no input
    if !rl.IsKeyDown(.LEFT) && !rl.IsKeyDown(.RIGHT) {
        player.velocity.x *= FRICTION
    }
    if !rl.IsKeyDown(.UP) && !rl.IsKeyDown(.DOWN) {
        player.velocity.y *= FRICTION
    }

    // Apply max velocity to make sure we don't exceed the max speed
    player.velocity.x = clamp(player.velocity.x, -MAX_VELOCITY, MAX_VELOCITY)
    player.velocity.y = clamp(player.velocity.y, -MAX_VELOCITY, MAX_VELOCITY)
    update_player(player, dt)
}

// A function to check if two rectangles (enemy and sword) are colliding
check_player_collision :: proc(enemy_pos: rl.Vector2, enemy_radius: f32, player: Player) -> bool {
    player_rect := rl.Rectangle {
        player.pos.x, player.pos.y,
        player.current_size.x, player.current_size.y,
    }
    return rl.CheckCollisionCircleRec(enemy_pos, enemy_radius, player_rect) 
}


// A function to check if two rectangles (enemy and sword) are colliding
check_sword_collision :: proc(enemy_pos: rl.Vector2, enemy_radius: f32, sword: Sword) -> bool {
    sword_hit_radius := math.max(sword.size.x, sword.size.y) / 2
    return rl.CheckCollisionCircles(sword.pos, sword_hit_radius, enemy_pos, enemy_radius)
}


// Adjust the camera position based on player movement with deadzone
camera_deadzone :: proc(camera: ^rl.Camera2D, player: ^Player, dt: f32) {
    player_center := rl.Vector2{
        player.pos.x + player.current_size.x / 2,
        player.pos.y + player.current_size.y / 2,
    }

    delta := rl.Vector2{
        player_center.x - camera.target.x,
        player_center.y - camera.target.y,
    }

    // Only update the camera's target if the difference exceeds the deadzone
    if math.abs(delta.x) > CAMERA_DEADZONE {
        camera.target.x = player_center.x - (delta.x / math.abs(delta.x)) * CAMERA_DEADZONE
    }
    if math.abs(delta.y) > CAMERA_DEADZONE {
        camera.target.y = player_center.y - (delta.y / math.abs(delta.y)) * CAMERA_DEADZONE
    }
}

basic_enemies_find :: proc(player_pos: rl.Vector2, enemy: ^Basic_Enemy, basic_enemies: [dynamic]Basic_Enemy, sword: Sword, dt: f32){
    if(enemy.hit == false){
        if enemy.pos.x < player_pos.x{
            enemy.velocity.x += MAX_ACCELERATION * dt
        }
        if enemy.pos.x > player_pos.x{
            enemy.velocity.x -= MAX_ACCELERATION * dt
        }
        if enemy.pos.y < player_pos.y{
            enemy.velocity.y += MAX_ACCELERATION * dt
        }
        if enemy.pos.y > player_pos.y{
            enemy.velocity.y -= MAX_ACCELERATION * dt
        }
        max_speed_multipler := f32(1)
        if enemy.pos.x < player_pos.x - 100{
            max_speed_multipler += 1
        }
        if enemy.pos.x > player_pos.x + 100{
            max_speed_multipler += 1
        }
        if enemy.pos.y < player_pos.y - 100{
            max_speed_multipler += 1
        }
        if enemy.pos.y > player_pos.y + 100{
            max_speed_multipler += 1
        }
        enemy.max_speed = STATIC_MAX_SPEED * max_speed_multipler
    }
    else{
        if enemy.pos.x < player_pos.x{
            enemy.velocity.x -= MAX_ACCELERATION * dt
        }
        if enemy.pos.x > player_pos.x{
            enemy.velocity.x += MAX_ACCELERATION * dt
        }
        if enemy.pos.y < player_pos.y{
            enemy.velocity.y -= MAX_ACCELERATION * dt
        }
        if enemy.pos.y > player_pos.y{
            enemy.velocity.y += MAX_ACCELERATION * dt
        }
        if enemy.pos.x + 25 < enemy.hit_distance.x{
            enemy.hit = false
        }
        if enemy.pos.x - 25 > enemy.hit_distance.x{
            enemy.hit = false
        }
        if enemy.pos.y + 25 < enemy.hit_distance.y{
            enemy.hit = false
        }
        if enemy.pos.y - 25 > enemy.hit_distance.y{
            enemy.hit = false
        }
    }

    
    // Check if the enemy collides with the sword
    if check_sword_collision(enemy.pos, enemy.radius, sword) {
        if(enemy.hit == false){
            enemy.hit = true
            enemy.hit_distance = enemy.pos
            // Apply bounce force (you can adjust the values to get a realistic bounce)
            enemy.velocity.x = -enemy.velocity.x * 10; // Reverse and reduce velocity (bounce effect)
            enemy.velocity.y = -enemy.velocity.y * 10; // Reverse and reduce velocity (bounce effect)
        }
        if(sword.attacking == true){
            enemy.health_lost += sword.attack_speed
            damage_tick := Damage_Ticker{
                pos = enemy.pos,
                move_speed = 10,
                damage = sword.attack_speed,
                alpha = 5 * sword.attack_speed,
            }
            append(&damage_ticker, damage_tick)
        }
        else{
            enemy.health_lost += 1
            damage_tick := Damage_Ticker{
                pos = enemy.pos,
                move_speed = 10,
                damage = 1,
                alpha = 5,
            }
            append(&damage_ticker, damage_tick)
        }
    }
    for other_enemy in basic_enemies{
        if other_enemy.pos != enemy.pos{
            if rl.CheckCollisionCircles(enemy.pos, enemy.radius, other_enemy.pos, other_enemy.radius)  {
                enemy.velocity.x = -enemy.velocity.x * 2; // Reverse and reduce velocity (bounce effect)
                enemy.velocity.y = -enemy.velocity.y * 2; // Reverse and reduce velocity (bounce effect)
            }
        }
    }

    enemy.velocity.x = clamp(enemy.velocity.x, -enemy.max_speed, enemy.max_speed)
    enemy.velocity.y = clamp(enemy.velocity.y, -enemy.max_speed, enemy.max_speed)
    update_enemy(enemy, dt)
}


main :: proc() {

    rl.SetConfigFlags({ .VSYNC_HINT })
    rl.InitWindow(SCREEN_SIZE, SCREEN_SIZE, "Pathways")

    restart()

    for !rl.WindowShouldClose() {
        DT := rl.GetFrameTime()

        if(!game_over){        
            apply_input_velocity(&player,DT)
            for &enemy in basic_enemies{
                basic_enemies_find(player.pos, &enemy, basic_enemies, player.sword, DT)
                if check_player_collision(enemy.pos, enemy.radius, player) {
                    if player.imortal_timer <= 0{
                        player.imortal_timer = DT + 100
                        player.health_lost += 10
                    }
                }
                if player.imortal_timer > 0 {
                    player.imortal_timer -= DT
                }
                if enemy.health_lost >= enemy.health{
                    new_basic_enemies := [dynamic]Basic_Enemy{}  // Create a new slice to store balls that are not removed
                    for basic_enemy in basic_enemies {
                        if basic_enemy.pos != enemy.pos {  // Keep balls that don't match the one to remove
                            append(&new_basic_enemies, basic_enemy)
                        }
                    }
                    basic_enemies = new_basic_enemies
                    player.score += enemy.health_lost
                }
            }

            player.sword.pos = {
                player.pos.x + player.current_size.x / 2 + math.cos_f32(rl.DEG2RAD * player.sword.angle) * 40,
                player.pos.y + player.current_size.y / 2 + math.sin_f32(rl.DEG2RAD * player.sword.angle) * 40,
            }

            if rl.IsKeyPressed(.SPACE) {
                if !player.sword.attacking {
                    player.sword.attacking = true
                    player.sword.angle = player.sword.angle
                    player.sword.starting_angle = player.sword.angle  // Start from left
                }
            }

        }



        
        camera_deadzone(&camera, &player, DT)
    

        rl.BeginDrawing()
        rl.ClearBackground({55, 130, 209, 255})

        if game_over {
			game_over_text := fmt.ctprintf("Reset: SPACE")
			game_over_text_width := rl.MeasureText(game_over_text, 15)
            player_score_text := fmt.ctprintf("Score: ")
            player_score_text_width := rl.MeasureText(player_score_text, 15)
			rl.DrawText(game_over_text, SCREEN_SIZE/2 - game_over_text_width/2, SCREEN_SIZE/2, 50, rl.WHITE)
            rl.DrawText(player_score_text, SCREEN_SIZE/2 - player_score_text_width/2, SCREEN_SIZE/2 - 100, 50, rl.WHITE)
            if( rl.IsKeyPressed(.SPACE)){
                restart()
            }
        }
        
        for i := 0; i < len(damage_ticker); i += 1 {
            damage := &damage_ticker[i] // Get a mutable reference
        
            fmt.printf("Damage position: %v\n", i32(damage.pos.y))
            fmt.printf("Player position: %v\n", player.pos.y)
        
            damage_text := fmt.ctprint(damage.damage)
        
            rl.DrawText(damage_text, i32(i32(SCREEN_SIZE/2)+i32(i*15)), i32(i32(SCREEN_SIZE/2) + i32(i * 15)), i32(damage.alpha), rl.WHITE)
        
            // Update position and alpha
            damage.pos.y += 10
            damage.alpha -= 1
        
            // Remove damage when fully faded
            if damage.alpha <= 0 {
                new_damage_ticker := [dynamic]Damage_Ticker{}
                for new_damage in damage_ticker{
                    if new_damage.pos != damage.pos{
                        append(&new_damage_ticker, new_damage)
                    } // Swap with last element
                }
                damage_ticker = new_damage_ticker
            }

        }

        player_health_text := fmt.ctprint("Health: ", player.health-player.health_lost)
		rl.DrawText(player_health_text, 10, 10, 20, rl.WHITE)
        player_score_text := fmt.ctprint("Score: ", player.score)
        rl.DrawText(player_score_text, 10, 30, 20, rl.WHITE)

        // Begin 2D mode using the camera.
        rl.BeginMode2D(camera)

        if(!game_over){
            for star in stars {
                rl.DrawCircleV(star.pos, star.size, star.color)
            }
            for &enemy in basic_enemies{
                color: rl.Color
                if enemy.hit == true{
                    color = rl.RED
                }
                else{
                    color = rl.WHITE
                }

                rl.DrawCircleV(enemy.pos, enemy.radius, color)
            }

            // Draw your game world here (player, obstacles, etc.)
            rl.DrawRectangleRec(
                {player.pos.x, player.pos.y, player.current_size.x, player.current_size.y},
                rl.WHITE
            )
            
            current_size: f32
            if(player.current_size.y < player.current_size.x){
                current_size = player.current_size.y
            }
            else{
                current_size = player.current_size.x
            }

           // sword_aabb := get_aabb_from_rotated_rect(player.sword.pos, player.sword.size, player.sword.angle)
            // Draw the AABB for debugging
            /*
            rl.DrawRectangleLines(
                i32(sword_aabb.x), i32(sword_aabb.y),
                i32(sword_aabb.width), i32(sword_aabb.height),
                rl.BLUE
            )
                */
            
            rl.DrawRectanglePro(
                {player.sword.pos.x, player.sword.pos.y, player.sword.size.x, player.sword.size.y},
                {current_size * -0.1, player.sword.size.y / 2},  // Pivot at the base of the sword
                player.sword.angle,
                rl.RED
            )
                

            if player.health-player.health_lost <= 0 {
                game_over = true
            }
        }

        rl.EndMode2D()
        rl.EndDrawing()

        free_all(context.temp_allocator)

    }

    rl.CloseWindow()
}
