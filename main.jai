#import "Basic";
#import "Hash_Table";
#import "Math";
#import "Random";
#import "Sound_Player";
#import "Wav_File";
#import "stb_vorbis";
#import "Window_Creation";
#import "File";
#import "String"; // For path_strip_filename.
#import "Thread";
#import "Input";
#import "System";

#load "C:/git/raylib-jai/raylib/module.jai";

#load "entities.jai";
#load "sound.jai";

windowWidth  : s32 = 1920; 
windowHeight : s32 = 1080;

shouldIgnoreInput := false;
shouldQuitGame    := false;

soundFireBullet : *Mixer_Sound_Data;

BULLET_LIVE_Y_MAX ::  1.1;
BULLET_LIVE_X_MAX ::  1.1;
BULLET_LIVE_Y_MIN :: -0.1;
BULLET_LIVE_X_MIN :: -0.1;

DELTATIME_MAX :: 0.15;
PLAYER_RADIUS :: .006;

entityManager : EntityManager;

shipMap : Texture;
skyMap : Texture;
enemyMap : Texture;
bulletMap: Texture;

moveDirection : Vector2;

// TODO: Move
GameState :: struct {
    camera   : *Camera2D;
    player   : *Player;
    aimPoint : *AimPoint;
    bullets  : [..] *Bullet;
    enemies  : [..] *Enemy;
    //emitters : [..] *Particle_Emitter;

    soundPlayer : *Sound_Player;

    lastDeltaTime    : float64 = 0.016667;
    currentDeltaTime : float;
}

main :: () {
    width  := windowWidth;
    height := windowHeight;

    InitWindow(windowWidth, windowHeight, "BulletHell");
    defer CloseWindow();

    SetTargetFPS(60);

    // TODO: gameState = init_game_state();
    gameState: GameState;
    
    //gameState.soundPlayer = init();
    //success := init(gameState.soundPlayer, xx window, true, true);
    
    player   := New(Player);
    player.position = make_vector2(.5, .5);
    player.size     = make_vector2(PLAYER_RADIUS*10, PLAYER_RADIUS*10);
    player.color    = Vector4.{1, 1, 1, 1};
    player.speed    = .15;
    //player.texture  = playerTexture;
    aimPoint := New(AimPoint);
    aimPoint.position = make_vector2(.5, .05);
    aimPoint.size     = make_vector2(0.004*2, 0.004*2);
    aimPoint.color    = Vector4.{1, 1, 1, 1};
    //aimPoint.texture  = aimPointTexture;
    enemy := New(Enemy);
    enemy.position = make_vector2(.1, .01);
    enemy.size     = make_vector2(PLAYER_RADIUS*10, PLAYER_RADIUS*10);
    enemy.color    = Vector4.{1, 1, 1, 1};
    enemy.speed    = .09;
    array_add(*gameState.enemies, enemy);
    
    camera : Camera2D;
    camera.target = player.position;
    camera.offset = make_vector2(.5, .5);
    camera.rotation = 0.0;
    camera.zoom = 1.0;
    
    gameState.lastDeltaTime = get_time();
    
    gameState.camera   = *camera;
    gameState.player   = player;
    gameState.aimPoint = aimPoint;

    while !WindowShouldClose() {

        update(*gameState);
        
        {
            BeginDrawing();
            defer EndDrawing();
          
            ClearBackground(LIGHTGRAY);
          
            {
                BeginMode2D(gameState.camera);
                defer EndMode2D();
                
                render(*gameState);  
            }
        }
       
        
    }
}

// ----------Update
update :: (gameState: *GameState) {
    
    // DeltaTime
    deltaTime, lastDeltaTime  := calculate_delta_time(gameState.currentDeltaTime, gameState.lastDeltaTime);
    gameState.currentDeltaTime = deltaTime;
    gameState.lastDeltaTime    = lastDeltaTime;
    // Music 
    //update_sound_player(gameState.soundPlayer, deltaTime);
    // Key events 
    keyLeft, keyRight, keyUp, keyDown, mouseLeft := get_key_events_this_frame();
    // Player
    update_player(gameState, keyLeft, keyRight, keyUp, keyDown, mouseLeft);
    if mouseLeft then fire_bullets(gameState);
    // AimPoint
    update_aim_point(gameState.aimPoint);
    // Enemies
    update_enemies(gameState.enemies, gameState.player.position, gameState.currentDeltaTime);
    // Bullets
    update_bullets(gameState.bullets, gameState.currentDeltaTime);
    // Camera
    update_camera_center_smooth_follow(gameState.camera, gameState.player, gameState.currentDeltaTime, windowWidth, windowHeight);
}

