package pathways

import rl "vendor:raylib"
import "core:math/rand"
import "core:time"
import "core:math"
import "core:fmt"

SCREEN_SIZE :: 1280
SMALLEST_SIZE :: 10
NUM_STARS :: 10000
WORLD_SIZE :: 10000

CAMERA_DEADZONE :: 250.0

STATIC_MAX_SPEED :: 20
MAX_ACCELERATION :: 4000.0
MAX_VELOCITY :: 2000.0
FRICTION :: 0.9
MAX_PARTICLES :: 100000
MAX_BLOOD :: 150


Particle :: struct {
    pos: rl.Vector2,
    velocity: rl.Vector2, 
    color: rl.Color,
    alpha: f32,
    size: f32,
    rotation: rl.Vector2,
    active: bool,      // NOTE: Use it to activate/deactive particle
} 

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
    basic_attacking: bool,     // If true, the sword is swinging
    basic_spinning: bool,
    attack_speed: f32,   // How fast the sword moves (in radians per frame)
    attacked: bool,
    damage: [dynamic]f32,
    
}

sword: Sword

Player :: struct{
    pos: rl.Vector2,
    velocity: rl.Vector2,
    original_base_size: rl.Vector2,
    base_size: rl.Vector2,
    current_size: rl.Vector2,
    max_speed: f32,
    sword: Sword,
    health: f32,
    health_lost: f32,
    imortal_timer: f32,
    score: f32,
    dash_timer: f32,
    stamina: f32,
    max_stamina: f32,
    stamina_regen_time: f32,
    last_stamina: f32,
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
    health_lost: f32,
    blood_spawn_timer : f32,
    particles: [dynamic]Particle,
    rotation: f32,
    rotation_speed: f32,
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
num_enemies: f32 = 200
enemy_center: rl.Vector2

game_over: bool


restart:: proc() {
    load_basic_enemies()
    load_players()
    load_swords()

    starting_pos := f32(WORLD_SIZE/2)
    player = Player{
        pos = {starting_pos, starting_pos},
        velocity = {0,0},
        base_size = {100,100},
        original_base_size = {100,100},
        current_size = {100,100},
        max_speed = 400,
        sword = Sword{
            pos = {
                starting_pos + 10 / 2 + math.cos_f32(rl.DEG2RAD * 0) * 45,
                starting_pos + 10 / 2 + math.sin_f32(rl.DEG2RAD * 0) * 45,
            },
            offset = {0, 100},   // Start on the right
            size = {19.8, 200},    // Sword size
            angle = 0,        // Start pointing left
            basic_attacking = false,
            basic_spinning = false,
            attack_speed = 6.0, // Adjust attcurrent_sizeack speed
            damage = {},
        },
        score = 0,
        health = 100,
        health_lost = 0,
        imortal_timer = 0,
        dash_timer = 0.0,
        stamina = 100,
        max_stamina = 100,
        stamina_regen_time = 0,
        last_stamina = 100,

    }
    
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

    for i := f32(0); i < num_enemies; i += 1 {
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
            blood_spawn_timer = 0.0,
            rotation = 0,
            rotation_speed = 1,
        }
        append(&basic_enemies, basic_enemy)
    }



    // Initialize Camera2D:
    camera = rl.Camera2D{
        target = player.pos,
        offset = {SCREEN_SIZE/2, SCREEN_SIZE/2},
        rotation = 0,
            zoom = player.base_size.x / 100,
        }


    game_over = false

    


}

