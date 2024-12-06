const std = @import("std");

const TokenType = enum { paren, number, string, name };

const Token = struct { type: TokenType, value: []const u8 };

fn isLetter(ch: u8) bool {
    return std.ascii.isAlphabetic(ch) or ch == '_';
}

fn isDigit(ch: u8) bool {
    return std.ascii.isDigit(ch);
}

pub fn tokenizer(input: []const u8) std.ArrayList(Token) {
    var current: u32 = 0;
    var tokens = std.ArrayList(Token).init(std.heap.page_allocator);
    errdefer tokens.deinit();
    while (current < input.len) {
        const char = input[current];
        const token = switch (char) {
            '(' => Token{ .type = TokenType.paren, .value = "(" },
            ')' => Token{ .type = TokenType.paren, .value = ")" },
            0...9 => {
                const start = current;
                var end = current;
                while (isDigit(input[end])) {
                    end += 1;
                }
                current = end;
                return Token{
                    .type = TokenType.number,
                    .value = input[start..end],
                };
            },
            ' ' => continue,
            else => continue,
            // [0..9] =>
        };
        try tokens.append(token);
        current += 1;
    }
    return tokens;
}

pub fn main() !void {
    const input = "(1234)(123)(1)(5678)";
    const tokens = tokenizer(input);
    defer tokens.deinit();
    for (tokens.items) |token| {
        std.log.info("Token value: {}", .{token.value});
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