calculate_delta_time :: (current: float, last: float64) -> deltaTime: float, lastDeltaTime: float64 {
    deltaTime: float; lastDeltaTime: float64;

    now          := get_time();
    lastDeltaTime = now;
    deltaTime     = cast(float)(now - last);

    if deltaTime > DELTATIME_MAX then deltaTime = DELTATIME_MAX;
    
    return deltaTime, lastDeltaTime;
}

get_key_events_this_frame :: () -> keyLeft : bool, keyRight : bool, keyUp : bool, keyDown : bool, mouseLeft : bool {
    keyLeft, keyRight, keyUp, keyDown, mouseLeft : bool;

    if IsKeyDown(.KEY_LEFT)  || IsKeyDown(.KEY_A) then keyLeft   = true; else keyLeft   = false;
    if IsKeyDown(.KEY_RIGHT) || IsKeyDown(.KEY_D) then keyRight  = true; else keyRight  = false;
    if IsKeyDown(.KEY_DOWN)  || IsKeyDown(.KEY_S) then keyDown   = true; else keyDown   = false;
    if IsKeyDown(.KEY_UP)    || IsKeyDown(.KEY_W) then keyUp     = true; else keyUp     = false;
    if IsMouseButtonDown(.MOUSE_LEFT_BUTTON)      then mouseLeft = true; else mouseLeft = false;
    if IsKeyReleased(.KEY_ESCAPE)                 then CloseWindow(); 

    return keyLeft, keyRight, keyUp, keyDown, mouseLeft;
}

update_player :: (gameState: *GameState, keyLeft : bool, keyRight : bool, keyUp : bool, keyDown : bool, mouseLeft : bool) {
   
   // Put direction into a vector, then normalize, so that
   // you don't move faster diagonally!
   playerDirection: Vector2;
 
   if keyUp    then playerDirection.y -= 1;
   if keyLeft  then playerDirection.x -= 1;
   if keyDown  then playerDirection.y += 1;
   if keyRight then playerDirection.x += 1;
 
   if length(playerDirection) > 1 then playerDirection = unit_vector(playerDirection);
 
   gameState.player.position += playerDirection * gameState.player.speed * gameState.currentDeltaTime;
}

update_aim_point :: (aimPoint: *AimPoint) {
     position : Vector2;

     position.x = cast(float)GetMouseX();
     position.y = cast(float)GetMouseY();



     aimPoint.position = position; // / cast(float)windowWidth;
}

update_bullets :: (bullets: [..] *Bullet, deltaTime: float) {

    update_bullet :: (bullet : *Bullet, deltaTime: float) -> bool {
        bullet.position += bullet.direction * bullet.speed * deltaTime;

        if bullet.position.y > BULLET_LIVE_Y_MAX return true;
        if bullet.position.x > BULLET_LIVE_X_MAX return true;
        if bullet.position.y < BULLET_LIVE_Y_MIN return true;
        if bullet.position.x < BULLET_LIVE_X_MIN return true;

        return false;
    }

    for bullets {
        done := update_bullet(it, deltaTime);
        if done {
            //it.emitter.producing = false;
            remove it;
            free(it);
        }
    }
}

update_enemies :: (enemies: [..] *Enemy, playerPosition: Vector2, deltaTime: float) {
     for enemies {
        // Vector subtraction. Calculates the bullets direction and normalize it
        it.direction = unit_vector(playerPosition - it.position);
        it.position += it.direction * it.speed * deltaTime;
    }
}

try_fire_bullets :: (gameState: *GameState) {
    if gameState.player.shotCooldown > 0  return;
    if gameState.player.destroyed         return;
    
    fire_bullets(gameState);
}

