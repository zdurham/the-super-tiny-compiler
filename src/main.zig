const std = @import("std");
const repl = @import("./repl.zig");

pub fn main() !void {
    std.debug.print("Type CTRL+C to exit: \n", .{});
    try repl.start();
}
