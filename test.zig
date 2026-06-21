const std = @import("std");
const testing = std.testing;
const Allocator = @import("alloc.zig").Allocator;
const offset_t = @import("alloc.zig").offset_t;



test "simple allocation" {
    var allocator = Allocator.init();
    const length = 128;
    const value: u8 = 115;
    const data = allocator.alloc(u8, length);
    @memset(data, value);
    const left = (allocator.data[0..length]).*;
    const right = [_] u8 {value}**length;
    try testing.expectEqualSlices(u8, &left, &right);
}


test "multiple allocations" {
    var allocator = Allocator.init();
    const length = 128;
    _ = allocator.alloc(u8, length);

    const data = allocator.alloc(u8, 1);
    const left = @intFromPtr(data.ptr);
    const right = @intFromPtr(allocator.data.ptr) + length;
    try testing.expectEqual(left, right);
}


test "free from start" {
    var allocator = Allocator.init();
    const length = 128;
    const data = allocator.alloc(u8, length);
    @memset(data, 1); // set memory to non-zero value
    allocator.free(data);

    const new_data = allocator.alloc(u8, 10);
    try testing.expectEqual(@intFromPtr(new_data.ptr), @intFromPtr(allocator.data.ptr));
}


test "free from middle of data buffer" {
    var allocator = Allocator.init();
    const length = 32;

    // allocate memory chunks
    const start = allocator.alloc(u8, length);
    @memset(start, 1); // set memory to non-zero value
    const middle = allocator.alloc(u8, length);
    @memset(middle, 2); // set memory to non-zero value
    const end = allocator.alloc(u8, length);
    @memset(end, 3); // set memory to non-zero value

    // Free middle of the chunks -> create gap
    const middle_addr = middle.ptr;
    allocator.free(middle);

    // Allocate chunk that does not fit the gap
    const new_end = allocator.alloc(u8, length*2);
    try testing.expect(new_end.ptr != middle_addr);
    try testing.expectEqual(@intFromPtr(end.ptr)+length, @intFromPtr(new_end.ptr));

    // Allocate chunk that fits the gap
    const new_middle = allocator.alloc(u8, length);
    try testing.expectEqual(new_middle.ptr,  middle_addr);
}