spawn_blood_particle :: proc(pos: rl.Vector2, sword_angle: f32, particles: ^[dynamic]Particle) {
    current_particle: Particle
    // Calculate velocity based on the sword's angle
    speed : f32 = 100.0  // base speed for blood particles
    for i := 0; i < (MAX_BLOOD-len(particles))/3; i += 1 {
            // Add randomness to the direction and magnitude of the velocity
            angle_randomness := rand.float32_range(-1, 1)  // Random angle offset in radians
            randomized_angle := sword_angle + angle_randomness
            speed_randomness := rand.float32_range(0.5, 1.5)   // Random speed multiplier
        current_particle = {
            pos      = pos,
            rotation = rl.Vector2({rand.float32_range(-1.5, 1.5), rand.float32_range(-3.0, 3.0) + sword_angle}),
            color    = rl.RED,
            alpha    = 255.0,  // full opacity
            size     = 1.0 + rand.float32_range(0, 2.0) ,
            velocity = rl.Vector2({math.cos_f32(randomized_angle) * speed * speed_randomness + rand.float32_range(-50.0, 50.0), 
                        math.sin_f32(randomized_angle) * speed * speed_randomness + rand.float32_range(-50.0, 50.0)})
        }
        append(particles, current_particle)      
            // Add some randomness to the velocity for a more natural splatter effect
            particles[i].velocity.x += rand.float32_range(-100.0, 100.0)
            particles[i].velocity.y += rand.float32_range(-100.0, 100.0)

            fmt.printfln("Particle %d: angle=%f, velocity=(%f, %f)", i, randomized_angle, particles[i].velocity.x, particles[i].velocity.y)
        }
    // If all particles are active, reuse the oldest one (optional)
}

// update_particles moves active particles with randomness (no gravity) and fades them out.
update_particles :: proc(dt: f32, particles: ^[dynamic]Particle) {
    speed : f32 = 100.0  // base speed for particle movement

    for i := 0; i < (len(particles)); i += 1  {
            // Move particle in the direction given by rotation
            particles[i].pos.x += math.cos_f32(particles[i].rotation.x) * speed * dt
            particles[i].pos.y += math.sin_f32(particles[i].rotation.y) * speed * dt

            // Add random jitter to simulate splatter effect (no gravity)
            particles[i].pos.x += rand.float32_range(-30.0, 30.0) * dt
            particles[i].pos.y += rand.float32_range(-30.0, 30.0) * dt

            // Gradually fade out the particle (over roughly 2 seconds)
            particles[i].alpha -= dt * 100
            if particles[i].alpha <= 0.0 {
            }
    }
}

