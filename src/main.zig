const std = @import("std");
const testing = std.testing;
const expectEqual = testing.expectEqual;

const c = @cImport({
    @cInclude("ggml/ggml.h");
});

pub fn numTypeToTensorType(comptime t: type) c.ggml_type {
    switch (@typeInfo(t)) {
        .Int => |info| {
            if (info.signedness == .unsigned) {
                @compileError("Unsigned integers are not supported");
            }

            switch (info.bits) {
                8  => return c.GGML_TYPE_I8,
                16 => return c.GGML_TYPE_I16,
                32 => return c.GGML_TYPE_I32,
                // 64 => return .I64,
                else => @compileError("Unsupported integer type"),
            }
        },
        .Float => |info| switch (info.bits) {
            16 => return c.GGML_TYPE_F16,
            32 => return c.GGML_TYPE_F32,
            // 64 => return .F64,
            else => @compileError("Unsupported float type"),
        },

        else => @compileError("Unsupported type"),
    }
}

const ContextParams = struct {
    mem_size: usize,
    mem_buffer: ?[*]u8 = null,
};

const Context = struct {
    ggml: *c.ggml_context,

    pub fn init(params: ContextParams) !Context {
        var ggml = c.ggml_init(.{
            .mem_size   = params.mem_size,
            .mem_buffer = if (params.mem_buffer) |b| b else c.NULL,
        });
        
        if (ggml == null) {
            return error.OutOfMemory;
        }

        return Context{ .ggml = ggml.? };
    }

    pub fn deinit(self: *Context) void {
        c.ggml_free(self.ggml);
    }

    pub fn newTensor1d(self: *Context, comptime tensor_type: type, n: i32) !*c.ggml_tensor {
        var t = c.ggml_new_tensor_1d(self.ggml, numTypeToTensorType(tensor_type), @intCast(c_int, n));
        if (t == null) {
            return error.OutOfMemory;
        }
        return t;
    }

    pub fn newTensor2d(self: *Context, comptime tensor_type: type, n: i32, m: i32) !*c.ggml_tensor {
        var t = c.ggml_new_tensor_2d(self.ggml, numTypeToTensorType(tensor_type), @intCast(c_int, n), @intCast(c_int, m));
        if (t == null) {
            return error.OutOfMemory;
        }
        return t;
    }

    pub fn newTensor3d(self: *Context, comptime tensor_type: type, n: i32, m: i32, k: i32) !*c.ggml_tensor {
        var t = c.ggml_new_tensor_3d(self.ggml, numTypeToTensorType(tensor_type), @intCast(c_int, n), @intCast(c_int, m), @intCast(c_int, k));
        if (t == null) {
            return error.OutOfMemory;
        }
        return t;
    }

    pub fn printObjects(self: *Context) void {
        c.ggml_print_objects(self.ggml);
    }
};

test "basic add functionality" {
    c.ggml_time_init(); // Need this, or we face Illegal Instruction (core dumped) on Windows

    var ctx0 = try Context.init(.{ .mem_size = 128 * 1024 * 1024 });
    defer ctx0.deinit();

    var t1 = try ctx0.newTensor1d(f32, 10);
    var t2 = try ctx0.newTensor2d(i16, 10, 20);
    var t3 = try ctx0.newTensor3d(i32, 10, 20, 30);

    try expectEqual(t1.*.n_dims, 1);
    try expectEqual(t1.*.ne[0] , 10);
    try expectEqual(t1.*.nb[1] , 10 * @sizeOf(f32));

    try expectEqual(t2.*.n_dims, 2);
    try expectEqual(t2.*.ne[0] , 10);
    try expectEqual(t2.*.ne[1] , 20);
    try expectEqual(t2.*.nb[1] , 10 * @sizeOf(i16));
    try expectEqual(t2.*.nb[2] , 10 * 20 * @sizeOf(i16));

    try expectEqual(t3.*.n_dims, 3);
    try expectEqual(t3.*.ne[0] , 10);
    try expectEqual(t3.*.ne[1] , 20);
    try expectEqual(t3.*.ne[2] , 30);
    try expectEqual(t3.*.nb[1] , 10 * @sizeOf(i32));
    try expectEqual(t3.*.nb[2] , 10 * 20 * @sizeOf(i32));
    try expectEqual(t3.*.nb[3] , 10 * 20 * 30 * @sizeOf(i32));

    ctx0.printObjects();
}