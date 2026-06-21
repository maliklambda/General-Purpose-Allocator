const std = @import("std");
const Allocator = @import("alloc.zig").Allocator;


pub fn main () void {
    var allocator = Allocator.init();

    const ints = allocator.alloc(u32, 2);
    @memset(ints, std.math.maxInt(u32));

    const other_ints = allocator.alloc(u8, 5);
    @memset(ints, std.math.maxInt(u8)-1);

    const new_ints = allocator.alloc(u8, 5);
    @memset(new_ints, std.math.maxInt(u8)-5);

    const new_ints_2 = allocator.alloc(u8, 5);
    @memset(new_ints_2, std.math.maxInt(u8)-200);

    std.log.info("Glob data: {any}", .{allocator.data});
    allocator.free(other_ints);
    std.log.info("Glob data: {any}", .{allocator.data});

    const new_ints_3 = allocator.alloc(u8, 5);
    @memset(new_ints_3, 3);
    std.log.info("Glob data: {any}", .{allocator.data});
}
