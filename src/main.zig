const std = @import("std");
pub const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Window = @import("Window.zig");

pub fn main() !void {
    const window = try Window.init("SDL Window", 600, 400, null);
    defer window.deinit();
    const renderer = window.renderer;

    render_loop: while (true) {
        c.SDL_Delay(10);

        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    break :render_loop;
                },
                else => {},
            }
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0x00, 0xff, 0xff);
        _ = c.SDL_RenderClear(renderer);

        c.SDL_RenderPresent(renderer);
    }
}