fire_bullets :: (gameState: *GameState) {

    fire :: (gameState: *GameState) -> *Bullet {
        bullet := New(Bullet);
        
        bullet.speed     = 1;                               
        bullet.color     = Vector4.{1, 1, 1, 1};            
        bullet.size      = make_vector2(0.004*2, 0.004*2);  
        bullet.position.x = gameState.player.position.x;
        bullet.position.y = gameState.player.position.y;

        // Vector subtraction. Calculates the bullets direction and normalize it
        bullet.direction = unit_vector(gameState.aimPoint.position - gameState.player.position);

        return bullet;
    }

    if gameState.player.shotType == .STRAIGHT_SINGLE || gameState.player.shotType == .STRAIGHT_TRIPLE {
        bullet := fire(gameState);
        array_add(*gameState.bullets, bullet);
    }

    //gameState.player.shotCooldown += gameState.player.shotCooldownBase + (cast(float) num_shots_fired) * gameState.player.shotCooldownPerBullet;

   // play_sound(gameState.soundPlayer, soundFireBullet);
}

update_camera_center_smooth_follow :: (camera: *Camera2D, player: *Player,  delta: float, width: int, height: int)
{
    camera.offset = make_vector2(width/2.0,height/2.0);
    camera.target = player.position * cast(float)windowWidth;

   // minSpeed        := 30.0 / windowWidth;
   // minEffectLength := 10.0 / windowWidth;
   // fractionSpeed   := 0.8  / windowWidth;
   // 
   // camera.offset = make_vector2(.5, .5);
   // diff         := player.position - camera.target;
   // diffLength   := length(diff);
   // 
   // if diffLength > minEffectLength
   // {
   //     speed         := max(fractionSpeed * diffLength, minSpeed);
   //     camera.target  = camera.target + diff * (speed * delta / diffLength);
   // }
}

// ----------Update

// ----------Render
render :: (using gameState: *GameState) {

    for bullets draw_bullet(*bulletMap, it.position, it.size, it.color);
    for enemies draw_enemy(*enemyMap, it.position, it.size, it.color);
        
    if !player.destroyed  draw_player(*shipMap, player.position, player.size, player.color);
        
    //render_sprite_quad_centered(aimPoint.position, aimPoint.size, aimPoint.color);

    rect:Rectangle;
    rect.x      = aimPoint.position.x;
    rect.y      = aimPoint.position.y;
    rect.width  = aimPoint.size.x;
    rect.height = aimPoint.size.y;
    
    DrawRectangleRec(rect, RED);
    
    text := sprint("(%,%)", rect.x, rect.y); 
    s := to_c_string(text);
    DrawText(s, cast(s32)rect.x, cast(s32)rect.y ,10, BLACK);

} 

draw_bullet :: (texture: *Texture, pos: Vector2, size: Vector2, color: Vector4) {
    render_sprite_quad_centered(pos, size, color);
}
draw_enemy  :: (texture: *Texture, pos: Vector2, size: Vector2, color: Vector4) {
    render_sprite_quad_centered(pos, size, color);
}
draw_player :: (texture: *Texture, pos: Vector2, size: Vector2, color: Vector4) {
   render_sprite_quad_centered(pos, size, color);
}

render_sprite_quad_centered :: (position: Vector2, size: Vector2, color: Vector4) {
    pos    := position * cast(float) windowWidth;
    height := size.x * .5 * windowWidth;
    width  := size.y * .5 * windowWidth;

    // xxx
    rect:Rectangle;
    rect.x      = pos.x;
    rect.y      = pos.y;
    rect.width  = height;
    rect.height = width;

    DrawRectangleRec(rect, RED);

    text := sprint("(%,%)", pos.x, pos.y); 
    s := to_c_string(text);
    DrawText(s, cast(s32)pos.x, cast(s32)pos.y ,10, BLACK);

}
// ----------Render

//init_textures :: ()  {
//    shipMap    = make_texture("ship.png");
//    skyMap     = make_texture("ground.png");
//    enemyMap   = make_texture("bug3.png");
//    bulletMap  = make_texture("bullet.png");
//}