const std = @import("std");
// If we don't want to namespace the SDL functions, use
// use @cImport({...
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_image.h");
});

const window_width: u32 = 1200;
const window_height: u32 = 800;
const sprite_width: u32 = 18;
const sprite_height: u32 = 28;
const TRUE: c_int = 1;
const FALSE: c_int = 0;

// These are needed because we can't implicitely convert from a C Enum integer
// to c_int in Zig.  Maybe this will get fixed in the future?
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, sdl.SDL_WINDOWPOS_UNDEFINED_MASK);
const SDL_TEXTUREACCESS_TARGET = @bitCast(c_int,
                                          sdl.SDL_TEXTUREACCESS_TARGET);

// NULL for SDL_Texture
var null_ptr: ?*sdl.SDL_Texture = null;

pub fn main() anyerror!void {
    std.debug.print("starting sprite blitting example\n", .{});

    // Initialize SDL2, and defer quit
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        sdl.SDL_Log("Unable to initialize SDL: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer sdl.SDL_Quit();

    // Initialize SDL_Image
    if (sdl.IMG_Init(sdl.IMG_INIT_PNG) == 0) {
        sdl.SDL_Log("Unable to initialize SDL_Image: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer sdl.IMG_Quit(); // Remember, FILO for defers, so this gets run before SDL_Quit

    // Initialize the window.
    const window = sdl.SDL_CreateWindow("Sprite Blitting",
                                      SDL_WINDOWPOS_UNDEFINED,
                                      SDL_WINDOWPOS_UNDEFINED,
                                      window_width,
                                      window_height,
                                      sdl.SDL_WINDOW_OPENGL) orelse {
        sdl.SDL_Log("Unable to create window: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    // Get the renderer
    const renderer = sdl.SDL_CreateRenderer(window, -1, 0) orelse {
        sdl.SDL_Log("Unable to create renderer: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyRenderer(renderer);

    // Load the Spritesheet
    var sprite_surface = sdl.IMG_Load("BrogueFont5.png");
    if (sprite_surface == 0) {
        sdl.SDL_Log("Unable to load spritesheet: file not found");
        return error.SDLInitializationFailed;
    }

    // Convert black pixels to be transparent
    if (sdl.SDL_SetColorKey(sprite_surface, TRUE, 0x000000ff) != 0) {
        sdl.SDL_Log("Unable to set color key: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    // Convert the surface to a texture
    var sprite_texture = sdl.SDL_CreateTextureFromSurface(
        renderer, sprite_surface) orelse {
        sdl.SDL_Log("Unable to create texture from surface: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    // Set the blend mode to ADD
    _ = sdl.SDL_SetTextureBlendMode(sprite_texture,
                                    sdl.SDL_BLENDMODE_ADD);

    // Create a double buffer
    var buffer = sdl.SDL_CreateTexture(renderer,
                                       0,
                                       SDL_TEXTUREACCESS_TARGET,
                                       window_width,
                                       window_height) orelse {
        sdl.SDL_Log("Unable to create double buffer texture: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    // Initialize the RNG
    var seed: u64 = undefined;
    try std.os.getrandom(std.mem.asBytes(&seed));
    var rng = std.rand.DefaultPrng.init(seed);

    // Main loop
    var quit = false;
    var elapsed_ticks: u32 = 1001; // To guarantee an initial render
    var old_ticks: u32 = 0;
    while (!quit) {
        // We want to render once a second, but we don't want to hang up our event
        // pump, so SDL_Delay is a bad choice.  Instead figure out how long the main
        // loop takes, and increment a counter until a second has passed, then render
        old_ticks = sdl.SDL_GetTicks();

        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                sdl.SDL_QUIT => {
                    quit = true;
                },
                sdl.SDL_KEYDOWN => {
                    if (event.@"key".@"keysym".@"sym" == sdl.SDLK_ESCAPE) {
                        quit = true;
                    }
                },
                else => {},
            }
        }

        if (elapsed_ticks > 1000) {
            elapsed_ticks = 0;
            // Set the render target to the double buffer
            _ = sdl.SDL_SetRenderTarget(renderer, buffer);
            _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
            _ = sdl.SDL_RenderClear(renderer);

            // Now blit a random assortment of sprites, in random colors,
            // from the spritesheet to the buffer
            var i: u32 = 0;
            const i_end = (window_width / sprite_width) + 1;
            const j_end = (window_height / sprite_height) + 1;
            while (i < i_end) {
                var j: u32 = 0;
                while (j < j_end) {
                    var glyph_x = rng.random.int(u32) % 16;
                    var glyph_y = rng.random.int(u32) % 13 + 3;

                    // Random color
                    var dest_rect = sdl.SDL_Rect{.x = @bitCast(c_int, i * 18),
                                                 .y = @bitCast(c_int, j * 28),
                                                 .w = 18,
                                                 .h = 28};
                    var src_rect = sdl.SDL_Rect{.x = @bitCast(c_int, glyph_x * 18),
                                                .y = @bitCast(c_int, glyph_y * 28),
                                                .w = 18,
                                                .h = 28};
                    // Fill the background of the sprite with a random color
                    var bg = sdl.SDL_Color{.r = rng.random.int(u8),
                                           .g = rng.random.int(u8),
                                           .b = rng.random.int(u8),
                                           .a = 255};
                    _ = sdl.SDL_SetRenderDrawColor(renderer, bg.r, bg.g, bg.b, bg.a);
                    _ = sdl.SDL_RenderFillRect(renderer, &dest_rect);


                    // Blit the sprite
                    var fg = sdl.SDL_Color{.r = rng.random.int(u8),
                                           .g = rng.random.int(u8),
                                           .b = rng.random.int(u8),
                                           .a = 255};
                    _ = sdl.SDL_SetTextureColorMod(sprite_texture, fg.r, fg.g, fg.b);
                    _ = sdl.SDL_RenderCopy(renderer, sprite_texture, &src_rect, &dest_rect);
                    j += 1;
                }
                i += 1;
            }
        }

        // Point the renderer back to the screen
        _ = sdl.SDL_SetRenderTarget(renderer, null_ptr);
        // Copy the double buffer to the screen
        _ = sdl.SDL_RenderClear(renderer);
        _ = sdl.SDL_RenderCopy(renderer, buffer, 0 , 0);
        sdl.SDL_RenderPresent(renderer);

        elapsed_ticks += sdl.SDL_GetTicks() - old_ticks;
    }
}
