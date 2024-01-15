const std = @import("std");
const c = @import("root").c;

// TODO: Consolidate errors into an error set

// TODO: Use OpenCL integral types and *always* explicitly cast

pub fn getDevice() !c.cl_device_id {
    var platforms: [16]c.cl_platform_id = undefined;
    var num_platforms: c.cl_uint = undefined;

    switch (c.clGetPlatformIDs(
        platforms.len,
        @ptrCast(&platforms),
        &num_platforms,
    )) {
        c.CL_SUCCESS => {},
        c.CL_INVALID_VALUE => unreachable,
        else => unreachable,
    }

    if (num_platforms == 0) {
        return error.CLNoAvailablePlatforms;
    }

    var devices: [16]c.cl_device_id = undefined;
    var num_devices: c.cl_uint = undefined;

    // TODO: Rank devices on suitability
    for (platforms[0..num_platforms]) |platform| {
        switch (c.clGetDeviceIDs(
            platform,
            c.CL_DEVICE_TYPE_ALL,
            devices.len,
            @ptrCast(&devices),
            &num_devices,
        )) {
            c.CL_SUCCESS => {},
            c.CL_INVALID_PLATFORM,
            c.CL_INVALID_DEVICE_TYPE,
            c.CL_INVALID_VALUE,
            => unreachable,
            c.CL_DEVICE_NOT_FOUND => continue,
            c.CL_OUT_OF_RESOURCES => return error.CLOutOfResources,
            c.CL_OUT_OF_HOST_MEMORY => return error.CLOutOfHostMemory,
            else => unreachable,
        }

        std.debug.assert(devices.len > 0);

        break;
    } else {
        return error.CLNoSuitableDevices;
    }

    return devices[0];
}

pub fn createContext(device: c.cl_device_id) !c.cl_context {
    var errcode_ret: c.cl_int = undefined;

    const context = c.clCreateContext(
        null,
        1, // TODO: Allow for multiple devices
        &device,
        null,
        null,
        &errcode_ret,
    );

    switch (errcode_ret) {
        c.CL_SUCCESS => {},
        c.CL_INVALID_PLATFORM => return error.CLInvalidPlatform,
        c.CL_INVALID_VALUE => return error.CLInvalidValue,
        c.CL_INVALID_DEVICE => return error.CLInvalidDevice,
        c.CL_DEVICE_NOT_AVAILABLE => return error.CLDeviceNotAvailable,
        c.CL_OUT_OF_HOST_MEMORY => return error.CLOutOfHostMemory,
        else => unreachable,
    }

    std.debug.assert(context != null);

    return context;
}

pub fn createCommandQueue(context: c.cl_context, device: c.cl_device_id) !c.cl_command_queue {
    var errcode_ret: c.cl_int = undefined;

    const command_queue = c.clCreateCommandQueueWithProperties(
        context,
        device,
        null,
        &errcode_ret,
    );

    switch (errcode_ret) {
        c.CL_SUCCESS => {},
        c.CL_INVALID_CONTEXT => return error.CLInvalidContext,
        c.CL_INVALID_DEVICE => return error.CLInvalidDevice,
        c.CL_INVALID_VALUE => return error.CLInvalidValue,
        c.CL_INVALID_QUEUE_PROPERTIES => return error.CLInvalidQueueProperties,
        c.CL_OUT_OF_RESOURCES => return error.CLOutOfResources,
        c.CL_OUT_OF_HOST_MEMORY => return error.CLOutOfHostMemory,
        else => unreachable,
    }

    std.debug.assert(command_queue != null);

    return command_queue;
}

pub fn createProgramFromSource(context: c.cl_context, program_src: []const u8) !c.cl_program {
    var errcode_ret: c.cl_int = undefined;

    var program_src_temp = program_src;

    const program = c.clCreateProgramWithSource(
        context,
        1, // TODO: Allow for multiple devices
        @ptrCast(&program_src_temp),
        null,
        &errcode_ret,
    );

    switch (errcode_ret) {
        c.CL_SUCCESS => {},
        c.CL_INVALID_CONTEXT => return error.CLInvalidContext,
        c.CL_INVALID_VALUE => return error.CLInvalidValue,
        c.CL_OUT_OF_RESOURCES => return error.CLOutOfResources,
        c.CL_OUT_OF_HOST_MEMORY => return error.CLOutOfHostMemory,
        else => unreachable,
    }

    std.debug.assert(program != null);

    return program;
}

