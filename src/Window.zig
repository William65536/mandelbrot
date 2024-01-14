const std = @import("std");
const c = @import("root").c;

const Self = @This();

window: *c.SDL_Window,
renderer: *c.SDL_Renderer,

pub fn init(title: [*c]const u8, width: c_int, height: c_int, comptime favicon_path: ?[]const u8) !Self {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLFailedInitialization;
    }
    errdefer c.SDL_Quit();

    var ret: Self = undefined;

    ret.window = c.SDL_CreateWindow(
        title,
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        width,
        height,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_MAXIMIZED,
    ) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLFailedWindowCreation;
    };
    errdefer c.SDL_DestroyWindow(ret.window);

    const favicon = if (favicon_path) |f| l: {
        const favicon_bmp = @embedFile(f);
        const rw = c.SDL_RWFromConstMem(favicon_bmp, favicon_bmp.len) orelse {
            c.SDL_Log("Unable to get RW from memory: %s", c.SDL_GetError());
            return error.SDLRWCreationFailed;
        };
        defer std.debug.assert(c.SDL_RWclose(rw) == 0);

        break :l c.SDL_LoadBMP_RW(rw, 0) orelse {
            c.SDL_Log("Unable to load BMP: %s", c.SDL_GetError());
            return error.SDLBMPLoadFailed;
        };
    } else null;
    defer if (favicon_path != null) {
        c.SDL_FreeSurface(favicon);
    };

    c.SDL_SetWindowIcon(ret.window, favicon);

    ret.renderer = c.SDL_CreateRenderer(ret.window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLFailedRendererCreation;
    };

    return ret;
}

pub fn deinit(self: Self) void {
    defer c.SDL_Quit();
    defer c.SDL_DestroyWindow(self.window);
    defer c.SDL_DestroyRenderer(self.renderer);
}

pub fn initTexture(self: Self, comptime path: []const u8) !*c.SDL_Texture {
    const bmp = @embedFile(path); // TODO: Maybe offer up an option for whether or not they want to read the file in at runtime

    const rw = c.SDL_RWFromConstMem(bmp, bmp.len) orelse {
        c.SDL_Log("Unable to get RW from memory: %s", c.SDL_GetError());
        return error.SDLRWCreationFailed;
    };
    defer std.debug.assert(c.SDL_RWclose(rw) == 0);

    const surface = c.SDL_LoadBMP_RW(rw, 0) orelse {
        c.SDL_Log("Unable to load BMP: %s", c.SDL_GetError());
        return error.SDLBMPLoadFailed;
    };
    defer c.SDL_FreeSurface(surface);

    return c.SDL_CreateTextureFromSurface(self.renderer, surface) orelse {
        c.SDL_Log("Unable to create texture from surface: %s", c.SDL_GetError());
        return error.SDLTextureCreationFailed;
    };
}
