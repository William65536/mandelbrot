const std = @import("std");
pub const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cDefine("CL_TARGET_OPENCL_VERSION", "330");
    @cInclude("CL/cl.h");
});
const Window = @import("Window.zig");
const cl = @import("cl.zig");

const Point = packed struct {
    x: f64,
    y: f64,
};

const Surface = struct {
    sdl: c.SDL_Surface,
    pixels: [*]u32,
    width: usize,
    height: usize,

    fn format(self: Surface, r: u8, g: u8, b: u8, a: u8) u32 {
        return c.SDL_MapRGBA(@ptrCast(&self.sdl.format.*.format), r, g, b, a);
    }
};

fn screenToWorld(x: usize, y: usize, width: usize, height: usize, scale: f64, origin: Point) Point {
    const halfwidth = (@as(f64, @floatFromInt(width)) - 1.0) * 0.5;
    const halfheight = (@as(f64, @floatFromInt(height)) - 1.0) * 0.5;

    return .{
        .x = (@as(f64, @floatFromInt(x)) - halfwidth) / scale - origin.x,
        .y = (halfheight - @as(f64, @floatFromInt(y))) / scale - origin.y,
    };
}

fn mandelbrotFunction(max_iteration_count: usize, z0: Point) usize {
    var z = Point{ .x = 0.0, .y = 0.0 };

    var iteration_count: usize = 0;

    while (z.x * z.x + z.y * z.y <= 2 * 2 and iteration_count < max_iteration_count) : (iteration_count += 1) {
        const zxtemp = z.x * z.x - z.y * z.y + z0.x;
        z.y = 2 * z.x * z.y + z0.y;
        z.x = zxtemp;
    }

    return iteration_count;
}

fn mandelbrot(windowsurface: Surface, scale: f64, origin: Point, max_iteration_count: usize) void {
    for (0..windowsurface.width) |x| {
        for (0..windowsurface.height) |y| {
            const z0 = screenToWorld(
                x,
                y,
                windowsurface.width,
                windowsurface.height,
                scale,
                origin,
            );

            const iteration_count = mandelbrotFunction(max_iteration_count, z0);

            const colort = @min(@as(f64, @floatFromInt(iteration_count)) / @as(f64, @floatFromInt(max_iteration_count)), 1.0) * std.math.pi;
            const r: u8 = @intFromFloat(@round((0.5 * @sin(colort) + 0.5) * 0xff.0));
            const g: u8 = @intFromFloat(@round((0.5 * @sin(colort + 0.5) + 0.5) * 0xff.0));
            const b: u8 = @intFromFloat(@round((0.5 * @sin(colort + 1.0) + 0.5) * 0xff.0));

            windowsurface.pixels[x + y * @as(usize, windowsurface.width)] = windowsurface.format(r, g, b, 0xff);
        }
    }
}

fn mandelbrotGPU(
    kernel: c.cl_kernel,
    command_queue: c.cl_command_queue,
    screen_gpu: c.cl_mem,
    windowsurface: Surface,
    scale: f64,
    origin: Point,
    max_iteration_count: usize,
) !void {
    try cl.setKernelArgs(kernel, .{
        screen_gpu,
        @as(c.cl_ulong, @intCast(windowsurface.width)),
        @as(c.cl_ulong, @intCast(windowsurface.height)),
        @as(c.cl_double, @floatCast(scale)),
        c.cl_double2{ .s = @bitCast(origin) },
        @as(c.cl_ulong, @intCast(max_iteration_count)),
    });

    switch (c.clEnqueueWriteBuffer(
        command_queue,
        screen_gpu,
        c.CL_TRUE,
        0,
        @sizeOf(@TypeOf(windowsurface.pixels[0])) * windowsurface.width * windowsurface.height,
        windowsurface.pixels,
        0,
        null,
        null,
    )) {
        c.CL_SUCCESS => {},
        else => @panic("TODO!"),
    }

    switch (c.clEnqueueNDRangeKernel(
        command_queue,
        kernel,
        2,
        null,
        @ptrCast(&[2]usize{ windowsurface.width, windowsurface.height }),
        null,
        0,
        null,
        null,
    )) {
        c.CL_SUCCESS => {},
        else => @panic("TODO!"),
    }

    switch (c.clFinish(command_queue)) {
        c.CL_SUCCESS => {},
        else => @panic("TODO!"),
    }

    switch (c.clEnqueueReadBuffer(
        command_queue,
        screen_gpu,
        c.CL_TRUE,
        0,
        @sizeOf(@TypeOf(windowsurface.pixels[0])) * windowsurface.width * windowsurface.height,
        windowsurface.pixels,
        0,
        null,
        null,
    )) {
        c.CL_SUCCESS => {},
        else => @panic("TODO!"),
    }

    for (0..windowsurface.width) |x| {
        for (0..windowsurface.height) |y| {
            const color = &windowsurface.pixels[x + y * windowsurface.width];

            color.* = windowsurface.format(
                @intCast((color.* >> 8 * 3) & 0xff),
                @intCast((color.* >> 8 * 2) & 0xff),
                @intCast((color.* >> 8 * 1) & 0xff),
                @intCast((color.* >> 8 * 0) & 0xff),
            );
        }
    }
}

