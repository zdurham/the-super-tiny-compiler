const std = @import("std");
const compiler = @import("./tiny-compiler.zig");

const PROMPT = ">> ";

pub fn start() !void {
    const stdin = std.io.getStdIn().reader();
    std.debug.print(PROMPT, .{});

    var buffer = std.ArrayList(u8).init(std.heap.page_allocator);
    defer buffer.deinit();

    while (true) {
        try stdin.streamUntilDelimiter(buffer.writer(), '\n', 1028);
        const compiled = try compiler.compile(try buffer.toOwnedSlice());
        std.debug.print("Compiled: {s}\n", .{compiled});
        std.debug.print(PROMPT, .{});
    }
}
