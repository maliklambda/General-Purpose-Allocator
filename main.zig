const std = @import("std");
const alloc = @import("alloc.zig");


pub fn main () void {
    // const std_alloc = std.heap.page_allocator;
    // std_alloc.alloc(comptime T: type, n: usize)
    // std_alloc.free(memory: anytype)
    var allocator = alloc.Allocator.init();

    var ints = allocator.alloc(u32, 2);
    for (0..ints.len) |i| {ints[i]=std.math.maxInt(u32);}

    var other_ints = allocator.alloc(u8, 5);
    for (0..other_ints.len) |i| {other_ints[i]=std.math.maxInt(u8)-1;}

    var new_ints = allocator.alloc(u8, 5);
    for (0..new_ints.len) |i| {new_ints[i]=std.math.maxInt(u8)-5;}

    var new_ints_2 = allocator.alloc(u8, 5);
    for (0..new_ints_2.len) |i| {new_ints_2[i]=std.math.maxInt(u8)-200;}

    std.log.info("Glob data: {any}", .{allocator.data});
    allocator.free(other_ints);
    std.log.info("Glob data: {any}", .{allocator.data});

    const new_ints_3 = allocator.alloc(u8, 5);
    @memset(new_ints_3, 3);
    std.log.info("Glob data: {any}", .{allocator.data});
}
