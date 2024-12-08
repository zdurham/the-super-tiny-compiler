const std = @import("std");
const mem = std.mem;

const TokenType = enum { paren, number, string, name, whitespace, illegal };

const Token = struct { type: TokenType, value: []const u8 };

fn isLetter(ch: u8) bool {
    return std.ascii.isAlphabetic(ch) or ch == '_';
}

fn isDigit(ch: u8) bool {
    return std.ascii.isDigit(ch);
}

pub fn tokenizer(allocator: mem.Allocator, input: []const u8) ![]Token {
    var current: u32 = 0;
    var tokens = std.ArrayList(Token).init(allocator);
    // defer tokens.deinit();
    while (current < input.len) {
        const char = input[current];
        const token = switch (char) {
            '(' => Token{ .type = TokenType.paren, .value = "(" },
            ')' => Token{ .type = TokenType.paren, .value = ")" },
            '0'...'9' => blk: {
                const start = current;
                var end = current;
                while (isDigit(input[end])) {
                    end += 1;
                }
                current = end - 1;
                break :blk Token{
                    .type = TokenType.number,
                    .value = input[start..end],
                };
            },
            ' ' => Token{ .type = TokenType.whitespace, .value = "" },
            else => Token{ .type = TokenType.illegal, .value = "" },
        };
        if (token.type != TokenType.illegal and token.type != TokenType.whitespace) {
            std.log.info("Token before appending: {s} ", .{token.value});
            try tokens.append(token);
        }
        current += 1;
    }
    return tokens.toOwnedSlice();
}

pub fn main() !void {
    const input = "(1234) (123)    (1)(5678)";
    const allocator = std.heap.page_allocator;
    const tokens = tokenizer(allocator, input) catch |err| {
        std.debug.print("oh jeez we fucked up somehow {}", .{err});
        return;
    };
    defer allocator.free(tokens);
}
test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
