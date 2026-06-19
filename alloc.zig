const std = @import("std");
const print = std.debug.print;

const offset_t = u64;

const init_data_size = 128;
const init_num_of_alloc_nodes = 10;
const init_free_spots_space = init_num_of_alloc_nodes;

/// Single allocation may not allocate more than max_bytes_single_alloc.
const max_bytes_single_alloc = 100;

const AllocError = error{
    FailedAlloc,
};

pub const Allocator = struct {
    data: []u8,

    /// start of Linked List in self.nodes
    /// It may be that element #0 is freed.
    ll_head: offset_t,
    nodes: []AllocNode,

    /// last inserted node.
    /// Does NOT count the number of nodes!
    sp: offset_t,

    /// Stack of freed_spots in self.nodes
    free_spots: []offset_t,
    /// Free spots stack pointer
    fs_sp: offset_t,

    pub fn init() Allocator {
        // allocate data buffer
        std.log.info("Initial allocation data: {} * {}", .{ init_data_size, @sizeOf(u8) });
        const ptr_data = map_memory(init_data_size * @sizeOf(u8));
        const data: []u8 = ptr_data[0..init_data_size];

        // allocate node buffer
        std.log.info("Initial allocation nodes: {} * {}", .{ init_num_of_alloc_nodes, @sizeOf(AllocNode) });
        const ptr_nodes = map_memory(init_num_of_alloc_nodes * @sizeOf(AllocNode));
        const nodes: []AllocNode = @ptrCast(@alignCast(ptr_nodes[0 .. init_num_of_alloc_nodes * @sizeOf(AllocNode)]));

        // allocate node buffer
        std.log.info("Initial allocation nodes: {} * {}", .{ init_num_of_alloc_nodes, @sizeOf(AllocNode) });
        const ptr_free_spots = map_memory(init_free_spots_space * @sizeOf(offset_t));
        const free_spots: []offset_t = @ptrCast(@alignCast(ptr_free_spots[0 .. init_free_spots_space * @sizeOf(offset_t)]));

        return Allocator{
            .data = data,
            .nodes = nodes,
            .sp = 0,
            .ll_head = 0,
            .free_spots = free_spots,
            .fs_sp = 0,
        };
    }

    /// Allocate a block of memory.
    ///
    /// Allocates n times sizeOf(T). Returns a slice of T with length n.
    pub fn alloc(self: *Allocator, comptime T: type, n: u64) []T {
        defer std.log.info("LL (sp={}): {any}", .{ self.sp, self.nodes[0..self.sp] });
        defer self.sp += 1;

        const byte_length = @sizeOf(T) * n;
        std.debug.assert(byte_length < max_bytes_single_alloc);

        // initial allocation
        if (self.sp == 0) {
            self.nodes[0] = AllocNode{ .start = 0, .length = byte_length, .next = 0 };
            const slice: []T = @ptrCast(@alignCast(self.data.ptr[0..byte_length]));
            return slice;
        } else if (self.sp == 1) {
            std.debug.assert(self.ll_head == 0);
            const start = self.nodes[0].start + self.nodes[0].length;
            self.nodes[0].next = 1;
            self.nodes[1] = AllocNode{ .start = start, .length = byte_length, .next = 0 };
            const slice: []T = @ptrCast(@alignCast(self.data.ptr[start .. start + byte_length]));
            return slice;
        }

        // iterate over free spaces
        var last: *AllocNode = &self.nodes[self.ll_head];
        var cur: *AllocNode = &self.nodes[last.next];
        var freed_space: u64 = 0;

        if (self.nodes[self.ll_head].start >= byte_length) {
            const start = 0;
            std.log.info("Enough space at beginning of data array", .{});
            self.nodes[self.sp] = AllocNode{ .start = start, .length = byte_length, .next = self.ll_head };
            self.ll_head = 0;
            const slice: []T = @ptrCast(@alignCast(self.data.ptr[start .. start + byte_length]));
            return slice;
        }

        while (cur.next != 0) : ({
            last = cur;
            cur = &self.nodes[cur.next];
        }) {
            freed_space = cur.start - (last.start + last.length);
            std.log.info("Freed space: {}", .{freed_space});
            if (freed_space >= byte_length) {
                const start = last.start + last.length;
                std.log.info("Found matching space @{}", .{last.start + last.length});
                std.log.info("last: {} -- cur: {}", .{ last, cur });
                self.nodes[self.sp] = AllocNode{ .start = start, .length = byte_length, .next = last.start };
                const slice: []T = @ptrCast(@alignCast(self.data.ptr[start .. start + byte_length]));
                return slice;
            }
        }

        // No space found in the middle of the data-array.
        // => allocate at the end of the array
        std.log.info("No freed space found. Appending to data array (no-array-resize).", .{});
        std.log.info("last: {any}, cur: {any}", .{ last, cur });
        std.debug.assert(self.sp < self.nodes.len);

        const start = cur.start + cur.length;
        self.nodes[self.sp] = AllocNode{ .start = start, .length = byte_length, .next = 0 };
        cur.*.next = self.sp;

        const slice: []T = @ptrCast(@alignCast(self.data.ptr[start .. start + byte_length]));
        return slice;
    }

    /// Free a previously allocated memory section.
    ///
    /// The requested freed section must be the exact same as allocated
    /// meaning that an allocated block must be freed in the same manner.
    pub fn free(self: *Allocator, memory: anytype) void {
        defer std.log.info("LL (sp={}): {any}", .{ self.sp, self.nodes[0..self.sp] });

        std.debug.assert(self.sp > 1);
        const bytes = std.mem.sliceAsBytes(memory);
        std.log.info("Mem len: {any}", .{bytes.len});

        var last: *AllocNode = &self.nodes[self.ll_head];
        var cur: *AllocNode = &self.nodes[last.next];
        var left, const right = .{ last.start + @intFromPtr(self.data.ptr), @intFromPtr(bytes.ptr) };

        // check for first entry in ll
        if (left == right) {
            std.log.info("Found AllocNode to free", .{});
            std.debug.assert(last.length == bytes.len);
            self.ll_head = last.next;
            @memset(self.data[last.start .. last.start + last.length], 0);
            return;
        }

        while (cur.next != 0) : ({
            last = cur;
            cur = &self.nodes[cur.next];
        }) {
            left = cur.start + @intFromPtr(self.data.ptr);
            if (left == right) {
                std.log.info("Found AllocNode to free", .{});
                std.debug.assert(cur.length == bytes.len);
                last.*.next = cur.next;
                @memset(self.data[cur.start .. cur.start + cur.length], 0);
                return;
            }
        }
        @panic("Requested block was not found");
    }

    /// Initial mapping
    fn map_memory(size: u64) [*]u8 {
        const r = std.os.linux.mmap(null, size, std.os.linux.PROT{ .READ = true, .WRITE = true }, std.os.linux.MAP{ .TYPE = std.os.linux.MAP_TYPE.SHARED, .ANONYMOUS = true }, -1, 0);

        // check for err
        const err = std.os.linux.errno(r);
        if (err != .SUCCESS) {
            std.log.info("Error: {}", .{err});
            @panic("Failed to allocate memory\n");
        }

        return @ptrFromInt(r);
    }
};

const AllocNode = struct {
    /// offset in Allocator.data to allocated block
    start: offset_t,

    /// length of allocated block
    length: u64,

    /// offset in Allocator.nodes to next AllocNode
    next: offset_t,
};