pub fn buildProgram(program: c.cl_program) !void {
    switch (c.clBuildProgram(
        program,
        0,
        null, // NOTE: Indicates all devices in context by default
        null,
        null,
        null,
    )) {
        c.CL_SUCCESS => {},
        c.CL_INVALID_PROGRAM => return error.CLInvalidProgram,
        c.CL_INVALID_VALUE => return error.CLInvalidValue,
        c.CL_INVALID_DEVICE => return error.CLInvalidDevice,
        c.CL_INVALID_BINARY => return error.CLInvalidBinary,
        c.CL_INVALID_BUILD_OPTIONS => return error.CLInvalidBuildOptions,
        c.CL_INVALID_OPERATION => return error.CLInvalidOperation,
        c.CL_COMPILER_NOT_AVAILABLE => return error.CLCompilerNotAvailable,
        c.CL_BUILD_PROGRAM_FAILURE => return error.CLBuildProgramFailure,
        c.CL_OUT_OF_RESOURCES => return error.CLOutOfResources,
        c.CL_OUT_OF_HOST_MEMORY => return error.CLOutOfHostMemory,
        else => unreachable,
    }
}

pub fn createKernel(program: c.cl_program, kernel_name: []const u8) !c.cl_kernel {
    var errcode_ret: c.cl_int = undefined;

    const kernel = c.clCreateKernel(
        program,
        @ptrCast(kernel_name),
        &errcode_ret,
    );

    switch (errcode_ret) {
        c.CL_SUCCESS => {},
        c.CL_INVALID_PROGRAM => return error.CLInvalidProgram,
        c.CL_INVALID_PROGRAM_EXECUTABLE => return error.CLInvalidProgramExecutable,
        c.CL_INVALID_KERNEL_NAME => return error.CLInvalidKernelName,
        c.CL_INVALID_KERNEL_DEFINITION => return error.CLInvalidKernelDefinition,
        c.CL_INVALID_VALUE => return error.CLInvalidKernelName,
        c.CL_OUT_OF_RESOURCES => return error.CLOutOfResources,
        c.CL_OUT_OF_HOST_MEMORY => return error.CLOutOfHostMemory,
        else => unreachable,
    }

    std.debug.assert(kernel != null);

    return kernel;
}

pub fn createBuffer(context: c.cl_context, flags: c.cl_mem_flags, size: usize) !c.cl_mem {
    var errcode_ret: c.cl_int = undefined;

    const buffer = c.clCreateBuffer(
        context,
        flags, // TODO: Make this a packed struct
        size,
        null, // TODO: Allow for memory mapping
        &errcode_ret,
    );

    switch (errcode_ret) {
        c.CL_SUCCESS => {},
        c.CL_INVALID_CONTEXT => return error.CLInvalidContext,
        c.CL_INVALID_VALUE => return error.CLInvalidValue,
        c.CL_INVALID_BUFFER_SIZE => return error.CLInvalidBufferSize,
        c.CL_INVALID_HOST_PTR => return error.CLInvalidHostPtr,
        c.CL_MEM_OBJECT_ALLOCATION_FAILURE => return error.CLMemObjectAllocationFailure,
        c.CL_OUT_OF_RESOURCES => return error.CLOutOfResources,
        c.CL_OUT_OF_HOST_MEMORY => return error.CLOutOfHostMemory,
        else => unreachable,
    }

    std.debug.assert(buffer != null);

    return buffer;
}

pub fn setKernelArgs(kernel: c.cl_kernel, arg_values: anytype) !void {
    switch (@typeInfo(@TypeOf(arg_values))) {
        .Struct => |struct_info| {
            if (!struct_info.is_tuple) {
                @compileError(@panic("Expected arg_values to be a tuple, not " ++ @typeName(@TypeOf(arg_values))));
            }
        },
        else => @compileError(@panic("Expected arg_values to be a tuple, not " ++ @typeName(@TypeOf(arg_values)))),
    }

    inline for (arg_values, 0..) |arg_value, i| {
        switch (c.clSetKernelArg(
            kernel,
            @intCast(i),
            @sizeOf(@TypeOf(arg_value)),
            @ptrCast(&arg_value),
        )) {
            c.CL_SUCCESS => {},
            c.CL_INVALID_KERNEL => return error.CLInvalidKernel,
            c.CL_INVALID_ARG_INDEX => return error.CLInvalidArgIndex,
            c.CL_INVALID_ARG_VALUE => return error.CLInvalidArgValue,
            c.CL_INVALID_MEM_OBJECT => return error.CLInvalidMemObject,
            c.CL_INVALID_SAMPLER => return error.CLInvalidSampler,
            c.CL_INVALID_DEVICE_QUEUE => return error.CLInvalidDeviceQueue,
            c.CL_INVALID_ARG_SIZE => return error.CLInvalidArgSize,
            else => unreachable,
        }
    }
}