pub fn main() !void {
    const device: c.cl_device_id = try cl.getDevice();

    const context: c.cl_context = try cl.createContext(device);
    defer std.debug.assert(c.clReleaseContext(context) == c.CL_SUCCESS);

    const command_queue: c.cl_command_queue = try cl.createCommandQueue(context, device);
    defer std.debug.assert(c.clReleaseCommandQueue(command_queue) == c.CL_SUCCESS);

    const program_src = @embedFile("mandelbrot.cl");

    const program: c.cl_program = try cl.createProgramFromSource(context, program_src);
    defer std.debug.assert(c.clReleaseProgram(program) == c.CL_SUCCESS);

    cl.buildProgram(program) catch |e| switch (e) {
        error.CLInvalidProgram => @panic("TODO!"), // TODO: Log debug info
        else => return e,
    };

    const kernel: c.cl_kernel = try cl.createKernel(program, "mandelbrot");
    defer std.debug.assert(c.clReleaseKernel(kernel) == c.CL_SUCCESS);

    const window = try Window.init("Mandelbrot", 600, 400, null);
    defer window.deinit();

    const arrow_cursor = c.SDL_CreateSystemCursor(c.SDL_SYSTEM_CURSOR_ARROW);
    defer c.SDL_FreeCursor(arrow_cursor);
    const pan_cursor = c.SDL_CreateSystemCursor(c.SDL_SYSTEM_CURSOR_SIZEALL);
    defer c.SDL_FreeCursor(pan_cursor);

    var windowsurface: Surface = l: {
        const sdl: c.SDL_Surface = (c.SDL_GetWindowSurface(window.window) orelse {
            return error.SDLFailedWindowSurfaceCreation;
        }).*;

        break :l .{
            .sdl = sdl,
            .pixels = @ptrCast(@alignCast(sdl.pixels)),
            .width = @intCast(sdl.w),
            .height = @intCast(sdl.h),
        };
    };

    const screen_gpu = try cl.createBuffer(
        context,
        c.CL_MEM_WRITE_ONLY,
        @sizeOf(@TypeOf(windowsurface.pixels[0])) * windowsurface.width * windowsurface.height,
    );
    defer std.debug.assert(c.clReleaseMemObject(screen_gpu) == c.CL_SUCCESS);

    var mouse: c.SDL_Point = undefined;
    var pan: ?struct { down: c.SDL_Point, origin: Point } = null;
    var origin = Point{ .x = 0.0, .y = 0.0 };
    var scale: f64 = 250.0;
    var max_iteration_count: usize = 64;

    var isgpu = false;

    render_loop: while (true) {
        c.SDL_Delay(10);

        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    break :render_loop;
                },
                c.SDL_KEYDOWN => switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => break :render_loop,
                    c.SDLK_UP => max_iteration_count *= 2,
                    c.SDLK_DOWN => if (max_iteration_count > 1) {
                        max_iteration_count = @divExact(max_iteration_count, 2);
                    },
                    c.SDLK_e => isgpu = !isgpu,
                    else => {},
                },
                c.SDL_WINDOWEVENT => {
                    if (event.window.event == c.SDL_WINDOWEVENT_SIZE_CHANGED) {
                        windowsurface = l: {
                            const sdl: c.SDL_Surface = (c.SDL_GetWindowSurface(window.window) orelse {
                                return error.SDLFailedWindowSurfaceCreation;
                            }).*;

                            break :l .{
                                .sdl = sdl,
                                .pixels = @ptrCast(@alignCast(sdl.pixels)),
                                .width = @intCast(sdl.w),
                                .height = @intCast(sdl.h),
                            };
                        };
                    }
                },
                c.SDL_MOUSEBUTTONDOWN => {
                    c.SDL_SetCursor(pan_cursor);

                    pan = .{
                        .down = mouse,
                        .origin = origin,
                    };
                },
                c.SDL_MOUSEBUTTONUP => {
                    c.SDL_SetCursor(arrow_cursor);

                    pan = null;
                },
                c.SDL_MOUSEMOTION => {
                    mouse.x = event.motion.x;
                    mouse.y = event.motion.y;

                    if (pan) |*p| {
                        origin.x = p.origin.x + @as(f64, @floatFromInt(mouse.x - p.down.x)) / scale;
                        origin.y = p.origin.y + @as(f64, @floatFromInt(p.down.y - mouse.y)) / scale;
                    }
                },
                c.SDL_MOUSEWHEEL => {
                    const zoom_delta = 1.2;

                    if (event.wheel.y > 0) {
                        scale *= zoom_delta;
                    } else if (event.wheel.y < 0) {
                        scale /= zoom_delta;
                    }
                },
                else => {},
            }
        }

        if (isgpu) {
            try mandelbrotGPU(
                kernel,
                command_queue,
                screen_gpu,
                windowsurface,
                scale,
                origin,
                max_iteration_count,
            );
        } else {
            mandelbrot(
                windowsurface,
                scale,
                origin,
                max_iteration_count,
            );
        }

        _ = c.SDL_UpdateWindowSurface(window.window);
    }
}