// draw_particles renders all active blood particles as circles.
draw_particles :: proc(particles: ^[dynamic]Particle) {
    for i := 0; i < len(particles); i += 1 {
            // Set the particle's color with its current alpha value
            particle_color : rl.Color = particles[i].color
            alpha_normalized := particles[i].alpha / 255.0
            // Draw a circle representing the blood particle
            rl.DrawCircle(
                i32(particles[i].pos.x),
                i32(particles[i].pos.y),
                particles[i].size,
                rl.ColorAlpha(particle_color, alpha_normalized )
            )
            //fmt.printfln("%d", i)
            //fmt.printfln("%d", particles[i])
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

        enemy.rotation += (enemy.velocity.x + enemy.velocity.y) / 10 * dt * enemy.rotation_speed  // Rotate faster when moving faster

        fmt.printfln("Enemy volicity %d enemy rotation speed %d, enemy rotation %d", enemy.velocity, enemy.rotation_speed, enemy.rotation)

        
        
        // Clamp position to prevent going out of bounds
        enemy.pos.x = clamp(enemy.pos.x, 0, WORLD_SIZE - enemy.radius)
        enemy.pos.y = clamp(enemy.pos.y, 0, WORLD_SIZE - enemy.radius)

        enemy.health = 10 + player.score / 50
        enemy.max_speed = 6.0 + player.score / 1000
        enemy.radius = 20 + player.score / 1000
}

update_player :: proc(player: ^Player, dt: f32, time: f32) {
    if(player.dash_timer < time) {
        // Handle acceleration
        player.velocity.x += player.velocity.x * dt * FRICTION
        player.velocity.y += player.velocity.y * dt * FRICTION

        // Apply max velocity clamp to ensure the player doesn't exceed max speed
        player.velocity.x = clamp(player.velocity.x, -MAX_VELOCITY, MAX_VELOCITY)
        player.velocity.y = clamp(player.velocity.y, -MAX_VELOCITY, MAX_VELOCITY)
    }
    else {
        // Handle acceleration
        player.velocity.x += player.velocity.x * 10 * dt * FRICTION
        player.velocity.y += player.velocity.y * 10 * dt * FRICTION
        player.velocity.x = clamp(player.velocity.x, -MAX_VELOCITY*10, MAX_VELOCITY*10)
        player.velocity.y = clamp(player.velocity.y, -MAX_VELOCITY*10, MAX_VELOCITY*10)
    }

        // Update position based on velocity
    player.pos.x += player.velocity.x * dt
    player.pos.y += player.velocity.y * dt
    
    // Clamp position to prevent going out of bounds
    player.pos.x = clamp(player.pos.x, 0, WORLD_SIZE - player.current_size.x)
    player.pos.y = clamp(player.pos.y, 0, WORLD_SIZE - player.current_size.y)


    player.sword.attack_speed = math.to_radians(6.0 + player.score / 10000)
    player.health = 100 + player.score / 1000    
    //player.sword.size.x = 120.0 + player.score / 10000
    //player.sword.size.y = 10.0 + player.score / 100000
    player.max_speed = 400.0 + player.score / 1000
    //player.base_size = {player.original_base_size.x + player.score, player.original_base_size.y + player.score}

    // Update player size based on velocity (stretch based on movement)
    update_size(player)

    // Update sword if it's attacking
    update_sword(player, dt)
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
update_sword :: proc(player: ^Player, dt: f32) {
    if player.sword.basic_spinning == false{
        if rl.IsMouseButtonDown(.LEFT){
            player.stamina -= dt * 10
            player.sword.angle += player.sword.attack_speed
            player.sword.basic_attacking = true
        }
        if rl.IsMouseButtonDown(.RIGHT){
            player.stamina -= dt * 10
            player.sword.angle -= player.sword.attack_speed
            player.sword.basic_attacking = true
        }
    }
    //if basic_spinning
    if player.sword.basic_spinning && player.sword.attacked{
        player.sword.angle += player.sword.attack_speed*2  // Rotate the sword
        // Reset attack when it reaches a full rotation
        if player.sword.angle > player.sword.starting_angle + math.PI * 6 {
            player.sword.basic_spinning = false
            player.sword.attacked = false
        }
    }
    else if player.sword.basic_spinning && !player.sword.attacked{
        player.sword.angle -= player.sword.attack_speed*2  // Rotate the sword

        // Reset attack when it reaches a full rotation
        if player.sword.angle < player.sword.starting_angle - math.PI * 6 {
            player.sword.basic_spinning = false
            player.sword.attacked = true
        }

    }
    player.sword.pos = rl.Vector2{
        player.pos.x + player.current_size.x / 2 + math.cos(player.sword.angle) ,
        player.pos.y + player.current_size.y / 2 + math.sin(player.sword.angle) ,
    }

}

apply_input_velocity :: proc(player: ^Player, dt: f32, time: f32) {
    // Acceleration when moving in directions
    if rl.IsKeyDown(.A) {
        player.velocity.x -= MAX_ACCELERATION * dt
        player.stamina -= dt*2
    }
    if rl.IsKeyDown(.D) {
        player.velocity.x += MAX_ACCELERATION * dt
        player.stamina -= dt*2
    }
    if rl.IsKeyDown(.W) {
        player.velocity.y -= MAX_ACCELERATION * dt
        player.stamina -= dt*2
    }
    if rl.IsKeyDown(.S) {
        player.velocity.y += MAX_ACCELERATION * dt
        player.stamina -= dt*2
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
    if player.dash_timer < time && player.stamina >= 15{
        if rl.IsKeyPressed(.R){
            player.dash_timer = time + 0.5
            player.imortal_timer = time + 0.5
            player.stamina -= 15
        }
    }
    // Apply smooth friction/damping to velocity when there's no input
    if !rl.IsKeyDown(.LEFT) && !rl.IsKeyDown(.RIGHT) {
        player.velocity.x *= FRICTION
    }
    if !rl.IsKeyDown(.UP) && !rl.IsKeyDown(.DOWN) {
        player.velocity.y *= FRICTION
    }

    update_player(player, dt, time)
}




// A function to check if two rectangles (enemy and sword) are colliding
check_player_collision :: proc(enemy_pos: rl.Vector2, enemy_radius: f32, player: Player) -> bool {
    player_rect := rl.Rectangle {
        player.pos.x, player.pos.y,
        player.current_size.x, player.current_size.y,
    }
    return rl.CheckCollisionCircleRec(enemy_pos, enemy_radius, player_rect) 
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
    //if(enemy.hit == false){
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
            
  //  }
        

    
    // Check if the enemy collides with the sword
    if check_sword_collision_circles(enemy.pos, enemy.radius, sword) {

        if(enemy.hit == false && (sword.basic_spinning == true || sword.basic_attacking == true)){
            enemy.hit = true
            enemy.hit_distance = enemy.pos
            //enemy.velocity.x = -enemy.velocity.x * 10; // Reverse and reduce velocity (bounce effect)
            //enemy.velocity.y = -enemy.velocity.y * 10; // Reverse and reduce velocity (bounce effect)

            enemy.health_lost += math.to_degrees_f32(sword.attack_speed) + player.score / 100
            enemy.blood_spawn_timer = 0.3
            if(enemy.blood_spawn_timer <= 0){
                //spawn_blood_particle(enemy.pos+10, &enemy.particles)
                enemy.blood_spawn_timer -= dt
            }

            damage_tick := Damage_Ticker{
                pos = enemy.pos,
                move_speed = 10,
                damage = (math.to_degrees_f32(sword.attack_speed) + player.score / 100),
                alpha = (math.to_degrees_f32(sword.attack_speed) + player.score / 100),
            }
            append(&damage_ticker, damage_tick)
        }
        else if(enemy.blood_spawn_timer > 0){
            spawn_blood_particle( enemy.pos, sword.angle, &enemy.particles)
            enemy.blood_spawn_timer -= dt
        }
    }
    for other_enemy in basic_enemies{
        if other_enemy.pos != enemy.pos{
            if rl.CheckCollisionCircles(enemy.pos, enemy.radius, other_enemy.pos, other_enemy.radius)  {
                enemy.velocity.x = -enemy.velocity.x * 2; // Reverse and reduce velocity (bounce effect)
                enemy.velocity.y = -enemy.velocity.y * 2; // Reverse and reduce velocity (bounce effect)
            }
            else{
                enemy.velocity.x = clamp(enemy.velocity.x, -enemy.max_speed, enemy.max_speed)
                enemy.velocity.y = clamp(enemy.velocity.y, -enemy.max_speed, enemy.max_speed)
            }
        }
    }


    update_enemy(enemy, dt)
}

spawn_enemy :: proc(){
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
    blood_spawn_timer = 0.0,
    rotation = 0,
    rotation_speed = 1,
    }
    append(&basic_enemies, basic_enemy)
}



player_textures: [10]rl.Texture2D  // Array to store all 32x32 sword textures

load_players :: proc() {
    sprite_sheet := rl.LoadImage("player.png")

    num_rows := 10
    player_index: int = 0

    // Extract each 32x32 player
    for row in 0..<num_rows {
        // Define the rectangle area to extract
        load_player_rect := rl.Rectangle{f32(0), f32(row * 100), 100, 100}

        // Extract the image section using ImageFromImage
        player_img := rl.ImageFromImage(sprite_sheet, load_player_rect)

        // Convert to texture and store in the array
        player_textures[player_index] = rl.LoadTextureFromImage(player_img)
        player_index += 1

        // Free the extracted image (only needed temporarily)
        rl.UnloadImage(player_img)
    }

    
        // Free the original sprite sheet
    rl.UnloadImage(sprite_sheet)
}

enemy_textures: [4]rl.Texture2D  // Array to store all 32x32 sword textures

load_basic_enemies :: proc() {
    sprite_sheet := rl.LoadImage("basic_enemy.png")

    num_cols := 4
    enemy_index: int = 0

    // Extract each 32x32 player
    for col in 0..<num_cols {
        // Define the rectangle area to extract
        load_enemy_rect := rl.Rectangle{f32(col*100), f32(0), 100, 100}

        // Extract the image section using ImageFromImagec:\Users\ryanp\Downloads\pixil-frame-0(15)-imageonline.co-merged(1).png
        enemy_img := rl.ImageFromImage(sprite_sheet, load_enemy_rect)

        // Convert to texture and store in the array
        enemy_textures[enemy_index] = rl.LoadTextureFromImage(enemy_img)
        enemy_index += 1

        // Free the extracted image (only needed temporarily)
        rl.UnloadImage(enemy_img)
    }

    
        // Free the original sprite sheet
    rl.UnloadImage(sprite_sheet)
}

sword_textures: [30]rl.Texture2D  // Array to store all 32x32 sword textures


load_swords :: proc() {
    sprite_sheet := rl.LoadImage("katana.png")

    num_columns := f32(30)
    sword_index: int = 0

    // Extract each 32x32 sword
    for col in 0..<num_columns {
        // Define the rectangle area to extract

        load_sword_rect := rl.Rectangle{f32(col * 62.4), f32(0), 62.4, 630}
       // if sprite_sheet.data == nil {
       //     fmt.printfln("Failed to load sprite sheet!")
            //return
     //   }

        // Extract the image section using ImageFromImage
        sword_img := rl.ImageFromImage(sprite_sheet, load_sword_rect)

        // Convert to texture and store in the array
        sword_textures[sword_index] = rl.LoadTextureFromImage(sword_img)
        sword_index += 1

        // Free the extracted image (only needed temporarily)
        rl.UnloadImage(sword_img)
    }

    // Free the original sprite sheet
    rl.UnloadImage(sprite_sheet)
}
/*
draw_player :: proc(player_index: f32) {    
    rl.DrawTextureRec(player_textures[int(player_index)], rl.Rectangle({0, 0, player.current_size.x, player.current_size.y}), player.pos, rl.WHITE)
}
    */

draw_player :: proc(player_index: int) {
    // Define the source rectangle (entire texture)

    //source_rect := rl.Rectangle{0, 0, player_textures[player_index].width, player_textures[player_index].height}

    player_index_clamped := clamp(player_index, 0, 9)


    // Define the destination rectangle (scaled to player.current_size)
    dest_rect := rl.Rectangle{
        player.pos.x,
        player.pos.y,
        player.current_size.x,
        player.current_size.y,
    }
    //player_index_clamp := clamp(player_index, 0, 9)  // Ensure the index is between 0 and 9

    // Draw the texture with scaling
    rl.DrawTexturePro(
        player_textures[player_index_clamped],
        rl.Rectangle{0, 0, f32(player_textures[player_index_clamped].width), f32(player_textures[player_index_clamped].height)},
        dest_rect,
        {0, 0}, // Origin (center of rotation/scaling)
        0,      // Rotation (in degrees)
        rl.WHITE,
    )
}

draw_enemy :: proc(enemy: Basic_Enemy, enemy_index: int) {
    // Define the source rectangle (entire texture)

    //source_rect := rl.Rectangle{0, 0, player_textures[player_index].width, player_textures[player_index].height}

    enemy_index_clamped := clamp(enemy_index, 0, 3)

    // Define the destination rectangle (scaled to player.current_size)
    dest_rect := rl.Rectangle{
        enemy.pos.x,
        enemy.pos.y,
        enemy.radius*2,
        enemy.radius*2,
    }
    //player_index_clamp := clamp(player_index, 0, 9)  // Ensure the index is between 0 and 9

    // Draw the texture with scaling
    rl.DrawTexturePro(
        enemy_textures[enemy_index_clamped],
        rl.Rectangle{0, 0, f32(enemy_textures[enemy_index_clamped].width), f32(enemy_textures[enemy_index_clamped].height)},
        dest_rect,
        {enemy.radius, enemy.radius},  // Pivot at the center of the enemy
        math.to_degrees_f32(enemy.rotation),  // Convert radians to degrees for raylib
        rl.WHITE,
    )
}



check_sword_collision_circles :: proc(enemy_pos: rl.Vector2, enemy_radius: f32, sword: Sword) -> bool {
    // Create 3 collision circles along the sword
    circles := [3]rl.Vector2{
        sword.pos + rotate_vector({0, sword.size.y  * 1.35}, sword.angle),
        //Tip circle
        sword.pos + rotate_vector({0, sword.size.y * 1.05}, sword.angle),
        // Mid circle
        sword.pos + rotate_vector({0, sword.size.y * 0.75}, sword.angle),
        // Hilt circle
    }

    
    // Check collisions
    for circle in circles {
        if rl.CheckCollisionCircles(circle, 15, enemy_pos, enemy_radius) { // 10 = circle radius
            return true
        }
    }
    return false
}

/*

KEEP THIS ONE - ERROR CHECKING FUNCTION NOT USED
*/
draw_sword_collision_circles :: proc(sword: Sword){
    circles := [3]rl.Vector2{
        sword.pos + rotate_vector({0, sword.size.y  * 1.15}, sword.angle),
        //Tip circle
        sword.pos + rotate_vector({0, sword.size.y * 0.85}, sword.angle),
        // Mid circle
        sword.pos + rotate_vector({0, sword.size.y * 0.55}, sword.angle),
        // Hilt circle
    }

    
    // Debug: Draw collision circles
    for circle in circles {
        rl.DrawCircleV(circle, sword.size.x, rl.GREEN)  // Radius 5 for visualization
    }
}

/*
^^^^^^^^^^^^^^^^^^^
KEEP THIS ONE - ERROR CHECKING FUNCTION NOT USED
*/

rotate_vector :: proc(vec: rl.Vector2, angle: f32) -> rl.Vector2 {
    cos_theta := math.cos(angle)
    sin_theta := math.sin(angle)
    return {
        vec.x * cos_theta - vec.y * sin_theta,
        vec.x * sin_theta + vec.y * cos_theta,
    }
}




draw_sword :: proc(sword_id: int) {

    source_rect := rl.Rectangle{
        x      = f32(f32((sword_id % 30)) * f32(62.4)),  // 6 columns in sprite sheet
        y      = f32(0),  // Row calculation
        width  = 62.4,
        height = 630
    }
        rl.DrawTexturePro(sword_textures[sword_id], 
        source_rect, 
        {player.sword.pos.x, player.sword.pos.y, player.sword.size.x, player.sword.size.y},
        {player.sword.size.x/2, -player.current_size.y + 50},  // Pivot at the base of the sword
        math.to_degrees_f32(player.sword.angle),
        rl.WHITE)
        
}

main :: proc() {

    rl.SetConfigFlags({ .VSYNC_HINT })
    rl.InitWindow(SCREEN_SIZE, SCREEN_SIZE, "Pathways")

    restart()
    start_time := rl.GetTime()
    time := rl.GetTime()

    start_pos := rl.Vector2{f32(rl.GetRandomValue(WORLD_SIZE * 2, WORLD_SIZE * 4)), 0}
    end_pos := rl.Vector2{start_pos.x, f32(rl.GetRandomValue(WORLD_SIZE * 2, WORLD_SIZE * 4))}


    for !rl.WindowShouldClose() {
        time = rl.GetTime()
        DT := rl.GetFrameTime()

        if(!game_over){

            if f32(time) / 5.0 > f32(len(basic_enemies)-50)  {
                spawn_enemy()       // Call your enemy spawning function
            }
            if player.stamina < 0 {
                player.stamina = 0
            }
            player.last_stamina = player.stamina
            player.sword.basic_attacking = false
      

            apply_input_velocity(&player,DT,f32(time))
            if(player.stamina <= player.max_stamina){
                if(player.stamina > player.last_stamina){
                    player.stamina += DT * player.stamina_regen_time
                    player.stamina_regen_time += 1
                }
                else if(player.stamina <= player.last_stamina){
                    player.stamina += DT * 10
                    player.stamina_regen_time = 0
                }  
            }

           // fmt.printfln("%d", player.dash_timer)


            
            for &enemy in basic_enemies{
                basic_enemies_find(player.pos, &enemy, basic_enemies, player.sword, DT)
                if check_player_collision(enemy.pos, enemy.radius, player) {
                    if player.imortal_timer <= 0{
                        player.imortal_timer = f32(time+0.5)
                        player.health_lost += 10
                    }
                }
                if player.imortal_timer < f32(time){
                    player.imortal_timer = 0
                }
                if enemy.health_lost >= enemy.health {
                    if enemy.blood_spawn_timer > 0{
                        player.score += enemy.health_lost
                        enemy.pos = rl.Vector2({-10000, -10000})
                    }
                    else{
                    new_basic_enemies := [dynamic]Basic_Enemy{}  // Create a new slice to store balls that are not removed
                    for basic_enemy in basic_enemies {
                        if basic_enemy.pos != enemy.pos {  // Keep balls that don't match the one to remove
                            append(&new_basic_enemies, basic_enemy)
                        }
                    }
                    
                    basic_enemies = new_basic_enemies
                    }

                }
                update_particles(DT, &enemy.particles)
            }


            player.sword.pos = {
                player.pos.x + player.current_size.x / 2 + math.cos_f32( player.sword.angle) * 45,
                player.pos.y + player.current_size.y / 2 + math.sin_f32( player.sword.angle) * 45,
            }

            if rl.IsKeyPressed(.SPACE) {
                if !player.sword.basic_spinning && player.stamina > 40{
                    player.stamina -= 40
                    player.sword.basic_spinning = true
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
        

        
            damage_text := fmt.ctprint(damage.damage)
        
            rl.DrawText(damage_text, i32(i32(SCREEN_SIZE/2)+i32(i*15)), i32(i32(SCREEN_SIZE/2+i32(i*15)) + i32(i * 15)), math.min(i32(damage.alpha), 100), rl.WHITE)
        
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
            // Outer glow layers
        for i := 10; i > 0; i -= 2 {
            alpha := 255 - (i * 20) // Reduce opacity for outer layers
            glow_color := rl.Color{u8(alpha), 255, 0, 255} // Cyan with transparency
            rl.DrawLineEx(start_pos, end_pos, f32(i), glow_color)
            glow_color = rl.Color{255, u8(alpha), 0, u8(alpha)} // Cyan with transparency
            rl.DrawLineEx(end_pos/2, end_pos, f32(i), glow_color)
        }

        for i := 10; i > 0; i -= 2 {
            alpha := 255 - (i * 20) // Reduce opacity for outer layers
            glow_color := rl.Color{0, 255, 255, u8(alpha)} // Cyan with transparency
            rl.DrawLineEx(start_pos, end_pos, f32(i), glow_color)
             glow_color = rl.Color{255, 0, 150, u8(alpha)} // Cyan with transparency
            rl.DrawLineEx(end_pos/2, end_pos , f32(i), glow_color)
        }

        // Main bright core
        rl.DrawLineEx(start_pos, end_pos, 4, rl.BLUE)

        player_health_text := fmt.ctprint("Health: ", player.health-player.health_lost)
		rl.DrawText(player_health_text, 10, 10, 20, rl.WHITE)
        player_stamina_text := fmt.ctprint("Stamina: ", player.stamina)
		rl.DrawText(player_stamina_text, 10, 30, 20, rl.WHITE)
        player_score_text := fmt.ctprint("Score: ", player.score)
        rl.DrawText(player_score_text, 10, 50, 20, rl.WHITE)

        // Begin 2D mode using the camera.
        rl.BeginMode2D(camera)


        if(!game_over){
           for star in stars {
                rl.DrawCircleV(star.pos, star.size, star.color)
            }
            for enemy in basic_enemies{
               if(enemy.health_lost == 0){
                    draw_enemy(enemy, 0)
               }
               else if(enemy.health_lost / enemy.health  < 0.2 || enemy.health_lost > enemy.health){
                    draw_enemy(enemy, 3)
                } 
                else if(enemy.health_lost /enemy.health  < 0.5 ){
                    draw_enemy(enemy, 2)
                }
                else if(enemy.health_lost /enemy.health  < 0.8 ){
                    draw_enemy(enemy,1)
                }
                else if(enemy.health_lost / enemy.health < 0.9){
                    draw_enemy(enemy,0)
                }
                else{
                    draw_enemy(enemy, 3)
                }    
       



                //rl.DrawCircleV(enemy.pos, enemy.radius, color)
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
            for &enemy in basic_enemies{
                draw_particles(&enemy.particles)
            }


            draw_sword(1)
           // draw_sword_collision_circles(player.sword) 
            
            draw_player(int(player.health_lost / player.health  * 10) )

                

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